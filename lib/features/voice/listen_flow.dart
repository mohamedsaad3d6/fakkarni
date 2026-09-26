import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/voice/listen_health.dart';
import '../../data/voice/speech_listener.dart';
import '../../data/voice/voice_service.dart';

/// مراحل السماع — الشاشة بترسمها، والاختبار بيقراها.
enum ListenPhase {
  idle,

  /// المايك مفتوح: مايك بينبض، «سامعك…»، والكلام بيتكتب وهو بيتقال
  /// ([ListenFlow.partial]).
  listening,

  /// الكلام اللي اتفهم مكتوب كبير، و«صح كده؟» **المسجّلة** — «أيوه»/«لأ»
  /// **بالإيد**.
  confirming,

  /// «معلش، مافهمتش» — المايك اشتغل وما سمعش حاجة مفهومة. «اتكلم تاني»
  /// دوسة جديدة؛ التانية ورا بعض «كمّل بإيدك» ([ListenFlow.missLine]).
  notUnderstood,

  /// «لأ» — مستني دوسة «اتكلم تاني» أو «اقفل». **مفيش سماع لوحده.**
  declined,

  /// المايك **ما اشتغلش أصلاً** (مش الإذن): «كمّل بإيدك» مرة، والزرار
  /// بيختفي من الشاشة دي.
  unavailable,

  /// اتطبّقت.
  done,
}

/// **سماع واحد لكل دوسة، والدوسة دايماً بتكسب** (آيفون، ٢٦ سبتمبر ٢٠٢٦):
/// المايك كان بيتفتح بعد جملة «اتكلم، أنا سامعك» بـ٢٥٠ ملّي فالكلمة الأولى
/// بتضيع، وجلسات بتبدأ وتموت في أقل من ثانية لأن السماع والأزرار بيتخانقوا،
/// و«أيوه» بالإيد ما كانتش بتكسب على طول، و«فهمت: …» بصوت الموبايل آلي.
///
/// - **الدوسة ← المايك على طول**: مفيش جملة قبله. النغمة الهادية بتيجي من
///   المتعرّف نفسه لحظة الفتح (`assets/sounds/speech_to_text_listening.m4r`)،
///   والشاشة بتقول «سامعك…» وبتكتب الكلام وهو بيتقال.
/// - **التأكيد بالإيد بس**: الكلام اللي اتفهم مكتوب كبير و«صح كده؟» المسجّلة
///   (`lis_confirm`) — مفيش سماع لـ«أيوه» ومفيش «فهمت: …» بصوت الموبايل.
/// - **أي دوسة بتوقّف المايك على طول وبتتطبّق** ([confirmYes] / [confirmNo] /
///   [cancel])، و**ولا سماع بيبدأ لوحده بعدها** — «اتكلم تاني» دوسة جديدة.
/// - وقعة في البداية ← «كمّل بإيدك» مرة والزرار يختفي؛ سكوت ← «مافهمتش»؛
///   التانية ورا بعض ← «كمّل بإيدك» والمايك فاضل.
///
/// **التطبيق بيعدّي من نفس السكّة بتاعة الزرار** ([onApply]). **تنبيه الجرعة
/// بيكسب**: `stop()` من برّه بيرجّع الكل لـidle في صمت.
class ListenFlow<T> extends ChangeNotifier {
  ListenFlow({
    required this.voice,
    required this.parse,
    required this.describe,
    required this.onApply,
    this.force = false,
    this.autoApply = true,
    Future<void> Function(String reason)? onStartFailure,
  }) : _onStartFailure = onStartFailure ?? recordListenProblem;

  final VoiceService voice;
  final T? Function(String heard) parse;

  /// اللي بيتكتب كبير وقت التأكيد («أخدته»، «الساعة ٨ الصبح»).
  final String Function(T value) describe;
  final Future<void> Function(T value) onApply;

  /// المقدمة: الصوت لسه ما اتشغّلش، والجمل بتتقال برضه.
  final bool force;

  /// «أيوه» بتطبّق على طول. الزرار بيحطّها false: الورقة بتتقفل الأول وبعدين
  /// بيطبّق ([confirmed]).
  final bool autoApply;

  final Future<void> Function(String reason) _onStartFailure;

  T? confirmed;
  ListenPhase phase = ListenPhase.idle;
  T? heard;
  String? heardText;

  /// الكلام وهو بيتقال — بيتكتب في الورقة لحظة بلحظة.
  String partial = '';

  /// سماعات اتفتحت — الاختبار بيعدّها: دوسة واحدة = سماع واحد.
  int sessions = 0;

  bool _busy = false;
  bool _disposed = false;
  int _misses = 0;
  String missLine = 'lis_not_understood';

  /// المايك ما اشتغلش على الشاشة دي — الزرار بيختفي لحد ما تتقفل.
  bool startFailed = false;

