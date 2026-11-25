import 'package:caronauni/core/geocoding.dart';
import 'package:caronauni/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('procura do mais específico ao mais geral', () async {
    final asked = <String>[];
    final point = await geocodePlace(
      'Demerval Lobão',
      'Praça',
      find: (address) async {
        asked.add(address);
        return address == 'Demerval Lobão, Piauí'
            ? const GeoPoint(-5.36, -42.67)
            : null;
      },
    );
    expect(point?.lat, -5.36);
    expect(asked, hasLength(3));
    expect(asked.first, 'Praça, Demerval Lobão, Teresina, Piauí');
  });

  test('sem resultado, a carona fica só com o texto (EX10)', () async {
    expect(await geocodePlace('x', 'y', find: (_) async => null), isNull);
  });
}
