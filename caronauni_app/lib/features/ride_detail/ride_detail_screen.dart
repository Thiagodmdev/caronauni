import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../shared/feedback.dart';
import '../shared/person_avatar.dart';
import '../shared/rating_label.dart';
import 'ride_detail_view_model.dart';
import 'ride_map.dart';

class RideDetailScreen extends StatelessWidget {
  const RideDetailScreen({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RideDetailViewModel(
        repository: context.read<RideRepository>(),
        ride: ride,
        user: context.read<SessionController>().user!,
      ),
      child: const _RideDetailView(),
    );
  }
}

class _RideDetailView extends StatelessWidget {
  const _RideDetailView();

  Future<void> _report(BuildContext context, Ride ride) async {
    final repository = context.read<RideRepository>();
    final user = context.read<SessionController>().user!;
    final reason = await askText(
      context,
      title: 'Denunciar ${ride.driver.name}',
      label: 'O que aconteceu?',
      action: 'Enviar',
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => repository.report(
        from: user,
        toId: ride.driver.id,
        toName: ride.driver.name,
        reason: reason,
      ),
      success: 'Denúncia enviada para análise.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RideDetailViewModel>();
    final ride = viewModel.ride;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da carona'),
        actions: [
          if (!viewModel.isDriver)
            IconButton(
              tooltip: 'Denunciar',
              onPressed: () => _report(context, ride),
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RouteCard(ride: ride),
          const SizedBox(height: 12),
          if (ride.originPoint != null && ride.destinationPoint != null) ...[
            RideMap(
              origin: ride.originPoint!,
              destination: ride.destinationPoint!,
            ),
            const SizedBox(height: 12),
          ],
          if (viewModel.phone != null) ...[
            _ContactCard(phone: viewModel.phone!),
            const SizedBox(height: 12),
          ],
          _DriverCard(driver: ride.driver),
          const SizedBox(height: 12),
          _VehicleCard(vehicle: ride.vehicle),
          const SizedBox(height: 12),
          _ReviewsSection(reviews: viewModel.reputation?.reviews ?? const []),
        ],
      ),
      bottomNavigationBar: viewModel.isDriver || ride.cancelled
          ? null
          : _RequestBar(viewModel: viewModel),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seats = ride.availableSeats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatDay(ride.departure, DateTime.now())}, '
              'às ${formatTime(ride.departure)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _RouteStop(
              icon: Icons.radio_button_checked,
              time: formatTime(ride.departure),
              place: ride.origin,
              detail: ride.originDetail,
              showLine: true,
            ),
            _RouteStop(
              icon: Icons.location_on,
              time: formatTime(ride.arrival),
              place: ride.destination,
              detail: ride.destinationDetail,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Rateio por pessoa',
                    value: formatPrice(ride.price),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Vagas livres',
                    value: '$seats de ${ride.totalSeats}',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Duração',
                    value: '${ride.durationMinutes} min',
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

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.icon,
    required this.time,
    required this.place,
    required this.detail,
    this.showLine = false,
  });

  final IconData icon;
  final String time;
  final String place;
  final String detail;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Text(time, style: theme.textTheme.bodyMedium),
          ),
          Column(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              if (showLine)
                Expanded(
                  child: Container(width: 2, color: scheme.outlineVariant),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            PersonAvatar(name: driver.name, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    driver.course,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            RatingLabel(userId: driver.id, showCount: true),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Text(phone),
        subtitle: const Text('Combine o encontro'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Ligar',
              onPressed: () => launchUrl(Uri.parse('tel:+55$digits')),
              icon: const Icon(Icons.phone_outlined),
            ),
            IconButton(
              tooltip: 'WhatsApp',
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/55$digits'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.chat_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(Icons.directions_car_outlined, color: scheme.primary),
        title: Text('${vehicle.model} ${vehicle.color.toLowerCase()}'),
        subtitle: Text('Placa ${vehicle.plate}'),
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            'Avaliações recentes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final review in reviews)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonAvatar(name: review.author, radius: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.author,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          for (var i = 0; i < review.stars; i++)
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                        ],
                      ),
                      Text(review.text, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RequestBar extends StatelessWidget {
  const _RequestBar({required this.viewModel});

  final RideDetailViewModel viewModel;

  Future<void> _confirmRequest(BuildContext context) async {
    final ride = viewModel.ride;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pedir vaga nesta carona?'),
        content: Text(
          '${ride.driver.name} vai receber seu pedido. O rateio de '
          '${formatPrice(ride.price)} é acertado direto com quem dirige.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pedir vaga'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.requestSeat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = viewModel.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              Text(error, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 8),
            ],
            if (viewModel.status == RequestStatus.pending ||
                viewModel.status == RequestStatus.accepted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        viewModel.status == RequestStatus.accepted
                            ? 'Vaga confirmada. Boa viagem!'
                            : 'Pedido enviado. Aguardando a resposta de quem '
                                  'dirige. O telefone aparece depois da '
                                  'aceitação.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: viewModel.busy ? null : viewModel.cancelRequest,
                child: Text(
                  viewModel.status == RequestStatus.accepted
                      ? 'Cancelar participação'
                      : 'Cancelar pedido',
                ),
              ),
            ] else ...[
              if (viewModel.status == RequestStatus.refused ||
                  viewModel.status == RequestStatus.expired) ...[
                Text(
                  viewModel.status == RequestStatus.refused
                      ? 'Seu pedido anterior foi recusado.'
                      : 'Seu pedido anterior expirou.',
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: viewModel.busy
                    ? null
                    : () => _confirmRequest(context),
                icon: const Icon(Icons.front_hand_outlined),
                label: const Text('Pedir vaga'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
