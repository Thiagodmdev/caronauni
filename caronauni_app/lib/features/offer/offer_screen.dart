import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/geocoding.dart';
import '../../core/theme.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../profile/license_screen.dart';
import '../profile/vehicle_screen.dart';
import '../shared/feedback.dart';
import '../shared/reloadable.dart';
import '../shared/road.dart';
import '../shared/time_sheet.dart';

class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key, required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  static const _weekdayLabels = {
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
    7: 'Dom',
  };

  final _formKey = GlobalKey<FormState>();
  final _origin = TextEditingController();
  final _originDetail = TextEditingController();
  final _destination = TextEditingController();
  final _destinationDetail = TextEditingController();
  final _price = TextEditingController(text: '8,00');
  final _duration = TextEditingController(text: '30');
  late DateTime _departure;
  int _seats = 3;
  bool _recurrent = false;
  final Set<int> _weekdays = {};
  bool _saving = false;
  Approval? _license;

  @override
  void initState() {
    super.initState();
    final now = context.read<RideRepository>().now;
    _departure = DateTime(now.year, now.month, now.day, now.hour + 2);
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    final repository = context.read<RideRepository>();
    final userId = context.read<SessionController>().user!.id;
    await runAction(context, () async {
      final license = await repository.licenseStatus(userId);
      if (mounted) setState(() => _license = license);
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _loadLicense();
  }

  @override
  void dispose() {
    for (final c in [
      _origin,
      _originDetail,
      _destination,
      _destinationDetail,
      _price,
      _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = context.read<RideRepository>().now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day + 7),
    );
    if (picked == null) return;
    setState(
      () => _departure = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _departure.hour,
        _departure.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await pickTime(
      context,
      title: 'Horário de saída',
      initial: TimeOfDay.fromDateTime(_departure),
    );
    if (picked == null) return;
    setState(
      () => _departure = DateTime(
        _departure.year,
        _departure.month,
        _departure.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  double? get _priceValue => double.tryParse(_price.text.replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recurrent && _weekdays.isEmpty) {
      showMessage(context, 'Escolha ao menos um dia da semana.');
      return;
    }
    setState(() => _saving = true);
    final repository = context.read<RideRepository>();
    final user = context.read<SessionController>().user!;
    final points = await Future.wait([
      geocodePlace(_origin.text, _originDetail.text),
      geocodePlace(_destination.text, _destinationDetail.text),
    ]);
    if (!mounted) return;
    final ok = await runAction(
      context,
      () => repository.offer(
        user,
        RideDraft(
          origin: _origin.text,
          originDetail: _originDetail.text,
          destination: _destination.text,
          destinationDetail: _destinationDetail.text,
          departure: _departure,
          durationMinutes: int.parse(_duration.text),
          seats: _seats,
          price: _priceValue!,
          weekdays: _recurrent ? _weekdays : const {},
          originPoint: points[0],
          destinationPoint: points[1],
        ),
      ),
      success: 'Carona publicada.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = context.watch<SessionController>().user?.vehicle;
    return Scaffold(
      appBar: AppBar(title: const Text('Oferecer carona')),
      body: vehicle == null
          ? _Requirement(
              icon: Icons.directions_car_outlined,
              text: 'Para oferecer carona, cadastre seu veículo primeiro.',
              action: 'Cadastrar veículo',
              onPressed: () => _open(const VehicleScreen()),
            )
          : switch (_license) {
              Approval.approved => _form(context, vehicle),
              null => _Requirement(
                icon: Icons.badge_outlined,
                text: 'Verificando sua CNH...',
                action: 'Tentar de novo',
                onPressed: _loadLicense,
              ),
              Approval.pending => _Requirement(
                icon: Icons.hourglass_top,
                text:
                    'Sua CNH está em análise. Você poderá oferecer caronas '
                    'depois da aprovação.',
                action: 'Verificar aprovação',
                onPressed: _loadLicense,
              ),
              Approval.missing => _Requirement(
                icon: Icons.badge_outlined,
                text: 'Agora envie a foto da sua CNH para análise.',
                action: 'Enviar foto da CNH',
                onPressed: () => _open(const LicenseScreen()),
              ),
              Approval.refused => _Requirement(
                icon: Icons.badge_outlined,
                text: 'Sua CNH não foi aprovada. Envie outra foto.',
                action: 'Enviar foto da CNH',
                onPressed: () => _open(const LicenseScreen()),
              ),
            },
    );
  }

  Widget _form(BuildContext context, Vehicle vehicle) {
    const gap = SizedBox(height: 12);
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? 'Campo obrigatório' : null;
    Widget field(
      TextEditingController controller,
      String label, {
      String? Function(String?)? validator,
      TextInputType? type,
    }) => TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Trajeto'),
            field(_origin, 'Saindo de (bairro ou campus)', validator: required),
            gap,
            field(_originDetail, 'Ponto de encontro', validator: required),
            gap,
            field(_destination, 'Destino (bairro ou campus)', validator: required),
            gap,
            field(_destinationDetail, 'Onde deixa as pessoas', validator: required),
            const SectionTitle('Saída'),
            Row(
              children: [
                if (!_recurrent) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        formatDay(_departure, context.read<RideRepository>().now),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(formatTime(_departure)),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetir toda semana'),
              value: _recurrent,
              onChanged: (v) => setState(() => _recurrent = v),
            ),
            if (_recurrent)
              Wrap(
                spacing: 8,
                children: [
                  for (final day in _weekdayLabels.entries)
                    FilterChip(
                      label: Text(day.value),
                      selected: _weekdays.contains(day.key),
                      onSelected: (on) => setState(
                        () => on
                            ? _weekdays.add(day.key)
                            : _weekdays.remove(day.key),
                      ),
                    ),
                ],
              ),
            const SectionTitle('Vagas e rateio'),
            Row(
              children: [
                const Expanded(child: Text('Vagas')),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (var i = 1; i <= RideRepository.maxSeats; i++)
                      ButtonSegment(value: i, label: Text('$i')),
                  ],
                  selected: {_seats},
                  onSelectionChanged: (s) => setState(() => _seats = s.first),
                ),
              ],
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: field(
                    _price,
                    'Rateio por pessoa (R\$)',
                    type: const TextInputType.numberWithOptions(decimal: true),
                    validator: (_) {
                      final value = _priceValue;
                      if (value == null || value < 0) return 'Valor inválido';
                      return value > RideRepository.maxPrice
                          ? 'Máximo de R\$ 30,00'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(
                    _duration,
                    'Duração (min)',
                    type: TextInputType.number,
                    validator: (v) {
                      final minutes = int.tryParse(v ?? '');
                      return minutes == null || minutes < 5 || minutes > 240
                          ? 'De 5 a 240'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            gap,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.model,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PlateBadge(vehicle.plate),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: AppTheme.laneButton,
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Publicando...' : 'Publicar carona'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.icon,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: AppColors.plate),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}
