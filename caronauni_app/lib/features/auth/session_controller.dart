import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../models/models.dart';

enum SignInOutcome { success, emailNotConfirmed, failed }

class SessionController extends ChangeNotifier {
  SessionController(this._repository) {
    _restore();
  }

  final AuthRepository _repository;

  AppUser? _user;
  AppUser? get user => _user;

  bool _restoring = true;
  bool get restoring => _restoring;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> _restore() async {
    _user = await _repository.restore();
    _restoring = false;
    notifyListeners();
  }

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

  Future<void> saveProfile(AppUser user) async {
    await _repository.saveProfile(user);
    _user = user;
    notifyListeners();
  }

  Future<void> refresh() async {
    _user = await _repository.reload(_user!);
    notifyListeners();
  }

  Future<void> requestApproval(String registration) async {
    await _repository.requestApproval(_user!, registration);
    await refresh();
  }

  Future<void> deleteAccount(String password) async {
    await _repository.deleteAccount(_user!, password);
    _user = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _user = null;
    _error = null;
    notifyListeners();
  }
}
