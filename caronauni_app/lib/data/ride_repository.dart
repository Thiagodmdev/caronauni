import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../models/models.dart';
import 'demo_data.dart';
import 'document_store.dart';
import 'ride_search.dart';

class RideException implements Exception {
  const RideException(this.message);

  final String message;
}

/// Regras de negócio das caronas, sobre qualquer [DocumentStore].
class RideRepository {
  RideRepository(
    this._store, {
    DateTime Function()? clock,
    this.searchLimit = 300,
  }) : _clock = clock ?? DateTime.now;

  static const int maxSeats = 4;
  static const double maxPrice = 30;
  static const Duration minNotice = Duration(hours: 1);
  static const int maxDaysAhead = 7;
  static const int faultLimit = 3;

  final DocumentStore _store;

  /// Máximo de caronas lidas por busca, para poupar rede e memória.
  final int searchLimit;
  final DateTime Function() _clock;
  final Map<String, Future<Reputation>> _reputations = {};

  DateTime get now => _clock();

  String _newId() =>
      '${_clock().microsecondsSinceEpoch.toRadixString(36)}'
      '${Random.secure().nextInt(1 << 30).toRadixString(36)}';

  int get _nowMs => _clock().millisecondsSinceEpoch;

  // Busca -------------------------------------------------------------------

  Future<List<Ride>> search(RideQuery query) async {
    final docs = await _store.query(
      'rides',
      atLeastField: 'departure',
      atLeast: _nowMs,
      limit: searchLimit,
    );
    return filterRides(
      docs.map((d) => Ride.fromJson(d.id, d.data)),
      query,
      _clock(),
    );
  }

  Future<Ride?> ride(String id) async {
    final json = await _store.get('rides/$id');
    return json == null ? null : Ride.fromJson(id, json);
  }

  /// Guardada em memória para a lista não repetir consultas por motorista.
  Future<Reputation> reputation(String userId) =>
      _reputations.putIfAbsent(userId, () async {
        final docs = await _store.query('ratings', where: {'toId': userId});
        return Reputation([
          for (final d in docs)
            Review(
              author: d.data['fromName'] as String,
              stars: d.data['stars'] as int,
              text: d.data['text'] as String,
            ),
        ]);
      });

  // CNH -----------------------------------------------------------------------

  /// Cabe em um documento do banco, que aceita até 1 MB.
  static const int maxLicensePhotoBytes = 600 * 1024;

  Future<Approval> licenseStatus(String userId) async {
    final json = await _store.get('licenses/$userId');
    return json == null
        ? Approval.missing
        : Approval.values.byName(json['status'] as String);
  }

  Future<void> sendLicense(AppUser user, Uint8List photo) async {
    if (photo.length > maxLicensePhotoBytes) {
      throw const RideException('A foto é muito grande. Tente outra.');
    }
    await _store.set('licenses/${user.id}', {
      'name': user.name,
      'photo': base64Encode(photo),
      'status': Approval.pending.name,
      'createdAt': _nowMs,
    });
  }

  Future<List<LicenseRequest>> pendingLicenses() async {
    final docs = await _store.query(
      'licenses',
      where: {'status': Approval.pending.name},
      limit: 10,
    );
    return [for (final d in docs) LicenseRequest.fromJson(d.id, d.data)];
  }

  /// A foto é apagada na decisão: só a situação fica guardada.
  Future<void> resolveLicense(
    LicenseRequest request,
    AppUser admin, {
    required bool approve,
  }) async {
    await _store.update('licenses/${request.userId}', {
      'status': (approve ? Approval.approved : Approval.refused).name,
      'photo': null,
    });
    await _notify(
      admin.id,
      request.userId,
      approve
          ? 'Sua CNH foi aprovada. Você já pode oferecer caronas.'
          : 'Sua CNH não foi aprovada. Envie outra foto.',
    );
  }

  // Oferta ------------------------------------------------------------------

