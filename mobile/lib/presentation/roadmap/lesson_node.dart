import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum LessonNodeStatus { locked, active, completed, unlocked }

class LessonNode extends HookWidget {
  const LessonNode({
    super.key,
    required this.title,
    required this.xpReward,
    required this.status,
    required this.animateUnlock,
    required this.onTap,
  });

  final String title;
  final int xpReward;
  final LessonNodeStatus status;
  final bool animateUnlock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pulse = useAnimationController(
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.96,
      upperBound: 1.04,
    );
    final pulseValue = useAnimation(pulse);

    useEffect(() {
      if (status == LessonNodeStatus.active && !reducedMotion) {
        pulse.repeat(reverse: true);
      } else {
        pulse.stop();
        pulse.value = 1;
      }
      return null;
    }, [status, reducedMotion]);

    final isLocked = status == LessonNodeStatus.locked;

    final outerGradient = switch (status) {
      LessonNodeStatus.locked => const [Color(0xFFC9CED6), Color(0xFFB6BDC8)],
      LessonNodeStatus.active => const [Color(0xFF3FD66A), Color(0xFF24B252)],
      LessonNodeStatus.completed => const [Color(0xFF6AE394), Color(0xFF31BF63)],
      LessonNodeStatus.unlocked => const [Color(0xFFB5E7C6), Color(0xFF8BD5A6)],
    };

    final icon = switch (status) {
      LessonNodeStatus.locked => const Icon(Icons.lock_rounded, color: Color(0xFF616A77), size: 26),
      LessonNodeStatus.completed => const Icon(Icons.check_rounded, color: Color(0xFF148E3A), size: 28),
      LessonNodeStatus.active => SvgPicture.string(
          _sparkSvg,
          width: 28,
          height: 28,
          colorFilter: const ColorFilter.mode(Color(0xFF1C9C45), BlendMode.srcIn),
        ),
      LessonNodeStatus.unlocked => const Icon(Icons.play_arrow_rounded, color: Color(0xFF1A9141), size: 28),
    };

    final scaleIn = Tween<double>(begin: animateUnlock ? 0.84 : 1, end: 1);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: reducedMotion ? 0 : 420),
      curve: Curves.easeOutBack,
      tween: scaleIn,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: reducedMotion ? 0 : 220),
          opacity: isLocked ? 0.64 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: outerGradient),
                  boxShadow: [
                    BoxShadow(
                      color: outerGradient.first.withValues(alpha: 0.34),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: icon),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '+$xpReward XP',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLocked ? const Color(0xFF7A828E) : const Color(0xFF188F3E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value * pulseValue,
          child: child,
        );
      },
    );
  }
}

const String _sparkSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 2L14.9 8.2L21.5 9L16.7 13.4L18 20L12 16.7L6 20L7.3 13.4L2.5 9L9.1 8.2L12 2Z" fill="#2BBE56"/>
</svg>
''';
