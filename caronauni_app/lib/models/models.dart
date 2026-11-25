import 'dart:convert';
import 'dart:typed_data';

import '../data/document_store.dart';

/// Situação da matrícula: só quem foi aprovado usa as caronas.
enum Approval { missing, pending, approved, refused }

/// Cadastro esperando a conferência da matrícula pela administração.
class ApprovalRequest {
  const ApprovalRequest({
    required this.userId,
    required this.name,
    required this.course,
    required this.registration,
    required this.repeated,
  });

  final String userId;
  final String name;
  final String course;
  final String registration;

  /// A matrícula já aparece em outra conta, aprovada ou bloqueada.
  final bool repeated;
}

/// CNH esperando a conferência da administração.
class LicenseRequest {
  const LicenseRequest({
    required this.userId,
    required this.name,
    required this.photo,
  });

  factory LicenseRequest.fromJson(String id, Json json) => LicenseRequest(
    userId: id,
    name: json['name'] as String,
    photo: base64Decode(json['photo'] as String),
  );

  final String userId;
  final String name;
  final Uint8List photo;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.course = '',
    this.phone = '',
    this.vehicle,
    this.isAdmin = false,
    this.registration = '',
    this.approval = Approval.missing,
  });

  final String id;
  final String name;
  final String email;
  final String course;
  final String phone;
  final Vehicle? vehicle;
  final bool isAdmin;
  final String registration;
  final Approval approval;

  bool get isMember => isAdmin || approval == Approval.approved;

  String get firstName => name.split(RegExp(r'\s+')).first;

  AppUser copyWith({
    String? name,
    String? course,
    String? phone,
    Vehicle? vehicle,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email,
    course: course ?? this.course,
    phone: phone ?? this.phone,
    vehicle: vehicle ?? this.vehicle,
    isAdmin: isAdmin,
    registration: registration,
    approval: approval,
  );
}

class SignUpData {
  const SignUpData({
    required this.name,
    required this.email,
    required this.phone,
    required this.course,
    required this.registration,
    required this.password,
  });

  final String name;
  final String email;
  final String phone;
  final String course;
  final String registration;
  final String password;
}

class Review {
  const Review({required this.author, required this.stars, required this.text});

  final String author;
  final int stars;
  final String text;
}

class Reputation {
  const Reputation(this.reviews);

  final List<Review> reviews;

  int get count => reviews.length;

  double? get average => reviews.isEmpty
      ? null
      : reviews.fold<int>(0, (sum, r) => sum + r.stars) / reviews.length;
}

class Driver {
  const Driver({required this.id, required this.name, required this.course});

  final String id;
  final String name;
  final String course;
}

class Vehicle {
  const Vehicle({required this.model, required this.color, required this.plate});

  factory Vehicle.fromJson(Json json) => Vehicle(
    model: json['model'] as String,
    color: json['color'] as String,
    plate: json['plate'] as String,
  );

  final String model;
  final String color;
  final String plate;

  Json toJson() => {'model': model, 'color': color, 'plate': plate};
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  static GeoPoint? fromJson(Object? json) => json is Map
      ? GeoPoint((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble())
      : null;

  final double lat;
  final double lng;

  Json toJson() => {'lat': lat, 'lng': lng};
}

class Ride {
  const Ride({
    required this.id,
    required this.origin,
    required this.originDetail,
    required this.destination,
    required this.destinationDetail,
    required this.departure,
    required this.durationMinutes,
    required this.totalSeats,
    required this.takenSeats,
    required this.price,
    required this.driver,
    required this.vehicle,
    this.originPoint,
    this.destinationPoint,
    this.cancelled = false,
  });

  factory Ride.fromJson(String id, Json json) => Ride(
    id: id,
    origin: json['origin'] as String,
    originDetail: json['originDetail'] as String,
    destination: json['destination'] as String,
    destinationDetail: json['destinationDetail'] as String,
    departure: DateTime.fromMillisecondsSinceEpoch(json['departure'] as int),
    durationMinutes: json['durationMinutes'] as int,
    totalSeats: json['totalSeats'] as int,
    takenSeats: json['takenSeats'] as int,
    price: (json['price'] as num).toDouble(),
    driver: Driver(
      id: json['driverId'] as String,
      name: json['driverName'] as String,
      course: json['driverCourse'] as String,
    ),
    vehicle: Vehicle.fromJson(Json.from(json['vehicle'] as Map)),
    originPoint: GeoPoint.fromJson(json['originPoint']),
    destinationPoint: GeoPoint.fromJson(json['destinationPoint']),
    cancelled: json['cancelled'] as bool,
  );

