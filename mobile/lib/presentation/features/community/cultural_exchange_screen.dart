import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/community_repository.dart';
import 'chat_hub_screen.dart';

class CulturalExchangeScreen extends ConsumerStatefulWidget {
  const CulturalExchangeScreen({super.key});

  @override
  ConsumerState<CulturalExchangeScreen> createState() =>
      _CulturalExchangeScreenState();
}

class _CulturalExchangeScreenState extends ConsumerState<CulturalExchangeScreen> {
  late Future<List<CulturalTopicData>> _topicsFuture;

  @override
  void initState() {
    super.initState();
    _topicsFuture = ref.read(communityRepositoryProvider).getCulturalTopics();
  }

  Future<void> _reload() async {
    final next = ref.read(communityRepositoryProvider).getCulturalTopics();
    setState(() => _topicsFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CulturalTopicData>>(
      future: _topicsFuture,
      builder: (context, snapshot) {
        final culturalTopics = snapshot.data ?? const <CulturalTopicData>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;

        return Scaffold(
          appBar: AppBar(title: const Text('Cultural Exchange')),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'France ↔ Ethiopia',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loading
                              ? 'Loading cultural exchange topics...'
                              : hasError
                                  ? 'Could not load cultural topics. Pull to refresh.'
                                  : culturalTopics.isEmpty
                                      ? 'No cultural topics seeded yet. Run cultural seed script.'
                                      : 'Practice French through cultural topics with AI guidance in your base language.',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF183765), Color(0xFF47BDB1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image_rounded,
                                    color: Colors.white, size: 34),
                                SizedBox(height: 8),
                                Text(
                                  'Cultural Exchange Hub',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: culturalTopics.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final topic = culturalTopics[index];
                              return _TopicCard(
                                title: topic.title,
                                subtitle: topic.subtitle,
                                bg: _topicColor(index),
                                icon: _topicIcon(topic.title),
                                onOpen: () => _openCulturalChat(
                                  context,
                                  topic,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cultural Mini Lessons',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.25,
                          children: culturalTopics
                              .map((topic) => _ImagePlaceholderCard(label: topic.title))
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: culturalTopics.isEmpty
                              ? null
                              : () => _openCulturalChat(
                                    context,
                                    culturalTopics.first,
                                  ),
                          icon: const Icon(Icons.forum_rounded),
                          label: const Text('Open Cultural Chat'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const _topicColors = [
    Color(0xFFFFF4E5),
    Color(0xFFEFF6FF),
    Color(0xFFEFFCF4),
    Color(0xFFF7F3FF),
  ];

  Color _topicColor(int index) => _topicColors[index % _topicColors.length];

  IconData _topicIcon(String topic) {
    final value = topic.toLowerCase();
    if (value.contains('food')) return Icons.restaurant_menu_rounded;
    if (value.contains('greet')) return Icons.waving_hand_rounded;
    if (value.contains('life')) return Icons.directions_walk_rounded;
    if (value.contains('tradit')) return Icons.celebration_rounded;
    return Icons.public_rounded;
  }

  void _openCulturalChat(
    BuildContext context,
    CulturalTopicData topic,
  ) {
    final prompt = topic.starterPrompts.isNotEmpty
        ? topic.starterPrompts.first
        : 'Let us discuss ${topic.title} between France and Ethiopia. Start in French and explain difficult parts in my base language when requested.';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatHubScreen(
          initialTabIndex: 1,
          startWithCulturalMode: true,
          initialAiPrompt: '${topic.subtitle}\n\n$prompt',
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.icon,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final Color bg;
  final IconData icon;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const Spacer(),
            const Row(
              children: [
                Icon(Icons.forum_rounded, size: 14, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text('Tap to open AI cultural chat',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholderCard extends StatelessWidget {
  const _ImagePlaceholderCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Icon(Icons.image_rounded,
                  size: 28, color: AppColors.textMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
