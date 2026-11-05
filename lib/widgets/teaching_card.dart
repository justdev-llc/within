import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/teaching.dart';

/// The teaching itself: full text, then its source and how faithfully it
/// follows that source.
class TeachingCard extends StatelessWidget {
  const TeachingCard({super.key, required this.teaching});

  final Teaching teaching;

  @override
  Widget build(BuildContext context) {
    final provenance = teaching.isParaphrase
        ? 'Paraphrase'
        : teaching.attribution ?? 'Translation';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          teaching.text,
          style: const TextStyle(
            fontFamily: WithinTheme.serif,
            fontSize: 26,
            height: 1.45,
            color: WithinColors.paper,
          ),
        ),
        const SizedBox(height: 28),
        Container(width: 24, height: 1, color: WithinColors.sage),
        const SizedBox(height: 14),
        Text(
          teaching.reference,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: WithinColors.sage,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          provenance,
          style: TextStyle(
            fontSize: 13,
            color: WithinColors.paper.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
