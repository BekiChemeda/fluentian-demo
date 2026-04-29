import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../ui_lab/components_hub_screen.dart';
import '../../widgets/streak_widget.dart';
import '../../widgets/xp_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final lessons = ref.watch(lessonsProvider);
    final progress = ref.watch(progressProvider);
    final badges = ref.watch(badgeProvider);
    final subscription = ref.watch(subscriptionProvider);
    final usage = ref.watch(usageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fluentian')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: me.when(
          data: (user) {
            return ListView(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Bonjour, ${user.email.split('@').first}!',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 12),
                XPBar(currentXp: user.xp, goal: user.dailyXpGoal),
                const SizedBox(height: 16),
                StreakWidget(streak: user.streak),
                const SizedBox(height: 16),
                _PlanSummary(subscription: subscription, usage: usage),
                const SizedBox(height: 24),
                Text('Next lesson',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                lessons.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Card(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'No lessons yet. Seed lessons from backend.')));
                    }
                    final next = items.firstWhere(
                      (l) => !l.completed,
                      orElse: () => items.last,
                    );
                    return Card(
                      child: ListTile(
                        title: Text(next.content['question']?.toString() ??
                            'Lesson ${next.orderIndex}'),
                        subtitle: Text('XP reward: ${next.xpReward}'),
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Could not load lessons'),
                ),
                const SizedBox(height: 24),
                _UsageDashboardSection(
                  totalLessons: lessons.maybeWhen(
                    data: (items) => items.length,
                    orElse: () => 0,
                  ),
                  completedLessons:
                      progress.where((item) => item.completed).length,
                  avgScore: progress.isEmpty
                      ? 0
                      : (progress
                                  .map((item) => item.score)
                                  .reduce((a, b) => a + b) /
                              progress.length)
                          .round(),
                  streak: user.streak,
                  badges: badges.length,
                ),
                const SizedBox(height: 24),
                _UiLabSection(onOpen: (screen) => _open(context, screen)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD5D5)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not load dashboard',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    SizedBox(height: 6),
                    Text(
                        'This usually means your session token expired or profile request failed.'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => ref
                          .read(fluentianStateProvider.notifier)
                          .refreshAll(),
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(authStateProvider.notifier).logout(),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _UiLabSection(onOpen: (screen) => _open(context, screen)),
            ],
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.subscription, required this.usage});

  final AsyncValue<dynamic> subscription;
  final AsyncValue<dynamic> usage;

  @override
  Widget build(BuildContext context) {
    final planLabel = subscription.maybeWhen(
      data: (plan) => plan.tier.toString().replaceAll('_', ' ').toUpperCase(),
      orElse: () => 'PLAN',
    );
    final usageCount = usage.maybeWhen(
      data: (items) => items.fold<int>(
        0,
        (total, item) => total + (item.usedCount as int),
      ),
      orElse: () => 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0x1A47BDB1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFF183765)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(planLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    usageCount == 0
                        ? 'No AI usage recorded today'
                        : '$usageCount AI actions used today',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageDashboardSection extends StatelessWidget {
  const _UsageDashboardSection({
    required this.totalLessons,
    required this.completedLessons,
    required this.avgScore,
    required this.streak,
    required this.badges,
  });

  final int totalLessons;
  final int completedLessons;
  final int avgScore;
  final int streak;
  final int badges;

  @override
  Widget build(BuildContext context) {
    final completion = totalLessons == 0
        ? 0
        : ((completedLessons / totalLessons) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Usage Dashboard', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.65,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _UsageStatCard(
              label: 'Completion',
              value: '$completion%',
              icon: Icons.task_alt_rounded,
            ),
            _UsageStatCard(
              label: 'Avg Score',
              value: '$avgScore',
              icon: Icons.bar_chart_rounded,
            ),
            _UsageStatCard(
              label: 'Streak',
              value: '$streak days',
              icon: Icons.local_fire_department_rounded,
            ),
            _UsageStatCard(
              label: 'Badges',
              value: '$badges',
              icon: Icons.emoji_events_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageStatCard extends StatelessWidget {
  const _UsageStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0x1A47BDB1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF183765), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiLabSection extends StatelessWidget {
  const _UiLabSection({required this.onOpen});

  final ComponentOpenCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'UI Lab',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ComponentsHubScreen(),
                  ),
                );
              },
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
            'All redesigned components are now merged into one reusable hub.'),
        const SizedBox(height: 10),
        ComponentsHubGrid(onOpen: onOpen),
      ],
    );
  }
}
