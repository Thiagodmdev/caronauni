import 'package:caronauni/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('e-mail', () {
    test('aceita qualquer domínio', () {
      expect(validateEmail('ana@gmail.com'), isNull);
      expect(validateEmail(' ANA@SempreUninassau.com.br '), isNull);
    });

    test('recusa e-mail vazio ou malformado', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('ana'), 'E-mail inválido');
    });
  });

  test('matrícula só com números (RN01)', () {
    expect(validateRegistration('12345678'), isNull);
    expect(validateRegistration(''), isNotNull);
    expect(validateRegistration('abc12345'), isNotNull);
    expect(validateRegistration('123'), isNotNull);
  });

  test('senha precisa de pelo menos 6 caracteres', () {
    expect(validatePassword(''), isNotNull);
    expect(validatePassword('12345'), isNotNull);
    expect(validatePassword('123456'), isNull);
  });
}
