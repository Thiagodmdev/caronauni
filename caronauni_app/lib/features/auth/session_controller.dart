import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../models/models.dart';

class SessionController extends ChangeNotifier {
  SessionController(this._repository);

  final AuthRepository _repository;

  AppUser? _user;
  AppUser? get user => _user;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> signIn({required String email, required String password}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _repository.signIn(email: email, password: password);
    } on AuthException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void signOut() {
    _user = null;
    notifyListeners();
  }
}
