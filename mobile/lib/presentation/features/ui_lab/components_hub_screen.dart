import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

import 'audio_call_screen.dart';
import 'chat_hub_screen.dart';
import 'dialogues_lesson_screen.dart';
import 'find_match_screen.dart';
import 'leaderboard_screen.dart';
import 'ordering_lesson_screen.dart';
import 'story_screen.dart';

typedef ComponentOpenCallback = void Function(Widget screen);

class ComponentsHubScreen extends StatelessWidget {
  const ComponentsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Components Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'All UI components in one place',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Review and test every designed flow from a single screen.',
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6978)),
          ),
          const SizedBox(height: 16),
          ComponentsHubGrid(onOpen: (screen) => _open(context, screen)),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class ComponentsHubGrid extends StatelessWidget {
  const ComponentsHubGrid({
    super.key,
    required this.onOpen,
  });

  final ComponentOpenCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cards = <_ComponentCardData>[
      _ComponentCardData(
        label: 'Dialogue Lesson',
        caption: 'Coach-style speaking flow',
        icon: Icons.forum_rounded,
        screen: const DialoguesLessonScreen(),
      ),
      _ComponentCardData(
        label: 'Ordering Lesson',
        caption: 'Build sentence order',
        icon: Icons.reorder_rounded,
        screen: const OrderingLessonScreen(),
      ),
      _ComponentCardData(
        label: 'Leaderboard',
        caption: 'Social competition view',
        icon: Icons.emoji_events_rounded,
        screen: const LeaderboardScreen(),
      ),
      _ComponentCardData(
        label: 'Story',
        caption: 'Immersive lesson story',
        icon: Icons.auto_stories_rounded,
        screen: const StoryScreen(),
      ),
      _ComponentCardData(
        label: 'Chat Hub',
        caption: 'Conversations and prompts',
        icon: Icons.chat_rounded,
        screen: const ChatHubScreen(),
      ),
      _ComponentCardData(
        label: 'Find Match',
        caption: 'Partner matching UI',
        icon: Icons.handshake_rounded,
        screen: const FindMatchScreen(),
      ),
      _ComponentCardData(
        label: 'Audio Call',
        caption: 'Voice practice experience',
        icon: Icons.call_rounded,
        screen: const AudioCallScreen(),
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (card) => _ComponentCard(
              data: card,
              onTap: () => onOpen(card.screen),
            ),
          )
          .toList(),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.data,
    required this.onTap,
  });

  final _ComponentCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E8EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(data.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                data.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7788), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComponentCardData {
  const _ComponentCardData({
    required this.label,
    required this.caption,
    required this.icon,
    required this.screen,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Widget screen;
}
