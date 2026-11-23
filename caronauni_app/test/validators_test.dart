import 'package:caronauni/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('e-mail institucional (RN01)', () {
    test('aceita os domínios da faculdade, sem diferenciar maiúsculas', () {
      expect(validateInstitutionalEmail('ana@aluno.faculdade.edu.br'), isNull);
      expect(validateInstitutionalEmail(' ANA@Faculdade.edu.br '), isNull);
    });

    test('recusa outros domínios com a mensagem do documento (EX04)', () {
      expect(
        validateInstitutionalEmail('ana@gmail.com'),
        'Use seu e-mail da faculdade',
      );
      expect(
        validateInstitutionalEmail('ana@faculdade.edu.br.golpe.com'),
        'Use seu e-mail da faculdade',
      );
    });

    test('recusa e-mail vazio ou malformado', () {
      expect(validateInstitutionalEmail(''), isNotNull);
      expect(validateInstitutionalEmail('ana'), 'E-mail inválido');
    });
  });

  test('senha precisa de pelo menos 6 caracteres', () {
    expect(validatePassword(''), isNotNull);
    expect(validatePassword('12345'), isNotNull);
    expect(validatePassword('123456'), isNull);
  });
}
