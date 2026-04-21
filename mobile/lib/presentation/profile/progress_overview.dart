import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/theme/app_theme.dart';
import 'profile_screen.dart';

class ProgressOverview extends StatelessWidget {
  const ProgressOverview({
    super.key,
    required this.data,
    required this.onTapUnit,
  });

  final ProfileViewData data;
  final void Function(ProfileUnitProgress unit) onTapUnit;

  @override
  Widget build(BuildContext context) {
    final totalUnits = data.unitsProgress.length;
    final completedUnits = data.unitsProgress.where((u) => u.completionPercentage >= 1).length;
    final dailyProgress = data.dailyGoal == 0 ? 0.0 : (data.todayXp / data.dailyGoal).clamp(0.0, 1.0);

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          AnimationConfiguration.staggeredList(
            position: 0,
            duration: const Duration(milliseconds: 320),
            child: FadeInAnimation(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Units Completed', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('$completedUnits / $totalUnits', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.unitsProgress.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final unit = data.unitsProgress[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onTapUnit(unit),
                            child: Container(
                              width: 150,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FBF8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE7EEE9)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(unit.unitTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const Spacer(),
                                  LinearPercentIndicator(
                                    animation: true,
                                    lineHeight: 8,
                                    percent: unit.completionPercentage.clamp(0.0, 1.0),
                                    progressColor: AppColors.primary,
                                    backgroundColor: const Color(0xFFE3EBE5),
                                    barRadius: const Radius.circular(99),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${(unit.completionPercentage * 100).round()}% complete',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF637284)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimationConfiguration.staggeredList(
            position: 1,
            duration: const Duration(milliseconds: 350),
            child: FadeInAnimation(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total XP', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('${data.totalXp}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          LinearPercentIndicator(
                            animation: true,
                            lineHeight: 9,
                            percent: (data.totalXp / (data.nextMilestoneXp == 0 ? 1 : data.nextMilestoneXp)).clamp(0.0, 1.0),
                            progressColor: AppColors.primary,
                            backgroundColor: const Color(0xFFE4EBE6),
                            barRadius: const Radius.circular(99),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${data.nextMilestoneXp - data.totalXp} XP to milestone',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF647485)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Goal', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('${data.todayXp} / ${data.dailyGoal}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          LinearPercentIndicator(
                            animation: true,
                            lineHeight: 9,
                            percent: dailyProgress,
                            progressColor: dailyProgress >= 1 ? AppColors.primary : AppColors.secondary,
                            backgroundColor: const Color(0xFFE6EBF1),
                            barRadius: const Radius.circular(99),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            dailyProgress >= 1 ? 'Goal reached today' : '${((1 - dailyProgress) * 100).round()}% remaining',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF647485)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