  Future<void> offer(AppUser user, RideDraft draft) async {
    final vehicle = user.vehicle;
    if (vehicle == null) {
      throw const RideException('Cadastre seu veículo antes de oferecer carona.');
    }
    if (draft.seats < 1 || draft.seats > maxSeats) {
      throw const RideException('Ofereça de 1 a $maxSeats vagas.');
    }
    if (draft.price < 0 || draft.price > maxPrice) {
      throw const RideException('O rateio máximo é de R\$ 30,00 por pessoa.');
    }
    if (draft.origin.trim().isEmpty || draft.destination.trim().isEmpty) {
      throw const RideException('Informe a origem e o destino.');
    }
    if (await licenseStatus(user.id) != Approval.approved) {
      throw const RideException(
        'Sua CNH precisa ser aprovada antes de oferecer carona.',
      );
    }
    await _ensureAllowed(user.id);

    if (draft.weekdays.isNotEmpty) {
      final recurrenceId = _newId();
      final recurrence = {
        'driverId': user.id,
        'weekdays': draft.weekdays.toList()..sort(),
        'hour': draft.departure.hour,
        'minute': draft.departure.minute,
        'active': true,
        'ride': _rideFrom('', user, vehicle, draft, draft.departure).toJson(),
      };
      await _store.set('recurrences/$recurrenceId', recurrence);
      final created = await _generate(user, recurrenceId, recurrence);
      if (created == 0) {
        await _store.delete('recurrences/$recurrenceId');
        throw const RideException(
          'Nenhuma viagem pôde ser criada: confira os horários e conflitos.',
        );
      }
      return;
    }
    _checkNotice(draft.departure);
    final id = _newId();
    final ride = _rideFrom(id, user, vehicle, draft, draft.departure);
    await _ensureNoOverlap(user.id, ride);
    await _store.set('rides/$id', ride.toJson());
  }

  void _checkNotice(DateTime departure) {
    final now = _clock();
    if (departure.isBefore(now.add(minNotice))) {
      throw const RideException('A carona precisa de 1h de antecedência.');
    }
    if (departure.isAfter(now.add(const Duration(days: maxDaysAhead)))) {
      throw const RideException('A carona pode ser criada até 7 dias antes.');
    }
  }

  Ride _rideFrom(
    String id,
    AppUser user,
    Vehicle vehicle,
    RideDraft d,
    DateTime departure,
  ) => Ride(
    id: id,
    origin: d.origin.trim(),
    originDetail: d.originDetail.trim(),
    destination: d.destination.trim(),
    destinationDetail: d.destinationDetail.trim(),
    departure: departure,
    durationMinutes: d.durationMinutes,
    totalSeats: d.seats,
    takenSeats: 0,
    price: d.price,
    driver: Driver(id: user.id, name: user.name, course: user.course),
    vehicle: vehicle,
    originPoint: d.originPoint,
    destinationPoint: d.destinationPoint,
  );

  /// Cria as viagens recorrentes dos próximos 7 dias (RN05). Sem servidor no
  /// plano gratuito, roda quando quem dirige abre o app.
  Future<void> refreshRecurrences(AppUser user) async {
    final docs = await _store.query(
      'recurrences',
      where: {'driverId': user.id, 'active': true},
    );
    for (final doc in docs) {
      await _generate(user, doc.id, doc.data);
    }
  }

  Future<int> _generate(AppUser user, String id, Json recurrence) async {
    final now = _clock();
    final weekdays = List<int>.from(recurrence['weekdays'] as List);
    var created = 0;
    for (var i = 0; i <= maxDaysAhead; i++) {
      final departure = DateTime(
        now.year,
        now.month,
        now.day + i,
        recurrence['hour'] as int,
        recurrence['minute'] as int,
      );
      if (!weekdays.contains(departure.weekday) ||
          departure.isBefore(now.add(minNotice)) ||
          departure.isAfter(now.add(const Duration(days: maxDaysAhead)))) {
        continue;
      }
      final rideId = '${id}_${departure.year}-${departure.month}-${departure.day}';
      if (await _store.get('rides/$rideId') != null) continue;
      final json = {
        ...Json.from(recurrence['ride'] as Map),
        'departure': departure.millisecondsSinceEpoch,
      };
      try {
        await _ensureNoOverlap(user.id, Ride.fromJson(rideId, json));
      } on RideException {
        continue;
      }
      await _store.set('rides/$rideId', json);
      created++;
    }
    return created;
  }

