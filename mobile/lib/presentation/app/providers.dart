import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/storage/token_store.dart';
import '../../data/models/badge_model.dart';
import '../../data/models/lesson_model.dart';
import '../../data/models/platform_models.dart';
import '../../data/models/progress_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/badge_repository.dart';
import '../../data/repositories/communication_repository.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/delf_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/platform_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/user_repository.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

const String _defaultApiBaseUrl = 'http://10.0.2.2:8000';

String _resolveBaseUrl() {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
      baseUrl: _resolveBaseUrl(), tokenStore: ref.read(tokenStoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
      apiClient: ref.read(apiClientProvider),
      tokenStore: ref.read(tokenStoreProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(ref.read(apiClientProvider));
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.read(apiClientProvider));
});

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(ref.read(apiClientProvider));
});

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  return BadgeRepository(ref.read(apiClientProvider));
});

final communicationRepositoryProvider =
    Provider<CommunicationRepository>((ref) {
  return CommunicationRepository(
    apiClient: ref.read(apiClientProvider),
    tokenStore: ref.read(tokenStoreProvider),
  );
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.read(apiClientProvider));
});

final delfRepositoryProvider = Provider<DelfRepository>((ref) {
  return DelfRepository(ref.read(apiClientProvider));
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final service =
      PushNotificationService(apiClient: ref.read(apiClientProvider));
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final pushBootstrapProvider = FutureProvider<void>((ref) async {
  final isAuthed = await ref.watch(authStateProvider.future);
  if (!isAuthed) {
    return;
  }
  await ref.read(pushNotificationServiceProvider).initialize();
});

final onboardingDoneProvider = StateProvider<bool>((ref) => false);
final onboardingNativeLanguageProvider =
    StateProvider<String>((ref) => 'Amharic');
final onboardingTargetLanguageProvider =
    StateProvider<String>((ref) => 'French');

final languagesProvider = FutureProvider<List<LanguageModel>>((ref) async {
  try {
    final items = await ref.read(platformRepositoryProvider).getLanguages();
    if (items.isNotEmpty) {
      return items;
    }
  } catch (_) {
    // Startup fallback for a brand-new backend before seed data is loaded.
  }
  return const [
    LanguageModel(
      id: 'fr',
      isoCode: 'fr',
      englishName: 'French',
      nativeName: 'Français',
      isActive: true,
    ),
    LanguageModel(
      id: 'en',
      isoCode: 'en',
      englishName: 'English',
      nativeName: 'English',
      isActive: true,
    ),
    LanguageModel(
      id: 'am',
      isoCode: 'am',
      englishName: 'Amharic',
      nativeName: 'አማርኛ',
      isActive: true,
    ),
    LanguageModel(
      id: 'om',
      isoCode: 'om',
      englishName: 'Afaan Oromoo',
      nativeName: 'Afaan Oromoo',
      isActive: true,
    ),
  ];
});

final learningPathProvider = FutureProvider<LearningPathModel>((ref) async {
  await ref.watch(authStateProvider.future);
  return ref.read(platformRepositoryProvider).getLearningPath();
});

final subscriptionProvider = FutureProvider<SubscriptionModel>((ref) async {
  await ref.watch(authStateProvider.future);
  return ref.read(platformRepositoryProvider).getSubscription();
});

final usageProvider = FutureProvider<List<UsageItemModel>>((ref) async {
  await ref.watch(authStateProvider.future);
  return ref.read(platformRepositoryProvider).getUsage();
});

final tutorsProvider = FutureProvider<List<TutorProfileModel>>((ref) async {
  await ref.watch(authStateProvider.future);
  return ref.read(platformRepositoryProvider).getTutors();
});

final bookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  await ref.watch(authStateProvider.future);
  return ref.read(platformRepositoryProvider).getBookings();
});

final opportunitiesProvider =
    FutureProvider<List<OpportunityModel>>((ref) async {
  await ref.watch(authStateProvider.future);
  return ref.read(platformRepositoryProvider).getOpportunities();
});

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final authStateProvider =
    AsyncNotifierProvider<AuthStateNotifier, bool>(AuthStateNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const String _themeModePreferenceKey = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeName = prefs.getString(_themeModePreferenceKey);
    return _themeModeFromName(themeModeName) ?? ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePreferenceKey, themeMode.name);
    state = AsyncData(themeMode);
  }

  ThemeMode? _themeModeFromName(String? themeModeName) {
    for (final themeMode in ThemeMode.values) {
      if (themeMode.name == themeModeName) {
        return themeMode;
      }
    }
    return null;
  }
}

class AuthStateNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await ref.read(tokenStoreProvider).getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      return true;
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String nativeLanguage,
    required String targetLanguage,
    required int dailyXpGoal,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            nativeLanguage: nativeLanguage,
            targetLanguage: targetLanguage,
            dailyXpGoal: dailyXpGoal,
          );
      return true;
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
  }
}

class FluentianState {
  const FluentianState({
    required this.user,
    required this.lessons,
    required this.progressItems,
    required this.badges,
    this.completionInFlight = false,
  });

  final UserModel user;
  final List<LessonModel> lessons;
  final List<ProgressItemModel> progressItems;
  final List<BadgeModel> badges;
  final bool completionInFlight;

  FluentianState copyWith({
    UserModel? user,
    List<LessonModel>? lessons,
    List<ProgressItemModel>? progressItems,
    List<BadgeModel>? badges,
    bool? completionInFlight,
  }) {
    return FluentianState(
      user: user ?? this.user,
      lessons: lessons ?? this.lessons,
      progressItems: progressItems ?? this.progressItems,
      badges: badges ?? this.badges,
      completionInFlight: completionInFlight ?? this.completionInFlight,
    );
  }
}

final fluentianStateProvider =
    AsyncNotifierProvider<FluentianStateNotifier, FluentianState>(
  FluentianStateNotifier.new,
);

class FluentianStateNotifier extends AsyncNotifier<FluentianState> {
  @override
  Future<FluentianState> build() async {
    final isAuthed = await ref.watch(authStateProvider.future);
    if (!isAuthed) {
      throw Exception('Not authenticated');
    }
    return _fetchAll();
  }

  Future<FluentianState> _fetchAll() async {
    final userRepository = ref.read(userRepositoryProvider);
    final lessonRepository = ref.read(lessonRepositoryProvider);
    final progressRepository = ref.read(progressRepositoryProvider);
    final badgeRepository = ref.read(badgeRepositoryProvider);

    // User is required to render core app state.
    final user = await userRepository.getMe();

    // Lessons can fail transiently; keep app usable with empty learn feed.
    List<LessonModel> lessons;
    try {
      lessons = await lessonRepository.getLessons();
    } catch (_) {
      lessons = const [];
    }

    // Optional domains should not block dashboard/profile rendering.
    List<ProgressItemModel> progressItems;
    try {
      progressItems = await progressRepository.getProgress();
    } catch (_) {
      progressItems = const [];
    }

    List<BadgeModel> badges;
    try {
      badges = await badgeRepository.getBadges();
    } catch (_) {
      badges = _buildFallbackBadges(user, progressItems);
    }

    final completedIds =
        progressItems.where((p) => p.completed).map((p) => p.lessonId).toSet();
    final mergedLessons = lessons
        .map((lesson) => completedIds.contains(lesson.id)
            ? lesson.copyWith(completed: true)
            : lesson)
        .toList();

    return FluentianState(
      user: user,
      lessons: mergedLessons,
      progressItems: progressItems,
      badges: badges,
    );
  }

  List<BadgeModel> _buildFallbackBadges(
      UserModel user, List<ProgressItemModel> progressItems) {
    final completedCount = progressItems.where((item) => item.completed).length;
    return [
      BadgeModel(
        id: 1,
        name: 'First Lesson',
        description: 'Complete your first lesson.',
        unlocked: completedCount >= 1,
        unlockDate: null,
        unlockCriteria: 'Complete 1 lesson',
        iconSvg: '',
      ),
      BadgeModel(
        id: 2,
        name: 'Five Lessons',
        description: 'Build momentum by finishing five lessons.',
        unlocked: completedCount >= 5,
        unlockDate: null,
        unlockCriteria: 'Complete 5 lessons',
        iconSvg: '',
      ),
      BadgeModel(
        id: 3,
        name: '7-Day Streak',
        description: 'Maintain your learning streak for seven days.',
        unlocked: user.streak >= 7,
        unlockDate: null,
        unlockCriteria: 'Reach a 7 day streak',
        iconSvg: '',
      ),
      BadgeModel(
        id: 4,
        name: 'XP Hunter',
        description: 'Earn your first 100 XP.',
        unlocked: user.xp >= 100,
        unlockDate: null,
        unlockCriteria: 'Reach 100 XP',
        iconSvg: '',
      ),
    ];
  }

