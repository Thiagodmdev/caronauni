import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../shared/feedback.dart';

Future<void> showRateDialog(
  BuildContext context, {
  required Ride ride,
  required AppUser from,
  required List<(String, String)> people,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          for (final person in people)
            _RatePerson(
              ride: ride,
              from: from,
              id: person.$1,
              name: person.$2,
            ),
        ],
      ),
    ),
  ),
);

class _RatePerson extends StatefulWidget {
  const _RatePerson({
    required this.ride,
    required this.from,
    required this.id,
    required this.name,
  });

  final Ride ride;
  final AppUser from;
  final String id;
  final String name;

  @override
  State<_RatePerson> createState() => _RatePersonState();
}

class _RatePersonState extends State<_RatePerson> {
  int _stars = 5;
  String _text = '';
  String? _done;

  Future<void> _run(Future<void> Function() action, String done) async {
    final ok = await runAction(context, action);
    if (ok && mounted) setState(() => _done = done);
    if (!ok && mounted) setState(() => _done = 'Já registrado ou fora do prazo.');
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RideRepository>();
    final done = _done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.name, style: Theme.of(context).textTheme.titleMedium),
        if (done != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(done))
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i de 5',
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFE09B00),
                  ),
                ),
            ],
          ),
          TextField(
            maxLength: 300,
            onChanged: (t) => _text = t,
            decoration: const InputDecoration(labelText: 'Comentário (opcional)'),
          ),
          FilledButton(
            onPressed: () => _run(
              () => repository.rate(
                ride: widget.ride,
                from: widget.from,
                toId: widget.id,
                stars: _stars,
                text: _text,
              ),
              'Avaliação enviada.',
            ),
            child: const Text('Enviar avaliação'),
          ),
          TextButton(
            onPressed: () => _run(
              () => repository.reportNoShow(
                ride: widget.ride,
                from: widget.from,
                userId: widget.id,
                userName: widget.name,
              ),
              'Falta registrada.',
            ),
            child: const Text('Não compareceu'),
          ),
          TextButton(
            onPressed: () async {
              final reason = await askText(
                context,
                title: 'Denunciar ${widget.name}',
                label: 'O que aconteceu?',
                action: 'Enviar',
              );
              if (reason == null) return;
              await _run(
                () => repository.report(
                  from: widget.from,
                  toId: widget.id,
                  toName: widget.name,
                  reason: reason,
                ),
                'Denúncia enviada para análise.',
              );
            },
            child: const Text('Denunciar'),
          ),
        ],
        const Divider(),
      ],
    );
  }
}
