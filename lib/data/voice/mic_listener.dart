import 'dart:async';

import '../../core/diagnostics.dart';
import 'speech_listener.dart';
import 'stt_driver.dart';

/// اللي الشاشات بتسمع بيه — فوق أي [SttDriver]. حاجتين من `webSpeechStt.js`:
///
/// - **ماكينة صارمة: السماع بيبدأ من الراحة بس.** دوستين ورا بعض (سباق) =
///   نفس السماع — [listen] بترجّع نفس الـFuture، ومفيش محرّك بيتفتح مرتين.
/// - **نهاية الكلام بتاعتنا** ([endOfSpeech] = ١٫٢ ثانية بعد آخر كلمة
///   اتسمعت)، مش سكوت المتعرّف: المتعرّف بيستنى ٣ ثواني وأكتر، وفي كلام ده
///   بيبان إن التطبيق هنج. سكوت المتعرّف فاضل **ورا** كشبكة أمان، وقبل أول
///   كلمة المتعرّف هو اللي بيستنى ([ListenTimings.firstWordWithin]).
///
/// و[stop] **بتكسب على طول**: السماع بيرجع [ListenSilence] في نفس اللحظة.
class MicListener implements SpeechListener {
  MicListener(this.driver, {this.endOfSpeech = defaultEndOfSpeech});

  static const defaultEndOfSpeech = Duration(milliseconds: 1200);

  final SttDriver driver;
  final Duration endOfSpeech;

  Completer<ListenResult>? _open;
  Timer? _eos;
  String _words = '';

  /// المايك مفتوح دلوقتي.
  bool get isListening => _open != null;

  @override
  bool? get lastOnDevice => driver.lastOnDevice;

  @override
  Future<bool> hasPermission() => driver.hasPermission();

  @override
  Future<ListenFailed?> prepare() => driver.prepare();

  @override
  Future<ListenResult> listen({
    Duration silence = ListenTimings.silence,
    Duration maxLength = ListenTimings.maxLength,
    Duration firstWordWithin = ListenTimings.firstWordWithin,
    void Function(String partial)? onPartial,
  }) {
    final open = _open;
    if (open != null) {
      // سماع شغّال — دوسة سابقت دوسة. **مش سماع تاني.**
      diag('Listen: سماع شغّال — الطلب التاني نفس السماع');
      return open.future;
    }
    final result = _open = Completer<ListenResult>();
    _words = '';
    unawaited(driver
        .listen(
          silence: silence,
          maxLength: maxLength,
          firstWordWithin: firstWordWithin,
          onPartial: (t) {
            if (!identical(_open, result) || t.trim().isEmpty) return;
            _words = t;
            onPartial?.call(t);
            _eos?.cancel();
            _eos = Timer(endOfSpeech, () {
              if (!identical(_open, result)) return;
              diag('Listen: نهاية الكلام — ${endOfSpeech.inMilliseconds}ms من غير كلمة جديدة');
              _complete(result, ListenHeard(_words));
              unawaited(driver.stop());
            });
          },
        )
        .then((r) => _complete(result, switch (r) {
              // المتعرّف قفل بسكوت أو وقع في النص، وإحنا سامعين كلام — الكلام يكسب
              ListenSilence() || ListenFailed(started: true) when _words.trim().isNotEmpty => ListenHeard(_words),
              _ => r,
            }))
        .catchError((Object e) => _complete(result, ListenFailed('driver: $e'))));
    return result.future;
  }

  void _complete(Completer<ListenResult> c, ListenResult r) {
    if (!identical(_open, c)) return;
    _eos?.cancel();
    _eos = null;
    _open = null;
    if (!c.isCompleted) c.complete(r);
  }

  /// بيقفل المايك **دلوقتي** — السماع بيرجع [ListenSilence] على طول.
  @override
  Future<void> stop() async {
    final open = _open;
    if (open != null) _complete(open, const ListenSilence());
    await driver.stop();
  }
}
