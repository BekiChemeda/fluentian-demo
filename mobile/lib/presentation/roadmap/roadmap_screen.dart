import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lesson_model.dart';
import '../../data/models/platform_models.dart';
import '../app/providers.dart';
import '../features/lessons/lesson_player_screen.dart';
import '../widgets/app_state_widgets.dart';
import 'unit_card.dart';

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  late final ScrollController _scrollController;
  late final ConfettiController _confettiController;
  final Set<int> _expandedUnits = <int>{};
  final Map<int, GlobalKey> _lessonKeys = <int, GlobalKey>{};
  bool _hasAutoScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(lessonsProvider);
    final meAsync = ref.watch(meProvider);
    final learningPathAsync = ref.watch(learningPathProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadmap'),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5FFF7), Color(0xFFFFFBF3)],
              ),
            ),
            child: lessonsAsync.when(
              loading: () => const AppLoadingState(message: 'Loading lessons'),
              error: (_, __) => AppErrorState(
                title: 'Could not load lessons',
                message:
                    'Check your API base URL and make sure the backend is running.',
                onRetry: () {
                  ref.read(fluentianStateProvider.notifier).refreshAll();
                  ref.invalidate(learningPathProvider);
                },
              ),
              data: (lessons) {
                final learningPath = learningPathAsync.valueOrNull;
                final units = _buildUnitsFromLearningPath(
                  lessons,
                  learningPath,
                  _lessonKeys,
                );

                if (lessons.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.route_rounded,
                    title: 'No lessons published yet',
                    message:
                        'Run the backend seed script or publish lessons from the admin API.',
                  );
                }

                if (_expandedUnits.isEmpty && units.isNotEmpty) {
                  _expandedUnits.add(units.first.id);
                }

                _tryAutoScrollToActive(
                  units: units,
                  lessonKeys: _lessonKeys,
                  expandedUnits: _expandedUnits,
                  hasAutoScrolled: _hasAutoScrolled,
                );

                return _RoadmapContent(
                  units: units,
                  meAsync: meAsync,
                  expandedUnits: _expandedUnits,
                  lessonKeys: _lessonKeys,
                  scrollController: _scrollController,
                  onTapLesson: (lesson) {
                    _openLessonSheet(
                      context: context,
                      lesson: lesson,
                      onStart: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  LessonPlayerScreen(lessonId: lesson.id)),
                        );
                      },
                    );
                  },
                  onToggleUnit: _toggleUnit,
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 22,
                maxBlastForce: 28,
                minBlastForce: 12,
                gravity: 0.24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleUnit(int unitId) {
    setState(() {
      if (_expandedUnits.contains(unitId)) {
        _expandedUnits.remove(unitId);
      } else {
        _expandedUnits.add(unitId);
      }
    });
  }

  void _tryAutoScrollToActive({
    required List<RoadmapUnitView> units,
    required Map<int, GlobalKey> lessonKeys,
    required Set<int> expandedUnits,
    required bool hasAutoScrolled,
  }) {
    if (hasAutoScrolled) {
      return;
    }

    final activeLesson = units
        .expand((unit) => unit.lessons)
        .cast<RoadmapLessonView?>()
        .firstWhere((lesson) => lesson?.isActive ?? false, orElse: () => null);

    if (activeLesson == null) {
      return;
    }

    final unitId = units
        .firstWhere((u) => u.lessons.any((l) => l.id == activeLesson.id))
        .id;
    if (!expandedUnits.contains(unitId)) {
      setState(() {
        expandedUnits.add(unitId);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final key = lessonKeys[activeLesson.id];
      final currentContext = key?.currentContext;
      if (currentContext != null) {
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 640),
          alignment: 0.28,
          curve: Curves.easeOutCubic,
        );
        _hasAutoScrolled = true;
      }
    });
  }

  static List<RoadmapUnitView> _buildUnitsFromLearningPath(
    List<LessonModel> lessons,
    LearningPathModel? learningPath,
    Map<int, GlobalKey> lessonKeys,
  ) {
    final sorted = [...lessons]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final views = <RoadmapUnitView>[];
    final lessonById = {for (final lesson in sorted) lesson.id: lesson};

    if (learningPath != null && learningPath.units.isNotEmpty) {
      for (final unit in learningPath.units) {
        final chunk = unit.lessonIds
            .map((id) => lessonById[id])
            .whereType<LessonModel>()
            .toList();
        if (chunk.isEmpty) {
          continue;
        }
        views.add(_buildUnitView(
          unitNumber: unit.unitNo,
          title: unit.title,
          description: unit.description ?? _unitDescription(unit.unitNo),
          chunk: chunk,
          allLessons: sorted,
        ));
      }
    }

    if (views.isEmpty) {
      const unitSize = 5;
      for (var i = 0; i < sorted.length; i += unitSize) {
        final chunk = sorted.skip(i).take(unitSize).toList();
        final unitNumber = (i ~/ unitSize) + 1;
        views.add(_buildUnitView(
          unitNumber: unitNumber,
          title: 'Unit $unitNumber',
          description: _unitDescription(unitNumber),
          chunk: chunk,
          allLessons: sorted,
        ));
      }
    }

    for (final unit in views) {
      for (final lesson in unit.lessons) {
        lessonKeys.putIfAbsent(lesson.id, GlobalKey.new);
      }
    }

    return views;
  }

  static RoadmapUnitView _buildUnitView({
    required int unitNumber,
    required String title,
    required String description,
    required List<LessonModel> chunk,
    required List<LessonModel> allLessons,
  }) {
    final lessonsInUnit = <RoadmapLessonView>[];

    for (final current in chunk) {
      final globalIndex =
          allLessons.indexWhere((lesson) => lesson.id == current.id);

        final previousCompleted =
            globalIndex <= 0 ? true : allLessons[globalIndex - 1].completed;
        final locked = (() {
          // Defensive: never lock the very first lesson in the overall list.
          if (globalIndex <= 0) return false;
          return !current.unlocked && !current.completed && !previousCompleted;
        })();
        // Debug logging to trace locking logic while running in emulator.
        // ignore: avoid_print
        print('Roadmap: lesson ${current.id} globalIndex=$globalIndex previousCompleted=$previousCompleted unlocked=${current.unlocked} completed=${current.completed} locked=$locked');

      lessonsInUnit.add(
        RoadmapLessonView(
          id: current.id,
          title: _lessonTitle(current),
          description: _lessonDescription(current),
          locked: locked,
          completed: current.completed,
          xpReward: current.xpReward,
          isActive: !locked && !current.completed,
        ),
      );
    }

    final completedCount =
        lessonsInUnit.where((lesson) => lesson.completed).length;
    final progress =
        lessonsInUnit.isEmpty ? 0.0 : completedCount / lessonsInUnit.length;

    return RoadmapUnitView(
      id: unitNumber,
      title: title,
      description: description,
      progress: progress,
      lessons: lessonsInUnit,
    );
  }
}

