import 'package:caronauni/app.dart';
import 'package:caronauni/data/auth_repository.dart';
import 'package:caronauni/data/ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CaronaUniApp(
        authRepository: MockAuthRepository(latency: Duration.zero),
        rideRepository: MockRideRepository(
          latency: Duration.zero,
          clock: () => DateTime(2026, 11, 5, 10),
        ),
      ),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail institucional'),
      MockAuthRepository.demoEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      MockAuthRepository.demoPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('login recusa e-mail de fora da faculdade', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail institucional'),
      'thiago@gmail.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Use seu e-mail da faculdade'), findsOneWidget);
    expect(find.text('Para onde você vai?'), findsNothing);
  });

  testWidgets('fluxo de login, busca, detalhes e pedido de vaga', (tester) async {
    await pumpApp(tester);
    await signIn(tester);

    expect(find.text('Olá, Conta'), findsOneWidget);
    expect(find.text('Jardim América'), findsWidgets);
    // Carona lotada dos dados de exemplo não aparece.
    expect(find.text('Boa Vista'), findsNothing);

    await tester.enterText(find.byType(TextField), 'centro');
    await tester.pumpAndSettle();
    expect(find.text('Jardim América'), findsNothing);
    expect(find.text('Centro'), findsWidgets);

    await tester.tap(find.text('Centro').first);
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da carona'), findsOneWidget);
    expect(find.text('Rafael Nogueira'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Pedir vaga'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Pedir vaga'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pedido enviado'), findsOneWidget);

    // O pedido continua registrado ao sair e voltar para a carona.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centro').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pedido enviado'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Pedir vaga'), findsOneWidget);
  });

  testWidgets('sair volta para o login', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
  });

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.text(label).last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fillSignUp(WidgetTester tester, {required String email}) async {
    await fill(tester, 'Nome completo', 'Ana Souza');
    await fill(tester, 'E-mail institucional', email);
    await fill(tester, 'Telefone', '81987654321');
    await fill(tester, 'Curso ou setor', 'Direito');
    await fill(tester, 'Senha', 'segredo1');
    await fill(tester, 'Confirmar senha', 'segredo1');
  }

  testWidgets('cadastro, confirmação de e-mail e login', (tester) async {
    const email = 'ana@aluno.faculdade.edu.br';
    await pumpApp(tester);
    await tapButton(tester, 'Criar conta');
    await fillSignUp(tester, email: email);
    expect(find.text('(81) 98765-4321'), findsOneWidget);
    await tapButton(tester, 'Cadastrar');
    expect(find.text('Confira sua caixa de entrada'), findsOneWidget);

    // Sem confirmar, o login leva de volta para a confirmação.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await fill(tester, 'E-mail institucional', email);
    await fill(tester, 'Senha', 'segredo1');
    await tapButton(tester, 'Entrar');
    expect(find.text('Confira sua caixa de entrada'), findsOneWidget);

    await tapButton(tester, 'Reenviar link');
    expect(find.text('Enviamos um novo link.'), findsOneWidget);
    await tapButton(tester, 'Simular abertura do link');
    await tapButton(tester, 'Ir para o login');
    await tapButton(tester, 'Entrar');
    expect(find.text('Olá, Ana'), findsOneWidget);
  });

  testWidgets('cadastro mostra erros dos campos', (tester) async {
    await pumpApp(tester);
    await tapButton(tester, 'Criar conta');
    await fillSignUp(tester, email: 'ana@gmail.com');
    await fill(tester, 'Confirmar senha', 'outra123');
    await tapButton(tester, 'Cadastrar');
    expect(find.text('Use seu e-mail da faculdade'), findsOneWidget);
    expect(find.text('As senhas não são iguais'), findsOneWidget);
  });

  testWidgets('cadastro recusa e-mail já usado', (tester) async {
    await pumpApp(tester);
    await tapButton(tester, 'Criar conta');
    await fillSignUp(tester, email: MockAuthRepository.demoEmail);
    await tapButton(tester, 'Cadastrar');
    expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
  });
}
