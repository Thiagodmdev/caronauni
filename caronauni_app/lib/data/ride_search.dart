import '../core/formatters.dart';
import '../models/models.dart';

/// Janela do horário buscado, para mais ou para menos (HU01).
const int timeWindowMinutes = 30;

/// Filtra e ordena as caronas visíveis na busca.
List<Ride> filterRides(Iterable<Ride> rides, RideQuery query, DateTime now) {
  final term = normalizeForSearch(query.destination);
  return rides.where((ride) {
    if (ride.cancelled ||
        !ride.departure.isAfter(now) ||
        ride.availableSeats <= 0) {
      return false;
    }
    if (term.isNotEmpty && !normalizeForSearch(ride.destination).contains(term)) {
      return false;
    }
    if (!_matchesDay(ride.departure, query.day, now)) return false;
    final wanted = query.minutesOfDay;
    if (wanted == null) return true;
    final minutes = ride.departure.hour * 60 + ride.departure.minute;
    return (minutes - wanted).abs() <= timeWindowMinutes;
  }).toList()
    ..sort((a, b) => a.departure.compareTo(b.departure));
}

bool _matchesDay(DateTime date, DayFilter day, DateTime now) {
  switch (day) {
    case DayFilter.all:
      return true;
    case DayFilter.today:
      return _sameDay(date, now);
    case DayFilter.tomorrow:
      return _sameDay(date, DateTime(now.year, now.month, now.day + 1));
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
