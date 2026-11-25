const List<String> _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String formatTime(DateTime date) =>
    '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

String formatMinutesOfDay(int minutes) =>
    '${_twoDigits(minutes ~/ 60)}:${_twoDigits(minutes % 60)}';

/// "Hoje", "Amanhã" ou "qui, 12/11".
String formatDay(DateTime date, DateTime now) {
  final days = DateTime(date.year, date.month, date.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inHours;
  if (days == 0) return 'Hoje';
  if (days >= 23 && days <= 25) return 'Amanhã';
  return '${_weekdays[date.weekday - 1]}, '
      '${_twoDigits(date.day)}/${_twoDigits(date.month)}';
}

String formatPrice(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

String formatRating(double value) =>
    value.toStringAsFixed(1).replaceAll('.', ',');

String initialsOf(String name) {
  final parts = name.replaceAll('(exemplo)', '').trim().split(RegExp(r'\s+'));
  final first = parts.first.isEmpty ? '' : parts.first[0];
  if (parts.length == 1) return first.toUpperCase();
  return '$first${parts.last[0]}'.toUpperCase();
}

/// Remove acentos para que "São" encontre "sao" na busca.
String normalizeForSearch(String text) {
  const from = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().trim().split('')) {
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}
