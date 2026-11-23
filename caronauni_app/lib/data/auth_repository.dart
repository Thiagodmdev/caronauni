import '../models/models.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

/// Contrato da autenticação. O Firebase Authentication entra como outra
/// implementação, sem mudanças nas telas.
abstract class AuthRepository {
  Future<AppUser> signIn({required String email, required String password});
}

/// Versão de demonstração: aceita qualquer e-mail que passou na validação.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 500)});

  final Duration latency;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    return AppUser(
      id: normalized,
      name: _nameFrom(normalized),
      email: normalized,
    );
  }

  String _nameFrom(String email) {
    final first = email.split('@').first.split(RegExp(r'[._-]')).first;
    if (first.isEmpty) return email;
    return first[0].toUpperCase() + first.substring(1);
  }
}
