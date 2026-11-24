import 'package:flutter/services.dart';

/// Formata o telefone como (00) 00000-0000 durante a digitação.
class PhoneInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    final text = format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static String format(String digits) {
    if (digits.length <= 2) return digits;
    final area = digits.substring(0, 2);
    final number = digits.substring(2);
    final prefix = digits.length > 10 ? 5 : 4;
    if (number.length <= prefix) return '($area) $number';
    return '($area) ${number.substring(0, prefix)}-${number.substring(prefix)}';
  }
}
