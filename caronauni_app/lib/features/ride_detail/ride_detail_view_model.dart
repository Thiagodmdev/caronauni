import 'package:flutter/foundation.dart';

import '../../data/ride_repository.dart';
import '../../models/models.dart';

class RideDetailViewModel extends ChangeNotifier {
  RideDetailViewModel({
    required this._repository,
    required this.ride,
    required this._user,
  }) {
    _run(() async {});
  }

  final RideRepository _repository;
  final AppUser _user;
  final Ride ride;

  bool get isDriver => ride.driver.id == _user.id;

  RequestStatus? _status;
  RequestStatus? get status => _status;

  SeatRequest? _request;

  Reputation? _reputation;
  Reputation? get reputation => _reputation;

  /// Só preenchido depois da aceitação (RNF06).
  String? _phone;
  String? get phone => _phone;

  bool _busy = true;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  Future<void> requestSeat() =>
      _run(() => _repository.requestSeat(ride, _user));

  Future<void> cancelRequest() => _run(() async {
    final request = _request;
    if (request != null) await _repository.cancelRequest(request, _user);
  });

  Future<void> _refresh() async {
    _reputation ??= await _repository.reputation(ride.driver.id);
    if (isDriver) return;
    final request = await _repository.request(ride.id, _user.id);
    _request = request;
    _status = request?.statusAt(_repository.now);
    _phone = _status == RequestStatus.accepted
        ? await _repository.phoneOf(ride.driver.id, _user.id)
        : null;
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    if (hasListeners) notifyListeners();
    try {
      await action();
      await _refresh();
    } on RideException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Não foi possível concluir. Verifique sua conexão.';
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
