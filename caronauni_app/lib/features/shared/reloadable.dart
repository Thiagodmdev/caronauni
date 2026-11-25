import 'package:flutter/material.dart';

/// Carrega dados, mostra espera e erro, e permite atualizar puxando a lista.
class Reloadable<T> extends StatefulWidget {
  const Reloadable({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final List<Widget> Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  @override
  State<Reloadable<T>> createState() => _ReloadableState<T>();
}

class _ReloadableState<T> extends State<Reloadable<T>> {
  T? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Center(
        child: _failed
            ? TextButton(
                onPressed: _reload,
                child: const Text('Não foi possível carregar. Tentar de novo'),
              )
            : const CircularProgressIndicator(),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: widget.builder(context, data, _reload),
      ),
    );
  }
}

class EmptyText extends StatelessWidget {
  const EmptyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleLarge,
    ),
  );
}