  final String id;
  final String origin;
  final String originDetail;
  final String destination;
  final String destinationDetail;
  final DateTime departure;
  final int durationMinutes;
  final int totalSeats;
  final int takenSeats;
  final double price;
  final Driver driver;
  final Vehicle vehicle;
  final GeoPoint? originPoint;
  final GeoPoint? destinationPoint;
  final bool cancelled;

  int get availableSeats => totalSeats - takenSeats;

  DateTime get arrival => departure.add(Duration(minutes: durationMinutes));

  bool overlaps(Ride other) =>
      departure.isBefore(other.arrival) && other.departure.isBefore(arrival);

  Json toJson() => {
    'origin': origin,
    'originDetail': originDetail,
    'destination': destination,
    'destinationDetail': destinationDetail,
    'departure': departure.millisecondsSinceEpoch,
    'durationMinutes': durationMinutes,
    'totalSeats': totalSeats,
    'takenSeats': takenSeats,
    'price': price,
    'driverId': driver.id,
    'driverName': driver.name,
    'driverCourse': driver.course,
    'vehicle': vehicle.toJson(),
    'originPoint': originPoint?.toJson(),
    'destinationPoint': destinationPoint?.toJson(),
    'cancelled': cancelled,
  };
}

/// Dados preenchidos por quem oferece a carona.
class RideDraft {
  const RideDraft({
    required this.origin,
    required this.originDetail,
    required this.destination,
    required this.destinationDetail,
    required this.departure,
    required this.durationMinutes,
    required this.seats,
    required this.price,
    this.weekdays = const {},
    this.originPoint,
    this.destinationPoint,
  });

  final String origin;
  final String originDetail;
  final String destination;
  final String destinationDetail;
  final DateTime departure;
  final int durationMinutes;
  final int seats;
  final double price;

  /// Dias da semana (1 = segunda) quando a carona é recorrente.
  final Set<int> weekdays;
  final GeoPoint? originPoint;
  final GeoPoint? destinationPoint;
}

enum RequestStatus { pending, accepted, refused, cancelled, expired }

class SeatRequest {
  const SeatRequest({
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerCourse,
    required this.status,
    required this.createdAt,
    required this.departure,
  });

  factory SeatRequest.fromJson(Json json) => SeatRequest(
    rideId: json['rideId'] as String,
    driverId: json['driverId'] as String,
    passengerId: json['passengerId'] as String,
    passengerName: json['passengerName'] as String,
    passengerCourse: json['passengerCourse'] as String,
    status: RequestStatus.values.byName(json['status'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    departure: DateTime.fromMillisecondsSinceEpoch(json['departure'] as int),
  );

  final String rideId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String passengerCourse;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime departure;

  String get id => '${rideId}_$passengerId';

  /// Expira em 2h ou 30 min antes da saída, o que vier primeiro (EX03).
  RequestStatus statusAt(DateTime now) {
    if (status != RequestStatus.pending) return status;
    final byAge = createdAt.add(const Duration(hours: 2));
    final byDeparture = departure.subtract(const Duration(minutes: 30));
    final limit = byAge.isBefore(byDeparture) ? byAge : byDeparture;
    return now.isAfter(limit) ? RequestStatus.expired : status;
  }
}

class MyRide {
  const MyRide({required this.ride, this.request, this.status});

  final Ride ride;

  /// Nulo quando a pessoa é quem dirige.
  final SeatRequest? request;
  final RequestStatus? status;

  bool get isDriver => request == null;
}

class Fault {
  const Fault({
    required this.id,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.createdAt,
    required this.status,
  });

  factory Fault.fromJson(String id, Json json) => Fault(
    id: id,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    reason: json['reason'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    status: json['status'] as String,
  );

  final String id;
  final String userId;
  final String userName;
  final String reason;
  final DateTime createdAt;

  /// active, contested, kept ou dismissed.
  final String status;
}

class Report {
  const Report({
    required this.id,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.reason,
    required this.status,
  });

  factory Report.fromJson(String id, Json json) => Report(
    id: id,
    fromName: json['fromName'] as String,
    toId: json['toId'] as String,
    toName: json['toName'] as String,
    reason: json['reason'] as String,
    status: json['status'] as String,
  );

  final String id;
  final String fromName;
  final String toId;
  final String toName;
  final String reason;
  final String status;
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final bool read;
}

class UsageReport {
  const UsageReport({required this.rideCount, required this.destinations});

  final int rideCount;
  final List<MapEntry<String, int>> destinations;
}

enum DayFilter { all, today, tomorrow }

class RideQuery {
  const RideQuery({
    this.destination = '',
    this.day = DayFilter.all,
    this.minutesOfDay,
  });

  final String destination;
  final DayFilter day;

  /// Horário desejado em minutos desde 00:00; nulo aceita qualquer horário.
  final int? minutesOfDay;
}
