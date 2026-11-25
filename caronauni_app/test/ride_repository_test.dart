import 'package:caronauni/data/document_store.dart';
import 'package:caronauni/data/ride_repository.dart';
import 'package:caronauni/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late MemoryStore store;
  late RideRepository repo;

  const vehicle = Vehicle(model: 'Carro', color: 'Branco', plate: 'AAA0A00');
  const driver = AppUser(
    id: 'd',
    name: 'Dora Lima',
    email: 'd@sempreuninassau.com.br',
    vehicle: vehicle,
  );
  const ana = AppUser(
    id: 'ana',
    name: 'Ana Souza',
    email: 'ana@sempreuninassau.com.br',
  );
  const bia = AppUser(
    id: 'bia',
    name: 'Bia Reis',
    email: 'bia@sempreuninassau.com.br',
  );

  setUp(() {
    now = DateTime(2026, 11, 5, 10);
    store = MemoryStore();
    repo = RideRepository(store, clock: () => now);
  });

  RideDraft draft(
    DateTime departure, {
    String destination = 'Centro',
    int seats = 1,
    double price = 5,
    Set<int> weekdays = const {},
  }) => RideDraft(
    origin: 'Campus',
    originDetail: 'Portão',
    destination: destination,
    destinationDetail: 'Praça',
    departure: departure,
    durationMinutes: 30,
    seats: seats,
    price: price,
    weekdays: weekdays,
  );

  Future<Ride> offer(
    DateTime departure, {
    AppUser by = driver,
    String destination = 'Centro',
    int seats = 1,
  }) async {
    await repo.offer(
      by,
      draft(departure, destination: destination, seats: seats),
    );
    final mine = await repo.myRides(by.id);
    return mine
        .map((m) => m.ride)
        .firstWhere((r) => r.departure == departure);
  }

  Future<SeatRequest> ask(Ride ride, AppUser user) async {
    await repo.requestSeat(ride, user);
    return (await repo.request(ride.id, user.id))!;
  }

  Matcher fails([String? text]) => throwsA(
    isA<RideException>().having(
      (e) => e.message,
      'mensagem',
      text == null ? anything : contains(text),
    ),
  );

  group('oferta', () {
    test('exige veículo (RN02)', () {
      expect(repo.offer(ana, draft(DateTime(2026, 11, 5, 18))), fails('veículo'));
    });

    test('limita vagas e rateio (RN03 e RN04)', () async {
      final at = DateTime(2026, 11, 5, 18);
      await expectLater(repo.offer(driver, draft(at, seats: 5)), fails('vagas'));
      await expectLater(
        repo.offer(driver, draft(at, price: 30.01)),
        fails('30,00'),
      );
      await repo.offer(driver, draft(at, seats: 4, price: 30));
    });

    test('aceita de 1h a 7 dias de antecedência (RN05)', () async {
      await expectLater(
        repo.offer(driver, draft(now.add(const Duration(minutes: 59)))),
        fails('1h'),
      );
      await expectLater(
        repo.offer(driver, draft(now.add(const Duration(days: 7, minutes: 1)))),
        fails('7 dias'),
      );
      await repo.offer(driver, draft(now.add(const Duration(hours: 1))));
    });

    test('recorrente cria só os dias escolhidos e se renova', () async {
      // 5/11/2026 é quinta; segunda e quarta caem em 9 e 11.
      await repo.offer(
        driver,
        draft(DateTime(2026, 11, 5, 18), weekdays: {1, 3}),
      );
      Future<List<int>> days() async =>
          (await repo.myRides('d')).map((m) => m.ride.departure.day).toList();
      expect(await days(), [9, 11]);
      await repo.refreshRecurrences(driver);
      expect(await days(), [9, 11]);
      now = DateTime(2026, 11, 10, 10);
      await repo.refreshRecurrences(driver);
      expect(await days(), [9, 11, 16]);
      final docs = await repo.recurrences('d');
      await repo.stopRecurrence(docs.single.id);
      now = DateTime(2026, 11, 17, 10);
      await repo.refreshRecurrences(driver);
      expect(await days(), [9, 11, 16]);
    });
  });

  group('busca', () {
    Future<List<String>> destinations(RideQuery q) async =>
        (await repo.search(q)).map((r) => r.destination).toList();

    test('esconde lotadas, canceladas e passadas', () async {
      final full = await offer(DateTime(2026, 11, 5, 12), destination: 'Lotada');
      await repo.accept(await ask(full, ana));
      final gone = await offer(DateTime(2026, 11, 5, 14), destination: 'Cancel');
      await repo.cancelRide(gone, driver);
      await offer(DateTime(2026, 11, 5, 16), destination: 'Ok');
      expect(await destinations(const RideQuery()), ['Ok']);
      now = DateTime(2026, 11, 5, 17);
      expect(await destinations(const RideQuery()), isEmpty);
    });

    test('ignora acentos, filtra dia e horário e ordena', () async {
      await offer(DateTime(2026, 11, 6, 18), destination: 'São Sebastião');
      await offer(DateTime(2026, 11, 5, 17, 29), destination: 'Centro');
      await offer(DateTime(2026, 11, 5, 20), destination: 'Boa Vista');
      expect(await destinations(const RideQuery(destination: 'SAO seb')), [
        'São Sebastião',
      ]);
      expect(await destinations(const RideQuery(day: DayFilter.today)), [
        'Centro',
        'Boa Vista',
      ]);
      expect(await destinations(const RideQuery(day: DayFilter.tomorrow)), [
        'São Sebastião',
      ]);
      expect(await destinations(const RideQuery(minutesOfDay: 18 * 60)), [
        'São Sebastião',
      ]);
    });
  });

  test('matrícula repetida ou bloqueada é sinalizada', () async {
    Future<void> add(String id, String status) => store.set('approvals/$id', {
      'name': id,
      'course': 'Direito',
      'registration': '12345678',
      'status': status,
    });
    await add('a', 'pending');
    expect((await repo.pendingApprovals()).single.repeated, isFalse);
    await add('b', 'approved');
    expect((await repo.pendingApprovals()).single.repeated, isTrue);
    await store.delete('approvals/b');
    await store.set('blocks/b', {'name': 'b', 'registration': '12345678'});
    final request = (await repo.pendingApprovals()).single;
    expect(request.repeated, isTrue);
    await repo.resolveApproval(request, approve: false);
    expect(await repo.pendingApprovals(), isEmpty);
    expect((await store.get('approvals/a'))!['status'], 'refused');
  });

  group('pedidos', () {
    test('recusa a própria carona e horários sobrepostos', () async {
      final a = await offer(DateTime(2026, 11, 5, 18));
      await expectLater(repo.requestSeat(a, driver), fails('própria'));
      const other = AppUser(
        id: 'o',
        name: 'Otto Luz',
        email: 'o@sempreuninassau.com.br',
        vehicle: vehicle,
      );
      final overlap = await offer(DateTime(2026, 11, 5, 18, 29), by: other);
      final next = await offer(DateTime(2026, 11, 5, 19), by: other);
      await ask(a, ana);
      await expectLater(repo.requestSeat(overlap, ana), fails('horário'));
      await ask(next, ana);
    });

    test('só a aceitação ocupa vaga e nunca passa do limite', () async {
      final ride = await offer(DateTime(2026, 11, 5, 18));
      final first = await ask(ride, ana);
      final second = await ask(ride, bia);
      expect((await repo.ride(ride.id))!.takenSeats, 0);
      await repo.accept(first);
      expect((await repo.ride(ride.id))!.takenSeats, 1);
      await expectLater(repo.accept(second), fails('lotou'));
      await expectLater(repo.accept(first), fails('pendente'));
    });

    test('expira em 2h ou 30 min antes da saída (EX03)', () async {
      final late = await ask(await offer(DateTime(2026, 11, 5, 18)), ana);
      expect(
        late.statusAt(DateTime(2026, 11, 5, 12, 1)),
        RequestStatus.expired,
      );
      final near = await ask(await offer(DateTime(2026, 11, 5, 11)), bia);
      expect(
        near.statusAt(DateTime(2026, 11, 5, 10, 29)),
        RequestStatus.pending,
      );
      now = DateTime(2026, 11, 5, 10, 31);
      await expectLater(repo.accept(near), fails('pendente'));
    });

    test('telefone só aparece depois da aceitação (RNF06)', () async {
      await store.set('users/d/private/contact', {'phone': '81'});
      final ride = await offer(DateTime(2026, 11, 5, 18));
      final request = await ask(ride, ana);
      expect(await repo.phoneOf('d', 'ana'), isNull);
      await repo.accept(request);
      expect(await repo.phoneOf('d', 'ana'), '81');
      expect(await repo.phoneOf('d', 'bia'), isNull);
    });

    test('cancelar libera a vaga e avisa quem dirige', () async {
      final ride = await offer(DateTime(2026, 11, 5, 18));
      final request = await ask(ride, ana);
      await repo.accept(request);
      await repo.cancelRequest(request, ana);
      expect((await repo.ride(ride.id))!.takenSeats, 0);
      expect(await repo.faults('ana'), isEmpty);
      expect(
        (await repo.notices('d')).map((n) => n.text),
        contains(contains('cancelou')),
      );
    });

    test('cancelar a carona avisa os passageiros', () async {
      final ride = await offer(DateTime(2026, 11, 5, 18));
      await repo.accept(await ask(ride, ana));
      await repo.cancelRide(ride, driver);
      expect(
        (await repo.notices('ana')).map((n) => n.text),
        contains(contains('foi cancelada')),
      );
      expect(await repo.faults('d'), isEmpty);
    });
  });

  group('faltas e avaliação', () {
    test('cancelar com menos de 1h conta falta (RN09)', () async {
      final ride = await offer(DateTime(2026, 11, 5, 18));
      final request = await ask(ride, ana);
      await repo.accept(request);
      now = DateTime(2026, 11, 5, 17, 1);
      await repo.cancelRequest(request, ana);
      expect(await repo.faults('ana'), hasLength(1));
    });

    test('3 faltas em 30 dias suspendem por 15 (RN10)', () async {
      for (final (i, day) in [1, 10, 20].indexed) {
        await store.set('faults/$i', {
          'userId': 'ana',
          'userName': 'Ana',
          'reason': 'x',
          'createdAt': DateTime(2026, 10, day).millisecondsSinceEpoch,
          'status': 'active',
        });
      }
      now = DateTime(2026, 10, 21);
      expect(await repo.suspendedUntil('ana'), DateTime(2026, 11, 4));
      now = DateTime(2026, 11, 4);
      expect(await repo.suspendedUntil('ana'), isNull);
      now = DateTime(2026, 10, 21);
      final fault = (await repo.faults('ana')).first;
      await repo.resolveFault(fault, keep: false);
      expect(await repo.suspendedUntil('ana'), isNull);
    });

    test('contestação vale por 48h (EX07)', () async {
      final ride = await offer(DateTime(2026, 11, 5, 18));
      await repo.accept(await ask(ride, ana));
      now = DateTime(2026, 11, 5, 19);
      await repo.reportNoShow(
        ride: ride,
        from: driver,
        userId: 'ana',
        userName: 'Ana Souza',
      );
      final fault = (await repo.faults('ana')).single;
      now = DateTime(2026, 11, 7, 19, 1);
      await expectLater(repo.contest(fault), fails('48h'));
      now = DateTime(2026, 11, 7, 18);
      await repo.contest(fault);
      expect(await repo.contestedFaults(), hasLength(1));
    });

    test('avalia uma vez, só até 48h depois (RN12)', () async {
      final ride = await offer(DateTime(2026, 11, 5, 18));
      Future<void> rate() => repo.rate(
        ride: ride,
        from: ana,
        toId: 'd',
        stars: 4,
        text: 'Boa',
      );
      await expectLater(rate(), fails('48h'));
      now = DateTime(2026, 11, 5, 19);
      await rate();
      await expectLater(rate(), fails('já avaliou'));
      expect((await repo.reputation('d')).average, 4);
    });
  });

  test('admin bloqueia e o bloqueado não usa caronas', () async {
    await repo.report(from: ana, toId: 'd', toName: 'Dora', reason: 'x');
    final report = (await repo.openReports()).single;
    await repo.resolveReport(report, bia, block: true);
    expect(await repo.openReports(), isEmpty);
    await expectLater(
      repo.offer(driver, draft(DateTime(2026, 11, 5, 18))),
      fails('bloqueada'),
    );
    await repo.unblock('d');
    await repo.offer(driver, draft(DateTime(2026, 11, 5, 18)));
  });

  test('relatório conta destinos e lista médias baixas (RN11)', () async {
    await offer(DateTime(2026, 11, 5, 12));
    await offer(DateTime(2026, 11, 5, 14));
    await offer(DateTime(2026, 11, 5, 16), destination: 'Boa Vista');
    final usage = await repo.usage(days: 30);
    expect(usage.rideCount, 3);
    expect(usage.destinations.first.key, 'Centro');
    for (var i = 0; i < 5; i++) {
      await store.set('ratings/$i', {'toId': 'd', 'stars': 2});
      if (i < 4) await store.set('ratings/x$i', {'toId': 'ana', 'stars': 1});
    }
    expect((await repo.lowRated()).single.value, 2);
  });
}
