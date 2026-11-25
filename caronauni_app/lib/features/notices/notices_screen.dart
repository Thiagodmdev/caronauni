import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../shared/reloadable.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  /// O lembrete de 1h antes (RF14) é calculado ao abrir a tela.
  Future<(List<AppNotice>, List<Ride>)> _load(
    RideRepository repository,
    String userId,
  ) async {
    final notices = await repository.notices(userId);
    final now = repository.now;
    final soon = [
      for (final mine in await repository.myRides(userId))
        if (!mine.ride.cancelled &&
            (mine.isDriver || mine.status == RequestStatus.accepted) &&
            mine.ride.departure.isAfter(now) &&
            mine.ride.departure.difference(now) <= const Duration(hours: 1))
          mine.ride,
    ];
    for (final notice in notices.where((n) => !n.read)) {
      await repository.markRead(notice);
    }
    return (notices, soon);
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RideRepository>();
    final userId = context.read<SessionController>().user!.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: Reloadable(
        load: () => _load(repository, userId),
        builder: (context, data, _) {
          final (notices, soon) = data;
          return [
            for (final ride in soon)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text('Sua carona sai às ${formatTime(ride.departure)}'),
                  subtitle: Text('${ride.origin} → ${ride.destination}'),
                ),
              ),
            if (notices.isEmpty && soon.isEmpty)
              const EmptyText('Nenhum aviso por enquanto.'),
            for (final notice in notices)
              ListTile(
                leading: Icon(
                  notice.read
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                ),
                title: Text(notice.text),
                subtitle: Text(
                  '${formatDay(notice.createdAt, repository.now)}, '
                  '${formatTime(notice.createdAt)}',
                ),
              ),
          ];
        },
      ),
    );
  }
}
