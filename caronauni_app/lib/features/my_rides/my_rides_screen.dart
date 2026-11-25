import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/document_store.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../ride_detail/ride_detail_screen.dart';
import '../shared/feedback.dart';
import '../shared/person_avatar.dart';
import '../shared/rating_label.dart';
import '../shared/reloadable.dart';
import '../shared/road.dart';
import 'rate_dialog.dart';

typedef _Data = ({
  List<SeatRequest> received,
  List<MyRide> rides,
  List<Document> recurrences,
});

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  Future<_Data> _load(RideRepository repository, String userId) async => (
    received: await repository.receivedRequests(userId),
    rides: await repository.myRides(userId),
    recurrences: await repository.recurrences(userId),
  );

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RideRepository>();
    final user = context.read<SessionController>().user!;

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas caronas')),
      body: Reloadable<_Data>(
        load: () => _load(repository, user.id),
        builder: (context, data, reload) {
          final now = repository.now;
          final pending = data.received
              .where((r) => r.statusAt(now) == RequestStatus.pending)
              .toList();
          final upcoming = data.rides
              .where((r) => r.ride.departure.isAfter(now))
              .toList();
          final past = data.rides
              .where((r) => !r.ride.departure.isAfter(now))
              .toList()
              .reversed;
          return [
            if (pending.isNotEmpty) ...[
              const SectionTitle('Pedidos recebidos'),
              for (final request in pending)
                _RequestCard(request: request, reload: reload),
            ],
            const SectionTitle('Próximas'),
            if (upcoming.isEmpty) const EmptyText('Nenhuma carona marcada.'),
            for (final mine in upcoming) _RideTile(mine: mine, reload: reload),
            if (data.recurrences.isNotEmpty) ...[
              const SectionTitle('Recorrentes'),
              for (final doc in data.recurrences)
                _RecurrenceTile(document: doc, reload: reload),
            ],
            const SectionTitle('Histórico'),
            if (past.isEmpty) const EmptyText('Nada por aqui ainda.'),
            for (final mine in past) _RideTile(mine: mine, reload: reload),
          ];
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.reload});

  final SeatRequest request;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RideRepository>();
    Future<void> act(Future<void> Function() action, String success) async {
      await runAction(context, action, success: success);
      await reload();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PersonAvatar(name: request.passengerName),
              title: Text(request.passengerName),
              subtitle: Text(
                '${request.passengerCourse}\n'
                '${formatDay(request.departure, repository.now)}, '
                '${formatTime(request.departure)}',
              ),
              trailing: RatingLabel(userId: request.passengerId),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => act(
                      () => repository.refuse(request),
                      'Pedido recusado.',
                    ),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => act(
                      () => repository.accept(request),
                      'Pedido aceito.',
                    ),
                    child: const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.mine, required this.reload});

  final MyRide mine;
  final Future<void> Function() reload;

  String get _status {
    if (mine.ride.cancelled) return 'Cancelada';
    if (mine.isDriver) {
      return 'Você dirige: ${mine.ride.takenSeats} de '
          '${mine.ride.totalSeats} vagas ocupadas';
    }
    return switch (mine.status!) {
      RequestStatus.pending => 'Aguardando resposta',
      RequestStatus.accepted => 'Confirmada com ${mine.ride.driver.name}',
      RequestStatus.refused => 'Pedido recusado',
      RequestStatus.cancelled => 'Você cancelou',
      RequestStatus.expired => 'Pedido expirado',
    };
  }

  PillTone get _tone {
    if (mine.ride.cancelled) return PillTone.bad;
    if (mine.isDriver) return PillTone.good;
    return switch (mine.status!) {
      RequestStatus.pending => PillTone.waiting,
      RequestStatus.accepted => PillTone.good,
      RequestStatus.refused => PillTone.bad,
      RequestStatus.cancelled || RequestStatus.expired => PillTone.neutral,
    };
  }

  Future<void> _rate(BuildContext context) async {
    final repository = context.read<RideRepository>();
    final user = context.read<SessionController>().user!;
    final people = mine.isDriver
        ? [
            for (final p in await repository.passengers(mine.ride))
              (p.passengerId, p.passengerName),
          ]
        : [(mine.ride.driver.id, mine.ride.driver.name)];
    if (!context.mounted) return;
    if (people.isEmpty) {
      showMessage(context, 'Esta carona não teve passageiros.');
      return;
    }
    await showRateDialog(
      context,
      ride: mine.ride,
      from: user,
      people: people,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RideRepository>();
    final user = context.read<SessionController>().user!;
    final ride = mine.ride;
    final future = ride.departure.isAfter(repository.now);
    final took = mine.isDriver || mine.status == RequestStatus.accepted;
    final canCancel =
        future &&
        !ride.cancelled &&
        (took || mine.status == RequestStatus.pending);

    Future<void> cancel() async {
      final late = !repository.now.isBefore(
        ride.departure.subtract(const Duration(hours: 1)),
      );
      final ok = await confirm(
        context,
        title: 'Cancelar?',
        text: late && took
            ? 'Falta menos de 1h: se houver vaga confirmada, conta como falta.'
            : 'As pessoas envolvidas serão avisadas.',
        action: 'Cancelar carona',
      );
      if (!ok || !context.mounted) return;
      await runAction(
        context,
        () => mine.isDriver
            ? repository.cancelRide(ride, user)
            : repository.cancelRequest(mine.request!, user),
        success: 'Cancelado.',
      );
      await reload();
    }

    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RideDetailScreen(ride: ride),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatDay(ride.departure, repository.now)}, '
                '${formatTime(ride.departure)}',
                style: text.titleLarge,
              ),
              const SizedBox(height: 12),
              RouteStops(from: ride.origin, to: ride.destination),
              const SizedBox(height: 14),
              StatusPill(_status, tone: _tone),
              if (canCancel || (took && repository.canRate(ride)))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      if (canCancel)
                        TextButton(
                          onPressed: cancel,
                          child: const Text('Cancelar'),
                        ),
                      if (took && repository.canRate(ride))
                        TextButton(
                          onPressed: () => _rate(context),
                          child: const Text('Avaliar ou informar falta'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceTile extends StatelessWidget {
  const _RecurrenceTile({required this.document, required this.reload});

  final Document document;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    const labels = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    final data = document.data;
    final ride = Json.from(data['ride'] as Map);
    final days = [
      for (final d in data['weekdays'] as List) labels[(d as int) - 1],
    ].join(', ');
    final minutes = (data['hour'] as int) * 60 + (data['minute'] as int);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('De ${ride['origin']} para ${ride['destination']}'),
        subtitle: Text('$days às ${formatMinutesOfDay(minutes)}'),
        trailing: TextButton(
          onPressed: () async {
            await runAction(
              context,
              () => context.read<RideRepository>().stopRecurrence(document.id),
              success: 'Não serão criadas novas viagens.',
            );
            await reload();
          },
          child: const Text('Encerrar'),
        ),
      ),
    );
  }
}