  Future<void> refreshAll() async {
    final previous = state;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAll);
    if (state.hasError && previous.hasValue) {
      state = previous;
    }
  }

  Future<Map<String, dynamic>> completeLesson(int lessonId, int score) async {
    final current = state.valueOrNull;
    if (current == null) {
      await refreshAll();
      return {'lesson_id': lessonId, 'score': score};
    }

    final lesson = current.lessons.firstWhere(
      (item) => item.id == lessonId,
      orElse: () => throw Exception('Lesson not found'),
    );

    final alreadyCompleted =
        current.progressItems.any((p) => p.lessonId == lessonId && p.completed);
    final optimisticXpGain = alreadyCompleted ? 0 : lesson.xpReward;

    final optimisticState = current.copyWith(
      user: current.user.copyWith(xp: current.user.xp + optimisticXpGain),
      lessons: current.lessons
          .map((item) =>
              item.id == lessonId ? item.copyWith(completed: true) : item)
          .toList(),
      progressItems: [
        ...current.progressItems.where((p) => p.lessonId != lessonId),
        ProgressItemModel(lessonId: lessonId, completed: true, score: score),
      ],
      completionInFlight: true,
    );

    state = AsyncData(optimisticState);

    try {
      final result = await ref
          .read(lessonRepositoryProvider)
          .completeLesson(lessonId, score);
      await ref.read(analyticsServiceProvider).logEvent(
        'lesson_completed',
        properties: {
          'lesson_id': lessonId,
          'score': score,
          'xp_gain': optimisticXpGain,
        },
      );
      final refreshed = await _fetchAll();
      state = AsyncData(refreshed.copyWith(completionInFlight: false));
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? nativeLanguage,
    String? targetLanguage,
    int? dailyXpGoal,
  }) async {
    await ref.read(userRepositoryProvider).updateMe(
          nativeLanguage: nativeLanguage,
          targetLanguage: targetLanguage,
          dailyXpGoal: dailyXpGoal,
        );
    await refreshAll();
  }
}

final userProvider = Provider<UserModel?>((ref) {
  return ref.watch(fluentianStateProvider).valueOrNull?.user;
});

final roadmapProvider = Provider<List<LessonModel>>((ref) {
  return ref.watch(fluentianStateProvider).valueOrNull?.lessons ?? const [];
});

final progressProvider = Provider<List<ProgressItemModel>>((ref) {
  return ref.watch(fluentianStateProvider).valueOrNull?.progressItems ??
      const [];
});

final badgeProvider = Provider<List<BadgeModel>>((ref) {
  return ref.watch(fluentianStateProvider).valueOrNull?.badges ?? const [];
});

final nextLessonProvider = Provider<LessonModel?>((ref) {
  final lessons = ref.watch(roadmapProvider);
  final progress = ref.watch(progressProvider);
  if (lessons.isEmpty) {
    return null;
  }

  final progressByLesson = {
    for (final item in progress) item.lessonId: item,
  };

  final unfinished = lessons.where((lesson) => !lesson.completed).toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  if (unfinished.isNotEmpty) {
    return unfinished.first;
  }

  // If everything is completed, suggest a weak area review.
  final sortedByScore = lessons.toList()
    ..sort((a, b) {
      final aScore = progressByLesson[a.id]?.score ?? 100;
      final bScore = progressByLesson[b.id]?.score ?? 100;
      if (aScore != bScore) {
        return aScore.compareTo(bScore);
      }
      return a.orderIndex.compareTo(b.orderIndex);
    });

  return sortedByScore.first;
});

final meProvider = FutureProvider<UserModel>((ref) async {
  final state = await ref.watch(fluentianStateProvider.future);
  return state.user;
});

final lessonsProvider = FutureProvider<List<LessonModel>>((ref) async {
  final state = await ref.watch(fluentianStateProvider.future);
  return state.lessons;
});

class CompletionState {
  CompletionState({required this.loading, this.lastResult, this.error});

  final bool loading;
  final Map<String, dynamic>? lastResult;
  final String? error;

  CompletionState copyWith(
      {bool? loading, Map<String, dynamic>? lastResult, String? error}) {
    return CompletionState(
      loading: loading ?? this.loading,
      lastResult: lastResult ?? this.lastResult,
      error: error,
    );
  }
}

class CompletionNotifier extends StateNotifier<CompletionState> {
  CompletionNotifier(this.ref, this.lessonRepository)
      : super(CompletionState(loading: false));

  final Ref ref;

  final LessonRepository lessonRepository;

  Future<void> completeLesson(int lessonId, int score) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await ref
          .read(fluentianStateProvider.notifier)
          .completeLesson(lessonId, score);
      state = state.copyWith(loading: false, lastResult: result);
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.response?.data.toString() ?? e.message,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final completionProvider =
    StateNotifierProvider<CompletionNotifier, CompletionState>((ref) {
  return CompletionNotifier(ref, ref.read(lessonRepositoryProvider));
});
