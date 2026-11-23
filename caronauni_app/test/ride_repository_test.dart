import 'package:caronauni/data/ride_repository.dart';
import 'package:caronauni/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 10, 0);

  const driver = Driver(
    id: 'motorista',
    name: 'Motorista Teste',
    course: 'Curso',
    rating: 5,
    ratingCount: 1,
  );
  const vehicle = Vehicle(model: 'Carro', color: 'Branco', plate: 'AAA0A00');

  Ride ride(
    String id,
    DateTime departure, {
    String destination = 'Centro',
    int taken = 0,
    int duration = 30,
  }) {
    return Ride(
      id: id,
      origin: 'Campus',
      originDetail: '',
      destination: destination,
      destinationDetail: '',
      departure: departure,
      durationMinutes: duration,
      totalSeats: 3,
      takenSeats: taken,
      price: 5,
      driver: driver,
      vehicle: vehicle,
    );
  }

  MockRideRepository repo(List<Ride> rides) => MockRideRepository(
    clock: () => now,
    latency: Duration.zero,
    rides: rides,
  );

  Future<List<String>> ids(RideRepository r, RideQuery q) async =>
      (await r.search(q)).map((e) => e.id).toList();

  group('busca', () {
    test('esconde caronas passadas e lotadas', () async {
      final r = repo([
        ride('passada', now.subtract(const Duration(minutes: 1))),
        ride('lotada', now.add(const Duration(hours: 2)), taken: 3),
        ride('ok', now.add(const Duration(hours: 2))),
      ]);
      expect(await ids(r, const RideQuery()), ['ok']);
    });

    test('ignora acentos e maiúsculas no destino', () async {
      final r = repo([
        ride('a', now.add(const Duration(hours: 1)), destination: 'São Sebastião'),
        ride('b', now.add(const Duration(hours: 1)), destination: 'Centro'),
      ]);
      expect(await ids(r, const RideQuery(destination: 'SAO seb')), ['a']);
    });

    test('filtra por hoje e amanhã', () async {
      final r = repo([
        ride('hoje', DateTime(2026, 11, 5, 18)),
        ride('amanha', DateTime(2026, 11, 6, 18)),
        ride('depois', DateTime(2026, 11, 7, 18)),
      ]);
      expect(await ids(r, const RideQuery(day: DayFilter.today)), ['hoje']);
      expect(await ids(r, const RideQuery(day: DayFilter.tomorrow)), ['amanha']);
    });

    test('aceita até 30 minutos em torno do horário buscado', () async {
      final r = repo([
        ride('antes', DateTime(2026, 11, 5, 17, 30)),
        ride('fora', DateTime(2026, 11, 5, 17, 29)),
        ride('depois', DateTime(2026, 11, 5, 18, 30)),
      ]);
      expect(
        await ids(r, const RideQuery(minutesOfDay: 18 * 60)),
        ['antes', 'depois'],
      );
    });

    test('ordena pela saída mais próxima', () async {
      final r = repo([
        ride('tarde', DateTime(2026, 11, 5, 20)),
        ride('cedo', DateTime(2026, 11, 5, 12)),
      ]);
      expect(await ids(r, const RideQuery()), ['cedo', 'tarde']);
    });
  });

  group('pedido de vaga', () {
    test('registra e cancela o pedido', () async {
      final c = ride('c', DateTime(2026, 11, 5, 18));
      final r = repo([c]);
      await r.requestSeat(ride: c, userId: 'u');
      expect(await r.hasRequested(rideId: 'c', userId: 'u'), isTrue);
      await r.cancelRequest(rideId: 'c', userId: 'u');
      expect(await r.hasRequested(rideId: 'c', userId: 'u'), isFalse);
    });

    test('recusa pedido na própria carona (RN07)', () async {
      final c = ride('c', DateTime(2026, 11, 5, 18));
      expect(
        () => repo([c]).requestSeat(ride: c, userId: driver.id),
        throwsA(isA<RideRequestException>()),
      );
    });

    test('recusa carona lotada', () async {
      final c = ride('c', DateTime(2026, 11, 5, 18), taken: 3);
      expect(
        () => repo([c]).requestSeat(ride: c, userId: 'u'),
        throwsA(isA<RideRequestException>()),
      );
    });

    test('recusa horários sobrepostos, mas aceita em sequência (RN08)', () async {
      final a = ride('a', DateTime(2026, 11, 5, 18));
      final sobreposta = ride('b', DateTime(2026, 11, 5, 18, 29));
      final seguinte = ride('c', DateTime(2026, 11, 5, 18, 30));
      final r = repo([a, sobreposta, seguinte]);
      await r.requestSeat(ride: a, userId: 'u');
      expect(
        () => r.requestSeat(ride: sobreposta, userId: 'u'),
        throwsA(isA<RideRequestException>()),
      );
      await r.requestSeat(ride: seguinte, userId: 'u');
      expect(await r.hasRequested(rideId: 'c', userId: 'u'), isTrue);
    });
  });
}
