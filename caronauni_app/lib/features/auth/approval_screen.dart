import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/models.dart';
import '../shared/feedback.dart';
import 'session_controller.dart';

/// Mostrada a quem confirmou o e-mail, mas ainda não teve a matrícula aprovada.
class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registration = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _registration.text = context.read<SessionController>().user!.registration;
  }

  @override
  void dispose() {
    _registration.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await runAction(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _check(SessionController session) => _run(() async {
    await session.refresh();
    if (mounted && session.user?.approval == Approval.pending) {
      showMessage(context, 'Sua matrícula ainda está em análise.');
    }
  });

  Future<void> _delete(SessionController session) async {
    final password = await askText(
      context,
      title: 'Excluir conta? Não dá para desfazer.',
      label: 'Digite sua senha para confirmar',
      action: 'Excluir',
      obscure: true,
    );
    if (password == null || !mounted) return;
    await _run(() => session.deleteAccount(password));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final pending = user.approval == Approval.pending;
    final refused = user.approval == Approval.refused;

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovação da matrícula')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Icon(
                  pending ? Icons.hourglass_top : Icons.badge_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  pending
                      ? 'Matrícula em análise'
                      : refused
                      ? 'Matrícula não aprovada'
                      : 'Informe sua matrícula',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  pending
                      ? 'A administração vai conferir a matrícula '
                            '${user.registration}. As caronas são liberadas '
                            'depois da aprovação.'
                      : refused
                      ? 'Confira o número e envie de novo.'
                      : 'A administração precisa conferir sua matrícula.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (pending)
                  FilledButton(
                    onPressed: _busy ? null : () => _check(session),
                    child: const Text('Verificar aprovação'),
                  )
                else ...[
                  TextFormField(
                    controller: _registration,
                    keyboardType: TextInputType.number,
                    validator: validateRegistration,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate()) return;
                            _run(
                              () => session.requestApproval(_registration.text),
                            );
                          },
                    child: const Text('Enviar matrícula'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : session.signOut,
                  child: const Text('Sair'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _delete(session),
                  child: const Text('Excluir conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
