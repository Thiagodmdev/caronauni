import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../models/models.dart';

class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._repository);

  final AuthRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  /// Retorna true quando a conta foi criada.
  Future<bool> submit(SignUpData data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    var created = false;
    try {
      await _repository.signUp(data);
      created = true;
    } on AuthException catch (e) {
      _error = e.message;
    }
    if (_disposed) return false;
    _loading = false;
    notifyListeners();
    return created;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
