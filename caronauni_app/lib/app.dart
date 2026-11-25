import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/auth_repository.dart';
import 'data/ride_repository.dart';
import 'features/auth/approval_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_controller.dart';
import 'features/home/home_screen.dart';

class CaronaUniApp extends StatelessWidget {
  const CaronaUniApp({
    super.key,
    required this.authRepository,
    required this.rideRepository,
  });

  final AuthRepository authRepository;
  final RideRepository rideRepository;

  /// Largura máxima do conteúdo, para o layout de celular continuar correto
  /// quando o app é aberto no navegador durante a apresentação.
  static const double _maxContentWidth = 480;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<RideRepository>.value(value: rideRepository),
        ChangeNotifierProvider(create: (_) => SessionController(authRepository)),
      ],
      child: MaterialApp(
        title: 'CaronaUni',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: child,
            ),
          ),
        ),
        home: const _SessionGate(),
      ),
    );
  }
}

/// Mostra o login ou a busca conforme o estado da sessão.
class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final restoring = context.select<SessionController, bool>(
      (s) => s.restoring,
    );
    final userId = context.select<SessionController, String?>(
      (s) => s.user?.id,
    );
    final isMember = context.select<SessionController, bool>(
      (s) => s.user?.isMember ?? false,
    );
    if (restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (userId == null) return const LoginScreen();
    return isMember ? const HomeScreen() : const ApprovalScreen();
  }
}
