import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/lesson_model.dart';
import '../app/providers.dart';
import 'badge_gallery.dart';
import 'profile_header.dart';
import 'progress_overview.dart';

final profileViewProvider = Provider<AsyncValue<ProfileViewData>>((ref) {
  final stateAsync = ref.watch(fluentianStateProvider);

  return stateAsync.whenData((state) {
    final me = state.user;
    final lessons = state.lessons;
    final badges = state.badges;

    final rawUsername = me.email.split('@').first.trim();
    final username = rawUsername.isEmpty ? 'learner' : rawUsername;
    final level = (me.xp ~/ 100) + 1;
    final levelTargetXp = level * 100;
    final safeDailyGoal = math.max(1, me.dailyXpGoal);
    final todayXp = me.xp % safeDailyGoal;
    final nextMilestoneXp = me.xp + 100;

    final unitsProgress = _buildUnitProgress(lessons, unitSize: 5);
    final mappedBadges = badges
        .map(
          (badge) => ProfileBadge(
            id: badge.id,
            name: badge.name,
            description: badge.description,
            unlocked: badge.unlocked,
            unlockDate: badge.unlockDate,
            unlockCriteria: badge.unlockCriteria,
            iconSvg: badge.iconSvg,
          ),
        )
        .toList();

    return ProfileViewData(
      id: me.id,
      username: username,
      email: me.email,
      nativeLanguage: me.nativeLanguage,
      targetLanguage: me.targetLanguage,
      level: level,
      currentXp: me.xp,
      levelTargetXp: levelTargetXp,
      streakDays: me.streak,
      dailyGoal: me.dailyXpGoal,
      todayXp: todayXp,
      totalXp: me.xp,
      nextMilestoneXp: nextMilestoneXp,
      unitsProgress: unitsProgress,
      badges: mappedBadges,
    );
  });
});

