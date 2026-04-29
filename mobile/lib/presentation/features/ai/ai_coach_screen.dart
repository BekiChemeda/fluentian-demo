import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../app/providers.dart';
import '../../widgets/app_state_widgets.dart';

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _controller = TextEditingController();
  String _mode = 'explain';
  String? _result;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write a sentence or question first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final repository = ref.read(platformRepositoryProvider);
      final response = switch (_mode) {
        'correct' => await repository.correct(text),
        'pronunciation' => await repository.pronunciationFeedback(text),
        _ => await repository.explain(text: text),
      };
      setState(() => _result = response.result);
      ref.invalidate(usageProvider);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      setState(() {
        _error = code == 402
            ? 'You reached today\'s usage limit for this feature.'
            : 'Could not reach the AI tutor right now.';
      });
    } catch (_) {
      setState(() => _error = 'Could not reach the AI tutor right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(usageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Tutor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FluentianCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask for help',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get a simple French explanation, correction, or pronunciation note.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'explain',
                      icon: Icon(Icons.lightbulb_outline_rounded),
                      label: Text('Explain'),
                    ),
                    ButtonSegment(
                      value: 'correct',
                      icon: Icon(Icons.edit_note_rounded),
                      label: Text('Correct'),
                    ),
                    ButtonSegment(
                      value: 'pronunciation',
                      icon: Icon(Icons.record_voice_over_rounded),
                      label: Text('Speak'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) {
                    setState(() => _mode = value.first);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Example: Pourquoi dit-on "je suis" ?',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Ask AI tutor'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_result != null)
            FluentianCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Feedback',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_result!, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          usage.when(
            data: (items) => FluentianCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today\'s usage',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text('No AI usage recorded today.')
                  else
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${item.featureKey}: ${item.usedCount}'
                          '${item.limitCount == null ? '' : ' / ${item.limitCount}'}',
                        ),
                      ),
                ],
              ),
            ),
            loading: () => const AppLoadingState(message: 'Checking usage'),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
