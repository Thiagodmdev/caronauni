import '../core/formatters.dart';
import '../models/models.dart';
import 'mock_rides.dart';

class RideRequestException implements Exception {
  const RideRequestException(this.message);

  final String message;
}

/// Contrato de acesso às caronas. O Cloud Firestore entra como outra
/// implementação, sem mudanças nas telas.
abstract class RideRepository {
  Future<List<Ride>> search(RideQuery query);

  Future<bool> hasRequested({required String rideId, required String userId});

  Future<void> requestSeat({required Ride ride, required String userId});

  Future<void> cancelRequest({required String rideId, required String userId});
}

class MockRideRepository implements RideRepository {
  MockRideRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 350),
    List<Ride>? rides,
  }) : _clock = clock ?? DateTime.now {
    _rides = rides ?? buildMockRides(_clock());
  }

  /// Janela do horário buscado, para mais ou para menos (HU01).
  static const int timeWindowMinutes = 30;

  final DateTime Function() _clock;
  final Duration latency;
  late final List<Ride> _rides;
  final Map<String, Set<String>> _requestsByUser = {};

  @override
  Future<List<Ride>> search(RideQuery query) async {
    await Future<void>.delayed(latency);
    final now = _clock();
    final term = normalizeForSearch(query.destination);
    final results = _rides.where((ride) {
      if (!ride.departure.isAfter(now) || ride.availableSeats <= 0) {
        return false;
      }
      if (term.isNotEmpty &&
          !normalizeForSearch(ride.destination).contains(term)) {
        return false;
      }
      if (!_matchesDay(ride.departure, query.day, now)) return false;
      final wanted = query.minutesOfDay;
      if (wanted != null) {
        final minutes = ride.departure.hour * 60 + ride.departure.minute;
        if ((minutes - wanted).abs() > timeWindowMinutes) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.departure.compareTo(b.departure));
    return results;
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

  @override
  Future<bool> hasRequested({
    required String rideId,
    required String userId,
  }) async {
    return _requestsByUser[userId]?.contains(rideId) ?? false;
  }

  @override
  Future<void> requestSeat({required Ride ride, required String userId}) async {
    await Future<void>.delayed(latency);
    if (ride.driver.id == userId) {
      throw const RideRequestException(
        'Você não pode pedir vaga na própria carona.',
      );
    }
    if (ride.availableSeats <= 0) {
      throw const RideRequestException('Esta carona já está lotada.');
    }
    final requests = _requestsByUser.putIfAbsent(userId, () => {});
    final hasConflict = _rides.any(
      (other) =>
          other.id != ride.id &&
          requests.contains(other.id) &&
          other.overlaps(ride),
    );
    if (hasConflict) {
      throw const RideRequestException(
        'Você já pediu vaga em outra carona neste horário.',
      );
    }
    requests.add(ride.id);
  }

  @override
  Future<void> cancelRequest({
    required String rideId,
    required String userId,
  }) async {
    await Future<void>.delayed(latency);
    _requestsByUser[userId]?.remove(rideId);
  }
}
