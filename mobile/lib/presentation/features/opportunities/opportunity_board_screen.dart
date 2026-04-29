import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/platform_models.dart';
import '../../app/providers.dart';
import '../../widgets/app_state_widgets.dart';

class OpportunityBoardScreen extends ConsumerWidget {
  const OpportunityBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunities = ref.watch(opportunitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(opportunitiesProvider),
        child: opportunities.when(
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.work_outline_rounded,
                title: 'No opportunities yet',
                message:
                    'Admins can publish scholarships, jobs, and exchange options from the backend.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _OpportunityCard(opportunity: items[index]);
              },
            );
          },
          loading: () => const AppLoadingState(message: 'Loading board'),
          error: (_, __) => AppErrorState(
            title: 'Board unavailable',
            message: 'The opportunity API may not be seeded yet.',
            onRetry: () => ref.invalidate(opportunitiesProvider),
          ),
        ),
      ),
    );
  }
}

class _OpportunityCard extends ConsumerStatefulWidget {
  const _OpportunityCard({required this.opportunity});

  final OpportunityModel opportunity;

  @override
  ConsumerState<_OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends ConsumerState<_OpportunityCard> {
  final _questionController = TextEditingController();
  bool _loading = false;
  String? _guidance;
  String? _error;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _askGuidance() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'Write a question first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _guidance = null;
    });
    try {
      final answer =
          await ref.read(platformRepositoryProvider).requestOpportunityGuidance(
                id: widget.opportunity.id,
                question: question,
              );
      setState(() => _guidance = answer);
    } catch (_) {
      setState(() => _error = 'Could not request guidance right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    await ref
        .read(platformRepositoryProvider)
        .saveOpportunity(widget.opportunity.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opportunity saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final opportunity = widget.opportunity;

    return FluentianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(opportunity.opportunityType)),
              if (opportunity.countryCode != null)
                Chip(label: Text(opportunity.countryCode!)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            opportunity.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            opportunity.providerName,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(opportunity.description),
          if (opportunity.deadlineAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Deadline: ${opportunity.deadlineAt!.toLocal()}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
              if (opportunity.url != null)
                TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open link'),
                ),
            ],
          ),
          const Divider(height: 24),
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'Ask for application guidance',
              hintText: 'What French level do I need?',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _askGuidance,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(_loading ? 'Asking...' : 'Ask guidance'),
          ),
          if (_guidance != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(_guidance!),
            ),
          ],
        ],
      ),
    );
  }
}
