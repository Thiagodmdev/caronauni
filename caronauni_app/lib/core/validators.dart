const int minPasswordLength = 6;

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = (value ?? '').trim().toLowerCase();
  if (email.isEmpty) return 'Informe seu e-mail';
  if (!_emailShape.hasMatch(email)) return 'E-mail inválido';
  return null;
}

/// A matrícula é conferida pela administração (RN01).
String? validateRegistration(String? value) {
  final registration = (value ?? '').trim();
  if (registration.isEmpty) return 'Informe sua matrícula';
  return RegExp(r'^\d{5,15}$').hasMatch(registration)
      ? null
      : 'Matrícula inválida. Use só números';
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Informe sua senha';
  if (password.length < minPasswordLength) {
    return 'A senha deve ter pelo menos $minPasswordLength caracteres';
  }
  return null;
}

String? validateName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Informe seu nome';
  if (!name.contains(RegExp(r'\s'))) return 'Informe nome e sobrenome';
  return null;
}

/// Aceita telefone fixo (10 dígitos) ou celular (11), com DDD.
String? validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'Informe seu telefone';
  final valid =
      RegExp(r'^[1-9]{2}9\d{8}$').hasMatch(digits) ||
      RegExp(r'^[1-9]{2}[2-5]\d{7}$').hasMatch(digits);
  return valid ? null : 'Telefone inválido. Use DDD + número';
}

String? validateCourse(String? value) =>
    (value ?? '').trim().isEmpty ? 'Informe seu curso ou setor' : null;

String? validatePasswordConfirmation(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Confirme sua senha';
  return value == password ? null : 'As senhas não são iguais';
}
