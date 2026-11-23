class AppUser {
  const AppUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;
}

class Review {
  const Review({required this.author, required this.stars, required this.text});

  final String author;
  final int stars;
  final String text;
}

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.course,
    required this.rating,
    required this.ratingCount,
    this.reviews = const [],
  });

  final String id;
  final String name;
  final String course;
  final double rating;
  final int ratingCount;
  final List<Review> reviews;
}

class Vehicle {
  const Vehicle({required this.model, required this.color, required this.plate});

  final String model;
  final String color;
  final String plate;
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
  });

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

  int get availableSeats => totalSeats - takenSeats;

  DateTime get arrival => departure.add(Duration(minutes: durationMinutes));

  bool overlaps(Ride other) =>
      departure.isBefore(other.arrival) && other.departure.isBefore(arrival);
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
