import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'badge_node.dart';
import 'profile_screen.dart';

class BadgeGallery extends StatelessWidget {
  const BadgeGallery({
    super.key,
    required this.badges,
    required this.confettiController,
    required this.onTapBadge,
  });

  final List<ProfileBadge> badges;
  final ConfettiController confettiController;
  final void Function(ProfileBadge badge) onTapBadge;

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: 2,
      duration: const Duration(milliseconds: 360),
      child: FadeInAnimation(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Badges & Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text(
                        '${badges.where((b) => b.unlocked).length}/${badges.length}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F6072)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: badges.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final badge = badges[index];
                        return BadgeNode(
                          badge: badge,
                          onTap: () {
                            if (badge.unlocked) {
                              confettiController.play();
                            }
                            onTapBadge(badge);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: ConfettiWidget(
                    confettiController: confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    emissionFrequency: 0.06,
                    maxBlastForce: 18,
                    minBlastForce: 9,
                    numberOfParticles: 14,
                    gravity: 0.28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
