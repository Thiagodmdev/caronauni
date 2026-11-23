/// Domínios aceitos no cadastro e no login (RN01).
/// Troque pelos domínios reais da faculdade.
const List<String> institutionalDomains = [
  'aluno.faculdade.edu.br',
  'faculdade.edu.br',
];

const int minPasswordLength = 6;

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateInstitutionalEmail(String? value) {
  final email = (value ?? '').trim().toLowerCase();
  if (email.isEmpty) return 'Informe seu e-mail';
  if (!_emailShape.hasMatch(email)) return 'E-mail inválido';
  final domain = email.substring(email.indexOf('@') + 1);
  if (!institutionalDomains.contains(domain)) {
    return 'Use seu e-mail da faculdade';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Informe sua senha';
  if (password.length < minPasswordLength) {
    return 'A senha deve ter pelo menos $minPasswordLength caracteres';
  }
  return null;
}
