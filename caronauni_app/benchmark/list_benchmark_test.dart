// Rodar com: flutter test benchmark/list_benchmark_test.dart
import 'package:caronauni/app.dart';
import 'package:caronauni/core/theme.dart';
import 'package:caronauni/data/auth_repository.dart';
import 'package:caronauni/data/demo_data.dart';
import 'package:caronauni/data/document_store.dart';
import 'package:caronauni/data/ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

class _CountingStore extends MemoryStore {
  int ratingQueries = 0;

  @override
  Future<List<Document>> query(
    String collection, {
    Json where = const {},
    String? atLeastField,
    int? atLeast,
    int limit = 100,
  }) {
    if (collection == 'ratings') ratingQueries++;
    return super.query(
      collection,
      where: where,
      atLeastField: atLeastField,
      atLeast: atLeast,
      limit: limit,
    );
  }
}

void main() {
  final now = DateTime(2026, 11, 24, 10);
  const count = 1000;

  testWidgets('lista completa x lista sob demanda', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final store = _CountingStore();
    await seedDemo(store, now);
    for (final ride in manyRides(count, now)) {
      await store.set('rides/${ride.id}', ride.toJson());
    }
    final repository = RideRepository(
      store,
      clock: () => now,
      searchLimit: count,
    );
    final auth = MockAuthRepository(store, latency: Duration.zero);
    await tester.pumpWidget(
      CaronaUniApp(authRepository: auth, rideRepository: repository),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      MockAuthRepository.demoEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      MockAuthRepository.demoPassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    final delegate = tester
        .widget<ListView>(find.byType(ListView))
        .childrenDelegate as SliverChildBuilderDelegate;

    Future<(double, int)> measure(Widget list) async {
      final times = <double>[];
      var elements = 0;
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final watch = Stopwatch()..start();
        await tester.pumpWidget(
          Provider<RideRepository>.value(
            value: repository,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(body: list),
            ),
          ),
        );
        times.add(watch.elapsedMicroseconds / 1000);
        await tester.pumpAndSettle();
        elements = find.byType(Card).evaluate().length;
      }
      times.sort();
      return (times[2], elements);
    }

    Iterable<Widget> all(BuildContext context) sync* {
      for (var i = 0; i < delegate.estimatedChildCount!; i++) {
        yield delegate.builder(context, i)!;
      }
    }

    final lazy = await measure(
      ListView.custom(
        padding: const EdgeInsets.all(16),
        childrenDelegate: delegate,
      ),
    );
    final eager = await measure(
      Builder(
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: all(context).toList()),
        ),
      ),
    );
    // ignore: avoid_print
    print(
      'RESULT lista n=${(delegate.estimatedChildCount! + 1) ~/ 2} '
      'antes_ms=${eager.$1.toStringAsFixed(1)} antes_cartoes=${eager.$2} '
      'depois_ms=${lazy.$1.toStringAsFixed(1)} depois_cartoes=${lazy.$2}',
    );
    // ignore: avoid_print
    print(
      'RESULT notas cartoes=${eager.$2} consultas=${store.ratingQueries}',
    );
    expect(lazy.$2, lessThan(eager.$2));
  });
}
