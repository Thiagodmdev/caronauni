import '../models/models.dart';
import 'document_store.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

/// A conta existe e a senha está certa, mas falta confirmar o e-mail (RF02).
class EmailNotConfirmedException extends AuthException {
  const EmailNotConfirmedException()
    : super('Confirme seu e-mail antes de entrar.');
}

abstract class AuthRepository {
  /// Pessoa que já estava conectada, se houver.
  Future<AppUser?> restore();

  Future<AppUser> signIn({required String email, required String password});

  /// Cria a conta e envia o link de confirmação.
  Future<void> signUp(SignUpData data);

  Future<void> resendConfirmation(String email);

  Future<void> sendPasswordReset(String email);

  Future<void> saveProfile(AppUser user);

  /// Lê de novo o perfil, para saber se a matrícula já foi aprovada.
  Future<AppUser> reload(AppUser user);

  /// Envia a matrícula para a conferência da administração.
  Future<void> requestApproval(AppUser user, String registration);

  /// Exige a senha para confirmar que é a própria pessoa.
  Future<void> deleteAccount(AppUser user, String password);

  Future<void> signOut();
}

/// Só existe na demonstração: faz o papel da caixa de entrada do usuário.
abstract class SimulatedInbox {
  Future<void> openConfirmationLink(String email);
}

/// Perfil no banco, usado pela demonstração e pelo Firebase.
class ProfileStore {
  const ProfileStore(this._store);

  final DocumentStore _store;

  Future<AppUser> load(String id, String email) async {
    final json = await _store.get('users/$id');
    if (json == null) throw const AuthException('Perfil não encontrado.');
    final contact = await _store.get('users/$id/private/contact');
    final approval = await _store.get('approvals/$id');
    final vehicle = json['vehicle'];
    return AppUser(
      id: id,
      name: json['name'] as String,
      email: email,
      course: json['course'] as String,
      phone: contact?['phone'] as String? ?? '',
      vehicle: vehicle is Map ? Vehicle.fromJson(Json.from(vehicle)) : null,
      isAdmin: await _store.get('admins/$id') != null,
      registration: approval?['registration'] as String? ?? '',
      approval: approval == null
          ? Approval.missing
          : Approval.values.byName(approval['status'] as String),
    );
  }

  Future<void> requestApproval(AppUser user, String registration) =>
      _store.set('approvals/${user.id}', {
        'name': user.name,
        'course': user.course,
        'registration': registration.trim(),
        'status': Approval.pending.name,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> save(AppUser user) async {
    await _store.set('users/${user.id}', {
      'name': user.name,
      'course': user.course,
      'vehicle': user.vehicle?.toJson(),
    });
    // Separado do perfil para só ser lido depois da aceitação (RNF06).
    await _store.set('users/${user.id}/private/contact', {'phone': user.phone});
  }

  Future<void> remove(String id) async {
    await _store.delete('approvals/$id');
    await _store.delete('licenses/$id');
    await _store.delete('users/$id/private/contact');
    await _store.delete('users/$id');
  }
}

class _Account {
  _Account({
    required this.id,
    required this.password,
    this.linkSentAt,
    this.confirmed = false,
  });

  final String id;
  final String password;
  DateTime? linkSentAt;
  bool confirmed;
}

/// Versão de demonstração: as contas ficam só na memória e somem ao fechar.
class MockAuthRepository implements AuthRepository, SimulatedInbox {
  MockAuthRepository(
    DocumentStore store, {
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : _profiles = ProfileStore(store),
       _clock = clock ?? DateTime.now;

  static const String demoEmail = 'demo@sempreuninassau.com.br';
  static const String driverEmail = 'marina@sempreuninassau.com.br';
  static const String adminEmail = 'admin@sempreuninassau.com.br';
  static const String demoPassword = 'carona123';
  static const Duration linkValidity = Duration(hours: 24);

  final ProfileStore _profiles;
  final Duration latency;
  final DateTime Function() _clock;
  final Map<String, _Account> _accounts = {
    for (final entry in const {
      demoEmail: 'demo',
      driverEmail: 'marina',
      adminEmail: 'admin',
    }.entries)
      entry.key: _Account(
        id: entry.value,
        password: demoPassword,
        confirmed: true,
      ),
  };

  String _normalize(String email) => email.trim().toLowerCase();

  @override
  Future<AppUser?> restore() async => null;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final key = _normalize(email);
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw const AuthException('E-mail ou senha incorretos.');
    }
    if (!account.confirmed) throw const EmailNotConfirmedException();
    return _profiles.load(account.id, key);
  }

  @override
  Future<void> signUp(SignUpData data) async {
    await Future<void>.delayed(latency);
    final email = _normalize(data.email);
    if (_accounts.containsKey(email)) {
      throw const AuthException('Já existe uma conta com este e-mail.');
    }
    _accounts[email] = _Account(
      id: email,
      password: data.password,
      linkSentAt: _clock(),
    );
    final user = AppUser(
      id: email,
      name: data.name.trim(),
      email: email,
      phone: data.phone,
      course: data.course.trim(),
    );
    await _profiles.save(user);
    await _profiles.requestApproval(user, data.registration);
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await Future<void>.delayed(latency);
    _accounts[_normalize(email)]?.linkSentAt = _clock();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      Future<void>.delayed(latency);

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

  @override
  Future<void> saveProfile(AppUser user) => _profiles.save(user);

  @override
  Future<AppUser> reload(AppUser user) => _profiles.load(user.id, user.email);

  @override
  Future<void> requestApproval(AppUser user, String registration) =>
      _profiles.requestApproval(user, registration);

  @override
  Future<void> deleteAccount(AppUser user, String password) async {
    if (_accounts[user.email]?.password != password) {
      throw const AuthException('Senha incorreta.');
    }
    await _profiles.remove(user.id);
    _accounts.remove(user.email);
  }

  @override
  Future<void> signOut() async {}
}
