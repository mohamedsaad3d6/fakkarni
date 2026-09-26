import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/diagnostics.dart';
import 'listen_session.dart';
import 'speech_listener.dart';
import 'stt_driver.dart';

/// متعرّف كلام الموبايل — **الملف الوحيد اللي بيستورد `speech_to_text`.**
///
/// كل قرار («الحدث ده بتاع مين؟ سكوت ولا عطل؟ نعيد عبر السيرفر؟») في
/// [ListenSession] — دارت نقية ومتختبرة. الملف ده بيوصّل أحداث الإضافة ليها
/// وبيكتب كل خطوة سطر `Listen:` (التجهيز، اللغة، على الجهاز ولا لأ، كل حالة،
/// كل كود عطل، والمدة) — بيبان في طرفية نسخة profile وفي «سجل التشخيص».
///
/// - اللغة: `ar_EG` لو الموبايل عنده، وإلا أي عربي، وإلا لغة النظام.
/// - **آيفون: من غير شرط «على الجهاز»** (`onDevice: false`). الإضافة لما
///   بنطلبه والعربي مش مدعوم على الجهاز بترجّع خطأ **وبتكمّل** تشغّل مهمة
///   بالشرط ده — حالة ملخبطة بتفضل للسماع اللي بعده. الصوت بيروح لأبل (مكتوب
///   في سياسة الخصوصية)، و`ar-SA` هي العربي اللي أبل عندها — قارئنا المصري
///   زي ما هو. أندرويد: على الجهاز الأول، وأي رفض قبل أول كلمة = إعادة عبر
///   سيرفر النظام. `lastOnDevice` بيقول اللي حصل.
/// - **وقعة في البداية = إعادة مرة بعد ٣٠٠ ملّي**، وبعدها «كمّل بإيدك»
///   ([ListenSession.startFailure]). والاستثناء بيتكتب **بحقوله** (message،
///   details، stackTrace) — كان بيتكتب «Instance of 'ListenFailedException'»
///   وده اللي خلّى رفض «على الجهاز» عمره ما يتعرف.
/// - **`cancelOnError: false`**: بـ`true` الإضافة بتلغي السماع **الشغّال** لما
///   عطل «دايم» من مهمة قديمة يوصل — ده جزء من «سامعك» وبعدها «مش قادر أساعد».
/// - **مفيش إلغاء في أول كل سماع إلا لو فيه حاجة شغّالة**، وبعد أي إلغاء بنستنى
///   الأحداث القديمة تخلص ([_settle]) قبل ما نبدأ.
class SpeechToTextListener implements SttDriver {
  @override
  String get name => 'device';

  @override
  bool get isSupported => true;

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  String? _localeId;
  bool _onDeviceRefused = false;
  bool? _lastOnDevice;
  Completer<ListenResult>? _pending;
  ListenSession? _session;
  Timer? _guard;
  int _attempt = 0;
  final _clock = Stopwatch()..start();
  int _startedAt = 0;
  bool _nativeMayRun = false;
  Duration _silence = ListenTimings.silence;
  void Function(String partial)? _onPartial;

  /// الأحداث القديمة بتاعة مهمة اتلغت بتوصل في الـrunloop اللي بعده —
  /// بنستناها تخلص قبل مهمة جديدة.
  static const _settle = Duration(milliseconds: 300);

  /// آيفون ما بنطلبش «على الجهاز» (شوف فوق).
  static bool get _preferOnDevice => !Platform.isIOS;

  /// الاستثناء بحقوله — مش «Instance of …».
  static String describe(Object e) => switch (e) {
        ListenFailedException() =>
          'ListenFailedException message=${e.message} details=${e.details} stack=${e.stackTrace}',
        PlatformException() => 'PlatformException(${e.code}) message=${e.message} details=${e.details}',
        _ => '$e',
      };

  @override
  bool? get lastOnDevice => _lastOnDevice;

  String get _tag => '#$_attempt +${_clock.elapsedMilliseconds - _startedAt}ms';

  @override
  Future<bool> hasPermission() async {
    try {
      return await _stt.hasPermission;
    } catch (e) {
      diag('Listen: قراية الإذن وقعت ($e)');
      return false;
    }
  }

  @override
  Future<ListenFailed?> prepare() async {
    if (_ready) return null;
    try {
      final ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
      diag('Listen: initialize=$ok');
      if (!ok) {
        // الإضافة بترجّع false للرفض وللموبايل اللي مفيهوش تعرّف — الإذن
        // هو اللي بيفرّق بينهم
        final permitted = await hasPermission();
        final why = _stt.lastError?.errorMsg ?? (permitted ? 'init_failed' : 'permission');
        diag('Listen: المتعرّف رفض يتجهّز ($why${permitted ? '' : ' — الإذن'})');
        return ListenFailed(why, permission: !permitted);
      }
      final locales = await _stt.locales();
      String norm(String id) => id.toLowerCase().replaceAll('-', '_');
      final ids = [for (final l in locales) l.localeId];
      _localeId = ids.cast<String?>().firstWhere((id) => norm(id!) == 'ar_eg',
          orElse: () => ids.cast<String?>().firstWhere((id) => norm(id!).startsWith('ar'), orElse: () => null));
      diag('Listen: جاهز — اللغة ${_localeId ?? 'لغة النظام'} (${ids.length} لغة، ar_EG ${ids.any((i) => norm(i) == 'ar_eg') ? 'موجودة' : 'مش موجودة'})');
      _ready = true;
      return null;
    } catch (e) {
      diag('Listen: التجهيز وقع ($e)');
      return ListenFailed('init: $e');
    }
  }

