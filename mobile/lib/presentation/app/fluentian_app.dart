import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../features/auth/auth_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'root_scaffold.dart';
import 'providers.dart';

class FluentianApp extends ConsumerWidget {
  const FluentianApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.light;

    return MaterialApp(
      title: 'Fluentian',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: themeMode,
      home: authState.when(
        data: (isAuthed) {
          if (!onboardingDone) return const OnboardingScreen();
          if (!isAuthed) return const AuthScreen();
          ref.watch(fluentianStateProvider);
          ref.watch(pushBootstrapProvider);
          return const RootScaffold();
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const AuthScreen(),
      ),
    );
  }
}
