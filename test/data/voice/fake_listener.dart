import 'dart:async';

import 'package:fakkarni/data/voice/speech_listener.dart';

/// متعرّف كلام مزيّف: بيرجّع الإجابات بالترتيب، وبيسجّل كل سماع.
///
/// الإجابة `String` = اتقال كلام، `null` = سكوت، و[ListenFailed] = **السماع
/// ما بدأش** — التالتة هي اللي الآيفون كان بيقلبها «مافهمتش».
class FakeListener implements SpeechListener {
  FakeListener({
    this.permission = true,
    this.prepareOk = true,
    this.prepareFailure,
    List<Object?> answers = const [],
  }) : answers = [...answers];

  bool permission;

  /// false = الإذن اترفض (زي قبل).
  bool prepareOk;

  /// عطل في التجهيز مش الإذن — المتعرّف ما اشتغلش.
  ListenFailed? prepareFailure;

  /// `String` كلام، `null` سكوت، [ListenFailed] السماع ما بدأش.
  final List<Object?> answers;
  int listens = 0;
  int stops = 0;
  int prepares = 0;
  bool prepared = false;

  /// السماع «بيفضل مفتوح» لحد ما `stop()` تتنده — زي مايك حقيقي مستني.
  bool hold = false;

  /// بيتنده لحظة ما السماع يبدأ — الاختبار بيشوف كان إيه حاصل ساعتها.
  void Function()? onListen;
  Completer<ListenResult>? _open;

  @override
  bool? lastOnDevice = true;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<ListenFailed?> prepare() async {
    prepares++;
    if (prepareFailure case final f?) return f;
    if (!prepareOk) return const ListenFailed('permission', permission: true);
    permission = true;
    prepared = true;
    return null;
  }

  static ListenResult _asResult(Object? a) => switch (a) {
        final ListenResult r => r,
        final String t => ListenHeard(t),
        _ => const ListenSilence(),
      };

  @override
  Future<ListenResult> listen({
    Duration silence = ListenTimings.silence,
    Duration maxLength = ListenTimings.maxLength,
    Duration firstWordWithin = ListenTimings.firstWordWithin,
    void Function(String partial)? onPartial,
  }) async {
    if (!prepared) throw StateError('listen قبل prepare');
    listens++;
    _partial = onPartial;
    onListen?.call();
    if (hold) {
      final c = _open = Completer<ListenResult>();
      return c.future;
    }
    final r = _asResult(answers.isEmpty ? null : answers.removeAt(0));
    if (r case ListenHeard(:final text)) onPartial?.call(text);
    return r;
  }

  void Function(String partial)? _partial;

  /// كلام اتسمع وهو لسه بيتكلم — زي المتعرّف الحقيقي.
  void partial(String text) => _partial?.call(text);

  /// المايك مفتوح دلوقتي (سماع مستني).
  bool get listening => _open != null;

  /// بيستنّى لحد ما سماع يتفتح — الدورة فيها كلام قبل كل سماع.
  Future<void> untilListening() async {
    for (var i = 0; i < 200 && !listening; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    if (!listening) throw StateError('مفيش سماع اتفتح');
  }

  /// بيقفل السماع المفتوح بإجابة (أو null = سكوت).
  void hear(String? text) {
    final c = _open;
    _open = null;
    if (c != null && !c.isCompleted) c.complete(_asResult(text));
  }

  @override
  Future<void> stop() async {
    stops++;
    hear(null);
  }
}
