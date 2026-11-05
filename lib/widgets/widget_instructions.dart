import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Bottom sheet explaining how to add the widget on iOS.
class WidgetInstructions extends StatelessWidget {
  const WidgetInstructions({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const WidgetInstructions(),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Add Within to your phone',
              style: TextStyle(
                fontFamily: WithinTheme.serif,
                fontSize: 22,
                color: WithinColors.paper,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'A new teaching appears each day — no need to open the app.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: WithinColors.sage,
              ),
            ),
            SizedBox(height: 28),
            _Section(
              title: 'Lock Screen',
              steps: [
                'Touch and hold the Lock Screen, then tap Customize.',
                'Choose Lock Screen, then tap the area below the clock.',
                'Find Within and tap Daily Teaching.',
                'Tap Done.',
              ],
            ),
            SizedBox(height: 24),
            _Section(
              title: 'Home Screen',
              steps: [
                'Touch and hold an empty area until the apps jiggle.',
                'Tap Edit in the top corner, then Add Widget.',
                'Search for Within and pick the small or medium size.',
                'Tap Add Widget, then Done.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: WithinColors.sage,
          ),
        ),
        const SizedBox(height: 12),
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 15,
                      color: WithinColors.paper.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: WithinColors.paper,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