  @override
  Future<ListenResult> listen({
    Duration silence = ListenTimings.silence,
    Duration maxLength = ListenTimings.maxLength,
    Duration firstWordWithin = ListenTimings.firstWordWithin,
    void Function(String partial)? onPartial,
  }) async {
    if (!_ready) return const ListenFailed('not_ready');
    _onPartial = onPartial;
    await _endPrevious();
    final result = _pending = Completer<ListenResult>();
    _session = ListenSession(onDevice: _preferOnDevice && !_onDeviceRefused, serverRetried: _onDeviceRefused);
    _silence = silence;
    await _startAttempt(maxLength: maxLength, firstWordWithin: firstWordWithin);
    // حارس: لو المتعرّف ما رجّعش ولا حالة (بيحصل)، بنقفل بإيدنا
    _guard?.cancel();
    _guard = Timer(maxLength + const Duration(seconds: 3), () {
      diag('Listen: $_tag الحارس قفل — مفيش نهاية من المتعرّف');
      unawaited(_cancelNative());
      final s = _session;
      _finish(s != null && s.words.isNotEmpty ? ListenHeard(s.words) : const ListenSilence());
    });
    return result.future;
  }

  Future<void> _startAttempt({required Duration maxLength, required Duration firstWordWithin}) async {
    final session = _session!;
    _attempt++;
    _startedAt = _clock.elapsedMilliseconds;
    _lastOnDevice = session.onDevice;
    diag('Listen: $_tag بداية — onDevice=${session.onDevice} locale=${_localeId ?? 'النظام'} '
        'listenFor=${maxLength.inSeconds}s pauseFor=${firstWordWithin.inSeconds}s→${_silence.inSeconds}s');
    try {
      _nativeMayRun = true;
      await _stt.listen(
        onResult: (r) {
          final first = session.words.isEmpty && r.recognizedWords.isNotEmpty;
          session.heard(r.recognizedWords);
          if (r.recognizedWords.isNotEmpty) _onPartial?.call(r.recognizedWords);
          if (first) {
            // بدأ يتكلم: من هنا السكوت القصير بيقفل
            diag('Listen: $_tag أول كلام');
            try {
              _stt.changePauseFor(_silence);
            } catch (_) {}
          }
          if (r.finalResult) {
            diag('Listen: $_tag نتيجة نهائية');
            _finish(ListenHeard(session.words));
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          onDevice: session.onDevice,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
          // أول كلمة ليها وقتها — الإضافة بتعدّ السكوت من أول السماع
          pauseFor: firstWordWithin,
          listenFor: maxLength,
        ),
      );
    } catch (e) {
      final why = describe(e);
      diag('Listen: $_tag listen() رمت: $why');
      _apply(session.startFailure(why), maxLength: maxLength, firstWordWithin: firstWordWithin);
    }
  }

  void _apply(ListenDecision? d, {Duration maxLength = ListenTimings.maxLength, Duration firstWordWithin = ListenTimings.firstWordWithin}) {
    switch (d) {
      case null:
        return;
      case ListenFinish(:final result):
        diag('Listen: $_tag النهاية ← $result (${_clock.elapsedMilliseconds - _startedAt}ms)');
        if (result is ListenFailed && !result.started) _nativeMayRun = false;
        _finish(result);
      case ListenRetry(:final why, :final onDevice):
        if (!onDevice && (_session?.serverRetried ?? false)) _onDeviceRefused = true;
        diag('Listen: $_tag إعادة بعد ${ListenSession.retryAfter.inMilliseconds}ms '
            '(onDevice=$onDevice) — السبب: $why');
        unawaited(() async {
          await _cancelNative();
          await Future<void>.delayed(ListenSession.retryAfter);
          final s = _session;
          if (s == null || _pending == null || _pending!.isCompleted) return;
          s.restart(onDevice: onDevice);
          await _startAttempt(maxLength: maxLength, firstWordWithin: firstWordWithin);
        }());
    }
  }

  void _onError(SpeechRecognitionError e) {
    diag('Listen: $_tag عطل ${e.errorMsg} (${e.permanent ? 'دايم' : 'عابر'})');
    final s = _session;
    if (s == null || _pending == null) return;
    final d = s.error(e.errorMsg);
    if (d == null) diag('Listen: $_tag العطل ده اتساب (قديم أو إلغاء)');
    _apply(d);
  }

  void _onStatus(String status) {
    diag('Listen: $_tag حالة $status');
    final s = _session;
    if (s == null || _pending == null) return;
    _apply(s.status(status));
  }

  void _finish(ListenResult result) {
    _guard?.cancel();
    _guard = null;
    final p = _pending;
    if (p == null || p.isCompleted) return;
    _pending = null;
    _session = null;
    p.complete(result);
  }

  /// لو فيه سماع شغّال أو ممكن يكون: إلغاء، وبعدين نستنى أحداثه القديمة.
  Future<void> _endPrevious() async {
    _finish(const ListenSilence());
    if (!_nativeMayRun && !_stt.isListening) return;
    await _cancelNative();
    await Future<void>.delayed(_settle);
  }

  Future<void> _cancelNative() async {
    if (!_ready) return;
    try {
      await _stt.cancel();
    } catch (e) {
      diag('Listen: الإلغاء وقع ($e)');
    }
    _nativeMayRun = false;
  }

  @override
  Future<void> stop() async {
    _finish(const ListenSilence());
    if (_nativeMayRun || _stt.isListening) await _cancelNative();
  }
}
