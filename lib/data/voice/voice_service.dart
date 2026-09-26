import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics.dart';
import '../../domain/voice/voice_catalog.dart';
import 'speech_listener.dart';

/// تشغيل تسجيل من الحزمة. `true` = اتقال لآخره، `false` = ما عرفش
/// (ملف ناقص، عطل في المشغّل) — ساعتها الخدمة بترجع لصوت الموبايل.
/// التنفيذ الحقيقي في `audio_voice_player.dart` (الملف الوحيد اللي بيستورد
/// `audioplayers`).
abstract interface class VoicePlayer {
  Future<bool> play(String assetPath, {required double volume});
  Future<void> stop();

  /// بيسيب المشغّل الأصلي خالص (مش بس يوقّف) — قبل المايك، عشان جلسة الصوت
  /// ما تفضلش ماسكها.
  Future<void> release();
}

/// صوت الموبايل (TTS) — عربي، ومصري لو موجود. التنفيذ في `device_tts.dart`
/// (الملف الوحيد اللي بيستورد `flutter_tts`).
abstract interface class VoiceTts {
  Future<void> speak(String text, {required double rate, required double volume});
  Future<void> stop();
}

/// جلسة الصوت: نوطّي اللي شغّال من تطبيقات تانية وإحنا بنتكلم، ونسيبه بعدها.
/// **ما بتلمسش نغمة الجرعة** — دي إشعار من النظام مش من المشغّل ده.
abstract interface class VoiceAudioFocus {
  Future<void> begin();
  Future<void> end();
}

/// السرعة — للـTTS بس (التسجيل بسرعته). **البطيء هو الافتراضي**: بنكلّم حد
/// كبير في السن.
enum VoiceSpeed {
  slow(0.38, 'بطيء'),
  normal(0.5, 'عادي'),
  fast(0.62, 'سريع');

  const VoiceSpeed(this.rate, this.label);
  final double rate;
  final String label;
}

enum VoiceVolume {
  low(0.5, 'واطي'),
  normal(0.8, 'عادي'),
  high(1.0, 'عالي');

  const VoiceVolume(this.level, this.label);
  final double level;
  final String label;
}

/// «الرفيق الصوتي» — المرحلة ١: **بيتكلم بس.** مفيش مايك، مفيش شبكة، مفيش
/// ذكاء. كل جملة من الكتالوج (تسجيل) أو قالب ملخص اليوم (صوت الموبايل).
///
/// **تنبيه الجرعة بيكسب دايماً**: [attachAlertSignal] بيوقّف أي كلام أول ما
/// إشعار جرعة يتداس أو شاشة التذكير تتفتح. الخدمة دي ما بتعرفش حاجة عن
/// الجدولة ولا الإشعارات — `voice_guard_test` بيقفل على ده.
class VoiceService extends ChangeNotifier {
  VoiceService({
    required this.player,
    required this.tts,
    this.focus,
    this.listener,
    Future<SharedPreferences> Function()? prefs,
    this.micSettle = Duration.zero,
  }) : _prefs = prefs ?? SharedPreferences.getInstance;

  /// بعد ما جملتنا تخلص وجلسة الصوت تتسلّم، قبل ما المايك يتفتح — المشغّل
  /// بيقفل ملفه في الخلفية، والمتعرّف محتاج الجلسة فاضية.
  /// (صفر في الاختبارات؛ `main` بيحط [defaultMicSettle].)
  final Duration micSettle;

  static const defaultMicSettle = Duration(milliseconds: 250);

  final VoicePlayer player;
  final VoiceTts tts;
  final VoiceAudioFocus? focus;

  /// «بيسمع» (المرحلة ٢) — null = مفيش مايك في النسخة دي (ولا زرار).
  final SpeechListener? listener;
  final Future<SharedPreferences> Function() _prefs;

  static const enabledKey = 'voice.enabled';
  static const speedKey = 'voice.speed';
  static const volumeKey = 'voice.volume';
  static const introDoneKey = 'voice.introDone';
  static const briefingDayKey = 'voice.briefingDay';
  static const listenIntroDoneKey = 'voice.listenIntroDone';
  static const cmdHintDoneKey = 'voice.cmdHintDone';