  Future<List<Document>> recurrences(String userId) => _store.query(
    'recurrences',
    where: {'driverId': userId, 'active': true},
  );

  Future<void> stopRecurrence(String id) =>
      _store.update('recurrences/$id', {'active': false});

  // Pedidos -----------------------------------------------------------------

  Future<SeatRequest?> request(String rideId, String userId) async {
    // Consulta em vez de get: as regras negam a leitura de pedido inexistente.
    final docs = await _store.query(
      'requests',
      where: {'rideId': rideId, 'passengerId': userId},
    );
    return docs.isEmpty ? null : SeatRequest.fromJson(docs.first.data);
  }

  Future<void> requestSeat(Ride ride, AppUser user) async {
    if (ride.driver.id == user.id) {
      throw const RideException('Você não pode pedir vaga na própria carona.');
    }
    await _ensureAllowed(user.id);
    final current = await this.ride(ride.id);
    if (current == null || current.cancelled) {
      throw const RideException('Esta carona foi cancelada.');
    }
    if (!current.departure.isAfter(_clock())) {
      throw const RideException('Esta carona já saiu.');
    }
    // Depois disso o pedido já nasceria expirado (EX03).
    if (!current.departure
        .subtract(const Duration(minutes: 30))
        .isAfter(_clock())) {
      throw const RideException(
        'Os pedidos se encerram 30 minutos antes da saída.',
      );
    }
    if (current.availableSeats <= 0) {
      throw const RideException('Esta carona já está lotada.');
    }
    await _ensureNoOverlap(user.id, current);
    final request = SeatRequest(
      rideId: ride.id,
      driverId: ride.driver.id,
      passengerId: user.id,
      passengerName: user.name,
      passengerCourse: user.course,
      status: RequestStatus.pending,
      createdAt: _clock(),
      departure: current.departure,
    );
    await _store.set('requests/${request.id}', {
      'rideId': request.rideId,
      'driverId': request.driverId,
      'passengerId': request.passengerId,
      'passengerName': request.passengerName,
      'passengerCourse': request.passengerCourse,
      'status': request.status.name,
      'createdAt': _nowMs,
      'departure': current.departure.millisecondsSinceEpoch,
    });
    await _notify(
      user.id,
      ride.driver.id,
      '${user.name} pediu vaga para ${ride.destination}.',
    );
    // Não há ninguém para aceitar no lugar de um motorista de exemplo.
    if (isSample(ride.driver.id)) await accept(request);
  }

  Future<List<SeatRequest>> receivedRequests(String driverId) async {
    final docs = await _store.query('requests', where: {'driverId': driverId});
    return docs
        .map((d) => SeatRequest.fromJson(d.data))
        .where((r) => r.departure.isAfter(_clock()))
        .toList()
      ..sort((a, b) => a.departure.compareTo(b.departure));
  }

  Future<void> accept(SeatRequest request) async {
    await _store.transaction((tx) async {
      final rideJson = await tx.get('rides/${request.rideId}');
      final json = await tx.get('requests/${request.id}');
      if (rideJson == null || json == null || rideJson['cancelled'] as bool) {
        throw const RideException('Esta carona não está mais disponível.');
      }
      final fresh = SeatRequest.fromJson(json);
      if (fresh.statusAt(_clock()) != RequestStatus.pending) {
        throw const RideException('Este pedido não está mais pendente.');
      }
      final ride = Ride.fromJson(request.rideId, rideJson);
      if (ride.availableSeats <= 0) {
        throw const RideException('A carona já lotou.');
      }
      tx.update('rides/${ride.id}', {'takenSeats': ride.takenSeats + 1});
      tx.update('requests/${request.id}', {
        'status': RequestStatus.accepted.name,
      });
      // Libera o telefone de um para o outro (RNF06).
      for (final pair in [
        (request.driverId, request.passengerId),
        (request.passengerId, request.driverId),
      ]) {
        tx.set('connections/${pair.$1}_${pair.$2}', {
          'ownerId': pair.$1,
          'viewerId': pair.$2,
          'requestId': request.id,
        });
      }
    });
    await _notify(
      isSample(request.driverId) ? request.passengerId : request.driverId,
      request.passengerId,
      'Seu pedido de vaga foi aceito.',
    );
  }

