import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../community/cultural_exchange_screen.dart';
import '../delf/delf_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreCard(
            icon: Icons.public_rounded,
            title: 'Cultural Exchange',
            subtitle: 'Open culture topics, AI prompts, and exchange cards.',
            accent: const Color(0xFF47BDB1),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CulturalExchangeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.assignment_rounded,
            title: 'DELF Practice',
            subtitle: 'Review test items, submission flow, and results.',
            accent: const Color(0xFF1F8B42),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DelfScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _MoreCard(
            icon: Icons.forum_rounded,
            title: 'Quick tip',
            subtitle: 'Use the Communication tab for live matching and chat.',
            accent: AppColors.primary,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, 10),
                color: Color(0x10000000),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}