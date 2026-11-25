// Compara a lista preguiçosa do app com uma lista que cria todos os cartões.
// Build:  flutter build apk --release -t benchmark/list_benchmark_app.dart
// Rodar:  abrir no celular, escolher um modo e esperar o resultado na tela.
//         Feche o app por completo entre uma medição e outra.
import 'dart:io';
import 'dart:ui';

import 'package:caronauni/core/theme.dart';
import 'package:caronauni/data/auth_repository.dart';
import 'package:caronauni/data/demo_data.dart';
import 'package:caronauni/data/ride_repository.dart';
import 'package:caronauni/features/auth/session_controller.dart';
import 'package:caronauni/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

const int rideCount = 1000;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();
  final store = await storeWith(manyRides(rideCount, now));
  await seedDemo(store, now);
  runApp(
    MultiProvider(
      providers: [
        Provider<RideRepository>.value(
          value: RideRepository(store, searchLimit: rideCount),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionController(MockAuthRepository(store)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const _ModePicker(),
      ),
    ),
  );
}

class _ModePicker extends StatelessWidget {
  const _ModePicker();

  @override
  Widget build(BuildContext context) {
    void start(bool eager) => Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => _Benchmark(eager: eager)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Medição da lista')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            FilledButton(
              onPressed: () => start(true),
              child: const Text('Antes: lista completa'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => start(false),
              child: const Text('Depois: lista sob demanda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benchmark extends StatefulWidget {
  const _Benchmark({required this.eager});

  final bool eager;

  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark> {
  final _controller = ScrollController();
  final _timings = <FrameTiming>[];
  SliverChildBuilderDelegate? _delegate;
  String? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// Usa os mesmos cartões da tela de busca real.
  SliverChildBuilderDelegate? _findDelegate() {
    SliverChildBuilderDelegate? found;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is ListView) {
        found = widget.childrenDelegate as SliverChildBuilderDelegate;
      }
      if (found == null) element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  Future<void> _run() async {
    while (_findDelegateSafely() == null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final delegate = _findDelegateSafely()!;
    await Future<void>.delayed(const Duration(seconds: 8));

    WidgetsBinding.instance.addTimingsCallback(_timings.addAll);
    setState(() => _delegate = delegate);
    await Future<void>.delayed(const Duration(seconds: 6));
    final mount = _timings
        .map((t) => t.buildDuration.inMicroseconds / 1000)
        .reduce((a, b) => a > b ? a : b);
    final rss = ProcessInfo.currentRss ~/ (1024 * 1024);

    _timings.clear();
    await _controller.animateTo(
      6000,
      duration: const Duration(seconds: 6),
      curve: Curves.linear,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    final build = _timings
        .map((t) => t.buildDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final raster = _timings
        .map((t) => t.rasterDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final slow = build.where((ms) => ms > 1000 / 60).length;
    final result =
      'RESULT modo=${widget.eager ? 'eager' : 'lazy'} n=$rideCount '
      'montagem_ms=${mount.toStringAsFixed(1)} rss_mb=$rss '
      'quadros=${build.length} '
      'build_p50=${build[build.length ~/ 2].toStringAsFixed(2)} '
      'build_p90=${build[build.length * 9 ~/ 10].toStringAsFixed(2)} '
      'build_acima_16ms=$slow '
      'raster_p50=${raster[raster.length ~/ 2].toStringAsFixed(2)} '
      'raster_p90=${raster[raster.length * 9 ~/ 10].toStringAsFixed(2)}';
    // ignore: avoid_print
    print(result);
    if (mounted) setState(() => _result = result);
  }

  SliverChildBuilderDelegate? _findDelegateSafely() =>
      mounted && context.findRenderObject() != null ? _findDelegate() : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultado')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            result.split(' ').join('\n'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
    }
    final delegate = _delegate;
    if (delegate == null) return const SearchScreen();
    if (!widget.eager) {
      return Scaffold(
        body: ListView.custom(
          controller: _controller,
          padding: const EdgeInsets.all(16),
          childrenDelegate: delegate,
        ),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < delegate.estimatedChildCount!; i++)
              delegate.builder(context, i)!,
          ],
        ),
      ),
    );
  }
}
