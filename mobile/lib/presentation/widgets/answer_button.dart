import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.state,
    this.isSelected = false,
  });

  final String text;
  final VoidCallback onTap;
  final AnswerState state;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color borderColor;
    Color iconColor;
    switch (state) {
      case AnswerState.correct:
        bg = Colors.green.shade300;
        borderColor = Colors.green.shade600;
        iconColor = Colors.green.shade900;
      case AnswerState.wrong:
        bg = Colors.red.shade300;
        borderColor = Colors.red.shade600;
        iconColor = Colors.red.shade900;
      case AnswerState.normal:
        bg = isSelected ? const Color(0xFFE8F5EC) : Colors.white;
        borderColor = isSelected ? AppColors.primary : Colors.black12;
        iconColor = isSelected ? AppColors.primary : const Color(0xFF7B8794);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(Icons.bubble_chart_rounded, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

enum AnswerState { normal, correct, wrong }
