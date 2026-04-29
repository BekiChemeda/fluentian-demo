import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../app/providers.dart';
import '../../widgets/app_state_widgets.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final usage = ref.watch(usageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription & Usage')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriptionProvider);
          ref.invalidate(usageProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            subscription.when(
              data: (plan) => FluentianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.tier.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${plan.status}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    const Text('Plan limits',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (plan.features.isEmpty)
                      const Text('No plan limits configured yet.')
                    else
                      for (final entry in plan.features.entries)
                        _LimitRow(
                          label: entry.key,
                          limit: entry.value,
                        ),
                  ],
                ),
              ),
              loading: () => const AppLoadingState(message: 'Loading plan'),
              error: (_, __) => AppErrorState(
                title: 'Plan unavailable',
                message: 'The backend could not return your subscription.',
                onRetry: () => ref.invalidate(subscriptionProvider),
              ),
            ),
            const SizedBox(height: 14),
            usage.when(
              data: (items) => FluentianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Used today',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text('No tracked usage yet today.')
                    else
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UsageBar(
                            label: item.featureKey,
                            used: item.usedCount,
                            limit: item.limitCount,
                          ),
                        ),
                  ],
                ),
              ),
              loading: () => const AppLoadingState(message: 'Loading usage'),
              error: (_, __) => AppErrorState(
                title: 'Usage unavailable',
                message: 'Usage resets daily after the backend records events.',
                onRetry: () => ref.invalidate(usageProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.label, required this.limit});

  final String label;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label.replaceAll('_', ' '))),
          Text(
            limit == null ? 'Unlimited' : '$limit/day',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final int used;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final progress = limit == null || limit == 0 ? 0.0 : used / limit!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(limit == null ? '$used used' : '$used / $limit'),
          ],
        ),
        const SizedBox(height: 6),
        if (limit == null)
          const Text('Unlimited', style: TextStyle(color: AppColors.success))
        else
          LinearProgressIndicator(
            minHeight: 9,
            value: progress.clamp(0, 1),
            borderRadius: BorderRadius.circular(999),
          ),
      ],
    );
  }
}
