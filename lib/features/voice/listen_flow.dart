import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/voice/listen_health.dart';
import '../../data/voice/speech_listener.dart';
import '../../data/voice/voice_service.dart';
import '../../domain/voice/answer_parser.dart';
import '../../domain/voice/mic_state.dart';

/// مراحل السماع — الشاشة بترسمها، والاختبار بيقراها.
enum ListenPhase {
  idle,

  /// المايك مفتوح: مايك بينبض، «سامعك…»، والكلام بيتكتب وهو بيتقال
  /// ([ListenFlow.partial]).
  listening,

  /// السماع خلص وبنفهم — «بفكّر…».
  thinking,

  /// الكلام اللي اتفهم مكتوب كبير، و«صح كده؟» **المسجّلة** — «أيوه»/«لأ»
  /// بالإيد، أو دوسة المايك وقولها ([ListenFlow.tapMic]).
  confirming,

  /// «معلش، مافهمتش» — المايك اشتغل وما سمعش حاجة مفهومة. «اتكلم تاني»
  /// دوسة جديدة؛ التانية ورا بعض «كمّل بإيدك» ([ListenFlow.missLine]).
  notUnderstood,

  /// «لأ» — مستني دوسة «اتكلم تاني» أو «اقفل». **مفيش سماع لوحده.**
  declined,

