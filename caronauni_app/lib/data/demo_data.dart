import '../models/models.dart';
import 'auth_repository.dart';
import 'document_store.dart';

const _argo = Vehicle(model: 'Fiat Argo', color: 'Branco', plate: 'BRA2E19');
const _onix = Vehicle(model: 'Chevrolet Onix', color: 'Prata', plate: 'QXA4B21');
const _hb20 = Vehicle(model: 'Hyundai HB20', color: 'Preto', plate: 'RTC7D55');
const _polo = Vehicle(model: 'Volkswagen Polo', color: 'Cinza', plate: 'PLK3F08');

const _marina = Driver(
  id: 'marina',
  name: 'Marina Duarte',
  course: 'Engenharia de Software',
);
const _rafael = Driver(
  id: 'rafael',
  name: 'Rafael Nogueira',
  course: 'Administração',
);
const _juliana = Driver(
  id: 'juliana',
  name: 'Juliana Prado',
  course: 'Enfermagem',
);
const _bruno = Driver(id: 'bruno', name: 'Bruno Teixeira', course: 'Direito');

// Posições aproximadas, só para ilustrar o mapa.
const _campusPoint = GeoPoint(-5.0756, -42.7903);

/// Caronas de exemplo, sempre no futuro em relação a [now].
List<Ride> buildDemoRides(DateTime now) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
  ).add(const Duration(hours: 1));
  // Longe o bastante para o pedido de vaga não nascer expirado.
  DateTime soon(int minutes) => start.add(Duration(minutes: minutes + 45));
  DateTime onDay(int offset, int hour, int minute) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);

  Ride ride(
    String id,
    Driver driver,
    Vehicle vehicle,
    DateTime departure,
    String destination,
    String detail,
    int duration,
    int total,
    int taken,
    double price, {
    GeoPoint? point,
    String origin = 'Campus Central',
    String originDetail = 'Portão principal',
    GeoPoint? originPoint = _campusPoint,
  }) => Ride(
    id: id,
    origin: origin,
    originDetail: originDetail,
    destination: destination,
    destinationDetail: detail,
    departure: departure,
    durationMinutes: duration,
    totalSeats: total,
    takenSeats: taken,
    price: price,
    driver: driver,
    vehicle: vehicle,
    originPoint: originPoint,
    destinationPoint: point,
  );

  return [
    ride('r1', _marina, _argo, soon(0), 'Jardim América', 'Praça das Flores',
        25, 3, 1, 8,
        point: const GeoPoint(-5.0603, -42.8121)),
    ride('r2', _rafael, _onix, soon(30), 'Centro', 'Terminal Central', 20, 4, 1,
        6.5,
        point: const GeoPoint(-5.0898, -42.8131)),
    ride('r3', _juliana, _hb20, soon(75), 'Vila Nova', 'Av. das Palmeiras', 35,
        2, 0, 10,
        point: const GeoPoint(-5.1103, -42.8021)),
    // Carona lotada: não aparece na busca.
    ride('r4', _bruno, _polo, soon(90), 'Boa Vista', 'Shopping Boa Vista', 30,
        3, 3, 9),
    ride('r5', _bruno, _polo, onDay(1, 7, 0), 'Campus Central',
        'Portão principal', 30, 4, 2, 9,
        point: _campusPoint,
        origin: 'Boa Vista',
        originDetail: 'Shopping Boa Vista',
        originPoint: const GeoPoint(-5.0803, -42.7721)),
    ride('r6', _marina, _argo, onDay(1, 18, 0), 'Jardim América',
        'Praça das Flores', 25, 3, 0, 8,
        point: const GeoPoint(-5.0603, -42.8121)),
    ride('r7', _juliana, _hb20, onDay(1, 18, 20), 'São Sebastião',
        'Rua das Acácias', 40, 3, 1, 12),
    ride('r8', _rafael, _onix, onDay(2, 12, 30), 'Centro', 'Terminal Central',
        20, 4, 0, 6.5,
        point: const GeoPoint(-5.0898, -42.8131)),
  ];
}

