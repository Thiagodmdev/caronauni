import 'package:caronauni/core/validators.dart';
import 'package:caronauni/data/auth_repository.dart';
import 'package:caronauni/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const email = 'ana@aluno.faculdade.edu.br';
  const data = SignUpData(
    name: 'Ana Souza',
    email: email,
    phone: '(81) 98765-4321',
    course: 'Direito',
    password: 'segredo1',
  );
  late DateTime now;
  late MockAuthRepository repo;

  setUp(() {
    now = DateTime(2026, 11, 24, 10);
    repo = MockAuthRepository(latency: Duration.zero, clock: () => now);
  });

  test('só entra com conta existente e senha certa', () async {
    final wrong = throwsA(
      isA<AuthException>().having(
        (e) => e.message,
        'mensagem',
        'E-mail ou senha incorretos.',
      ),
    );
    await expectLater(repo.signIn(email: email, password: 'segredo1'), wrong);
    await repo.signUp(data);
    await expectLater(repo.signIn(email: email, password: 'errada1'), wrong);
  });

  test('exige e-mail confirmado (RF02)', () async {
    await repo.signUp(data);
    await expectLater(
      repo.signIn(email: email, password: 'segredo1'),
      throwsA(isA<EmailNotConfirmedException>()),
    );
    await repo.openConfirmationLink(email);
    final user = await repo.signIn(
      email: ' ANA@aluno.faculdade.edu.br ',
      password: 'segredo1',
    );
    expect(user.firstName, 'Ana');
    expect(user.course, 'Direito');
  });

  test('link expira em 24h e pode ser reenviado (EX05)', () async {
    await repo.signUp(data);
    now = now.add(const Duration(hours: 24, minutes: 1));
    await expectLater(
      repo.openConfirmationLink(email),
      throwsA(isA<AuthException>()),
    );
    await repo.resendConfirmation(email);
    await repo.openConfirmationLink(email);
    await repo.signIn(email: email, password: 'segredo1');
  });

  test('recusa e-mail repetido, mesmo com maiúsculas', () async {
    await repo.signUp(data);
    await expectLater(
      repo.signUp(
        const SignUpData(
          name: 'Outra Pessoa',
          email: 'ANA@aluno.faculdade.edu.br',
          phone: '(81) 98765-4321',
          course: 'Direito',
          password: 'segredo2',
        ),
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('valida nome e telefone', () {
    expect(validateName('Ana'), isNotNull);
    expect(validateName('Ana Souza'), isNull);
    expect(validatePhone('(81) 98765-4321'), isNull);
    expect(validatePhone('(81) 3456-7890'), isNull);
    expect(validatePhone('8198765'), isNotNull);
    expect(validatePhone('01987654321'), isNotNull);
  });
}
