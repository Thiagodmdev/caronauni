// Rodar com: flutter test benchmark/search_benchmark_test.dart
import 'package:caronauni/core/formatters.dart';
import 'package:caronauni/data/document_store.dart';
import 'package:caronauni/data/ride_repository.dart';
import 'package:caronauni/data/ride_search.dart';
import 'package:caronauni/features/search/search_view_model.dart';
import 'package:caronauni/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

class _CountingRepository extends RideRepository {
  _CountingRepository() : super(MemoryStore());

  int searches = 0;

  @override
  Future<List<Ride>> search(RideQuery query) {
    searches++;
    return super.search(query);
  }
}

void main() {
  testWidgets('buscas disparadas ao digitar "centro"', (tester) async {
    Future<int> run({required bool debounce}) async {
      final repository = _CountingRepository();
      final viewModel = SearchViewModel(repository);
      await tester.pump(const Duration(seconds: 1));
      repository.searches = 0;
      for (var i = 1; i <= 'centro'.length; i++) {
        viewModel.setDestination('centro'.substring(0, i));
        // Sem o debounce, cada tecla dispararia uma busca.
        if (!debounce) viewModel.search();
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pump(const Duration(seconds: 1));
      final total = repository.searches - (debounce ? 0 : 1);
      viewModel.dispose();
      return total;
    }

    final before = await run(debounce: false);
    final after = await run(debounce: true);
    // ignore: avoid_print
    print('RESULT debounce sem=$before com=$after');
    expect(after, 1);
  });

  testWidgets('sair da tela cancela a busca pendente', (tester) async {
    final repository = _CountingRepository();
    final viewModel = SearchViewModel(repository);
    await tester.pump(const Duration(seconds: 1));
    repository.searches = 0;
    viewModel.setDestination('centro');
    viewModel.dispose();
    await tester.pump(const Duration(seconds: 1));
    // ignore: avoid_print
    print('RESULT buscas_apos_sair=${repository.searches}');
    expect(repository.searches, 0);
  });

  test('tempo de filtrar e ordenar na thread principal', () async {
    final now = DateTime(2026, 11, 24, 10);
    for (final count in [100, 1000, 10000]) {
      final rides = manyRides(count, now);
      const query = RideQuery(destination: 'centro');
      for (var i = 0; i < 20; i++) {
        filterRides(rides, query, now);
      }
      final times = <double>[];
      for (var i = 0; i < 30; i++) {
        final watch = Stopwatch()..start();
        filterRides(rides, query, now);
        times.add(watch.elapsedMicroseconds / 1000);
      }
      times.sort();
      // ignore: avoid_print
      print('RESULT filtro n=$count mediana_ms=${times[15].toStringAsFixed(2)}');
    }
    expect(normalizeForSearch('São'), 'sao');
  });
}
