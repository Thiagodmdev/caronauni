import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';
import '../auth/session_controller.dart';
import '../shared/road.dart';
import 'ride_detail_screen.dart';
import 'ride_detail_view_model.dart';

/// Acompanha o pedido de vaga até a resposta de quem dirige.
class RequestStatusScreen extends StatelessWidget {
  const RequestStatusScreen({
    super.key,
    required this.ride,
    this.fromDetail = false,
  });

  final Ride ride;

  /// Aberta pela própria tela de detalhes, que está logo atrás.
  final bool fromDetail;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => RideDetailViewModel(
      repository: context.read<RideRepository>(),
      ride: ride,
      user: context.read<SessionController>().user!,
    ),
    child: _RequestStatusView(fromDetail: fromDetail),
  );
}

class _RequestStatusView extends StatefulWidget {
  const _RequestStatusView({required this.fromDetail});

  final bool fromDetail;

  @override
  State<_RequestStatusView> createState() => _RequestStatusViewState();
}

class _RequestStatusViewState extends State<_RequestStatusView> {
  static const _interval = Duration(seconds: 5);

  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<RideDetailViewModel>();
    _timer = Timer.periodic(_interval, (timer) {
      if (viewModel.status == RequestStatus.pending) {
        viewModel.refresh();
      } else if (viewModel.status != null) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _openRide(Ride ride) {
    final navigator = Navigator.of(context);
    if (widget.fromDetail) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => RideDetailScreen(ride: ride)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RideDetailViewModel>();
    final ride = viewModel.ride;
    final status = viewModel.status;
    final text = Theme.of(context).textTheme;
    final driver = ride.driver.name.split(' ').first;
    final error = viewModel.error;

    final (title, message) = switch (status) {
      RequestStatus.pending => (
        'Aguardando $driver aceitar',
        'Esta tela se atualiza sozinha. Você pode sair: o pedido continua em '
            'Caronas.',
      ),
      RequestStatus.accepted => (
        'Vaga confirmada',
        'Combine o ponto de encontro com $driver pelo telefone ou WhatsApp.',
      ),
      RequestStatus.refused => (
        'Pedido recusado',
        'Busque outra carona para o mesmo destino.',
      ),
      RequestStatus.expired => (
        'Pedido expirado',
        '$driver não respondeu a tempo. Busque outra carona.',
      ),
      RequestStatus.cancelled => (
        'Pedido cancelado',
        'Você pode pedir a vaga de novo na tela da carona.',
      ),
      null => ('Carregando pedido', 'Só um momento.'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Seu pedido')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SignPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          title,
                          style: text.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: text.bodyLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const RoadScene(height: 120),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Steps(status: status, driver: driver),
                if (status == RequestStatus.pending &&
                    viewModel.request != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'O pedido vale até '
                    '${formatTime(viewModel.request!.expiresAt)} '
                    '(${formatDay(viewModel.request!.expiresAt, DateTime.now())}).',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatDay(ride.departure, DateTime.now())}, '
                          'às ${formatTime(ride.departure)}',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        RouteStops(
                          from: ride.origin,
                          to: ride.destination,
                          fromDetail: ride.originDetail,
                          toDetail: ride.destinationDetail,
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error, style: const TextStyle(color: AppColors.stop)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => _openRide(ride),
                  child: Text(
                    status == RequestStatus.accepted
                        ? 'Ver carona e contato'
                        : 'Ver carona',
                  ),
                ),
                if (status == RequestStatus.pending) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: viewModel.busy ? null : viewModel.cancelRequest,
                    child: const Text('Cancelar pedido'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etapas do pedido, na ordem em que acontecem.
class _Steps extends StatelessWidget {
  const _Steps({required this.status, required this.driver});

  final RequestStatus? status;
  final String driver;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accepted = status == RequestStatus.accepted;
    final pending = status == RequestStatus.pending;
    final stopped =
        status == RequestStatus.refused ||
        status == RequestStatus.expired ||
        status == RequestStatus.cancelled;

    Widget step(IconData icon, Color color, String label, {bool off = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: text.titleMedium?.copyWith(
                    color: off ? AppColors.muted : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        );

    return Column(
      children: [
        step(Icons.check_circle_rounded, AppColors.go, 'Pedido enviado'),
        if (stopped)
          step(Icons.cancel_rounded, AppColors.stop, switch (status) {
            RequestStatus.refused => 'Recusado por $driver',
            RequestStatus.expired => 'Sem resposta no prazo',
            _ => 'Cancelado por você',
          })
        else ...[
          step(
            accepted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            accepted
                ? AppColors.go
                : pending
                ? const Color(0xFFB57A00)
                : AppColors.line,
            accepted ? '$driver aceitou' : 'Aguardando resposta de $driver',
            off: !accepted && !pending,
          ),
          step(
            accepted ? Icons.check_circle_rounded : Icons.circle_outlined,
            accepted ? AppColors.go : AppColors.line,
            'Vaga garantida e telefone liberado',
            off: !accepted,
          ),
        ],
      ],
    );
  }
}
