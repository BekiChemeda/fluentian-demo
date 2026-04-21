import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../app/providers.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  String _language = 'Any';
  String _level = 'Any';
  String _interests = 'Any';
  String _status = 'searching';
  int _progress = 8;
  Timer? _progressTimer;
  Timer? _phraseTimer;
  bool _cancelRequested = false;
  int _phraseIndex = 0;
  static const List<String> _frenchPhrases = [
    'Recherche d\'un partenaire...',
    'Un moment, on trouve le bon profil.',
    'On compare niveau et objectif.',
    'Presque pret pour parler en francais.',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startMatching();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _phraseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startMatching() async {
    setState(() {
      _status = 'searching';
      _progress = 8;
      _cancelRequested = false;
      _phraseIndex = 0;
    });

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted || _status != 'searching') return;
      setState(() => _progress = (_progress + 7).clamp(8, 92));
    });

    _phraseTimer?.cancel();
    _phraseTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _status != 'searching') return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _frenchPhrases.length);
    });

    try {
      final result = await ref.read(communityRepositoryProvider).findMatch();
      if (!mounted || _cancelRequested) return;
      _progressTimer?.cancel();
      _phraseTimer?.cancel();
      setState(() {
        _status = 'found';
        _progress = 100;
      });

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted || _cancelRequested) return;
      _progressTimer?.cancel();
      _phraseTimer?.cancel();
      setState(() => _status = 'failed');
    }
  }

  Future<void> _cancelMatching() async {
    _cancelRequested = true;
    _progressTimer?.cancel();
    _phraseTimer?.cancel();

    try {
      await ref.read(communityRepositoryProvider).leaveMatch();
    } catch (_) {
      // Intentional no-op: screen exit should remain instant even if network fails.
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Match')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _FilterDropdown(
                            label: 'Language',
                            value: _language,
                            values: const ['Any', 'French', 'English'],
                            onChanged: (v) => setState(() => _language = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FilterDropdown(
                            label: 'Level',
                            value: _level,
                            values: const [
                              'Any',
                              'Beginner',
                              'Intermediate',
                              'Advanced'
                            ],
                            onChanged: (v) => setState(() => _level = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FilterDropdown(
                      label: 'Interests',
                      value: _interests,
                      values: const ['Any', 'Travel', 'Business', 'Daily life'],
                      onChanged: (v) => setState(() => _interests = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: _status == 'failed'
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sentiment_dissatisfied_rounded,
                            size: 56,
                            color: AppColors.warning,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No match found yet.',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try again to keep searching.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _startMatching,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween(begin: 0.92, end: 1.06).animate(
                                CurvedAnimation(
                                    parent: _pulseController,
                                    curve: Curves.easeInOut)),
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.secondary),
                              ),
                              child: const Icon(
                                Icons.radar_rounded,
                                color: AppColors.primary,
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _status == 'found'
                                ? 'Match found!'
                                : 'Finding a match...',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          if (_status == 'found') ...[
                            const Chip(
                              avatar: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 14),
                              ),
                              label: Text('Connected learner • Intermediate'),
                            ),
                          ] else ...[
                            Text(
                              _frenchPhrases[_phraseIndex],
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _progress / 100,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: AppColors.surfaceMuted,
                          ),
                          const SizedBox(height: 8),
                          Text('$_progress% matched',
                              style:
                                  const TextStyle(color: AppColors.textMuted)),
                          if (_status == 'searching') ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _cancelMatching,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel'),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
