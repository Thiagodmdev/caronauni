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
      'thiago.macedo@aluno.faculdade.edu.br',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), '123456');
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

    expect(find.text('Olá, Thiago'), findsOneWidget);
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
}