  bool get available =>
      voice.listener != null && !voice.micDenied && !startFailed && (voice.enabled || force);

  String get confirmText => heardText ?? '';

  void _set(ListenPhase p) {
    if (_disposed) return;
    phase = p;
    notifyListeners();
  }

  bool _interrupted(int gen) {
    if (gen == voice.interrupts) return false;
    if (phase != ListenPhase.idle) _set(ListenPhase.idle);
    return true;
  }

  /// دوسة المايك — **سماع واحد**.
  Future<void> start() async {
    final listener = voice.listener;
    if (listener == null || _busy || startFailed) return;
    _busy = true;
    try {
      final wasSpeaking = voice.speaking;
      await voice.stop();
      final gen = voice.interrupts;
      if (!await listener.hasPermission()) {
        // مرة واحدة، قبل طلب النظام: «عشان أسمع حضرتك، محتاج إذن الميكروفون»
        await voice.speakLine('lis_mic_permission', force: true);
        if (_interrupted(gen)) return;
      }
      final failed = await listener.prepare();
      if (_interrupted(gen)) return;
      if (failed != null) {
        await _cantListen(failed);
        return;
      }
      await _listenOnce(listener, gen, settle: wasSpeaking);
    } finally {
      _busy = false;
    }
  }

  Future<void> _listenOnce(SpeechListener listener, int gen, {required bool settle}) async {
    heard = null;
    heardText = null;
    partial = '';
    // الجلسة للمايك — النفَس بس لو جملة كانت بتتقال لحظة الدوسة
    await voice.yieldToMic(settle: settle);
    if (_interrupted(gen)) return;
    sessions++;
    _set(ListenPhase.listening);
    final result = await listener.listen(onPartial: (t) {
      if (phase != ListenPhase.listening || _disposed) return;
      partial = t;
      notifyListeners();
    });
    if (_interrupted(gen) || phase != ListenPhase.listening) return; // دوسة كسبت
    final String? text;
    switch (result) {
      case ListenFailed(started: false) || ListenFailed(permission: true):
        return _cantListen(result);
      case ListenFailed():
        text = null;
      case ListenSilence():
        text = null;
      case ListenHeard(text: final t):
        text = t;
    }
    if (result is! ListenFailed) unawaited(clearListenProblem());
    final value = text == null ? null : parse(text);
    if (value == null) return _miss();
    _misses = 0;
    heard = value;
    heardText = describe(value);
    _set(ListenPhase.confirming);
    // المسجّلة — مش «فهمت: …» بصوت الموبايل. الزرارين قدّامه، ومفيش سماع.
    await voice.speakLine('lis_confirm', force: force);
  }

  Future<void> _cantListen(ListenFailed failed) async {
    if (failed.permission) {
      voice.markMicDenied();
      _set(ListenPhase.idle);
      await voice.speakLine('lis_mic_denied', force: true);
      return;
    }
    startFailed = true;
    _set(ListenPhase.unavailable);
    await _onStartFailure(failed.reason);
    await voice.speakLine('gen_try_hands', force: force);
  }

  Future<void> _miss() async {
    _misses++;
    missLine = _misses >= 2 ? 'gen_try_hands' : 'lis_not_understood';
    if (_misses >= 2) _misses = 0;
    _set(ListenPhase.notUnderstood);
    await voice.speakLine(missLine, force: force);
  }

  /// «أيوه» — **دوسة**، بتكسب على طول: الكلام والمايك بيقفوا وبيتطبّق.
  Future<void> confirmYes() async {
    final value = heard;
    if (value == null || phase != ListenPhase.confirming) return;
    heard = null;
    _set(ListenPhase.done);
    unawaited(voice.stop());
    if (autoApply) {
      await onApply(value);
    } else {
      confirmed = value;
    }
  }

  /// «لأ» — دوسة: الكلام يقف، ومفيش سماع لوحده. «اتكلم تاني» دوسة جديدة.
  Future<void> confirmNo() async {
    if (phase != ListenPhase.confirming) return;
    heard = null;
    _set(ListenPhase.declined);
    await voice.stop();
  }

  /// «اتكلم تاني» — دوسة جديدة = سماع جديد.
  Future<void> again() => start();

  /// بيطبّق اللي اتأكّد (بعد ما الورقة اتقفلت) — مرة واحدة.
  Future<void> applyConfirmed() async {
    final value = confirmed;
    if (value == null) return;
    confirmed = null;
    await onApply(value);
  }

  /// «اقفل» أو الورقة اتقفلت — المايك بيقف على طول.
  Future<void> cancel() async {
    heard = null;
    if (phase != ListenPhase.unavailable) _set(ListenPhase.idle);
    await voice.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(voice.listener?.stop());
    super.dispose();
  }
}
