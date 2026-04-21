import 'package:flutter/material.dart';

class StreakWidget extends StatelessWidget {
  const StreakWidget({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange),
          const SizedBox(width: 6),
          Text('$streak day streak', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
