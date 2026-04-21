import 'dart:convert';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lesson_model.dart';
import '../app/providers.dart';
import '../features/lessons/lesson_player_screen.dart';
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
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 1200));
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _RoadmapFromSample(
                expandedUnits: _expandedUnits,
                scrollController: _scrollController,
                hasAutoScrolled: _hasAutoScrolled,
                meAsync: meAsync,
                confettiController: _confettiController,
                lessonKeys: _lessonKeys,
                onRefresh: () {
                  ref.read(fluentianStateProvider.notifier).refreshAll();
                },
                onCompleteLesson: (lessonId) async {
                  await ref.read(completionProvider.notifier).completeLesson(lessonId, 100);
                },
                onToggleUnit: _toggleUnit,
                onMarkAutoScrolled: _markAutoScrolled,
              ),
              data: (lessons) {
                // Map your lesson API response into unit-grouped view models for the roadmap.
                final units = _buildUnitsFromLessons(lessons, _lessonKeys);

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
                          MaterialPageRoute(builder: (_) => LessonPlayerScreen(lessonId: lesson.id)),
                        );
                      },
                      onComplete: () async {
                        await ref.read(completionProvider.notifier).completeLesson(lesson.id, 100);
                        _confettiController.play();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Great work! +${lesson.xpReward} XP')),
                          );
                        }
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

  void _markAutoScrolled() {
    _hasAutoScrolled = true;
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

    final unitId = units.firstWhere((u) => u.lessons.any((l) => l.id == activeLesson.id)).id;
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

  static List<RoadmapUnitView> _buildUnitsFromLessons(List<LessonModel> lessons, Map<int, GlobalKey> lessonKeys) {
    if (lessons.isEmpty) {
      return _buildUnitsFromSampleJson(lessonKeys);
    }

    final sorted = [...lessons]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    const unitSize = 5;

    final views = <RoadmapUnitView>[];

    for (var i = 0; i < sorted.length; i += unitSize) {
      final chunk = sorted.skip(i).take(unitSize).toList();
      final unitNumber = (i ~/ unitSize) + 1;

      final lessonsInUnit = <RoadmapLessonView>[];

      for (var j = 0; j < chunk.length; j++) {
        final globalIndex = i + j;
        final current = chunk[j];

        final previousCompleted = globalIndex == 0 ? true : sorted[globalIndex - 1].completed;
        final locked = !current.unlocked && !current.completed && !previousCompleted;

        lessonsInUnit.add(
          RoadmapLessonView(
            id: current.id,
            title: 'Lesson ${current.orderIndex}',
            description: _lessonDescription(current),
            locked: locked,
            completed: current.completed,
            xpReward: current.xpReward,
            isActive: !locked && !current.completed,
          ),
        );
      }

      final completedCount = lessonsInUnit.where((lesson) => lesson.completed).length;
      final progress = lessonsInUnit.isEmpty ? 0.0 : completedCount / lessonsInUnit.length;

      views.add(
        RoadmapUnitView(
          id: unitNumber,
          title: 'Unit $unitNumber',
          description: _unitDescription(unitNumber),
          progress: progress,
          lessons: lessonsInUnit,
        ),
      );
    }

    for (final unit in views) {
      for (final lesson in unit.lessons) {
        lessonKeys.putIfAbsent(lesson.id, GlobalKey.new);
      }
    }

    return views;
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
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                      const SnackBar(content: Text('Finish the previous lesson to unlock this one.')),
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
    final lessonCount = units.fold<int>(0, (acc, unit) => acc + unit.lessons.length);
    final completedCount = units.fold<int>(0, (acc, unit) => acc + unit.lessons.where((l) => l.completed).length);
    final totalXp = units
        .expand((unit) => unit.lessons)
        .where((lesson) => lesson.completed)
        .fold<int>(0, (sum, lesson) => sum + lesson.xpReward);

    final progress = lessonCount == 0 ? 0.0 : completedCount / lessonCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEEFFF2), Color(0xFFFFFFFF)]),
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
            style: const TextStyle(color: Color(0xFF566273), fontWeight: FontWeight.w700),
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
              _HeroChip(icon: Icons.bolt_rounded, label: '$totalXp XP earned', tint: const Color(0xFF198C3E)),
              const SizedBox(width: 8),
              _HeroChip(icon: Icons.layers_rounded, label: '${units.length} units', tint: const Color(0xFF2B7FD4)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, required this.tint});

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
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: tint)),
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
                const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(
                  meAsync.maybeWhen(data: (u) => 'Streak: ${u.streak} days', orElse: () => 'Streak: -'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4D5A6B)),
                ),
                const SizedBox(height: 6),
                Text(
                  meAsync.maybeWhen(data: (u) => 'XP: ${u.xp}', orElse: () => 'XP: -'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4D5A6B)),
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

