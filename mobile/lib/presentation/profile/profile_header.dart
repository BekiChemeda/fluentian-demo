import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/theme/app_theme.dart';
import 'profile_screen.dart';

class ProfileHeader extends HookWidget {
  const ProfileHeader({
    super.key,
    required this.data,
    required this.onEditProfile,
    required this.onSettings,
    required this.onShare,
  });

  final ProfileViewData data;
  final VoidCallback onEditProfile;
  final VoidCallback onSettings;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final safeUsername =
        data.username.trim().isEmpty ? 'Learner' : data.username.trim();

    final flameController =
        useAnimationController(duration: const Duration(milliseconds: 900));
    final flamePulse = useAnimation(flameController);

    useEffect(() {
      flameController.repeat(reverse: true);
      return null;
    }, const []);

    final levelProgress =
        (data.currentXp / (data.levelTargetXp == 0 ? 1 : data.levelTargetXp))
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFFEF3), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EFE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.secondary,
                    child: Text(
                      safeUsername.characters.first.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onEditProfile,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeUsername,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.nativeLanguage} -> ${data.targetLanguage}',
                      style: const TextStyle(
                          color: Color(0xFF5E6C7B),
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 34,
                lineWidth: 7,
                percent: levelProgress,
                animation: true,
                animateFromLastPercent: true,
                center: Text(
                  'Lv ${data.level}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 12),
                ),
                progressColor: AppColors.primary,
                backgroundColor: const Color(0xFFE5ECE8),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${data.currentXp} XP',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearPercentIndicator(
                        animation: true,
                        animateFromLastPercent: true,
                        lineHeight: 11,
                        percent: levelProgress,
                        progressColor: AppColors.secondary,
                        backgroundColor: const Color(0xFFE8EFEA),
                        padding: EdgeInsets.zero,
                        barRadius: const Radius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${data.levelTargetXp - data.currentXp} XP to next level',
                      style: const TextStyle(
                          color: Color(0xFF6D7988),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.96 + (0.08 * math.max(0, flamePulse)),
                        child: const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFFF18F29)),
                      ),
                      const SizedBox(width: 6),
                      Text('${data.streakDays} day streak',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
