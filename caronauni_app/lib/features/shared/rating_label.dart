import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/ride_repository.dart';
import '../../models/models.dart';

/// Nota média de uma pessoa, carregada só quando aparece na tela.
class RatingLabel extends StatefulWidget {
  const RatingLabel({super.key, required this.userId, this.showCount = false});

  final String userId;
  final bool showCount;

  @override
  State<RatingLabel> createState() => _RatingLabelState();
}

class _RatingLabelState extends State<RatingLabel> {
  late final Future<Reputation> _future = context
      .read<RideRepository>()
      .reputation(widget.userId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        final reputation = snapshot.data;
        final average = reputation?.average;
        if (average == null) return const Text('Sem notas');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 18, color: const Color(0xFFE09B00)),
            const SizedBox(width: 2),
            Text(
              widget.showCount
                  ? '${formatRating(average)} (${reputation!.count})'
                  : formatRating(average),
            ),
          ],
        );
      },
    );
  }
}