/// (id de quem recebeu, quem avaliou, estrelas, texto).
const demoRatings = [
  ('marina', 'Lucas', 5, 'Pontual e muito cuidadosa no trânsito.'),
  ('marina', 'Bianca', 5, 'Avisou com antecedência onde me buscar.'),
  ('rafael', 'Camila', 5, 'Carro limpo e viagem tranquila.'),
  ('rafael', 'Pedro', 4, 'Saiu 5 minutos depois, mas avisou.'),
  ('juliana', 'Tiago', 5, 'Super simpática e organizada.'),
  ('bruno', 'Ana', 4, 'Boa carona, deixou perto de casa.'),
];

Future<void> seedDemo(DocumentStore store, DateTime now) async {
  final profiles = ProfileStore(store);
  const people = [
    AppUser(
      id: 'demo',
      name: 'Conta Demonstração',
      email: MockAuthRepository.demoEmail,
      course: 'Ciência da Computação',
      phone: '(86) 90000-0001',
    ),
    AppUser(
      id: 'marina',
      name: 'Marina Duarte',
      email: MockAuthRepository.driverEmail,
      course: 'Engenharia de Software',
      phone: '(86) 90000-0002',
      vehicle: _argo,
    ),
    AppUser(
      id: 'admin',
      name: 'Administração Demo',
      email: MockAuthRepository.adminEmail,
      course: 'Moderação',
    ),
  ];
  for (final person in people) {
    await profiles.save(person);
  }
  await store.set('admins/admin', {'demo': true});
  for (final (id, name, course, registration, status) in [
    ('demo', 'Conta Demonstração', 'Ciência da Computação', '10000001',
        Approval.approved),
    ('marina', 'Marina Duarte', 'Engenharia de Software', '10000002',
        Approval.approved),
    ('carla', 'Carla Mendes', 'Psicologia', '10000003', Approval.pending),
  ]) {
    await store.set('approvals/$id', {
      'name': name,
      'course': course,
      'registration': registration,
      'status': status.name,
      'createdAt': now.millisecondsSinceEpoch,
    });
  }

  await store.set('licenses/marina', {
    'name': 'Marina Duarte',
    'photo': null,
    'status': Approval.approved.name,
    'createdAt': now.millisecondsSinceEpoch,
  });
  for (final ride in buildDemoRides(now)) {
    await store.set('rides/${ride.id}', ride.toJson());
  }

  // Carona já feita, para mostrar a avaliação e o registro de falta.
  final past = buildDemoRides(now.subtract(const Duration(hours: 4))).first;
  await store.set('rides/past', past.toJson());
  await store.set('requests/past_demo', {
    'rideId': 'past',
    'driverId': 'marina',
    'passengerId': 'demo',
    'passengerName': 'Conta Demonstração',
    'passengerCourse': 'Ciência da Computação',
    'status': RequestStatus.accepted.name,
    'createdAt': now
        .subtract(const Duration(hours: 6))
        .millisecondsSinceEpoch,
    'departure': past.departure.millisecondsSinceEpoch,
  });

  for (final (i, r) in demoRatings.indexed) {
    await store.set('ratings/seed$i', {
      'rideId': 'seed',
      'fromId': 'seed$i',
      'fromName': r.$2,
      'toId': r.$1,
      'stars': r.$3,
      'text': r.$4,
      'createdAt': now.millisecondsSinceEpoch,
    });
  }
  await store.set('reports/seed', {
    'fromId': 'demo',
    'fromName': 'Conta Demonstração',
    'toId': 'bruno',
    'toName': 'Bruno Teixeira',
    'reason': 'Dirigiu acima da velocidade.',
    'status': 'open',
    'createdAt': now.millisecondsSinceEpoch,
  });
}