  Future<void> refuse(SeatRequest request) async {
    await _store.update('requests/${request.id}', {
      'status': RequestStatus.refused.name,
    });
    await _notify(
      request.driverId,
      request.passengerId,
      'Seu pedido de vaga foi recusado.',
    );
  }

  /// Cancela o pedido ou a participação já aceita (RF13).
  Future<void> cancelRequest(SeatRequest request, AppUser user) async {
    final wasAccepted = await _store.transaction((tx) async {
      final rideJson = await tx.get('rides/${request.rideId}');
      final json = await tx.get('requests/${request.id}');
      if (json == null) throw const RideException('Pedido não encontrado.');
      final accepted = json['status'] == RequestStatus.accepted.name;
      tx.update('requests/${request.id}', {
        'status': RequestStatus.cancelled.name,
      });
      if (accepted && rideJson != null) {
        tx.update('rides/${request.rideId}', {
          'takenSeats': (rideJson['takenSeats'] as int) - 1,
        });
      }
      return accepted;
    });
    if (!wasAccepted) return;
    await _faultIfLate(request.rideId, request.departure, user);
    await _notify(
      user.id,
      request.driverId,
      '${user.name} cancelou a participação na carona.',
    );
  }

  Future<void> cancelRide(Ride ride, AppUser user) async {
    final requests = await _store.query(
      'requests',
      where: {'rideId': ride.id, 'driverId': user.id},
    );
    await _store.update('rides/${ride.id}', {'cancelled': true});
    var hadPassenger = false;
    for (final doc in requests) {
      final request = SeatRequest.fromJson(doc.data);
      final accepted = request.status == RequestStatus.accepted;
      hadPassenger = hadPassenger || accepted;
      if (accepted || request.status == RequestStatus.pending) {
        await _store.update('requests/${doc.id}', {
          'status': RequestStatus.refused.name,
        });
        await _notify(
          user.id,
          request.passengerId,
          'A carona para ${ride.destination} foi cancelada. '
          'Busque outra opção.',
        );
      }
    }
    if (hadPassenger) await _faultIfLate(ride.id, ride.departure, user);
  }

  Future<List<MyRide>> myRides(String userId) async {
    final driving = await _store.query('rides', where: {'driverId': userId});
    final requests = await _store.query(
      'requests',
      where: {'passengerId': userId},
    );
    final result = [
      for (final d in driving) MyRide(ride: Ride.fromJson(d.id, d.data)),
    ];
    for (final doc in requests) {
      final request = SeatRequest.fromJson(doc.data);
      final ride = await this.ride(request.rideId);
      if (ride == null) continue;
      result.add(
        MyRide(ride: ride, request: request, status: request.statusAt(_clock())),
      );
    }
    return result..sort((a, b) => a.ride.departure.compareTo(b.ride.departure));
  }

  Future<List<SeatRequest>> passengers(Ride ride) async {
    final docs = await _store.query(
      'requests',
      where: {'rideId': ride.id, 'driverId': ride.driver.id},
    );
    return docs
        .map((d) => SeatRequest.fromJson(d.data))
        .where((r) => r.status == RequestStatus.accepted)
        .toList();
  }

  Future<void> _ensureNoOverlap(String userId, Ride ride) async {
    for (final mine in await myRides(userId)) {
      final active = mine.isDriver
          ? !mine.ride.cancelled
          : mine.status == RequestStatus.pending ||
                mine.status == RequestStatus.accepted;
      if (active && mine.ride.id != ride.id && mine.ride.overlaps(ride)) {
        throw const RideException('Você já tem outra carona neste horário.');
      }
    }
  }

