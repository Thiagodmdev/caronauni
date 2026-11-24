import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';

class ConfirmEmailViewModel extends ChangeNotifier {
  ConfirmEmailViewModel({required this._repository, required this.email});

  final AuthRepository _repository;
  final String email;

  bool _busy = false;
  bool get busy => _busy;

  bool _confirmed = false;
  bool get confirmed => _confirmed;

  String? _message;
  String? get message => _message;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  bool get canSimulateLink => _repository is SimulatedInbox;

  Future<void> resend() => _run(() async {
    await _repository.resendConfirmation(email);
    _message = 'Enviamos um novo link.';
  });

  Future<void> simulateLink() => _run(() async {
    final Object repository = _repository;
    if (repository is! SimulatedInbox) return;
    await repository.openConfirmationLink(email);
    _confirmed = true;
  });

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      await action();
    } on AuthException catch (e) {
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