class _RoadmapContent extends StatelessWidget {
  const _RoadmapContent({
    required this.units,
    required this.meAsync,
    required this.expandedUnits,
    required this.lessonKeys,
    required this.scrollController,
    required this.onTapLesson,
    required this.onToggleUnit,
  });

  final List<RoadmapUnitView> units;
  final AsyncValue<dynamic> meAsync;
  final Set<int> expandedUnits;
  final Map<int, GlobalKey> lessonKeys;
  final ScrollController scrollController;
  final void Function(RoadmapLessonView lesson) onTapLesson;
  final void Function(int unitId) onToggleUnit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;

        if (wide) {
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _RoadmapList(
                  units: units,
                  expandedUnits: expandedUnits,
                  lessonKeys: lessonKeys,
                  scrollController: scrollController,
                  onTapLesson: onTapLesson,
                  onToggleUnit: onToggleUnit,
                ),
              ),
              Expanded(
                flex: 2,
                child: _RoadmapSidePanel(meAsync: meAsync, units: units),
              ),
            ],
          );
        }

        return _RoadmapList(
          units: units,
          expandedUnits: expandedUnits,
          lessonKeys: lessonKeys,
          scrollController: scrollController,
          onTapLesson: onTapLesson,
          onToggleUnit: onToggleUnit,
        );
      },
    );
  }
}

class _RoadmapList extends StatelessWidget {
  const _RoadmapList({
    required this.units,
    required this.expandedUnits,
    required this.lessonKeys,
    required this.scrollController,
    required this.onTapLesson,
    required this.onToggleUnit,
  });