  /// Telefone de quem tem carona aceita com a pessoa; nulo se não houver.
  Future<String?> phoneOf(String ownerId, String viewerId) async {
    final links = await _store.query(
      'connections',
      where: {'ownerId': ownerId, 'viewerId': viewerId},
    );
    if (links.isEmpty) return null;
    final contact = await _store.get('users/$ownerId/private/contact');
    return contact?['phone'] as String?;
  }

  // Avaliação, faltas e denúncias ---------------------------------------------

  bool canRate(Ride ride) {
    final now = _clock();
    return !ride.cancelled &&
        now.isAfter(ride.departure) &&
        now.isBefore(ride.departure.add(const Duration(hours: 48)));
  }

  Future<void> rate({
    required Ride ride,
    required AppUser from,
    required String toId,
    required int stars,
    required String text,
  }) async {
    if (!canRate(ride)) {
      throw const RideException('A avaliação vale até 48h depois da carona.');
    }
    final id = '${ride.id}_${from.id}_$toId';
    if (await _store.get('ratings/$id') != null) {
      throw const RideException('Você já avaliou esta pessoa nesta carona.');
    }
    await _store.set('ratings/$id', {
      'rideId': ride.id,
      'fromId': from.id,
      'fromName': from.firstName,
      'toId': toId,
      'stars': stars,
      'text': text.trim(),
      'createdAt': _nowMs,
    });
    _reputations.remove(toId);
  }

  Future<void> reportNoShow({
    required Ride ride,
    required AppUser from,
    required String userId,
    required String userName,
  }) async {
    if (!canRate(ride)) {
      throw const RideException('A falta pode ser informada até 48h depois.');
    }
    await _addFault(ride.id, userId, userName, 'Não compareceu', from.id);
    await _notify(
      from.id,
      userId,
      'Uma falta foi registrada na carona para ${ride.destination}. '
      'Você pode contestar em até 48h no seu perfil.',
    );
  }

  Future<void> _faultIfLate(
    String rideId,
    DateTime departure,
    AppUser user,
  ) async {
    if (_clock().isBefore(departure.subtract(const Duration(hours: 1)))) return;
    await _addFault(
      rideId,
      user.id,
      user.name,
      'Cancelou com menos de 1h',
      user.id,
    );
  }

  Future<void> _addFault(
    String rideId,
    String userId,
    String userName,
    String reason,
    String by,
  ) async {
    final id = '${rideId}_${userId}_$by';
    if (await _store.get('faults/$id') != null) return;
    await _store.set('faults/$id', {
      'rideId': rideId,
      'userId': userId,
      'userName': userName,
      'reason': reason,
      'createdBy': by,
      'createdAt': _nowMs,
      'status': 'active',
    });
  }

