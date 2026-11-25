import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/ride_repository.dart';
import '../../models/models.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._repository) {
    search();
  }

  static const Duration _typingDelay = Duration(milliseconds: 300);

  final RideRepository _repository;

  String _destination = '';
  DayFilter _day = DayFilter.all;
  DayFilter get day => _day;

  int? _minutesOfDay;
  int? get minutesOfDay => _minutesOfDay;

  List<Ride> _rides = const [];
  List<Ride> get rides => _rides;

  bool _failed = false;
  bool get failed => _failed;

  bool _loading = true;
  bool get loading => _loading;

  Timer? _typingTimer;
  int _lastSearch = 0;
  bool _disposed = false;

  void setDestination(String value) {
    _destination = value;
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingDelay, search);
  }

  void setDay(DayFilter value) {
    _day = value;
    search();
  }

  void setTime(int? minutesOfDay) {
    _minutesOfDay = minutesOfDay;
    search();
  }

  Future<void> search() async {
    final current = ++_lastSearch;
    _loading = true;
    notifyListeners();
    var results = const <Ride>[];
    var failed = false;
    try {
      results = await _repository.search(
        RideQuery(
          destination: _destination,
          day: _day,
          minutesOfDay: _minutesOfDay,
        ),
      );
    } catch (_) {
      failed = true;
    }
    // Só a busca mais recente pode atualizar a lista.
    if (_disposed || current != _lastSearch) return;
    _rides = results;
    _failed = failed;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _typingTimer?.cancel();
    super.dispose();
  }
}
