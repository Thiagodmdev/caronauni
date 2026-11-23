import 'package:flutter/foundation.dart';

import '../../data/ride_repository.dart';
import '../../models/models.dart';

class RideDetailViewModel extends ChangeNotifier {
  RideDetailViewModel({
    required this._repository,
    required this.ride,
    required this._userId,
  }) {
    _load();
  }

  final RideRepository _repository;
  final String _userId;
  final Ride ride;

  bool _requested = false;
  bool get requested => _requested;

  bool _busy = true;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  Future<void> _load() async {
    final requested = await _repository.hasRequested(
      rideId: ride.id,
      userId: _userId,
    );
    if (_disposed) return;
    _requested = requested;
    _busy = false;
    notifyListeners();
  }

  Future<void> requestSeat() => _run(() async {
    await _repository.requestSeat(ride: ride, userId: _userId);
    _requested = true;
  });

  Future<void> cancelRequest() => _run(() async {
    await _repository.cancelRequest(rideId: ride.id, userId: _userId);
    _requested = false;
  });

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on RideRequestException catch (e) {
      _error = e.message;
    }
    if (_disposed) return;
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
