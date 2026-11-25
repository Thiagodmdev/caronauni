import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Pista com a faixa amarela: a imagem da marca na entrada do app.
/// O carro percorre a pista uma única vez, ao abrir.
class RoadScene extends StatefulWidget {
  const RoadScene({super.key, this.height = 190});

  final double height;

  @override
  State<RoadScene> createState() => _RoadSceneState();
}

class _RoadSceneState extends State<RoadScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(painter: _RoadPainter(_progress)),
      ),
    ),
  );
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  Path _road(Size s) => Path()
    ..moveTo(-40, s.height * 0.86)
    ..cubicTo(
      s.width * 0.30,
      s.height * 1.05,
      s.width * 0.30,
      s.height * 0.30,
      s.width * 0.56,
      s.height * 0.42,
    )
    ..cubicTo(
      s.width * 0.80,
      s.height * 0.53,
      s.width * 0.74,
      s.height * 0.10,
      s.width + 40,
      s.height * 0.16,
    );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final road = _road(size);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 58
      ..color = AppColors.asphalt;
    canvas.drawPath(road, stroke);

    final metric = road.computeMetrics().first;
    final lane = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = AppColors.lane;
    for (var d = 0.0; d < metric.length; d += 34) {
      canvas.drawPath(metric.extractPath(d, d + 18), lane);
    }

    final end = metric.length * 0.60;
    final at = metric.getTangentForOffset(math.max(1, end * progress.value))!;
    canvas
      ..save()
      ..translate(at.position.dx, at.position.dy)
      ..rotate(-at.angle)
      ..translate(0, 15);
    _car(canvas);
    canvas.restore();
  }

  /// Carro visto de cima.
  void _car(Canvas canvas) {
    final body = Paint()..color = Colors.white;
    final glass = Paint()..color = AppColors.plate;
    RRect box(double l, double t, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));
    canvas
      ..drawRRect(box(-23, -10, 46, 20, 7), body)
      ..drawRRect(box(4, -8, 8, 16, 3), glass)
      ..drawRRect(box(-17, -7, 5, 14, 2), glass)
      ..drawRRect(box(20, -8, 3, 4, 1), Paint()..color = AppColors.lane)
      ..drawRRect(box(20, 4, 3, 4, 1), Paint()..color = AppColors.lane);
  }

  @override
  bool shouldRepaint(_RoadPainter old) => false;
}

/// Trajeto da carona: saída, faixa tracejada e chegada.
class RouteStops extends StatelessWidget {
  const RouteStops({
    super.key,
    required this.from,
    required this.to,
    this.fromTime,
    this.toTime,
    this.fromDetail,
    this.toDetail,
    this.onDark = false,
    this.large = false,
    this.emphasizeTo = false,
  });

  final String from;
  final String to;
  final String? fromTime;
  final String? toTime;
  final String? fromDetail;
  final String? toDetail;
  final bool onDark;
  final bool large;

  /// Na busca, o destino é o que a pessoa procura.
  final bool emphasizeTo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = onDark ? Colors.white : AppColors.ink;
    final soft = onDark ? Colors.white.withValues(alpha: 0.8) : AppColors.muted;

    Widget stop(
      String place,
      String? detail,
      String? time, {
      required bool last,
    }) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (time != null)
            SizedBox(
              width: 54,
              child: Text(time, style: text.titleSmall?.copyWith(color: ink)),
            ),
          SizedBox(
            width: 18,
            child: CustomPaint(
              painter: _StopPainter(
                last: last,
                color: onDark ? AppColors.lane : AppColors.plate,
                hole: onDark ? AppColors.plate : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    style:
                        (large || last && emphasizeTo
                                ? text.titleLarge
                                : emphasizeTo
                                ? text.bodyMedium
                                : text.titleMedium)
                            ?.copyWith(color: ink, height: 1.15),
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(detail, style: text.bodySmall?.copyWith(color: soft)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        stop(from, fromDetail, fromTime, last: false),
        stop(to, toDetail, toTime, last: true),
      ],
    );
  }
}

class _StopPainter extends CustomPainter {
  const _StopPainter({
    required this.last,
    required this.color,
    required this.hole,
  });

  final bool last;
  final Color color;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 10);
    final paint = Paint()..color = color;
    if (last) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 14, height: 14),
          const Radius.circular(3),
        ),
        paint,
      );
    } else {
      canvas
        ..drawCircle(center, 7, paint)
        ..drawCircle(center, 3, Paint()..color = hole);
      for (var y = 22.0; y < size.height; y += 9) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 1.5, y, 3, math.min(5, size.height - y)),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StopPainter old) =>
      old.last != last || old.color != color || old.hole != hole;
}

/// Um assento por vaga: cheio quando ocupado.
class SeatRow extends StatelessWidget {
  const SeatRow({super.key, required this.total, required this.free});

  final int total;
  final int free;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Icon(
            i < free ? Icons.event_seat_rounded : Icons.event_seat_outlined,
            size: 18,
            color: i < free ? AppColors.plate : AppColors.line,
          ),
      ],
    ),
  );
}

/// Placa do veículo, para reconhecer o carro no ponto de encontro.
class PlateBadge extends StatelessWidget {
  const PlateBadge(this.plate, {super.key});

  final String plate;

  @override
  Widget build(BuildContext context) {
    // Só a placa Mercosul tem a faixa azul; a antiga tem só números no fim.
    final mercosul = RegExp(r'^[A-Z]{3}\d[A-Z]').hasMatch(plate);
    return Semantics(
      label: 'Placa $plate',
      excludeSemantics: true,
      child: Container(
        width: 112,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: mercosul ? Colors.white : AppColors.line,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mercosul)
              Container(
                width: double.infinity,
                color: AppColors.plate,
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: const Text(
                  'Brasil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 1),
              child: Text(
                plate,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PillTone { good, waiting, bad, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.tone = PillTone.neutral});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PillTone.good => (AppColors.goSoft, AppColors.go),
      PillTone.waiting => (AppColors.laneSoft, AppColors.ink),
      PillTone.bad => (AppColors.stopSoft, AppColors.stop),
      PillTone.neutral => (AppColors.paper, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: foreground),
      ),
    );
  }
}

/// Painel azul de placa que abre as telas principais.
class SignPanel extends StatelessWidget {
  const SignPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.fromLTRB(20, 4, 20, 24),
    decoration: const BoxDecoration(
      color: AppColors.plate,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: child,
  );
}
