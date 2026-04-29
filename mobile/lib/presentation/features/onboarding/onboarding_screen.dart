import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _nativeLanguage = 'Amharic';
  String _targetLanguage = 'French';
  double _goal = 20;

  @override
  void initState() {
    super.initState();
    _nativeLanguage = ref.read(onboardingNativeLanguageProvider);
    _targetLanguage = ref.read(onboardingTargetLanguageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final languagesAsync = ref.watch(languagesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFE7F8EA), Color(0xFFFFF8EE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome to Fluentian',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text(
                    'Start French with your local language and build your daily streak.'),
                const SizedBox(height: 24),
                languagesAsync.when(
                  data: (languages) {
                    final baseLanguages = languages
                        .where((language) => language.englishName != 'French')
                        .toList();
                    final targetLanguages = languages
                        .where((language) => language.englishName == 'French')
                        .toList();

                    if (!baseLanguages
                        .any((item) => item.englishName == _nativeLanguage)) {
                      _nativeLanguage = baseLanguages.first.englishName;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Base language'),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: _nativeLanguage,
                          items: baseLanguages
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang.englishName,
                                  child: Text(
                                    lang.nativeName == null
                                        ? lang.englishName
                                        : '${lang.englishName} · ${lang.nativeName}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            final value = v ?? baseLanguages.first.englishName;
                            setState(() => _nativeLanguage = value);
                            ref
                                .read(onboardingNativeLanguageProvider.notifier)
                                .state = value;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Target language'),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: _targetLanguage,
                          items: targetLanguages
                              .map(
                                (lang) => DropdownMenuItem(
                                  value: lang.englishName,
                                  child: Text(lang.englishName),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _targetLanguage = v ?? 'French'),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text(
                    'Using starter language options until the API is ready.',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Daily XP Goal: ${_goal.toInt()}'),
                Slider(
                    min: 10,
                    max: 100,
                    value: _goal,
                    onChanged: (v) => setState(() => _goal = v)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    ref.read(onboardingNativeLanguageProvider.notifier).state =
                        _nativeLanguage;
                    ref.read(onboardingTargetLanguageProvider.notifier).state =
                        _targetLanguage;
                    ref.read(onboardingDoneProvider.notifier).state = true;
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
