import '../models/models.dart';

const _marina = Driver(
  id: 'marina',
  name: 'Marina Duarte',
  course: 'Engenharia de Software',
  rating: 4.9,
  ratingCount: 47,
  reviews: [
    Review(
      author: 'Lucas',
      stars: 5,
      text: 'Pontual e muito cuidadosa no trânsito.',
    ),
    Review(
      author: 'Bianca',
      stars: 5,
      text: 'Avisou com antecedência onde me buscar.',
    ),
  ],
);

const _rafael = Driver(
  id: 'rafael',
  name: 'Rafael Nogueira',
  course: 'Administração',
  rating: 4.6,
  ratingCount: 23,
  reviews: [
    Review(author: 'Camila', stars: 5, text: 'Carro limpo e viagem tranquila.'),
    Review(author: 'Pedro', stars: 4, text: 'Saiu 5 minutos depois, mas avisou.'),
  ],
);

const _juliana = Driver(
  id: 'juliana',
  name: 'Juliana Prado',
  course: 'Enfermagem',
  rating: 4.8,
  ratingCount: 31,
  reviews: [
    Review(author: 'Tiago', stars: 5, text: 'Super simpática e organizada.'),
  ],
);

const _bruno = Driver(
  id: 'bruno',
  name: 'Bruno Teixeira',
  course: 'Direito',
  rating: 4.3,
  ratingCount: 12,
  reviews: [
    Review(author: 'Ana', stars: 4, text: 'Boa carona, deixou perto de casa.'),
  ],
);

const _argo = Vehicle(model: 'Fiat Argo', color: 'Branco', plate: 'BRA2E19');
const _onix = Vehicle(model: 'Chevrolet Onix', color: 'Prata', plate: 'QXA4B21');
const _hb20 = Vehicle(model: 'Hyundai HB20', color: 'Preto', plate: 'RTC7D55');
const _polo = Vehicle(model: 'Volkswagen Polo', color: 'Cinza', plate: 'PLK3F08');

const _campus = 'Campus Central';
const _campusDetail = 'Portão principal';

/// Dados de exemplo, calculados a partir de [now] para sempre haver caronas
/// futuras durante a demonstração.
List<Ride> buildMockRides(DateTime now) {
  final start = DateTime(now.year, now.month, now.day, now.hour)
      .add(const Duration(hours: 1));
  DateTime soon(int minutes) => start.add(Duration(minutes: minutes + 15));
  DateTime onDay(int offset, int hour, int minute) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);

  Ride ride(
    String id,
    Driver driver,
    Vehicle vehicle,
    DateTime departure, {
    required String destination,
    required String detail,
    required int duration,
    required int total,
    required int taken,
    required double price,
    String origin = _campus,
    String originDetail = _campusDetail,
  }) {
    return Ride(
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
    );
  }

  return [
    ride('r1', _marina, _argo, soon(0),
        destination: 'Jardim América',
        detail: 'Praça das Flores',
        duration: 25,
        total: 3,
        taken: 1,
        price: 8),
    ride('r2', _rafael, _onix, soon(30),
        destination: 'Centro',
        detail: 'Terminal Central',
        duration: 20,
        total: 4,
        taken: 1,
        price: 6.5),
    ride('r3', _juliana, _hb20, soon(75),
        destination: 'Vila Nova',
        detail: 'Av. das Palmeiras',
        duration: 35,
        total: 2,
        taken: 0,
        price: 10),
    // Carona lotada: não aparece na busca.
    ride('r4', _bruno, _polo, soon(90),
        destination: 'Boa Vista',
        detail: 'Shopping Boa Vista',
        duration: 30,
        total: 3,
        taken: 3,
        price: 9),
    ride('r5', _bruno, _polo, onDay(1, 7, 0),
        destination: _campus,
        detail: _campusDetail,
        origin: 'Boa Vista',
        originDetail: 'Shopping Boa Vista',
        duration: 30,
        total: 4,
        taken: 2,
        price: 9),
    ride('r6', _marina, _argo, onDay(1, 18, 0),
        destination: 'Jardim América',
        detail: 'Praça das Flores',
        duration: 25,
        total: 3,
        taken: 0,
        price: 8),
    ride('r7', _juliana, _hb20, onDay(1, 18, 20),
        destination: 'São Sebastião',
        detail: 'Rua das Acácias',
        duration: 40,
        total: 3,
        taken: 1,
        price: 12),
    ride('r8', _rafael, _onix, onDay(2, 12, 30),
        destination: 'Centro',
        detail: 'Terminal Central',
        duration: 20,
        total: 4,
        taken: 0,
        price: 6.5),
  ];
}
