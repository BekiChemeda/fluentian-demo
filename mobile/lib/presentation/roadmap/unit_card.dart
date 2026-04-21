import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../core/theme/app_theme.dart';
import 'lesson_node.dart';

class RoadmapLessonView {
  const RoadmapLessonView({
    required this.id,
    required this.title,
    required this.description,
    required this.locked,
    required this.completed,
    required this.xpReward,
    required this.isActive,
  });

  final int id;
  final String title;
  final String description;
  final bool locked;
  final bool completed;
  final int xpReward;
  final bool isActive;
}

class RoadmapUnitView {
  const RoadmapUnitView({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.lessons,
  });

  final int id;
  final String title;
  final String description;
  final double progress;
  final List<RoadmapLessonView> lessons;
}

class UnitCard extends StatelessWidget {
  const UnitCard({
    super.key,
    required this.unit,
    required this.expanded,
    required this.lessonKeys,
    required this.onTapHeader,
    required this.onTapLesson,
  });

  final RoadmapUnitView unit;
  final bool expanded;
  final Map<int, GlobalKey> lessonKeys;
  final VoidCallback onTapHeader;
  final void Function(RoadmapLessonView lesson) onTapLesson;

  @override
  Widget build(BuildContext context) {
    final progressLabel = '${(unit.progress * 100).round()}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9EDF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(18)),
            onTap: onTapHeader,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          unit.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F3F8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          progressLabel,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF637083),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    unit.description,
                    style: const TextStyle(color: Color(0xFF586576), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: unit.progress,
                      backgroundColor: const Color(0xFFEDF2F4),
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
              child: _UnitTimeline(
                unit: unit,
                lessonKeys: lessonKeys,
                onTapLesson: onTapLesson,
              ),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

class _UnitTimeline extends StatelessWidget {
  const _UnitTimeline({
    required this.unit,
    required this.lessonKeys,
    required this.onTapLesson,
  });

  final RoadmapUnitView unit;
  final Map<int, GlobalKey> lessonKeys;
  final void Function(RoadmapLessonView lesson) onTapLesson;

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Column(
        children: List.generate(unit.lessons.length, (index) {
          final lesson = unit.lessons[index];
          final key = lessonKeys[lesson.id]!;
          final isLeft = index.isEven;
          final showConnector = index < unit.lessons.length - 1;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 360),
            child: SlideAnimation(
              horizontalOffset: isLeft ? -14 : 14,
              child: FadeInAnimation(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              key: key,
                              margin: EdgeInsets.only(
                                top: 8,
                                bottom: 8,
                                left: isLeft ? 4 : 30,
                                right: isLeft ? 30 : 4,
                              ),
                              child: LessonNode(
                                title: lesson.title,
                                xpReward: lesson.xpReward,
                                status: lesson.completed
                                    ? LessonNodeStatus.completed
                                    : lesson.locked
                                        ? LessonNodeStatus.locked
                                        : lesson.isActive
                                            ? LessonNodeStatus.active
                                            : LessonNodeStatus.unlocked,
                                animateUnlock: !lesson.locked,
                                onTap: () => onTapLesson(lesson),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showConnector)
                      SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                painter: _ConnectorPainter(
                                  color: lesson.locked ? const Color(0xFFC9CFD9) : AppColors.primary,
                                  startFromLeft: isLeft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.color, required this.startFromLeft});

  final Color color;
  final bool startFromLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final startX = startFromLeft ? size.width * 0.22 : size.width * 0.78;
    final endX = startFromLeft ? size.width * 0.78 : size.width * 0.22;
    path.moveTo(startX, 4);
    path.cubicTo(startX, size.height * 0.44, endX, size.height * 0.56, endX, size.height - 4);

    final roadShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 19
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final roadEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.35);

    final roadBody = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEEF2F6);

    final centerStripe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.95);

    canvas.drawPath(path, roadShadow);
    canvas.drawPath(path, roadEdge);
    canvas.drawPath(path, roadBody);
    canvas.drawPath(path, centerStripe);

    final startGlow = Paint()..color = color.withValues(alpha: 0.2);
    final endGlow = Paint()..color = color.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(startX, 5), 6, startGlow);
    canvas.drawCircle(Offset(endX, size.height - 5), 6, endGlow);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.startFromLeft != startFromLeft;
  }
}
