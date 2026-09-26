import 'dart:async';

import 'package:flutter/material.dart';


import '../../core/theme/tokens.dart';
import '../../core/widgets/fa_mark.dart';
import '../../core/widgets/primitives.dart';
import '../../data/voice/voice_service.dart';
import '../../domain/voice/voice_catalog.dart';

/// المقدمة (القسم ١): الخمس جمل ورا بعض، وبعدها «تحب أكلّمك بصوتي؟» —
/// «أيوه» بيشغّل الصوت ويقول `intro_yes`، و«لأ» بيقفله ويقول `intro_no`.
/// **«تخطّي» ظاهر طول الوقت**، وبيودّي لأول سؤال على طول.
///
/// الترجمة المكتوبة هنا جوّه الشاشة (مش الطبقة العامة) عشان الجملة تبقى
/// كبيرة وفي النص — أول مرة يسمع الصوت، والكلام قدّامه.
class VoiceIntroScreen extends StatefulWidget {
  const VoiceIntroScreen({required this.voice, required this.onDone, this.replay = false, super.key});

  final VoiceService voice;
  final VoidCallback onDone;

  /// من الإعدادات: المقدمة بتتعاد، والاختيار في الآخر بيتحفظ زي أول مرة.
  final bool replay;

  @override
  State<VoiceIntroScreen> createState() => _VoiceIntroScreenState();
}

class _VoiceIntroScreenState extends State<VoiceIntroScreen> {
  bool _asking = false;
  bool _closing = false;
  String _shown = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_play()));
  }

  Future<void> _play() async {
    for (final id in introSequence) {
      if (!mounted || _closing) return;
      setState(() => _shown = voiceLine(id));
      await widget.voice.speakLine(id, force: true);
    }
    if (mounted && !_closing) setState(() => _asking = true);
  }

  Future<void> _answer(bool yes) async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _shown = voiceLine(yes ? 'intro_yes' : 'intro_no');
    });
    await widget.voice.setEnabled(yes);
    await widget.voice.markIntroDone();
    // الجملة الأخيرة بتتقال والشاشة اللي بعدها بتفتح — ما بنحبسوش لحد ما
    // تخلص، والتنبيه لو جه بيوقّفها زي أي كلام.
    unawaited(widget.voice.speakLine(yes ? 'intro_yes' : 'intro_no', force: true));
    if (mounted) widget.onDone();
  }

  Future<void> _skip() async {
    if (_closing) return;
    _closing = true;
    await widget.voice.stop();
    await widget.voice.markIntroDone();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    // «تمام، أنا معاك» بتكمّل والشاشة اللي بعدها بتفتح — الوقف هنا للي
    // ساب الشاشة وهي لسه بتقدّم نفسها
    if (!_closing) unawaited(widget.voice.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(F.gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SizedBox(
                    height: F.minTapTarget,
                    child: TextButton(
                      key: const ValueKey('intro-skip'),
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: F.ink,
                        minimumSize: const Size(F.minTapTarget, F.minTapTarget),
                        textStyle: const TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('تخطّي'),
                    ),
                  ),
                ),
                const Spacer(),
                const Center(child: FaMark(size: 76, letterColor: F.greenDeep)),
                const SizedBox(height: F.gap),
                Text(
                  _shown,
                  key: const ValueKey('intro-caption'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: F.displayFamily,
                    fontSize: F.subtitleSize,
                    fontWeight: FontWeight.w700,
                    color: F.ink,
                    height: 1.6,
                  ),
                ),
                const Spacer(),
                if (_asking && !_closing) ...[
                  FPrimaryButton(
                    key: const ValueKey('intro-yes'),
                    label: 'أيوه، اتكلم',
                    onPressed: () => _answer(true),
                  ),
                  const SizedBox(height: F.s12),
                  FSecondaryButton(
                    key: const ValueKey('intro-no'),
                    label: 'لأ، من غير صوت',
                    onPressed: () => _answer(false),
                  ),
                ] else
                  const SizedBox(height: F.primaryButtonHeight + F.s12 + F.minTapTarget + F.s12 + F.minTapTarget),
              ],
            ),
          ),
        ),
      );
}