  final List<RoadmapUnitView> units;
  final Set<int> expandedUnits;
  final Map<int, GlobalKey> lessonKeys;
  final ScrollController scrollController;
  final void Function(RoadmapLessonView lesson) onTapLesson;
  final void Function(int unitId) onToggleUnit;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _ProgressHero(units: units),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.separated(
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final unit = units[index];

              return UnitCard(
                unit: unit,
                expanded: expandedUnits.contains(unit.id),
                lessonKeys: lessonKeys,
                onTapHeader: () => onToggleUnit(unit.id),
                onTapLesson: (lesson) {
                  if (lesson.locked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Finish the previous lesson to unlock this one.')),
                    );
                    return;
                  }
                  onTapLesson(lesson);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.units});

  final List<RoadmapUnitView> units;

  @override
  Widget build(BuildContext context) {
    final lessonCount =
        units.fold<int>(0, (acc, unit) => acc + unit.lessons.length);
    final completedCount = units.fold<int>(
        0, (acc, unit) => acc + unit.lessons.where((l) => l.completed).length);
    final totalXp = units
        .expand((unit) => unit.lessons)
        .where((lesson) => lesson.completed)
        .fold<int>(0, (sum, lesson) => sum + lesson.xpReward);

    final progress = lessonCount == 0 ? 0.0 : completedCount / lessonCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFEEFFF2), Color(0xFFFFFFFF)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EFE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Fluency Road',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount / $lessonCount lessons completed',
            style: const TextStyle(
                color: Color(0xFF566273), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progress,
              backgroundColor: const Color(0xFFEAF0EC),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF35B95F)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeroChip(
                  icon: Icons.bolt_rounded,
                  label: '$totalXp XP earned',
                  tint: const Color(0xFF198C3E)),
              const SizedBox(width: 8),
              _HeroChip(
                  icon: Icons.layers_rounded,
                  label: '${units.length} units',
                  tint: const Color(0xFF2B7FD4)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(
      {required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontWeight: FontWeight.w800, color: tint)),
        ],
      ),
    );
  }
}

class _RoadmapSidePanel extends StatelessWidget {
  const _RoadmapSidePanel({required this.meAsync, required this.units});

  final AsyncValue<dynamic> meAsync;
  final List<RoadmapUnitView> units;

  @override
  Widget build(BuildContext context) {
    final activeLesson = units
        .expand((unit) => unit.lessons)
        .cast<RoadmapLessonView?>()
        .firstWhere((lesson) => lesson?.isActive ?? false, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8ECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(
                  meAsync.maybeWhen(
                      data: (u) => 'Streak: ${u.streak} days',
                      orElse: () => 'Streak: -'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF4D5A6B)),
                ),
                const SizedBox(height: 6),
                Text(
                  meAsync.maybeWhen(
                      data: (u) => 'XP: ${u.xp}', orElse: () => 'XP: -'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF4D5A6B)),
                ),
                const SizedBox(height: 10),
                if (activeLesson != null)
                  Text(
                    'Active lesson: ${activeLesson.title}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _openLessonSheet({
  required BuildContext context,
  required RoadmapLessonView lesson,
  required VoidCallback onStart,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LessonSheet(lesson: lesson, onStart: onStart),
  );
}

class _LessonSheet extends StatelessWidget {
  const _LessonSheet({
    required this.lesson,
    required this.onStart,
  });

  final RoadmapLessonView lesson;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lesson.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                lesson.description,
                style: const TextStyle(
                    color: Color(0xFF5A6778), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF9F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${lesson.xpReward} XP reward',
                  style: const TextStyle(
                      color: Color(0xFF168A3C), fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onStart();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _lessonDescription(LessonModel lesson) {
  final mode = lesson.type == 'translation' ? 'translation' : lesson.type;
  return 'Practice $mode with short interactive prompts.';
}

String _lessonTitle(LessonModel lesson) {
  final blocks = lesson.content['blocks'];
  if (blocks is List && blocks.isNotEmpty) {
    final first = blocks.first;
    if (first is Map<String, dynamic>) {
      final title = first['title']?.toString().trim();
      if (title != null && title.isNotEmpty) {
        return title;
      }
    }
  }
  return 'Lesson ${lesson.orderIndex}';
}

String _unitDescription(int unitNumber) {
  const themes = <String>[
    'Build your basics with greetings and everyday verbs.',
    'Focus on sentence flow and useful conversation patterns.',
    'Master practical responses for travel and daily life.',
    'Sharpen comprehension and confidence under time pressure.',
  ];

  return themes[(unitNumber - 1) % themes.length];
}
