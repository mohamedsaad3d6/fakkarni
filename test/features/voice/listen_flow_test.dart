// «اتكلم» — سماع واحد لكل دوسة، والدوسة دايماً بتكسب (آيفون، ٢٦ سبتمبر ٢٠٢٦):
// المايك كان بيتفتح بعد جملة فالكلمة الأولى بتضيع، وجلسات بتبدأ وتموت في
// أقل من ثانية لأن السماع والأزرار بيتخانقوا، و«فهمت: …» بصوت الموبايل آلي.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/data/voice/speech_listener.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/voice/answer_parser.dart';
import 'package:fakkarni/domain/voice/mic_state.dart';
import 'package:fakkarni/features/voice/listen_flow.dart';

import '../../data/voice/fake_listener.dart';
import '../../data/voice/voice_service_test.dart' show FakePlayer, FakeTts;

void main() {
  late FakePlayer player;
  late FakeTts tts;
  late FakeListener listener;
  late VoiceService voice;
  late List<SpokenTime> applied;
  late List<String> startFailures;

  Future<void> setUpWith({
    bool permission = true,
    bool prepareOk = true,
    ListenFailed? prepareFailure,
    List<Object?> answers = const [],
    bool enabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: enabled});
    player = FakePlayer();
    tts = FakeTts();
    startFailures = [];
    listener = FakeListener(permission: permission, prepareOk: prepareOk, prepareFailure: prepareFailure, answers: answers);
    voice = VoiceService(player: player, tts: tts, listener: listener);
    await voice.load();
    applied = [];
  }

  List<String> said() => [for (final p in player.played) p.split('/').last.replaceAll('.mp3', '')];

  ListenFlow<SpokenTime> flow({bool force = false}) => ListenFlow<SpokenTime>(
        voice: voice,
        parse: (h) => parseTime(h, hint: DayPartHint.morning),
        describe: (t) => 'الساعة ${t.hour}:${t.minute}',
        onApply: (t) async => applied.add(t),
        force: force,
        onStartFailure: (why) async => startFailures.add(why),
      );

  Future<void> flush() async {
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // ── الدوسة ← المايك على طول ─────────────────────────────────────────

  test('الدوسة بتفتح المايك على طول — ولا جملة قبله', () async {
    await setUpWith(answers: ['تمانية ونص']);
    List<String>? saidBeforeListen;
    listener.onListen = () => saidBeforeListen ??= said();
    await flow().start();
    expect(saidBeforeListen, isEmpty, reason: 'الكلمة الأولى كانت بتضيع ورا «اتكلم، أنا سامعك»');
    expect(said(), isNot(contains('lis_listening')));
  });

  test('الكلام بيتكتب وهو بيتقال', () async {
    await setUpWith();
    listener.hold = true;
    final f = flow();
    final run = f.start();
    await listener.untilListening();
    expect(f.phase, ListenPhase.listening);
    listener.partial('تمانية');
    expect(f.partial, 'تمانية');
    listener.hear('تمانية ونص');
    await run;
    expect(f.phase, ListenPhase.confirming);
  });

  // ── التأكيد: مكتوب كبير + «صح كده؟» المسجّلة، وبالإيد بس ──────────────

  test('اتفهم ← الكلام كبير و«صح كده؟» المسجّلة — مفيش «فهمت:» بصوت الموبايل، ومفيش سماع تاني', () async {
    await setUpWith(answers: ['تمانية ونص', 'أيوه']);
    final f = flow();
    await f.start();
    expect(f.phase, ListenPhase.confirming);
    expect(f.confirmText, 'الساعة 8:30');
    expect(said(), ['lis_confirm']);
    expect(tts.spoken, isEmpty, reason: 'صوت الموبايل كان آلي');
    expect(listener.listens, 1, reason: '«أيوه» بالإيد — مفيش سماع لوحده بعد السماع');
    expect(applied, isEmpty, reason: 'مفيش تطبيق من غير دوسة «أيوه»');
    await f.confirmYes();
    expect(applied, [const SpokenTime(8, 30)]);
    expect(f.phase, ListenPhase.done);
  });

  test('«أيوه» بتكسب على طول — حتى و«صح كده؟» لسه بتتقال', () async {
    await setUpWith(answers: ['تمانية ونص']);
    final f = flow();
    player.holdPlayback = true;
    final run = f.start();
    await flush();
    expect(f.phase, ListenPhase.confirming);
    expect(voice.speaking, isTrue, reason: '«صح كده؟» شغّالة');
    await f.confirmYes();
    expect(applied, [const SpokenTime(8, 30)], reason: 'اتطبّقت من غير ما تستنى الجملة');
    await flush();
    expect(voice.speaking, isFalse, reason: 'الجملة اتقطعت');
    await run;
  });

  test('«لأ» ← ولا تطبيق ولا سماع لوحده؛ «اتكلم تاني» دوسة جديدة = سماع جديد', () async {
    await setUpWith(answers: ['تمانية ونص', 'تسعة']);
    final f = flow();
    await f.start();
    await f.confirmNo();
    expect(f.phase, ListenPhase.declined);
    await flush();
    expect(listener.listens, 1, reason: 'مفيش سماع بيبدأ لوحده بعد دوسة');
    expect(applied, isEmpty);
    await f.again();
    expect(listener.listens, 2);
    expect(f.confirmText, 'الساعة 9:0');
  });

  // ── الدوسة بتكسب على السماع ─────────────────────────────────────────

  test('«اقفل» وهو بيسمع ← المايك يقف على طول، والكلام اللي ييجي بعدها بيتساب', () async {
    await setUpWith();
    listener.hold = true;
    final f = flow();
    final run = f.start();
    await listener.untilListening();
    await f.cancel();
    expect(listener.stops, greaterThanOrEqualTo(1), reason: 'المايك اتقفل');
    expect(f.phase, ListenPhase.idle);
    await run;
    expect(f.phase, ListenPhase.idle, reason: 'نتيجة السماع المقفول ما بتكسبش الدوسة');
    expect(said(), isNot(contains('lis_not_understood')));
    expect(applied, isEmpty);
  });

  test('تنبيه الجرعة بيكسب: stop() وإحنا بنسمع ← idle في صمت', () async {
    await setUpWith();
    listener.hold = true;
    final f = flow();
    final run = f.start();
    await listener.untilListening();
    await voice.stop();
    await run;
    expect(f.phase, ListenPhase.idle);
    expect(said(), isEmpty);
  });

  // ── مفيش لفّ لوحده ──────────────────────────────────────────────────

  test('سكوت = راحة مش عطل: ولا جملة، والمايك فاضل، ومفيش سماع لوحده', () async {
    await setUpWith(answers: [const ListenSilence(), const ListenSilence()]);
    final f = flow();
    await f.start();
    expect(f.phase, ListenPhase.idle);
    expect(f.mic, MicState.idle);
    expect(f.note, isNotNull, reason: 'سطر مكتوب هادي');
    expect(said(), isEmpty, reason: 'السكوت ما بيتقالش عليه «مافهمتش»');
    await flush();
    expect(listener.listens, 1, reason: 'سماع واحد لكل دوسة');
    await f.tapMic();
    expect(listener.listens, 2);
    expect(said(), isEmpty);
    expect(f.available, isTrue);
    expect(startFailures, isEmpty);
  });

  test('كلام مش مفهوم ← «مافهمتش»، والتانية ورا بعض «كمّل بإيدك» — نسأل تاني، مش بنقفل', () async {
    await setUpWith(answers: ['الجو حر', 'برضه مش ساعة']);
    final f = flow();
    await f.start();
    expect(said().last, 'lis_not_understood');
    expect(f.phase, ListenPhase.notUnderstood);
    await f.tapMic();
    expect(said().last, 'gen_try_hands');
    expect(f.available, isTrue);
  });

  test('عطل بعد ما السماع بدأ = تعثّرة هادية — مش «مافهمتش» ومش إخفا', () async {
    await setUpWith(answers: [const ListenFailed('error_audio', started: true)]);
    final f = flow();
    await f.start();
    expect(said(), isEmpty);
    expect(f.phase, ListenPhase.idle);
    expect(f.note, isNotNull);
    expect(f.available, isTrue);
    expect(startFailures, isEmpty, reason: 'بدأ — مش عطل مايك للأدمن');
  });

  // ── المايك ما اشتغلش ────────────────────────────────────────────────

  test('التجهيز وقع (مش الإذن) ← «كمّل بإيدك» مرة، الزرار يختفي، والسبب للسجل والأدمن', () async {
    await setUpWith(prepareFailure: const ListenFailed('init: no recognizer'));
    final f = flow();
    await f.start();
    expect(said(), ['gen_try_hands']);
    expect(f.phase, ListenPhase.unavailable);
    expect(f.available, isFalse);
    expect(startFailures, ['init: no recognizer']);
    await f.start();
    expect(said(), ['gen_try_hands'], reason: 'مرة واحدة');
    expect(listener.listens, 0);
  });

  test('السماع ما بدأش مرة ← المايك فاضل (القاطع مش أول وقعة)، والسبب للأدمن', () async {
    await setUpWith(answers: [const ListenFailed('error_listen_failed')]);
    final f = flow();
    await f.start();
    expect(said(), isEmpty);
    expect(f.phase, ListenPhase.idle);
    expect(f.available, isTrue);
    expect(startFailures, ['error_listen_failed']);
  });

  test('القاطع: ٥ وقعات في ١٠ ثواني ← المايك يتقفل على الشاشة دي، «اكتب أو دوس بدل الصوت»', () async {
    await setUpWith(answers: List.filled(6, const ListenFailed('error_listen_failed')));
    final now = DateTime(2026, 9, 26, 10);
    final f = ListenFlow<SpokenTime>(
      voice: voice,
      parse: (h) => parseTime(h, hint: DayPartHint.morning),
      describe: (t) => '',
      onApply: (t) async {},
      onStartFailure: (why) async => startFailures.add(why),
      breaker: MicBreaker(clock: () => now),
    );
    for (var i = 0; i < 4; i++) {
      await f.tapMic();
      expect(f.available, isTrue, reason: 'وقعة ${i + 1} — لسه');
    }
    await f.tapMic();
    expect(f.phase, ListenPhase.unavailable);
    expect(f.mic, MicState.off);
    expect(micStateLabel(f.mic), 'اكتب أو دوس بدل الصوت');
    expect(f.available, isFalse);
    await f.tapMic();
    expect(listener.listens, 5, reason: 'المقفول ما بيفتحش مايك');
  });

  test('الإذن: «محتاج إذن الميكروفون» قبل طلب النظام، والرفض بيخفي الزرار', () async {
    await setUpWith(permission: false, prepareOk: false);
    final f = flow();
    await f.start();
    expect(said(), ['lis_mic_permission', 'lis_mic_denied']);
    expect(voice.micDenied, isTrue);
    expect(f.available, isFalse);
  });

  test('الصوت مقفول = مفيش زرار؛ من غير مايك = مفيش زرار', () async {
    await setUpWith(enabled: false);
    expect(flow().available, isFalse);
    expect(flow(force: true).available, isTrue);
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true});
    final noMic = VoiceService(player: FakePlayer(), tts: FakeTts());
    await noMic.load();
    final f = ListenFlow<SpokenTime>(
      voice: noMic,
      parse: (h) => parseTime(h),
      describe: (t) => '',
      onApply: (_) async {},
    );
    expect(f.available, isFalse);
  });

  // ── الجلسة للمايك ───────────────────────────────────────────────────

  test('جملة كانت بتتقال لحظة الدوسة ← بتقف، والمشغّل بيتساب، وبعدين المايك', () async {
    await setUpWith(answers: ['تمانية']);
    player.holdPlayback = true;
    final speaking = voice.speakLine('help_today');
    await flush();
    expect(voice.speaking, isTrue);
    var releasesAtListen = -1;
    listener.onListen = () => releasesAtListen = releasesAtListen == -1 ? player.releases : releasesAtListen;
    player.holdPlayback = false;
    await flow().start();
    await speaking;
    expect(releasesAtListen, greaterThanOrEqualTo(1));
  });

  test('من غير حاجة بتتقال: مفيش نفَس — المايك على طول حتى لو micSettle كبير', () async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true});
    final v = VoiceService(player: FakePlayer(), tts: FakeTts(), micSettle: const Duration(hours: 1));
    await v.load();
    await v.yieldToMic(settle: false).timeout(const Duration(seconds: 2));
  });

  // ── الماكينة (MicOrb بتاع jarvis-ai-finance) ─────────────────────────

  test('ولا تشغيل مرتين: دوستين ورا بعض = سماع واحد', () async {
    await setUpWith();
    listener.hold = true;
    final f = flow();
    final a = f.tapMic();
    final b = f.tapMic();
    await listener.untilListening();
    await f.start();
    expect(listener.listens, 1);
    listener.hear('تمانية');
    await Future.wait([a, b]);
    expect(listener.listens, 1);
  });

  test('مقاطعة بالدوسة: والموبايل بيتكلم ← يسكت ويفتح المايك في نفس الدوسة', () async {
    await setUpWith(answers: ['تسعة']);
    final f = flow();
    player.holdPlayback = true;
    unawaited(voice.speakLine('help_today'));
    await flush();
    expect(f.mic, MicState.speaking);
    expect(micStateLabel(f.mic), 'برد عليك — دوس عشان تقاطعني');
    bool? speakingAtListen;
    listener.onListen = () => speakingAtListen = voice.speaking;
    player.holdPlayback = false;
    await f.tapMic();
    expect(speakingAtListen, isFalse, reason: 'الجملة اتقطعت قبل ما المايك يتفتح');
    expect(listener.listens, 1);
    expect(f.phase, ListenPhase.confirming);
  });

  test('الدوسة والمايك مفتوح = «خلصت»: اللي اتسمع هو الإجابة', () async {
    await setUpWith();
    listener.hold = true;
    final f = flow();
    final run = f.tapMic();
    await listener.untilListening();
    expect(f.mic, MicState.listening);
    listener.partial('تمانية ونص');
    await f.tapMic();
    await run;
    expect(f.phase, ListenPhase.confirming);
    expect(f.confirmText, 'الساعة 8:30');
    expect(listener.listens, 1);
  });

  test('idle ← listening ← thinking ← confirming: كل مرحلة بالترتيب، ومفيش رجوع للسماع لوحده', () async {
    await setUpWith(answers: ['تمانية']);
    final f = flow();
    final seen = <MicState>[];
    f.addListener(() {
      if (seen.isEmpty || seen.last != f.mic) seen.add(f.mic);
    });
    await f.start();
    await flush();
    expect(seen.where((m) => m != MicState.speaking), [MicState.listening, MicState.thinking, MicState.confirming]);
    expect(listener.listens, 1);
  });

  group('«أيوه» / «لأ» بالصوت — classifyReply (affirm.js)', () {
    test('«أيوه» ← اتطبّقت', () async {
      await setUpWith(answers: ['تمانية ونص', 'أيوه']);
      final f = flow();
      await f.start();
      await f.tapMic();
      expect(applied, [const SpokenTime(8, 30)]);
      expect(f.phase, ListenPhase.done);
      expect(listener.listens, 2);
    });

    test('«لا مش كده» ← رفض (الرفض الأول) — ولا تطبيق', () async {
      await setUpWith(answers: ['تمانية ونص', 'لا خلاص تمام كده']);
      final f = flow();
      await f.start();
      await f.tapMic();
      expect(applied, isEmpty);
      expect(f.phase, ListenPhase.declined);
    });

    test('مش واضح ← «صح كده؟» تاني، وفاضل مستني — عمره ما يأكّد لوحده', () async {
      await setUpWith(answers: ['تمانية ونص', 'مش عارف']);
      final f = flow();
      await f.start();
      await f.tapMic();
      expect(applied, isEmpty);
      expect(f.phase, ListenPhase.confirming);
      expect(f.note, contains('أيوه'));
      expect(said(), ['lis_confirm', 'lis_confirm']);
      await flush();
      expect(listener.listens, 2, reason: 'ولا سماع لوحده بعد السؤال التاني');
      await f.confirmYes();
      expect(applied, [const SpokenTime(8, 30)], reason: 'الإجابة الأولى لسه محفوظة');
    });

    test('الدوسة و«صح كده؟» لسه بتتقال ← تقطعها وتسمع الرد (كانت بتتبلع)', () async {
      await setUpWith(answers: ['تمانية ونص', 'أيوه']);
      final f = flow();
      player.holdPlayback = true;
      final run = f.start();
      await flush();
      expect(f.phase, ListenPhase.confirming);
      expect(f.mic, MicState.speaking);
      player.holdPlayback = false;
      await f.tapMic();
      expect(listener.listens, 2);
      expect(applied, [const SpokenTime(8, 30)]);
      await run;
    });

    test('سكوت على «صح كده؟» ← فاضل مستني الرد، مش idle', () async {
      await setUpWith(answers: ['تمانية ونص', const ListenSilence()]);
      final f = flow();
      await f.start();
      await f.tapMic();
      expect(f.phase, ListenPhase.confirming);
      expect(f.confirmText, 'الساعة 8:30');
    });
  });
}
