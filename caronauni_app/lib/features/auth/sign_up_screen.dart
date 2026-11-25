import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/phone_input_formatter.dart';
import '../../core/validators.dart';
import '../../data/auth_repository.dart';
import '../../models/models.dart';
import 'confirm_email_screen.dart';
import 'sign_up_view_model.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SignUpViewModel(context.read<AuthRepository>()),
      child: const _SignUpForm(),
    );
  }
}

class _SignUpForm extends StatefulWidget {
  const _SignUpForm();

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _course = TextEditingController();
  final _registration = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _course,
      _registration,
      _password,
      _confirmation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final email = _email.text.trim().toLowerCase();
    final created = await context.read<SignUpViewModel>().submit(
      SignUpData(
        name: _name.text,
        email: email,
        phone: _phone.text,
        course: _course.text,
        registration: _registration.text,
        password: _password.text,
      ),
    );
    if (!created || !mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ConfirmEmailScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignUpViewModel>();
    final scheme = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: validateName,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _email,
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
                gap,
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [PhoneInputFormatter()],
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  validator: validatePhone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '(00) 00000-0000',
                    helperText: 'Só aparece depois que a carona for aceita',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _course,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: validateCourse,
                  decoration: const InputDecoration(
                    labelText: 'Curso ou setor',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _registration,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: validateRegistration,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    helperText: 'Só a administração vê, para aprovar sua conta',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                gap,
                TextFormField(
                  controller: _confirmation,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      validatePasswordConfirmation(value, _password.text),
                  onFieldSubmitted: (_) {
                    if (!viewModel.loading) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 24),
                if (viewModel.error != null) ...[
                  Text(viewModel.error!, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: viewModel.loading ? null : _submit,
                  child: viewModel.loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