  Future<List<Fault>> faults(String userId) async {
    final docs = await _store.query('faults', where: {'userId': userId});
    return docs.map((d) => Fault.fromJson(d.id, d.data)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> contest(Fault fault) async {
    if (_clock().isAfter(fault.createdAt.add(const Duration(hours: 48)))) {
      throw const RideException('O prazo de 48h para contestar terminou.');
    }
    await _store.update('faults/${fault.id}', {'status': 'contested'});
  }

  /// Fim da suspensão, se houver: 3 faltas em 30 dias suspendem 15 (RN10).
  Future<DateTime?> suspendedUntil(String userId) async {
    final valid = (await faults(
      userId,
    )).where((f) => f.status != 'dismissed').toList();
    DateTime? until;
    for (var i = faultLimit - 1; i < valid.length; i++) {
      final first = valid[i - faultLimit + 1].createdAt;
      final last = valid[i].createdAt;
      if (last.difference(first) <= const Duration(days: 30)) {
        until = last.add(const Duration(days: 15));
      }
    }
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  Future<void> _ensureAllowed(String userId) async {
    if (await isBlocked(userId)) {
      throw const RideException('Sua conta está bloqueada pela moderação.');
    }
    final until = await suspendedUntil(userId);
    if (until != null) {
      throw RideException(
        'Sua conta está suspensa até ${until.day}/${until.month}/${until.year}.',
      );
    }
  }

  Future<void> report({
    required AppUser from,
    required String toId,
    required String toName,
    required String reason,
  }) async {
    await _store.set('reports/${_newId()}', {
      'fromId': from.id,
      'fromName': from.name,
      'toId': toId,
      'toName': toName,
      'reason': reason.trim(),
      'status': 'open',
      'createdAt': _nowMs,
    });
  }

  // Administração -------------------------------------------------------------

  Future<bool> isBlocked(String userId) async =>
      await _store.get('blocks/$userId') != null;

  Future<List<ApprovalRequest>> pendingApprovals() async {
    final docs = await _store.query(
      'approvals',
      where: {'status': Approval.pending.name},
    );
    final result = <ApprovalRequest>[];
    for (final d in docs) {
      final registration = d.data['registration'] as String;
      final same = await _store.query(
        'approvals',
        where: {'registration': registration},
      );
      final blocked = await _store.query(
        'blocks',
        where: {'registration': registration},
      );
      result.add(
        ApprovalRequest(
          userId: d.id,
          name: d.data['name'] as String,
          course: d.data['course'] as String,
          registration: registration,
          repeated: blocked.isNotEmpty || same.any((s) => s.id != d.id),
        ),
      );
    }
    return result;
  }

  Future<void> resolveApproval(
    ApprovalRequest request, {
    required bool approve,
  }) => _store.update('approvals/${request.userId}', {
    'status': (approve ? Approval.approved : Approval.refused).name,
  });

  Future<List<Report>> openReports() async {
    final docs = await _store.query('reports', where: {'status': 'open'});
    return docs.map((d) => Report.fromJson(d.id, d.data)).toList();
  }

  Future<List<Fault>> contestedFaults() async {
    final docs = await _store.query('faults', where: {'status': 'contested'});
    return docs.map((d) => Fault.fromJson(d.id, d.data)).toList();
  }

  Future<void> resolveFault(Fault fault, {required bool keep}) =>
      _store.update('faults/${fault.id}', {
        'status': keep ? 'kept' : 'dismissed',
      });

  Future<void> resolveReport(
    Report report,
    AppUser admin, {
    required bool block,
  }) async {
    if (block) {
      final approval = await _store.get('approvals/${report.toId}');
      await _store.set('blocks/${report.toId}', {
        'name': report.toName,
        // Permite reconhecer a matrícula se a pessoa criar outra conta.
        'registration': approval?['registration'],
        'by': admin.id,
        'createdAt': _nowMs,
      });
    }
    await _store.update('reports/${report.id}', {
      'status': block ? 'blocked' : 'dismissed',
    });
  }

  Future<List<Document>> blockedUsers() => _store.query('blocks');

  Future<void> unblock(String userId) => _store.delete('blocks/$userId');

  Future<UsageReport> usage({required int days}) async {
    final since = _clock().subtract(Duration(days: days));
    final docs = await _store.query(
      'rides',
      atLeastField: 'departure',
      atLeast: since.millisecondsSinceEpoch,
      limit: 500,
    );
    final rides = docs
        .map((d) => Ride.fromJson(d.id, d.data))
        .where((r) => !r.cancelled);
    final counts = <String, int>{};
    for (final ride in rides) {
      counts.update(ride.destination, (n) => n + 1, ifAbsent: () => 1);
    }
    return UsageReport(
      rideCount: rides.length,
      destinations: counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Médias abaixo de 2,5 com 5 ou mais avaliações (RN11).
  Future<List<MapEntry<String, double>>> lowRated() async {
    final docs = await _store.query('ratings', limit: 500);
    final stars = <String, List<int>>{};
    for (final d in docs) {
      stars.putIfAbsent(d.data['toId'] as String, () => []).add(
        d.data['stars'] as int,
      );
    }
    final result = <MapEntry<String, double>>[];
    for (final entry in stars.entries) {
      final average = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (entry.value.length < 5 || average >= 2.5) continue;
      final user = await _store.get('users/${entry.key}');
      result.add(MapEntry(user?['name'] as String? ?? 'Usuário', average));
    }
    return result;
  }

  // Exemplos para apresentação ------------------------------------------------

  static bool isSample(String id) => id.startsWith('exemplo_');

  /// Cria (ou renova) caronas fictícias para os próximos dias.
  Future<void> addSamples() async {
    await removeSamples();
    final now = _clock();
    final writes = <Future<void>>[];
    final drivers = <String>{};
    for (final day in [0, 2, 4]) {
      for (final ride in buildDemoRides(now.add(Duration(days: day)))) {
        final driver = Driver(
          id: 'exemplo_${ride.driver.id}',
          name: '${ride.driver.name} (exemplo)',
          course: ride.driver.course,
        );
        writes.add(
          _store.set('rides/exemplo_${_nowMs}_${day}_${ride.id}', {
            ...ride.toJson(),
            'driverId': driver.id,
            'driverName': driver.name,
          }),
        );
        if (!drivers.add(driver.id)) continue;
        writes
          ..add(
            _store.set('users/${driver.id}', {
              'name': driver.name,
              'course': driver.course,
              'vehicle': ride.vehicle.toJson(),
            }),
          )
          ..add(
            _store.set('users/${driver.id}/private/contact', {
              'phone': '(81) 90000-000${drivers.length}',
            }),
          );
      }
    }
    for (final (i, r) in demoRatings.indexed) {
      writes.add(
        _store.set('ratings/exemplo_$i', {
          'rideId': 'exemplo_seed',
          'fromId': 'exemplo_seed$i',
          'fromName': r.$2,
          'toId': 'exemplo_${r.$1}',
          'stars': r.$3,
          'text': r.$4,
          'createdAt': now.millisecondsSinceEpoch,
        }),
      );
    }
    await Future.wait(writes);
    _reputations.clear();
  }

  Future<void> removeSamples() async {
    final deletes = <Future<void>>[];
    for (final id in {
      for (final ride in buildDemoRides(_clock())) 'exemplo_${ride.driver.id}',
    }) {
      final rides = await _store.query('rides', where: {'driverId': id});
      deletes
        ..addAll(rides.map((r) => _store.delete('rides/${r.id}')))
        ..add(_store.delete('users/$id/private/contact'))
        ..add(_store.delete('users/$id'));
    }
    for (var i = 0; i < demoRatings.length; i++) {
      deletes.add(_store.delete('ratings/exemplo_$i'));
    }
    await Future.wait(deletes);
    _reputations.clear();
  }

  // Avisos --------------------------------------------------------------------

  Future<void> _notify(String fromId, String toId, String text) async {
    if (isSample(toId)) return;
    await _store.set('notices/${_newId()}', {
      'fromId': fromId,
      'toId': toId,
      'text': text,
      'createdAt': _nowMs,
      'read': false,
    });
  }

  Future<List<AppNotice>> notices(String userId) async {
    final docs = await _store.query('notices', where: {'toId': userId});
    return [
      for (final d in docs)
        AppNotice(
          id: d.id,
          text: d.data['text'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            d.data['createdAt'] as int,
          ),
          read: d.data['read'] as bool,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> markRead(AppNotice notice) =>
      _store.update('notices/${notice.id}', {'read': true});

  /// Dados da pessoa em um só lugar, para a cópia pedida pela LGPD.
  Future<Json> export(AppUser user) async {
    Future<List<Json>> all(String collection, String field) async => [
      for (final d in await _store.query(collection, where: {field: user.id}))
        d.data,
    ];
    return {
      'perfil': {
        'nome': user.name,
        'email': user.email,
        'telefone': user.phone,
        'curso': user.course,
        'matricula': user.registration,
        'cnh': (await licenseStatus(user.id)).name,
        'veiculo': user.vehicle?.toJson(),
      },
      'caronas': await all('rides', 'driverId'),
      'pedidos': await all('requests', 'passengerId'),
      'avaliacoes_feitas': await all('ratings', 'fromId'),
      'faltas': await all('faults', 'userId'),
    };
  }
}
