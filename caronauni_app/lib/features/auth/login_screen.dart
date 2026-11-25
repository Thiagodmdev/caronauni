import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../shared/feedback.dart';
import 'confirm_email_screen.dart';
import 'session_controller.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final email = _emailController.text.trim().toLowerCase();
    final outcome = await context.read<SessionController>().signIn(
      email: email,
      password: _passwordController.text,
    );
    if (outcome != SignInOutcome.emailNotConfirmed || !mounted) return;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => ConfirmEmailScreen(email: email)),
    );
  }

  Future<void> _resetPassword() async {
    if (validateEmail(_emailController.text) != null) {
      showMessage(context, 'Preencha seu e-mail da faculdade primeiro.');
      return;
    }
    final auth = context.read<AuthRepository>();
    await runAction(
      context,
      () => auth.sendPasswordReset(_emailController.text.trim().toLowerCase()),
      success: auth is SimulatedInbox
          ? 'Demonstração: nenhum e-mail é enviado.'
          : 'Se a conta existir, você vai receber um link por e-mail.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isDemo = context.read<AuthRepository>() is SimulatedInbox;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          size: 40,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CaronaUni',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Caronas entre quem estuda e trabalha na sua faculdade',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      validator: validateEmail,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'nome@exemplo.com',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: validatePassword,
                      onFieldSubmitted: (_) {
                        if (!session.loading) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                    if (session.error != null) ...[
                      Text(
                        session.error!,
                        style: TextStyle(color: scheme.error),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: session.loading ? null : _submit,
                      child: session.loading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: session.loading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SignUpScreen(),
                              ),
                            ),
                      child: const Text('Criar conta'),
                    ),
                    if (isDemo) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Versão de demonstração: crie uma conta ou entre com '
                      '${MockAuthRepository.demoEmail} (passageiro), '
                      '${MockAuthRepository.driverEmail} (motorista) ou '
                      '${MockAuthRepository.adminEmail}. Senha: '
                      '${MockAuthRepository.demoPassword}.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
