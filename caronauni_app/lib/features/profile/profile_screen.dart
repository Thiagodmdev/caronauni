import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/phone_input_formatter.dart';
import '../../core/validators.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../admin/admin_screen.dart';
import '../auth/session_controller.dart';
import '../shared/feedback.dart';
import '../shared/person_avatar.dart';
import '../shared/rating_label.dart';
import '../shared/reloadable.dart';
import 'license_screen.dart';
import 'vehicle_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _export(BuildContext context, AppUser user) async {
    final repository = context.read<RideRepository>();
    await runAction(context, () async {
      final data = await repository.export(user);
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
      );
    }, success: 'Seus dados foram copiados.');
  }

  Future<void> _delete(BuildContext context) async {
    final session = context.read<SessionController>();
    final password = await askText(
      context,
      title: 'Excluir conta? Não dá para desfazer.',
      label: 'Digite sua senha para confirmar',
      action: 'Excluir',
      obscure: true,
    );
    if (password == null || !context.mounted) return;
    await runAction(context, () => session.deleteAccount(password));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();
    final repository = context.read<RideRepository>();
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Reloadable<(List<Fault>, DateTime?)>(
        load: () async => (
          await repository.faults(user.id),
          await repository.suspendedUntil(user.id),
        ),
        builder: (context, data, reload) {
          final (faults, suspended) = data;
          return [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PersonAvatar(name: user.name, radius: 28),
              title: Text(user.name),
              subtitle: Text('${user.course}\n${user.email}'),
              trailing: RatingLabel(userId: user.id),
              isThreeLine: true,
            ),
            if (suspended != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.block),
                  title: Text(
                    'Conta suspensa até ${suspended.day}/${suspended.month}/'
                    '${suspended.year}',
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar perfil'),
              onTap: () => open(const EditProfileScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Meu veículo'),
              subtitle: Text(
                user.vehicle == null
                    ? 'Não cadastrado'
                    : '${user.vehicle!.model} (${user.vehicle!.plate})',
              ),
              onTap: () => open(const VehicleScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Minha CNH'),
              onTap: () => open(const LicenseScreen()),
            ),
            if (user.isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Administração'),
                onTap: () => open(const AdminScreen()),
              ),
            const SectionTitle('Faltas'),
            if (faults.isEmpty) const EmptyText('Você não tem faltas.'),
            for (final fault in faults)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(fault.reason),
                subtitle: Text(
                  '${formatDay(fault.createdAt, repository.now)} · '
                  '${switch (fault.status) {
                    'contested' => 'Em análise',
                    'kept' => 'Mantida',
                    'dismissed' => 'Retirada',
                    _ => 'Registrada',
                  }}',
                ),
                trailing: fault.status == 'active'
                    ? TextButton(
                        onPressed: () async {
                          await runAction(
                            context,
                            () => repository.contest(fault),
                            success: 'Contestação enviada.',
                          );
                          await reload();
                        },
                        child: const Text('Contestar'),
                      )
                    : null,
              ),
            const SectionTitle('Privacidade'),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copiar meus dados'),
              onTap: () => _export(context, user),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir conta'),
              onTap: () => _delete(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: session.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            ),
          ];
        },
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _course = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().user!;
    _name.text = user.name;
    _phone.text = user.phone;
    _course.text = user.course;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionController>();
    final ok = await runAction(
      context,
      () => session.saveProfile(
        session.user!.copyWith(
          name: _name.text.trim(),
          phone: _phone.text,
          course: _course.text.trim(),
        ),
      ),
      success: 'Perfil atualizado.',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                validator: validateName,
                decoration: const InputDecoration(labelText: 'Nome completo'),
              ),
              gap,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                validator: validatePhone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              gap,
              TextFormField(
                controller: _course,
                validator: validateCourse,
                decoration: const InputDecoration(labelText: 'Curso ou setor'),
              ),
              gap,
              FilledButton(onPressed: _save, child: const Text('Salvar')),
            ],
          ),
        ),
      ),
    );
  }
}
