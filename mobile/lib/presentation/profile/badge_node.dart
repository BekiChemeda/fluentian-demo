import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'profile_screen.dart';

class BadgeNode extends HookWidget {
  const BadgeNode({
    super.key,
    required this.badge,
    required this.onTap,
  });

  final ProfileBadge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.96,
      upperBound: 1.03,
    );
    final pulseValue = useAnimation(pulseController);

    useEffect(() {
      if (badge.unlocked) {
        pulseController.repeat(reverse: true);
      }
      return null;
    }, [badge.unlocked]);

    final tint = badge.unlocked ? const Color(0xFF38B860) : const Color(0xFFAAB3C2);

    return GestureDetector(
      onTap: onTap,
      child: Transform.scale(
        scale: badge.unlocked ? pulseValue : 1,
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tint.withValues(alpha: 0.3), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: badge.unlocked ? 0.2 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badge.iconSvg.isNotEmpty)
                    ColorFiltered(
                      colorFilter: badge.unlocked
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                          : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      child: SvgPicture.string(
                        badge.iconSvg,
                        width: 34,
                        height: 34,
                        placeholderBuilder: (_) => Icon(Icons.military_tech_rounded, color: tint, size: 32),
                      ),
                    )
                  else
                    Icon(Icons.military_tech_rounded, color: tint, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    badge.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: badge.unlocked ? const Color(0xFF203143) : const Color(0xFF6F7B8E),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              if (!badge.unlocked)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(Icons.lock_rounded, size: 16, color: Color(0xFF96A1AF)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
