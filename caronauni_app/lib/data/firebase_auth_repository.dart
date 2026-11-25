import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'auth_repository.dart';
import 'document_store.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, DocumentStore store)
    : _profiles = ProfileStore(store);

  final FirebaseAuth _auth;
  final ProfileStore _profiles;

  @override
  Future<AppUser?> restore() async {
    final user = await _auth.authStateChanges().first;
    if (user == null || !user.emailVerified) return null;
    try {
      return await _profiles.load(user.uid, user.email!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    if (!user.emailVerified) throw const EmailNotConfirmedException();
    // O token antigo ainda diz que o e-mail não foi confirmado.
    await user.getIdToken(true);
    return _profiles.load(user.uid, user.email!);
  });

  @override
  Future<void> signUp(SignUpData data) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: data.email,
      password: data.password,
    );
    final user = credential.user!;
    final profile = AppUser(
      id: user.uid,
      name: data.name.trim(),
      email: data.email,
      phone: data.phone,
      course: data.course.trim(),
    );
    await _profiles.save(profile);
    await _profiles.requestApproval(profile, data.registration);
    await _auth.setLanguageCode('pt-BR');
    await user.sendEmailVerification();
  });

  @override
  Future<void> resendConfirmation(String email) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null || user.email != email) {
      throw const AuthException('Entre com seu e-mail e senha para reenviar.');
    }
    await _auth.setLanguageCode('pt-BR');
    await user.sendEmailVerification();
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    await _auth.setLanguageCode('pt-BR');
    await _auth.sendPasswordResetEmail(email: email);
  });

  @override
  Future<void> saveProfile(AppUser user) => _guard(() => _profiles.save(user));

  @override
  Future<AppUser> reload(AppUser user) =>
      _guard(() => _profiles.load(user.id, user.email));

  @override
  Future<void> requestApproval(AppUser user, String registration) =>
      _guard(() => _profiles.requestApproval(user, registration));

  @override
  Future<void> deleteAccount(AppUser user, String password) => _guard(() async {
    final current = _auth.currentUser!;
    await current.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email, password: password),
    );
    await _profiles.remove(user.id);
    await current.delete();
  });

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    } on FirebaseException {
      throw const AuthException('Não foi possível concluir. Tente de novo.');
    }
  }

  String _message(String code) => switch (code) {
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => 'E-mail ou senha incorretos.',
    'email-already-in-use' => 'Já existe uma conta com este e-mail.',
    'weak-password' => 'Escolha uma senha mais forte.',
    'too-many-requests' => 'Muitas tentativas. Aguarde alguns minutos.',
    'network-request-failed' => 'Sem conexão com a internet.',
    _ => 'Não foi possível concluir. Tente de novo.',
  };
}
