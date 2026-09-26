import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../domain/voice/mic_state.dart';

/// الدايرة — `MicOrb` بتاع jarvis-ai-finance: **الحالة كلمة مكتوبة تحتها**،
/// عمرها ما تبقى لون أو حركة بس — اللي مش شايف النبض أو مقفّل الحركة عارف
/// المايك مفتوح ولا لأ.
///
/// الدوسة واحدة لكل الحالات ([onTap]) والدورة هي اللي بتقرر: والموبايل بيتكلم
/// = يسكت ويفتح المايك (مقاطعة بالدوسة، من غير إلغاء صدى)، والمايك مفتوح =
/// «خلصت».
class MicOrb extends StatelessWidget {
  const MicOrb({required this.state, required this.onTap, this.elder = false, super.key});

  final MicState state;
  final VoidCallback onTap;
  final bool elder;

  @override
  Widget build(BuildContext context) {
    final size = elder ? 88.0 : 72.0;
    final off = state == MicState.off;
    final label = micStateLabel(state);
    final Widget face = switch (state) {
      MicState.listening => PulsingMic(size: size),
      MicState.thinking => _disc(size, F.railGround, Icon(Icons.hourglass_top, size: size * 0.42, color: F.mutedDark)),
      MicState.speaking => _disc(size, F.green, Icon(Icons.stop_rounded, size: size * 0.46, color: F.onDark)),
      MicState.off => _disc(size, F.railGround, Icon(Icons.mic_off_outlined, size: size * 0.42, color: F.mutedDark)),
      MicState.idle || MicState.confirming => _disc(size, F.green, Icon(Icons.mic, size: size * 0.46, color: F.onDark)),
    };
    return Semantics(
      button: !off,
      enabled: !off,
      label: label,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const ValueKey('mic-orb'),
            customBorder: const CircleBorder(),
            onTap: off || state == MicState.thinking ? null : onTap,
            child: face,
          ),
          const SizedBox(height: F.s6),
          // الكلمة هي الحالة
          Text(
            label,
            key: const ValueKey('mic-orb-label'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: elder ? F.elderTextSize : F.minBodySize, fontWeight: FontWeight.w700, color: F.ink, height: 1.4),
          ),
        ],
      ),
    );
  }

  static Widget _disc(double size, Color color, Widget icon) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        alignment: Alignment.center,
        child: icon,
      );
}

/// مايك بينبض — **لحظة ما المايك مفتوح بس**. «تقليل الحركة» = ثابت.
class PulsingMic extends StatefulWidget {
  const PulsingMic({this.size = 56, super.key});

  final double size;

  @override
  State<PulsingMic> createState() => PulsingMicState();
}

class PulsingMicState extends State<PulsingMic> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Container(
          key: const ValueKey('listen-pulse'),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: F.gold.withValues(alpha: 0.15 + 0.25 * _c.value),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.mic, size: widget.size * 0.57, color: F.gold),
        ),
      );
}