  bool _enabled = false;
  VoiceSpeed _speed = VoiceSpeed.slow;
  VoiceVolume _volume = VoiceVolume.normal;
  bool _introDone = false;
  String? _briefingDay;
  bool _listenIntroDone = false;
  bool _cmdHintDone = false;
  bool _micDenied = false;
  int _interrupts = 0;

  /// آخر جملة في الطابور — null لما يخلص. **مش `Future.value()` جاهزة**: الـ
  ///`Future` بيتعمل في منطقة (zone) اللي بينده، وواحدة اتعملت قبل الاختبار
  /// (في `setUp`) `.then` بتاعها ما بيتشغّلش جوّه المنطقة المزيّفة أبداً.
  Future<void>? _queue;

  bool get enabled => _enabled;
  VoiceSpeed get speed => _speed;
  VoiceVolume get volume => _volume;

  /// المقدمة اتعرضت (أو اتخطّت) مرة — ما بتترجعش غير من الإعدادات.
  bool get introDone => _introDone;

  /// اللي بيتقال دلوقتي — الشاشة بتكتبه (ترجمة مكتوبة لكل جملة).
  final ValueNotifier<String?> caption = ValueNotifier<String?>(null);

  /// عدد الشاشات اللي **كاتبة الجملة بنفسها** دلوقتي (ورقة «اتكلم» و«كلّمني»).
  /// طول ما هو أكبر من صفر الترجمة المكتوبة تحت ما بتظهرش — وإلا نفس الجملة
  /// بتتكتب مرتين: في الورقة وفي الكارت اللي تحتها (آيفون، ٢٦ سبتمبر ٢٠٢٦).
  final ValueNotifier<int> captionHolds = ValueNotifier<int>(0);

  void holdCaption() => captionHolds.value++;

  void releaseCaption() {
    if (captionHolds.value > 0) captionHolds.value--;
  }

  bool get speaking => caption.value != null;

  /// «دلوقتي تقدر تكلّمني…» اتقالت مرة (أول ما زرار المايك ظهر).
  bool get listenIntroDone => _listenIntroDone;

  /// رفض إذن المايك في الجلسة دي — الزرار بيختفي وكل حاجة بالإيد.
  bool get micDenied => _micDenied;

  /// بيزيد مع كل [stop] من برّه (تنبيه جرعة، شاشة اتقفلت، لمسة) — اللي
  /// بيسمع بيقارنه قبل وبعد كل خطوة، ولو اتغيّر بيسكت من غير ما يكمّل.
  int get interrupts => _interrupts;

  int _generation = 0;
  ValueListenable<String?>? _alert;

