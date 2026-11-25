import 'package:caronauni/data/demo_data.dart';
import 'package:caronauni/data/document_store.dart';
import 'package:caronauni/models/models.dart';

/// Gera [count] caronas futuras a partir dos dados de exemplo.
List<Ride> manyRides(int count, DateTime now) {
  final base = buildDemoRides(now).where((r) => r.availableSeats > 0).toList();
  return List.generate(count, (i) {
    final r = base[i % base.length];
    return Ride(
      id: 'b$i',
      origin: r.origin,
      originDetail: r.originDetail,
      destination: r.destination,
      destinationDetail: r.destinationDetail,
      departure: now.add(Duration(minutes: 60 + i)),
      durationMinutes: r.durationMinutes,
      totalSeats: r.totalSeats,
      takenSeats: r.takenSeats,
      price: r.price,
      driver: r.driver,
      vehicle: r.vehicle,
    );
  });
}

Future<MemoryStore> storeWith(List<Ride> rides) async {
  final store = MemoryStore();
  for (final ride in rides) {
    await store.set('rides/${ride.id}', ride.toJson());
  }
  return store;
}
