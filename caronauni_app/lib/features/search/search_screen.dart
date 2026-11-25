import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/ride_repository.dart';
import '../auth/session_controller.dart';
import '../../models/models.dart';
import '../ride_detail/ride_detail_screen.dart';
import '../shared/person_avatar.dart';
import '../shared/rating_label.dart';
import '../shared/road.dart';
import 'search_view_model.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SearchViewModel(context.read<RideRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatelessWidget {
  const _SearchView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SearchViewModel>();
    final user = context.read<SessionController>().user;

    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Olá, ${user?.firstName ?? ''}',
          style: text.titleMedium?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => context.read<SessionController>().signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          SignPanel(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para onde você vai?',
                  style: text.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: viewModel.setDestination,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Buscar destino (ex.: Centro)',
                    prefixIcon: Icon(Icons.search, color: AppColors.plate),
                  ),
                ),
              ],
            ),
          ),
          _Filters(viewModel: viewModel),
          Expanded(child: _Results(viewModel: viewModel)),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.viewModel});

  final SearchViewModel viewModel;

  Future<void> _pickTime(BuildContext context) async {
    final minutes = viewModel.minutesOfDay;
    final picked = await showTimePicker(
      context: context,
      helpText: 'Horário de saída desejado',
      initialTime: minutes == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) viewModel.setTime(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      DayFilter.all: 'Todas as datas',
      DayFilter.today: 'Hoje',
      DayFilter.tomorrow: 'Amanhã',
    };
    final minutes = viewModel.minutesOfDay;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: viewModel.day == entry.key,
              onSelected: (_) => viewModel.setDay(entry.key),
            ),
            const SizedBox(width: 8),
          ],
          InputChip(
            avatar: const Icon(Icons.schedule, size: 18),
            label: Text(
              minutes == null
                  ? 'Horário'
                  : 'Por volta de ${formatMinutesOfDay(minutes)}',
            ),
            selected: minutes != null,
            showCheckmark: false,
            onPressed: () => _pickTime(context),
            onDeleted: minutes == null ? null : () => viewModel.setTime(null),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.viewModel});

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.loading && viewModel.rides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.failed) {
      return Center(
        child: TextButton(
          onPressed: viewModel.search,
          child: const Text('Não foi possível carregar. Tentar de novo'),
        ),
      );
    }
    if (viewModel.rides.isEmpty) return const _EmptyResults();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: viewModel.rides.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = viewModel.rides[index];
        return _RideCard(key: ValueKey(ride.id), ride: ride);
      },
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma carona encontrada',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tente outro destino, data ou horário.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seats = ride.availableSeats;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RideDetailScreen(ride: ride)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    formatDay(ride.departure, DateTime.now()),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatPrice(ride.price),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.go,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: RouteStops(
                      from: 'Saindo de ${ride.origin}',
                      to: ride.destination,
                      fromTime: formatTime(ride.departure),
                      toTime: formatTime(ride.arrival),
                      emphasizeTo: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SeatRow(total: ride.totalSeats, free: seats),
                      Text(
                        seats == 1 ? '1 vaga' : '$seats vagas',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  PersonAvatar(name: ride.driver.name, radius: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.driver.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RatingLabel(userId: ride.driver.id),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
