import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/ride_repository.dart';

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Executa [action] e mostra o resultado; devolve se deu certo.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  String? message = success;
  var ok = true;
  try {
    await action();
  } on RideException catch (e) {
    ok = false;
    message = e.message;
  } on AuthException catch (e) {
    ok = false;
    message = e.message;
  } catch (_) {
    ok = false;
    message = 'Não foi possível concluir. Verifique sua conexão.';
  }
  if (context.mounted && message != null) showMessage(context, message);
  return ok;
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String text,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Pede um texto; nulo quando a pessoa desiste.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  bool obscure = false,
}) {
  var value = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        autofocus: true,
        obscureText: obscure,
        maxLines: obscure ? 1 : 3,
        minLines: 1,
        onChanged: (text) => value = text,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () {
            if (value.trim().isNotEmpty) Navigator.of(context).pop(value);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}
