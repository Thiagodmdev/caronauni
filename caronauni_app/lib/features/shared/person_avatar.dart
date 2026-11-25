import 'package:flutter/material.dart';

import '../../core/formatters.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
