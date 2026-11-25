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

/// Do mais específico ao mais geral: o ponto de encontro costuma ser um texto
/// livre, que o mapa não conhece, e há caronas para cidades vizinhas.
Future<GeoPoint?> geocodePlace(
  String place,
  String detail, {
  Future<GeoPoint?> Function(String address) find = geocode,
}) async {
  for (final address in [
    '$detail, $place, Teresina, Piauí',
    '$place, Teresina, Piauí',
    '$place, Piauí',
  ]) {
    final point = await find(address);
    if (point != null) return point;
  }
  return null;
}
