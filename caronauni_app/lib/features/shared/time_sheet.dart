import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';

/// Escolhe hora e minuto tocando direto nos números.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required String title,
  required TimeOfDay initial,
}) => showModalBottomSheet<TimeOfDay>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (_) => _TimeSheet(title: title, initial: initial),
);

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.title, required this.initial});

  final String title;
  final TimeOfDay initial;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  static const _step = 5;

  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute ~/ _step * _step;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: text.titleMedium)),
              Text(
                formatMinutesOfDay(_hour * 60 + _minute),
                style: text.headlineMedium?.copyWith(color: AppColors.plate),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Hora', style: text.labelLarge),
          const SizedBox(height: 6),
          _NumberGrid(
            label: 'hora',
            values: [for (var h = 0; h < 24; h++) h],
            selected: _hour,
            onSelected: (h) => setState(() => _hour = h),
          ),
          const SizedBox(height: 14),
          Text('Minuto', style: text.labelLarge),
          const SizedBox(height: 6),
          _NumberGrid(
            label: 'minuto',
            values: [for (var m = 0; m < 60; m += _step) m],
            selected: _minute,
            onSelected: (m) => setState(() => _minute = m),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: AppTheme.laneButton,
            onPressed: () => Navigator.of(
              context,
            ).pop(TimeOfDay(hour: _hour, minute: _minute)),
            child: const Text('Usar este horário'),
          ),
        ],
      ),
    );
  }
}

class _NumberGrid extends StatelessWidget {
  const _NumberGrid({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  static const _columns = 6;

  final String label;
  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < values.length; row += _columns)
        Row(
          children: [
            for (final value in values.skip(row).take(_columns))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _cell(context, value),
                ),
              ),
          ],
        ),
    ],
  );

  Widget _cell(BuildContext context, int value) {
    final isSelected = value == selected;
    final number = value.toString().padLeft(2, '0');
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label $number',
      excludeSemantics: true,
      onTap: () => onSelected(value),
      child: Material(
        key: ValueKey('$label $number'),
        color: isSelected ? AppColors.lane : AppColors.paper,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelected(value),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(number, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        ),
      ),
    );
  }
}