  Future<void> load() async {
    try {
      final p = await _prefs();
      _enabled = p.getBool(enabledKey) ?? false;
      _speed = VoiceSpeed.values.asNameMap()[p.getString(speedKey)] ?? VoiceSpeed.slow;
      _volume = VoiceVolume.values.asNameMap()[p.getString(volumeKey)] ?? VoiceVolume.normal;
      _introDone = p.getBool(introDoneKey) ?? false;
      _briefingDay = p.getString(briefingDayKey);
      _listenIntroDone = p.getBool(listenIntroDoneKey) ?? false;
      _cmdHintDone = p.getBool(cmdHintDoneKey) ?? false;
    } catch (e) {
      diag('Voice: قراية الإعدادات وقعت ($e)');
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    if (!on) await stop();
    notifyListeners();
    await _put((p) => p.setBool(enabledKey, on));
  }

  Future<void> setSpeed(VoiceSpeed s) async {
    _speed = s;
    notifyListeners();
    await _put((p) => p.setString(speedKey, s.name));
  }

  Future<void> setVolume(VoiceVolume v) async {
    _volume = v;
    notifyListeners();
    await _put((p) => p.setString(volumeKey, v.name));
  }

  Future<void> markIntroDone() async {
    _introDone = true;
    notifyListeners();
    await _put((p) => p.setBool(introDoneKey, true));
  }

  /// «تقدر تقولّي مثلاً…» اتقالت مرة (أول دوسة على «كلّمني»).
  bool get cmdHintDone => _cmdHintDone;

  Future<void> markCmdHintDone() async {
    _cmdHintDone = true;
    await _put((p) => p.setBool(cmdHintDoneKey, true));
  }

  Future<void> markListenIntroDone() async {
    _listenIntroDone = true;
    await _put((p) => p.setBool(listenIntroDoneKey, true));
  }

  void markMicDenied() {
    _micDenied = true;
    notifyListeners();
  }

  /// ملخص اليوم مرة واحدة لكل يوم روتين — [dayKey] هو اليوم بصيغة ثابتة.
  bool shouldBrief(String dayKey) => _enabled && _briefingDay != dayKey;

  Future<void> markBriefed(String dayKey) async {
    _briefingDay = dayKey;
    await _put((p) => p.setString(briefingDayKey, dayKey));
  }

  /// جملة من الكتالوج: التسجيل الأول، ولو ناقص أو وقع → صوت الموبايل بنفس
  /// النص. بترجع لما الكلام يخلص أو يتقطع. [force] للمقدمة (قبل ما يجاوب
  /// «تحب أكلّمك؟») ولإعادتها من الإعدادات — غير كده الصوت المقفول صامت.
  /// بترجّع `true` لو الجملة اتقالت لآخرها من غير ما حاجة تقطعها.
  Future<bool> speakLine(String id, {bool force = false}) async {
    if (!_enabled && !force) return false;
    final text = voiceLine(id);
    final gen = await _begin(text);
    try {
      var ok = false;
      try {
        ok = await player.play(voiceAssetPath(id), volume: _volume.level);
      } catch (e) {
        diag('Voice: التسجيل $id وقع ($e) — صوت الموبايل بداله');
      }
      if (gen != _generation) return false;
      if (!ok) await _tts(text);
      return gen == _generation;
    } finally {
      await _end(gen);
    }
  }

  /// كذا جملة ورا بعض (المقدمة). بتقف أول ما حاجة توقّفها.
  Future<void> speakLines(List<String> ids, {bool force = false}) async {
    for (final id in ids) {
      // اتقطعت في النص = الباقي ما يتقالش. (كانت بتقارن بـ«الجيل + ١»،
      // و`_begin` بيزوّده مرتين — فكانت بتقف بعد أول جملة دايماً.)
      if (!await speakLine(id, force: force)) return;
    }
  }

  /// جمل بتستنّى دورها: بعد اللي بيتقال دلوقتي وبعد أي حاجة اتحطّت قبلها
  /// (جملة الصفحة في البداية، وبعدها «دلوقتي تقدر تكلّمني»). [stop] من
  /// برّه بيلغي اللي لسه ما بدأش.
  Future<void> speakQueued(List<String> ids, {bool force = false}) {
    final gen = _interrupts;
    Future<void> run() async {
      if (gen != _interrupts) return;
      await _quiet();
      if (gen != _interrupts) return;
      await speakLines(ids, force: force);
    }

    final prev = _queue;
    late final Future<void> mine;
    mine = (prev == null ? run() : prev.then((_) => run())).whenComplete(() {
      if (identical(_queue, mine)) _queue = null;
    });
    return _queue = mine;
  }

  Future<void> _quiet() {
    if (!speaking) return Future.value();
    final done = Completer<void>();
    void listen() {
      if (caption.value == null && !done.isCompleted) {
        caption.removeListener(listen);
        done.complete();
      }
    }

    caption.addListener(listen);
    return done.future;
  }

  /// نص حر (ملخص اليوم) — **صوت الموبايل بس**، مفيش تسجيل ليه.
  Future<void> speakText(String text, {bool force = false}) async {
    if (!_enabled && !force) return;
    final gen = await _begin(text);
    try {
      await _tts(text);
    } finally {
      await _end(gen);
    }
  }

  /// بيوقّف كل حاجة فوراً — تسجيل وصوت موبايل **والسماع** — ويشيل الترجمة.
  /// ده الباب اللي تنبيه الجرعة والشاشات بيدخلوا منه؛ الكلام اللي الخدمة
  /// نفسها بتبدأه بيوقّف اللي قبله من [_stopSpeaking] من غير ما يعدّ مقاطعة.
  Future<void> stop() async {
    _interrupts++;
    await Future.wait([
      _stopSpeaking(),
      if (listener case final l?) l.stop().catchError((Object e) => diag('Voice: وقف السماع ($e)')),
    ]);
  }

  /// **قبل ما المايك يتفتح**: التسجيل وصوت الموبايل بيقفوا وجلسة الصوت
  /// بتتسلّم — عشان متعرّف الكلام ياخد الجلسة (تسجيل) من غير ما يزاحم جملة
  /// لسه شغّالة (زي `onb_name`). مش مقاطعة: اللي بيسمع ما بيتلغيش.
  ///
  /// **الترتيب** (لوج الجهاز، ٢٦ سبتمبر ٢٠٢٦: `error_listen_failed` = تجهيز
  /// جلسة الصوت أو محرّكه رمى، وقبله على طول تحذير من `audioplayers`): جملتنا
  /// خلصت (اللي بينده استناها) ← المشغّل والـTTS بيقفوا ← **المشغّل بيتساب**
  /// ← الجلسة بتتسلّم ← نفَس ← المتعرّف ياخد الجلسة (`playAndRecord`). وبعد
  /// السماع، أول جملة بتعيد ضبط الجلسة للتشغيل ([VoiceAudioFocus.begin]).
  ///
  /// [settle]: النفَس بعد التسليم — **بس لو كان فيه حاجة بتتقال** لحظة
  /// الدوسة. من غيرها المايك بيتفتح على طول (الكلمة الأولى كانت بتضيع في
  /// الـ٢٥٠ ملّي دي: «محمد سعد» ← «سعد»).
  Future<void> yieldToMic({bool settle = true}) async {
    await _stopSpeaking();
    try {
      await player.release();
    } catch (e) {
      diag('Voice: سيب المشغّل وقع ($e)');
    }
    diag('Listen: الجلسة اتسلّمت للمايك (المشغّل اتساب، الـTTS وقف)');
    if (settle && micSettle > Duration.zero) await Future<void>.delayed(micSettle);
  }

  Future<void> _stopSpeaking() async {
    _generation++;
    caption.value = null;
    await Future.wait([
      player.stop().catchError((Object e) => diag('Voice: وقف التسجيل ($e)')),
      tts.stop().catchError((Object e) => diag('Voice: وقف الصوت ($e)')),
    ]);
    await _release();
  }

  /// **تنبيه الجرعة بيكسب.** أي قيمة جديدة على الإشارة دي (دوسة على إشعار
  /// جرعة) بتوقّف الكلام في لحظتها.
  void attachAlertSignal(ValueListenable<String?> signal) {
    _alert?.removeListener(_onAlert);
    _alert = signal..addListener(_onAlert);
  }

  void _onAlert() {
    if (_alert?.value != null) unawaited(stop());
  }

  Future<int> _begin(String text) async {
    await _stopSpeaking();
    final gen = ++_generation;
    caption.value = text;
    try {
      await focus?.begin();
    } catch (e) {
      diag('Voice: جلسة الصوت ($e)');
    }
    return gen;
  }

  Future<void> _tts(String text) async {
    try {
      await tts.speak(text, rate: _speed.rate, volume: _volume.level);
    } catch (e) {
      diag('Voice: صوت الموبايل وقع ($e)');
    }
  }

  Future<void> _end(int gen) async {
    if (gen != _generation) return;
    caption.value = null;
    await _release();
  }

  Future<void> _release() async {
    try {
      await focus?.end();
    } catch (e) {
      diag('Voice: تسليم جلسة الصوت ($e)');
    }
  }

  Future<void> _put(Future<void> Function(SharedPreferences p) write) async {
    try {
      await write(await _prefs());
    } catch (e) {
      diag('Voice: حفظ الإعدادات وقع ($e)');
    }
  }

  @override
  void dispose() {
    _alert?.removeListener(_onAlert);
    caption.dispose();
    captionHolds.dispose();
    super.dispose();
  }
}
