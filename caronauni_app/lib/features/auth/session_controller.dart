import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../models/models.dart';

enum SignInOutcome { success, emailNotConfirmed, failed }

class SessionController extends ChangeNotifier {
  SessionController(this._repository);

  final AuthRepository _repository;

  AppUser? _user;
  AppUser? get user => _user;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<SignInOutcome> signIn({
    required String email,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _repository.signIn(email: email, password: password);
      return SignInOutcome.success;
    } on EmailNotConfirmedException {
      return SignInOutcome.emailNotConfirmed;
    } on AuthException catch (e) {
      _error = e.message;
      return SignInOutcome.failed;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void signOut() {
    _user = null;
    _error = null;
    notifyListeners();
  }
}
