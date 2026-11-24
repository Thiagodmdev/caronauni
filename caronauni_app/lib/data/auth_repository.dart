import '../models/models.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

/// A conta existe e a senha está certa, mas falta confirmar o e-mail (RF02).
class EmailNotConfirmedException extends AuthException {
  const EmailNotConfirmedException()
    : super('Confirme seu e-mail antes de entrar.');
}

/// Contrato da autenticação. O Firebase Authentication entra como outra
/// implementação, sem mudanças nas telas.
abstract class AuthRepository {
  Future<AppUser> signIn({required String email, required String password});

  /// Cria a conta e envia o link de confirmação.
  Future<void> signUp(SignUpData data);

  Future<void> resendConfirmation(String email);
}

/// Só existe na demonstração: faz o papel da caixa de entrada do usuário.
abstract class SimulatedInbox {
  Future<void> openConfirmationLink(String email);
}

class _Account {
  _Account({
    required this.user,
    required this.password,
    this.linkSentAt,
    this.confirmed = false,
  });

  final AppUser user;
  final String password;
  DateTime? linkSentAt;
  bool confirmed;
}

/// Versão de demonstração: as contas ficam só na memória e somem ao fechar.
class MockAuthRepository implements AuthRepository, SimulatedInbox {
  MockAuthRepository({
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String demoEmail = 'demo@aluno.faculdade.edu.br';
  static const String demoPassword = 'carona123';
  static const Duration linkValidity = Duration(hours: 24);

  final Duration latency;
  final DateTime Function() _clock;
  final Map<String, _Account> _accounts = {
    demoEmail: _Account(
      user: const AppUser(
        id: demoEmail,
        name: 'Conta Demonstração',
        email: demoEmail,
      ),
      password: demoPassword,
      confirmed: true,
    ),
  };

  String _normalize(String email) => email.trim().toLowerCase();

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final account = _accounts[_normalize(email)];
    if (account == null || account.password != password) {
      throw const AuthException('E-mail ou senha incorretos.');
    }
    if (!account.confirmed) throw const EmailNotConfirmedException();
    return account.user;
  }

  @override
  Future<void> signUp(SignUpData data) async {
    await Future<void>.delayed(latency);
    final email = _normalize(data.email);
    if (_accounts.containsKey(email)) {
      throw const AuthException('Já existe uma conta com este e-mail.');
    }
    _accounts[email] = _Account(
      user: AppUser(
        id: email,
        name: data.name.trim(),
        email: email,
        phone: data.phone,
        course: data.course.trim(),
      ),
      password: data.password,
      linkSentAt: _clock(),
    );
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await Future<void>.delayed(latency);
    _accounts[_normalize(email)]?.linkSentAt = _clock();
  }

  @override
  Future<void> openConfirmationLink(String email) async {
    await Future<void>.delayed(latency);
    final account = _accounts[_normalize(email)];
    final sentAt = account?.linkSentAt;
    if (account == null || sentAt == null) {
      throw const AuthException('Link inválido.');
    }
    if (_clock().difference(sentAt) > linkValidity) {
      throw const AuthException('O link expirou. Peça um novo link.');
    }
    account.confirmed = true;
  }
}
