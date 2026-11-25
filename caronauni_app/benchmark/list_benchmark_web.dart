// Mesma comparação do list_benchmark_app, para o navegador. Quem mede FPS e
// memória é o próprio navegador, pelo protocolo do DevTools (measure_web.mjs).
// Build: flutter build web --release -t benchmark/list_benchmark_web.dart \
//          -o build/web_bench
// Abrir: index.html?modo=antes ou index.html?modo=depois
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

void _mark(String phase) {
  // ignore: avoid_print
  print('BENCH $phase');
}

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
        home: _Benchmark(eager: Uri.base.queryParameters['modo'] == 'antes'),
      ),
    ),
  );
}

class _Benchmark extends StatefulWidget {
  const _Benchmark({required this.eager});

  final bool eager;

  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark> {
  final _controller = ScrollController();
  SliverChildBuilderDelegate? _delegate;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SliverChildBuilderDelegate? _find() {
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
    SliverChildBuilderDelegate? delegate;
    while (delegate == null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      delegate = _find();
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    _mark('mount_start');
    final watch = Stopwatch()..start();
    setState(() => _delegate = delegate);
    await WidgetsBinding.instance.endOfFrame;
    _mark('mounted ${watch.elapsedMicroseconds / 1000}');
    await Future<void>.delayed(const Duration(seconds: 4));
    _mark('scroll_start');
    await _controller.animateTo(
      6000,
      duration: const Duration(seconds: 6),
      curve: Curves.linear,
    );
    _mark('scroll_end');
  }

  @override
  Widget build(BuildContext context) {
    final delegate = _delegate;
    if (delegate == null) return const SearchScreen();
    const padding = EdgeInsets.all(16);
    return Scaffold(
      body: widget.eager
          ? SingleChildScrollView(
              controller: _controller,
              padding: padding,
              child: Column(
                children: [
                  for (var i = 0; i < delegate.estimatedChildCount!; i++)
                    delegate.builder(context, i)!,
                ],
              ),
            )
          : ListView.custom(
              controller: _controller,
              padding: padding,
              childrenDelegate: delegate,
            ),
    );
  }
}
