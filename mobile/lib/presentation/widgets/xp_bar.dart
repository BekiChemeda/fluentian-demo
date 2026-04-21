import 'package:flutter/material.dart';

class XPBar extends StatelessWidget {
  const XPBar({super.key, required this.currentXp, required this.goal});

  final int currentXp;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (currentXp / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('XP: $currentXp / $goal', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LinearProgressIndicator(minHeight: 16, value: progress),
        ),
      ],
    );
  }
}