final profileAnalyticsProvider =
    FutureProvider<ProfileAnalyticsData>((ref) async {
  final raw = await ref.read(communicationRepositoryProvider).getUserStats();
  return ProfileAnalyticsData.fromJson(raw);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ConfettiController _badgeConfettiController;

  @override
  void initState() {
    super.initState();
    _badgeConfettiController =
        ConfettiController(duration: const Duration(milliseconds: 950));
  }

  @override
  void dispose() {
    _badgeConfettiController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(fluentianStateProvider.notifier).refreshAll();
    ref.invalidate(profileAnalyticsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileViewProvider);
    final analytics = ref.watch(profileAnalyticsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColors = isDarkMode
        ? const [Color(0xFF0B1220), Color(0xFF121C31)]
        : const [Color(0xFFEAFBED), Color(0xFFFFF8EE)];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: backgroundColors,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: profile.when(
            loading: _ProfileLoading.new,
            error: (error, _) => _ProfileError(
              onRetry: () {
                ref.read(fluentianStateProvider.notifier).refreshAll();
              },
            ),
            data: (data) {
              return ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: [
                  ProfileHeader(
                    data: data,
                    onEditProfile: () => _openEditProfileDialog(context, data),
                    onSettings: () => _openSettingsSheet(context, data),
                    onShare: () => _shareProfile(data),
                  ),
                  const SizedBox(height: 12),
                  ProgressOverview(
                    data: data,
                    onTapUnit: (unit) {
                      _openUnitSheet(context, unit);
                    },
                  ),
                  const SizedBox(height: 12),
                  BadgeGallery(
                    badges: data.badges,
                    confettiController: _badgeConfettiController,
                    onTapBadge: (badge) => _openBadgeSheet(context, badge),
                  ),
                  const SizedBox(height: 12),
                  _AnalyticsCard(analytics: analytics),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).logout(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE05252)),
                    child: const Text('Logout'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openEditProfileDialog(
      BuildContext context, ProfileViewData data) async {
    final nativeLanguageNotifier = ValueNotifier<String>(
      data.nativeLanguage == 'English' ? 'English' : 'Amharic',
    );
    final targetController = TextEditingController(text: data.targetLanguage);
    final goalController =
        TextEditingController(text: data.dailyGoal.toString());

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit learning profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: nativeLanguageNotifier,
                builder: (_, selected, __) {
                  return DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration:
                        const InputDecoration(labelText: 'Native language'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Amharic', child: Text('Amharic')),
                      DropdownMenuItem(
                          value: 'English', child: Text('English')),
                    ],
                    onChanged: (value) {
                      nativeLanguageNotifier.value = value ?? 'Amharic';
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Target language'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: goalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily XP goal'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !mounted) {
      nativeLanguageNotifier.dispose();
      targetController.dispose();
      goalController.dispose();
      return;
    }

    final nativeLanguage = nativeLanguageNotifier.value;
    final targetLanguage = targetController.text.trim();
    final parsedGoal = int.tryParse(goalController.text.trim());

    nativeLanguageNotifier.dispose();
    targetController.dispose();
    goalController.dispose();

    if (nativeLanguage.isEmpty ||
        targetLanguage.isEmpty ||
        parsedGoal == null ||
        parsedGoal < 1) {
      _showMessage('Please enter valid profile values');
      return;
    }

    try {
      await ref.read(fluentianStateProvider.notifier).updateUserProfile(
            nativeLanguage: nativeLanguage,
            targetLanguage: targetLanguage,
            dailyXpGoal: parsedGoal,
          );
      await _refresh();
      _showMessage('Profile updated');
    } catch (_) {
      _showMessage('Unable to update profile right now');
    }
  }

  Future<void> _openSettingsSheet(
      BuildContext context, ProfileViewData data) async {
    final currentThemeMode =
        ref.read(themeModeProvider).valueOrNull ?? ThemeMode.light;
    var selectedThemeMode = currentThemeMode;

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        const goals = [20, 30, 40, 60, 80, 100];
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily XP Goal',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: goals
                      .map(
                        (goal) => ChoiceChip(
                          label: Text('$goal XP'),
                          selected: goal == data.dailyGoal,
                          onSelected: (_) => Navigator.of(context).pop(goal),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                const Text('Appearance',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                StatefulBuilder(
                  builder: (context, setState) {
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Day'),
                          icon: Icon(Icons.light_mode_rounded),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Night'),
                          icon: Icon(Icons.dark_mode_rounded),
                        ),
                      ],
                      selected: {selectedThemeMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) async {
                        final mode = selection.first;
                        setState(() {
                          selectedThemeMode = mode;
                        });
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(mode);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    try {
      await ref
          .read(fluentianStateProvider.notifier)
          .updateUserProfile(dailyXpGoal: selected);
      await _refresh();
      _showMessage('Daily goal set to $selected XP');
    } catch (_) {
      _showMessage('Could not save settings');
    }
  }

  Future<void> _shareProfile(ProfileViewData data) async {
    final message =
        'I\'m learning ${data.targetLanguage} on Fluentian. Level ${data.level}, streak ${data.streakDays} days, total ${data.totalXp} XP.';
    await Share.share(message, subject: 'My Fluentian Progress');
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openUnitSheet(BuildContext context, ProfileUnitProgress unit) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unit.unitTitle,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(
                  'Completion: ${(unit.completionPercentage * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep practicing this unit to increase your fluency score and unlock more badges.',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openBadgeSheet(BuildContext context, ProfileBadge badge) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      badge.unlocked
                          ? Icons.military_tech_rounded
                          : Icons.lock_rounded,
                      color: badge.unlocked
                          ? AppColors.primary
                          : const Color(0xFF9AA4B2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        badge.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(badge.description,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFF556273))),
                const SizedBox(height: 10),
                Text('Criteria: ${badge.unlockCriteria}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  badge.unlocked
                      ? 'Unlocked on ${badge.unlockDate ?? 'recently'}'
                      : 'Not unlocked yet',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF6B7888)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<ProfileUnitProgress> _buildUnitProgress(List<LessonModel> lessons,
    {required int unitSize}) {
  if (lessons.isEmpty) {
    return const [];
  }

  final totalUnits = (lessons.length / unitSize).ceil();
  final result = <ProfileUnitProgress>[];

  for (var i = 0; i < totalUnits; i++) {
    final unitLessons = lessons.skip(i * unitSize).take(unitSize).toList();
    if (unitLessons.isEmpty) {
      continue;
    }
    final completed =
        unitLessons.where((lesson) => lesson.completed == true).length;
    result.add(
      ProfileUnitProgress(
        unitId: i + 1,
        unitTitle: 'Unit ${i + 1}',
        completionPercentage: completed / unitLessons.length,
      ),
    );
  }

  return result;
}

class _ProfileLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDarkMode ? const Color(0xFF1A2742) : const Color(0xFFE7ECEB);
    final highlightColor =
        isDarkMode ? const Color(0xFF243252) : const Color(0xFFF7FAF9);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        _shimmerCard(
          height: 210,
          isDarkMode: isDarkMode,
          baseColor: baseColor,
          highlightColor: highlightColor,
        ),
        const SizedBox(height: 12),
        _shimmerCard(
          height: 250,
          isDarkMode: isDarkMode,
          baseColor: baseColor,
          highlightColor: highlightColor,
        ),
        const SizedBox(height: 12),
        _shimmerCard(
          height: 170,
          isDarkMode: isDarkMode,
          baseColor: baseColor,
          highlightColor: highlightColor,
        ),
      ],
    );
  }

  Widget _shimmerCard({
    required double height,
    required bool isDarkMode,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF111B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load profile',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.analytics});

  final AsyncValue<ProfileAnalyticsData> analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D9A6C), Color(0xFF0E6E97)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: analytics.when(
          loading: () => const _AnalyticsLoading(),
          error: (_, __) => const Text(
            'Analytics unavailable right now',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Communication Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Realtime practice trends',
                style: TextStyle(
                    color: Color(0xFFE5F5F8), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric('Today', '${data.todaySeconds}s'),
                  _metric('Yesterday', '${data.yesterdaySeconds}s'),
                  _metric('Weekly', '${data.weeklySeconds}s'),
                  _metric('Sessions', '${data.totalSessions}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Average session: ${data.averageSessionDuration.toStringAsFixed(1)}s',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFE3F6FC), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
        ],
      ),
    );
  }
}

class _AnalyticsLoading extends StatelessWidget {
  const _AnalyticsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Communication Analytics',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          color: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.22),
        ),
      ],
    );
  }
}

class ProfileAnalyticsData {
  const ProfileAnalyticsData({
    required this.todaySeconds,
    required this.yesterdaySeconds,
    required this.weeklySeconds,
    required this.totalSessions,
    required this.averageSessionDuration,
  });

  final int todaySeconds;
  final int yesterdaySeconds;
  final int weeklySeconds;
  final int totalSessions;
  final double averageSessionDuration;

  factory ProfileAnalyticsData.fromJson(Map<String, dynamic> json) {
    return ProfileAnalyticsData(
      todaySeconds: json['today'] as int? ?? 0,
      yesterdaySeconds: json['yesterday'] as int? ?? 0,
      weeklySeconds: json['weekly'] as int? ?? 0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      averageSessionDuration:
          (json['average_session_duration'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProfileViewData {
  const ProfileViewData({
    required this.id,
    required this.username,
    required this.email,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.level,
    required this.currentXp,
    required this.levelTargetXp,
    required this.streakDays,
    required this.dailyGoal,
    required this.todayXp,
    required this.totalXp,
    required this.nextMilestoneXp,
    required this.unitsProgress,
    required this.badges,
  });

  final int id;
  final String username;
  final String email;
  final String nativeLanguage;
  final String targetLanguage;
  final int level;
  final int currentXp;
  final int levelTargetXp;
  final int streakDays;
  final int dailyGoal;
  final int todayXp;
  final int totalXp;
  final int nextMilestoneXp;
  final List<ProfileUnitProgress> unitsProgress;
  final List<ProfileBadge> badges;

  factory ProfileViewData.fromJson(Map<String, dynamic> json) {
    return ProfileViewData(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      nativeLanguage: json['native_language'] as String,
      targetLanguage: json['target_language'] as String,
      level: json['level'] as int,
      currentXp: json['current_xp'] as int,
      levelTargetXp: json['level_target_xp'] as int,
      streakDays: json['streak'] as int,
      dailyGoal: json['daily_goal'] as int,
      todayXp: json['today_xp'] as int,
      totalXp: json['total_xp'] as int,
      nextMilestoneXp: json['next_milestone_xp'] as int,
      unitsProgress: (json['units_progress'] as List)
          .cast<Map<String, dynamic>>()
          .map(ProfileUnitProgress.fromJson)
          .toList(),
      badges: (json['badges'] as List)
          .cast<Map<String, dynamic>>()
          .map(ProfileBadge.fromJson)
          .toList(),
    );
  }

  ProfileViewData copyWith({
    int? id,
    String? username,
    String? email,
    String? nativeLanguage,
    String? targetLanguage,
    int? level,
    int? currentXp,
    int? levelTargetXp,
    int? streakDays,
    int? dailyGoal,
    int? todayXp,
    int? totalXp,
    int? nextMilestoneXp,
    List<ProfileUnitProgress>? unitsProgress,
    List<ProfileBadge>? badges,
  }) {
    return ProfileViewData(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      levelTargetXp: levelTargetXp ?? this.levelTargetXp,
      streakDays: streakDays ?? this.streakDays,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      todayXp: todayXp ?? this.todayXp,
      totalXp: totalXp ?? this.totalXp,
      nextMilestoneXp: nextMilestoneXp ?? this.nextMilestoneXp,
      unitsProgress: unitsProgress ?? this.unitsProgress,
      badges: badges ?? this.badges,
    );
  }
}

class ProfileUnitProgress {
  const ProfileUnitProgress({
    required this.unitId,
    required this.unitTitle,
    required this.completionPercentage,
  });

  final int unitId;
  final String unitTitle;
  final double completionPercentage;

  factory ProfileUnitProgress.fromJson(Map<String, dynamic> json) {
    return ProfileUnitProgress(
      unitId: json['unit_id'] as int,
      unitTitle: json['unit_title'] as String,
      completionPercentage: (json['completion_percentage'] as num).toDouble(),
    );
  }
}

class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.unlockDate,
    required this.unlockCriteria,
    required this.iconSvg,
  });

  final int id;
  final String name;
  final String description;
  final bool unlocked;
  final String? unlockDate;
  final String unlockCriteria;
  final String iconSvg;

  factory ProfileBadge.fromJson(Map<String, dynamic> json) {
    final rawSvg = (json['icon_svg'] as String?)?.trim() ?? '';
    final safeSvg = rawSvg.startsWith('<svg') ? rawSvg : _defaultBadgeSvg;

    return ProfileBadge(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      unlocked: json['unlocked'] as bool,
      unlockDate: json['unlock_date'] as String?,
      unlockCriteria: json['unlock_criteria'] as String,
      iconSvg: safeSvg,
    );
  }
}

const String _defaultBadgeSvg =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#35B95E" d="M12 2l3.1 6.2L22 9l-5 4.6L18.2 22 12 18.7 5.8 22 7 13.6 2 9l6.9-.8L12 2z"/></svg>';