class _RoadmapFromSample extends StatelessWidget {
  const _RoadmapFromSample({
    required this.expandedUnits,
    required this.scrollController,
    required this.hasAutoScrolled,
    required this.meAsync,
    required this.confettiController,
    required this.lessonKeys,
    required this.onRefresh,
    required this.onCompleteLesson,
    required this.onToggleUnit,
    required this.onMarkAutoScrolled,
  });

  final Set<int> expandedUnits;
  final ScrollController scrollController;
  final bool hasAutoScrolled;
  final AsyncValue<dynamic> meAsync;
  final ConfettiController confettiController;
  final Map<int, GlobalKey> lessonKeys;
  final VoidCallback onRefresh;
  final Future<void> Function(int lessonId) onCompleteLesson;
  final void Function(int unitId) onToggleUnit;
  final VoidCallback onMarkAutoScrolled;

  @override
  Widget build(BuildContext context) {
    final units = _buildUnitsFromSampleJson(lessonKeys);

    if (expandedUnits.isEmpty && units.isNotEmpty) {
      expandedUnits.add(units.first.id);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasAutoScrolled) {
        final active = units
            .expand((unit) => unit.lessons)
            .cast<RoadmapLessonView?>()
            .firstWhere((lesson) => lesson?.isActive ?? false, orElse: () => null);
        final targetKey = active == null ? null : lessonKeys[active.id];
        if (targetKey?.currentContext != null) {
          Scrollable.ensureVisible(targetKey!.currentContext!, duration: const Duration(milliseconds: 500));
          onMarkAutoScrolled();
        }
      }
    });

    return Column(
      children: [
        Expanded(
          child: _RoadmapContent(
            units: units,
            meAsync: meAsync,
            expandedUnits: expandedUnits,
            lessonKeys: lessonKeys,
            scrollController: scrollController,
            onTapLesson: (lesson) {
              _openLessonSheet(
                context: context,
                lesson: lesson,
                onStart: () {},
                onComplete: () async {
                  await onCompleteLesson(lesson.id);
                  confettiController.play();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
            onToggleUnit: onToggleUnit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry API load'),
          ),
        ),
      ],
    );
  }
}

void _openLessonSheet({
  required BuildContext context,
  required RoadmapLessonView lesson,
  required VoidCallback onStart,
  required Future<void> Function() onComplete,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LessonSheet(lesson: lesson, onStart: onStart, onComplete: onComplete),
  );
}

class _LessonSheet extends HookWidget {
  const _LessonSheet({
    required this.lesson,
    required this.onStart,
    required this.onComplete,
  });

  final RoadmapLessonView lesson;
  final VoidCallback onStart;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final tries = useState(0);
    final shakeController = useAnimationController(duration: const Duration(milliseconds: 420));
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final shakeCurve = CurvedAnimation(parent: shakeController, curve: Curves.elasticIn);

    Future<void> runIncorrectFeedback() async {
      tries.value += 1;
      if (!reducedMotion) {
        await shakeController.forward(from: 0);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not quite. Review and try again.')),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AnimatedBuilder(
        animation: shakeCurve,
        builder: (context, child) {
          final shake = math.sin(shakeCurve.value * math.pi * 3) * 8;
          return Transform.translate(offset: Offset(shake, 0), child: child);
        },
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  lesson.description,
                  style: const TextStyle(color: Color(0xFF5A6778), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF9F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${lesson.xpReward} XP reward',
                        style: const TextStyle(color: Color(0xFF168A3C), fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Attempts: ${tries.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: runIncorrectFeedback,
                        child: const Text('Simulate Incorrect'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: lesson.completed ? null : onComplete,
                        child: const Text('Mark Complete'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Open Lesson Player'),
                  ),
                ),
              ],
            ),
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

String _unitDescription(int unitNumber) {
  const themes = <String>[
    'Build your basics with greetings and everyday verbs.',
    'Focus on sentence flow and useful conversation patterns.',
    'Master practical responses for travel and daily life.',
    'Sharpen comprehension and confidence under time pressure.',
  ];

  return themes[(unitNumber - 1) % themes.length];
}

List<RoadmapUnitView> _buildUnitsFromSampleJson(Map<int, GlobalKey> lessonKeys) {
  final parsed = jsonDecode(_sampleRoadmapJson) as Map<String, dynamic>;
  final unitsJson = (parsed['units'] as List).cast<Map<String, dynamic>>();

  final units = unitsJson
      .map(
        (unitJson) => RoadmapUnitView(
          id: unitJson['id'] as int,
          title: unitJson['title'] as String,
          description: unitJson['description'] as String,
          progress: (unitJson['progress'] as num).toDouble(),
          lessons: (unitJson['lessons'] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (lessonJson) => RoadmapLessonView(
                  id: lessonJson['id'] as int,
                  title: lessonJson['title'] as String,
                  description: lessonJson['description'] as String,
                  locked: lessonJson['locked'] as bool,
                  completed: lessonJson['completed'] as bool,
                  xpReward: lessonJson['xp_reward'] as int,
                  isActive: lessonJson['is_active'] as bool,
                ),
              )
              .toList(),
        ),
      )
      .toList();

  for (final unit in units) {
    for (final lesson in unit.lessons) {
      lessonKeys.putIfAbsent(lesson.id, GlobalKey.new);
    }
  }

  return units;
}

const String _sampleRoadmapJson = '''
{
  "units": [
    {
      "id": 1,
      "title": "Unit 1",
      "description": "Core phrases and introductions",
      "progress": 0.66,
      "lessons": [
        {
          "id": 1001,
          "title": "Hello & Bye",
          "description": "Learn greeting basics with short drills.",
          "locked": false,
          "completed": true,
          "xp_reward": 10,
          "is_active": false
        },
        {
          "id": 1002,
          "title": "Names",
          "description": "Ask and answer names naturally.",
          "locked": false,
          "completed": true,
          "xp_reward": 12,
          "is_active": false
        },
        {
          "id": 1003,
          "title": "Where Are You From",
          "description": "Use country and city phrases.",
          "locked": false,
          "completed": false,
          "xp_reward": 15,
          "is_active": true
        }
      ]
    },
    {
      "id": 2,
      "title": "Unit 2",
      "description": "Daily actions and habits",
      "progress": 0.0,
      "lessons": [
        {
          "id": 2001,
          "title": "Morning Routine",
          "description": "Vocabulary for daily routine talk.",
          "locked": true,
          "completed": false,
          "xp_reward": 14,
          "is_active": false
        },
        {
          "id": 2002,
          "title": "Asking Time",
          "description": "Use practical time expressions.",
          "locked": true,
          "completed": false,
          "xp_reward": 14,
          "is_active": false
        }
      ]
    }
  ]
}
''';
