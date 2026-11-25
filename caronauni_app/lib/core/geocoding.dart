import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Localiza um endereço no OpenStreetMap. Nulo quando não encontra ou o
/// serviço falha: a carona continua só com o endereço em texto (EX09).
Future<GeoPoint?> geocode(String address) async {
  try {
    final response = await http
        .get(
          Uri.https('nominatim.openstreetmap.org', '/search', {
            'q': address,
            'format': 'json',
            'limit': '1',
            'countrycodes': 'br',
          }),
        )
        .timeout(const Duration(seconds: 6));
    final results = jsonDecode(response.body) as List;
    if (results.isEmpty) return null;
    final first = results.first as Map;
    return GeoPoint(
      double.parse(first['lat'] as String),
      double.parse(first['lon'] as String),
    );
  } catch (_) {
    return null;
  }
}
