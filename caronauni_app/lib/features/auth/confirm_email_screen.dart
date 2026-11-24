import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import 'confirm_email_view_model.dart';

class ConfirmEmailScreen extends StatelessWidget {
  const ConfirmEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ConfirmEmailViewModel(
        repository: context.read<AuthRepository>(),
        email: email,
      ),
      child: const _ConfirmEmailView(),
    );
  }
}

class _ConfirmEmailView extends StatelessWidget {
  const _ConfirmEmailView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ConfirmEmailViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final confirmed = viewModel.confirmed;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar e-mail')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                confirmed
                    ? Icons.check_circle_outline
                    : Icons.mark_email_unread_outlined,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                confirmed ? 'E-mail confirmado' : 'Confira sua caixa de entrada',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                confirmed
                    ? 'Sua conta está pronta. Entre com seu e-mail e senha.'
                    : 'Use o link enviado para ${viewModel.email}. '
                          'Ele vale por 24 horas.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (viewModel.message != null) ...[
                Text(viewModel.message!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              if (viewModel.error != null) ...[
                Text(
                  viewModel.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (confirmed)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ir para o login'),
                )
              else ...[
                if (viewModel.canSimulateLink) ...[
                  FilledButton(
                    onPressed: viewModel.busy ? null : viewModel.simulateLink,
                    child: const Text('Simular abertura do link'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: viewModel.busy ? null : viewModel.resend,
                  child: const Text('Reenviar link'),
                ),
                if (viewModel.canSimulateLink) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Versão de demonstração: nenhum e-mail é enviado.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
