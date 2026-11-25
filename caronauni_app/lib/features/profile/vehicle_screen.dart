import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../shared/feedback.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  // Placa antiga (AAA0000) ou Mercosul (AAA0A00).
  static final _plateShape = RegExp(r'^[A-Z]{3}\d[A-Z0-9]\d{2}$');

  final _formKey = GlobalKey<FormState>();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  bool _hasLicense = false;

  @override
  void initState() {
    super.initState();
    final vehicle = context.read<SessionController>().user?.vehicle;
    _model.text = vehicle?.model ?? '';
    _color.text = vehicle?.color ?? '';
    _plate.text = vehicle?.plate ?? '';
  }

  @override
  void dispose() {
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  String get _plateValue =>
      _plate.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasLicense) {
      showMessage(context, 'Confirme que você tem CNH válida.');
      return;
    }
    final session = context.read<SessionController>();
    final ok = await runAction(
      context,
      () => session.saveProfile(
        session.user!.copyWith(
          vehicle: Vehicle(
            model: _model.text.trim(),
            color: _color.text.trim(),
            plate: _plateValue,
          ),
        ),
      ),
      success: 'Veículo salvo.',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? 'Campo obrigatório' : null;
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu veículo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _model,
                validator: required,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              gap,
              TextFormField(
                controller: _color,
                validator: required,
                decoration: const InputDecoration(labelText: 'Cor'),
              ),
              gap,
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                validator: (_) => _plateShape.hasMatch(_plateValue)
                    ? null
                    : 'Placa inválida (ex.: ABC1D23)',
                decoration: const InputDecoration(labelText: 'Placa'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Declaro que tenho CNH válida'),
                value: _hasLicense,
                onChanged: (v) => setState(() => _hasLicense = v ?? false),
              ),
              gap,
              FilledButton(onPressed: _save, child: const Text('Salvar veículo')),
            ],
          ),
        ),
      ),
    );
  }
}