  /// المايك اتقفل على الشاشة دي: الإذن، أو المتعرّف مش موجود، أو القاطع
  /// اشتغل (٥ وقعات في ١٠ ثواني). «اكتب أو دوس بدل الصوت».
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
/// - **التأكيد**: الكلام اللي اتفهم مكتوب كبير و«صح كده؟» المسجّلة
///   (`lis_confirm`) — مفيش «فهمت: …» بصوت الموبايل، و**ولا سماع لوحده**:
///   «أيوه»/«لأ» بالإيد، أو دوسة المايك وقولها.
/// - **أي دوسة بتوقّف المايك على طول وبتتطبّق** ([confirmYes] / [confirmNo] /
///   [cancel])، و**ولا سماع بيبدأ لوحده بعدها** — كل سماع دوسة.
/// - سكوت ← راحة بسطر مكتوب؛ كلام مش مفهوم ← «مافهمتش»، والتانية ورا بعض
///   «كمّل بإيدك»؛ الإذن أو القاطع ← المايك يتقفل على الشاشة دي.
///
/// **ماكينة `MicOrb` بتاعة jarvis-ai-finance** ([mic]): idle ← listening ←
/// thinking ← confirming/speaking ← idle. السماع بيبدأ من الراحة بس، ودوسة
/// المايك والموبايل بيتكلم بتقطعه وبتفتح المايك في نفس الدوسة ([tapMic]).
/// «مفيش كلام» مش عطل (راحة، والمايك فاضل)؛ ٥ وقعات في ١٠ ثواني = المايك
/// يتقفل على الشاشة دي ([MicBreaker]). و«أيوه»/«لأ» بالصوت بتتفهم بـ
/// [classifyReply] (بورت `affirm.js`): الرفض الأول، ومش واضح = نسأل تاني.
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
    MicBreaker? breaker,
  })  : _onStartFailure = onStartFailure ?? recordListenProblem,
        breaker = breaker ?? MicBreaker();

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

  /// ٥ وقعات في ١٠ ثواني ← المايك يتقفل على الشاشة دي.
  final MicBreaker breaker;

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

  /// سطر هادي تحت المايك وهو مرتاح («ما سمعتش حاجة — …») — **مكتوب**، ما
  /// بيتقالش: السكوت مش عطل.
  String? note;

  /// المايك مفتوح عشان «أيوه» / «لأ» على اللي اتفهم.
  bool _reply = false;

  bool get available =>
      voice.listener != null && !voice.micDenied && !startFailed && (voice.enabled || force);

  String get confirmText => heardText ?? '';

  /// حالة المايك — الكلمة اللي تحت الدايرة ([micStateLabel]).
  MicState get mic => switch (phase) {
        ListenPhase.unavailable => MicState.off,
        ListenPhase.listening => MicState.listening,
        ListenPhase.thinking => MicState.thinking,
        _ when voice.speaking => MicState.speaking,
        ListenPhase.confirming => MicState.confirming,
        _ => (voice.micDenied ? MicState.off : MicState.idle),
      };

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
      _reply = false;
      note = null;
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
    final text = await _hear(listener, gen);
    if (text == null) return;
    final value = parse(text);
    if (value == null) return _miss();
    _misses = 0;
    heard = value;
    heardText = describe(value);
    _set(ListenPhase.confirming);
    // المسجّلة — مش «فهمت: …» بصوت الموبايل. الزرارين قدّامه، ومفيش سماع.
    await voice.speakLine('lis_confirm', force: force);
  }

  /// سماع واحد. الكلام اللي اتقال، أو null لو السماع خلص من غير كلام (والحالة
  /// اتظبطت: راحة بسطر، أو وقعة، أو دوسة كسبت).
  Future<String?> _hear(SpeechListener listener, int gen) async {
    sessions++;
    _set(ListenPhase.listening);
    final result = await listener.listen(onPartial: (t) {
      if (phase != ListenPhase.listening || _disposed) return;
      partial = t;
      notifyListeners();
    });
    // المايك اتقفل: من هنا الدوسة الجاية مسموحة — **حتى والموبايل لسه بيقول
    // الرد أو «صح كده؟»**. من غير ده الدوسة وقت الكلام كانت بتتبلع، والمقاطعة
    // ما بتحصلش.
    _busy = false;
    if (_interrupted(gen) || phase != ListenPhase.listening) return null; // دوسة كسبت
    final String text;
    switch (result) {
      case ListenFailed(permission: true):
        await _cantListen(result);
        return null;
      case ListenFailed():
        await _stumble(result);
        return null;
      case ListenSilence() when partial.trim().isEmpty:
        // **مفيش كلام مش عطل**: راحة، والمايك فاضل — ولا جملة بتتقال
        note = 'ما سمعتش حاجة — دوس واتكلم.';
        _set(_reply ? ListenPhase.confirming : ListenPhase.idle);
        return null;
      case ListenSilence():
        // دوسة «خلصت» وهو بيتكلم — اللي اتسمع هو الإجابة
        text = partial;
      case ListenHeard(text: final t):
        text = t;
    }
    unawaited(clearListenProblem());
    _set(ListenPhase.thinking);
    return text;
  }

  /// المايك وقع. مش «مافهمتش» — ولا بيتقفل من أول مرة: ٥ في ١٠ ثواني بس.
  Future<void> _stumble(ListenFailed failed) async {
    if (!failed.started) unawaited(_onStartFailure(failed.reason));
    if (breaker.fail()) return _cantListen(failed);
    note = 'معلش — دوس واتكلم تاني.';
    _set(_reply ? ListenPhase.confirming : ListenPhase.idle);
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

  /// **دوسة الدايرة** — نفس `onPress` بتاع `MicOrb`:
  /// - الموبايل بيتكلم ← يسكت **ويفتح المايك في نفس الدوسة** (مقاطعة).
  /// - المايك مفتوح ← «خلصت»: يقفل، واللي اتسمع هو الإجابة.
  /// - مستنيين «أيوه»/«لأ» ← سماع واحد للرد.
  /// - غير كده ← سماع جديد. «بفكّر…» والمقفول ما بيعملوش حاجة.
  Future<void> tapMic() async {
    switch (phase) {
      case ListenPhase.unavailable || ListenPhase.thinking || ListenPhase.done:
        return;
      case ListenPhase.listening:
        await voice.listener?.stop();
      case ListenPhase.confirming:
        await _listenReply();
      case ListenPhase.idle || ListenPhase.notUnderstood || ListenPhase.declined:
        await start();
    }
  }

  /// «أيوه» / «لأ» بالصوت — [classifyReply]: الرفض الأول، ومش واضح = «صح
  /// كده؟» تاني. **عمره ما يأكّد لوحده من غير كلمة واضحة.**
  Future<void> _listenReply() async {
    final listener = voice.listener;
    if (listener == null || _busy || heard == null) return;
    _busy = true;
    try {
      final wasSpeaking = voice.speaking;
      await voice.stop();
      final gen = voice.interrupts;
      _reply = true;
      note = null;
      partial = '';
      await voice.yieldToMic(settle: wasSpeaking);
      if (_interrupted(gen)) return;
      final text = await _hear(listener, gen);
      if (text == null) return;
      _set(ListenPhase.confirming);
      switch (classifyReply(text)) {
        case ReplyClass.affirm:
          _reply = false;
          await confirmYes();
        case ReplyClass.deny:
          _reply = false;
          await confirmNo();
        case ReplyClass.unclear:
          note = 'قول «أيوه» أو «لأ» — أو دوس.';
          notifyListeners();
          await voice.speakLine('lis_confirm', force: force);
      }
    } finally {
      _busy = false;
    }
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
