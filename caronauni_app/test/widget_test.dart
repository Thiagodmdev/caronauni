import 'dart:convert';

import 'package:caronauni/app.dart';
import 'package:caronauni/data/auth_repository.dart';
import 'package:caronauni/data/demo_data.dart';
import 'package:caronauni/data/document_store.dart';
import 'package:caronauni/data/ride_repository.dart';
import 'package:caronauni/features/profile/license_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  final now = DateTime(2026, 11, 5, 10);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    await seedDemo(store, now);
    // Sem mapa, que buscaria imagens na rede durante o teste.
    for (final doc in await store.query('rides')) {
      await store.update('rides/${doc.id}', {'originPoint': null});
    }
    await tester.pumpWidget(
      CaronaUniApp(
        authRepository: MockAuthRepository(
          store,
          latency: Duration.zero,
          clock: () => now,
        ),
        rideRepository: RideRepository(store, clock: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  Future<void> tapText(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> signIn(
    WidgetTester tester, [
    String email = MockAuthRepository.demoEmail,
    String password = MockAuthRepository.demoPassword,
  ]) async {
    await fill(tester, 'E-mail', email);
    await fill(tester, 'Senha', password);
    await tapText(tester, 'Entrar');
  }

  Future<void> signOut(WidgetTester tester) async {
    await tapText(tester, 'Buscar');
    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
  }

  testWidgets('login recusa e-mail inválido e senha errada', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'thiago');
    expect(find.text('E-mail inválido'), findsOneWidget);
    await signIn(tester, MockAuthRepository.demoEmail, 'errada1');
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('pedido, aceitação e contato entre as duas contas', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester);
    expect(find.text('Olá, Conta'), findsOneWidget);
    // A carona lotada dos dados de exemplo não aparece.
    expect(find.text('Boa Vista'), findsNothing);
    await tester.enterText(find.byType(TextField), 'jardim');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jardim América').first);
    await tester.pumpAndSettle();
    await tapText(tester, 'Pedir vaga');
    await tester.tap(find.widgetWithText(TextButton, 'Pedir vaga'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pedido enviado'), findsOneWidget);
    expect(find.byTooltip('WhatsApp'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await signOut(tester);

    await signIn(tester, MockAuthRepository.driverEmail);
    await tapText(tester, 'Avisos');
    expect(find.textContaining('pediu vaga'), findsOneWidget);
    await tapText(tester, 'Caronas');
    await tapText(tester, 'Aceitar');
    expect(find.text('Pedido aceito.'), findsOneWidget);
    expect(find.text('Pedidos recebidos'), findsNothing);
    await signOut(tester);

    await signIn(tester);
    await tapText(tester, 'Caronas');
    expect(find.textContaining('Confirmada com Marina'), findsWidgets);
    await tester.tap(find.textContaining('Confirmada com Marina').first);
    await tester.pumpAndSettle();
    expect(find.text('(81) 90000-0002'), findsOneWidget);
    expect(find.byTooltip('WhatsApp'), findsOneWidget);
  });

  testWidgets('avalia uma carona já feita', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tapText(tester, 'Caronas');
    await tapText(tester, 'Avaliar ou informar falta');
    await tapText(tester, 'Enviar avaliação');
    expect(find.text('Avaliação enviada.'), findsOneWidget);
  });

  testWidgets('oferecer exige veículo e depois mostra o formulário', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester);
    await tapText(tester, 'Oferecer');
    await tapText(tester, 'Cadastrar veículo');
    await fill(tester, 'Modelo', 'Fiat Uno');
    await fill(tester, 'Cor', 'Azul');
    await fill(tester, 'Placa', 'abc');
    await tapText(tester, 'Salvar veículo');
    expect(find.textContaining('Placa inválida'), findsOneWidget);
    await fill(tester, 'Placa', 'abc-1d23');
    await tapText(tester, 'Salvar veículo');
    expect(find.textContaining('CNH válida.'), findsOneWidget);
    await tapText(tester, 'Declaro que tenho CNH válida');
    await tapText(tester, 'Salvar veículo');
    expect(find.textContaining('envie a foto da sua CNH'), findsOneWidget);
    await tapText(tester, 'Enviar foto da CNH');
    expect(find.text('Envie a foto da sua CNH'), findsOneWidget);
    expect(find.text('Escolher imagem'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await signOut(tester);

    // Quem já tem a CNH aprovada vê o formulário.
    await signIn(tester, MockAuthRepository.driverEmail);
    await tapText(tester, 'Oferecer');
    expect(find.text('Publicar carona'), findsOneWidget);
  });

  testWidgets('envia CNH e o admin aprova pela foto', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    final context = tester.element(find.byType(NavigationBar));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LicenseScreen(
          pickPhoto: (_) async => base64Decode(_pixel),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Escolher imagem');
    await tapText(tester, 'Enviar CNH');
    expect(find.text('CNH em análise'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await signOut(tester);

    await signIn(tester, MockAuthRepository.adminEmail);
    await tapText(tester, 'Perfil');
    await tapText(tester, 'Administração');
    await tapText(tester, 'Aprovar CNH');
    expect(find.text('Aprovar CNH'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await signOut(tester);

    await signIn(tester);
    await tapText(tester, 'Perfil');
    await tapText(tester, 'Minha CNH');
    expect(find.text('CNH aprovada'), findsOneWidget);
  });

  testWidgets('admin modera denúncia; passageiro não vê a área', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester);
    await tapText(tester, 'Perfil');
    expect(find.text('Administração'), findsNothing);
    await signOut(tester);
    await signIn(tester, MockAuthRepository.adminEmail);
    await tapText(tester, 'Perfil');
    await tapText(tester, 'Administração');
    expect(find.text('Bruno Teixeira'), findsOneWidget);
    await tapText(tester, 'Bloquear');
    expect(find.text('Desbloquear'), findsOneWidget);
  });

  Future<void> fillSignUp(WidgetTester tester, {required String email}) async {
    await fill(tester, 'Nome completo', 'Ana Souza');
    await fill(tester, 'E-mail', email);
    await fill(tester, 'Telefone', '81987654321');
    await fill(tester, 'Curso ou setor', 'Direito');
    await fill(tester, 'Matrícula', '12345678');
    await fill(tester, 'Senha', 'segredo1');
    await fill(tester, 'Confirmar senha', 'segredo1');
  }

  testWidgets('cadastro, confirmação de e-mail e aprovação', (tester) async {
    const email = 'ana@gmail.com';
    await pumpApp(tester);
    await tapText(tester, 'Criar conta');
    await fillSignUp(tester, email: email);
    expect(find.text('(81) 98765-4321'), findsOneWidget);
    await tapText(tester, 'Cadastrar');
    expect(find.text('Confira sua caixa de entrada'), findsOneWidget);

    // Sem confirmar, o login leva de volta para a confirmação.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await signIn(tester, email, 'segredo1');
    expect(find.text('Confira sua caixa de entrada'), findsOneWidget);
    await tapText(tester, 'Reenviar link');
    expect(find.text('Enviamos um novo link.'), findsOneWidget);
    await tapText(tester, 'Simular abertura do link');
    await tapText(tester, 'Ir para o login');
    await tapText(tester, 'Entrar');
    expect(find.text('Matrícula em análise'), findsOneWidget);
    await tapText(tester, 'Verificar aprovação');
    expect(find.text('Sua matrícula ainda está em análise.'), findsOneWidget);
    await tapText(tester, 'Sair');

    Future<void> decide(String action) async {
      await signIn(tester, MockAuthRepository.adminEmail);
      await tapText(tester, 'Perfil');
      await tapText(tester, 'Administração');
      final card = find.ancestor(
        of: find.text('Ana Souza'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: card, matching: find.text(action)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ana Souza'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await signOut(tester);
    }

    // Recusada, a pessoa corrige e envia de novo.
    await decide('Recusar');
    await signIn(tester, email, 'segredo1');
    expect(find.text('Matrícula não aprovada'), findsOneWidget);
    await fill(tester, 'Matrícula', '87654321');
    await tapText(tester, 'Enviar matrícula');
    expect(find.text('Matrícula em análise'), findsOneWidget);
    await tapText(tester, 'Sair');

    await decide('Aprovar');
    await signIn(tester, email, 'segredo1');
    expect(find.text('Olá, Ana'), findsOneWidget);
  });

  testWidgets('cadastro mostra erros e recusa e-mail já usado', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Criar conta');
    await fillSignUp(tester, email: 'ana');
    await fill(tester, 'Confirmar senha', 'outra123');
    await tapText(tester, 'Cadastrar');
    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(find.text('As senhas não são iguais'), findsOneWidget);
    await fillSignUp(tester, email: MockAuthRepository.demoEmail);
    await tapText(tester, 'Cadastrar');
    expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
  });
}
