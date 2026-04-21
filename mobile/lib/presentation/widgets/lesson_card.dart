import 'package:flutter/material.dart';

class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.completed,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool locked;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = completed ? Colors.green.shade200 : Colors.white;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Card(
        color: color,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          subtitle: Text(subtitle),
          trailing: Icon(
            locked ? Icons.lock_rounded : (completed ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded),
            size: 32,
            color: locked ? Colors.grey : Colors.green,
          ),
          onTap: locked ? null : onTap,
        ),
      ),
    );
  }
}
