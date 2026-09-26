// «كلّمني»: اسمع ← افهم محلي ← (السحابة) ← «صح كده؟» ← نفّذ بنفس سكّة الزرار.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/ai/command_reader.dart';
import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/data/dose_state.dart';
import 'package:fakkarni/data/services/reminder_plan.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/escalation/escalation_ladder.dart';
import 'package:fakkarni/domain/medication/medication_purpose.dart';
import 'package:fakkarni/domain/scheduling/day_routine.dart';
import 'package:fakkarni/domain/scheduling/dose_schedule.dart';
import 'package:fakkarni/domain/voice/voice_catalog.dart';
import 'package:fakkarni/features/voice/command_flow.dart';
import 'package:fakkarni/features/voice/voice_flags.dart';

import '../../data/voice/fake_listener.dart';
import '../../data/voice/voice_service_test.dart' show FakePlayer, FakeTts;
import '../scan/scan_test_support.dart' show Harness, aug31;

class FakeReader implements VoiceCommandReader {
  FakeReader({this.result = const CloudReadResult()});
  CloudReadResult result;
  final transcripts = <String>[];
  @override
  Future<CloudReadResult> read(String transcript) async {
    transcripts.add(transcript);
    return result;
  }
}

void main() {
  late Harness h;
  late FakePlayer player;
  late FakeTts tts;
  late FakeListener listener;
  late VoiceService voice;
  late List<AddMedPrefill> opened;
  late bool saveResult;
  final now = DateTime(2026, 8, 31, 20, 5);

  setUp(() async {
    voiceCommandsCloud = true;
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true, VoiceService.cmdHintDoneKey: true});
    h = Harness();
    await h.setUp();
    player = FakePlayer();
    tts = FakeTts();
    opened = [];
    saveResult = true;
  });
  tearDown(() => h.tearDown());

  Future<CommandFlow> flowWith(List<String?> answers, {FakeReader? reader, bool Function()? cloudAllowed, void Function()? onCloudUsed}) async {
    listener = FakeListener(answers: answers);
    voice = VoiceService(player: player, tts: tts, listener: listener);
    await voice.load();
    final s = h.services;
    return CommandFlow(
      voice: voice,
      services: AppServices(
        db: s.db, routines: s.routines, medications: s.medications, events: s.events,
        scheduler: s.scheduler, patientId: s.patientId, voice: voice,
      ),
      routineDay: aug31,
      reader: reader,
      cloudAllowed: cloudAllowed,
      onCloudUsed: onCloudUsed,
      clock: () => now,
      onOpenAdd: (p) async {
        opened.add(p);
        return saveResult;
      },
    );
  }

  List<String> said() => [for (final p in player.played) p.split('/').last.replaceAll('.mp3', '')];

  Future<int> seed(String name, {DayAnchor anchor = DayAnchor.dinner, MedicationPurpose? purpose}) async {
    return h.meds.addMedicationWithDoses(
      patientId: h.services.patientId,
      name: name,
      timings: [AnchorTiming(anchor, 0)],
      startDate: aug31,
      purpose: purpose,
    );
  }

  Future<void> schedule() => h.services.scheduler.rescheduleAll(now: DateTime(2026, 8, 31, 19, 55));

  Future<DoseState> stateOf(String name) async =>
      (await h.services.events.watchDay(aug31).first).firstWhere((d) => d.medicationName == name).state;

  group('أخدت الدوا', () {
    test('«أخدت الدوا» وجرعة واحدة مستنية → مكتوبة كبير + «صح كده؟» المسجّلة → دوسة «أيوه» → نفس سكّة الزرار', () async {
      await seed('Concor');
      await schedule();
      final at = DateTime(2026, 8, 31, 20);
      final f = await flowWith(['أخدت الدوا', 'أيوه']);
      await f.start();
      expect(f.phase, CommandPhase.confirming);
      expect(f.shown, contains('أخدت Concor'));
      expect(tts.spoken, isEmpty, reason: '«فهمت: …» بصوت الموبايل اتشالت — كانت آلية');
      expect(listener.listens, 1, reason: '«أيوه» بالإيد — مفيش سماع تاني لوحده');
      await f.confirmYes();
      expect(f.phase, CommandPhase.done);
      expect(await stateOf('Concor'), DoseState.taken);
      expect(h.sink.cancelled, containsAll([notificationIdFor(at), escalationIdFor(at, EscalationRung.first), repeatIdFor(at, 0)]),
          reason: 'القاعدة الخامسة — نفس confirmGroup');
      expect(said(), containsAllInOrder(['lis_confirm', 'help_confirm_done']));
      expect(said(), isNot(contains('lis_listening')), reason: 'ولا جملة قبل المايك');
    });

    test('من غير «أيوه» مفيش كتابة — والزرار بالإيد بيكتب', () async {
      await seed('Concor');
      await schedule();
      final f = await flowWith(['أخدت الدوا', null]);
      await f.start();
      expect(f.phase, CommandPhase.confirming);
      expect(await stateOf('Concor'), DoseState.pending, reason: 'لسه ما أكّدش');
      await f.confirmYes();
      expect(await stateOf('Concor'), DoseState.taken);
    });

    test('«لأ» → «تمام، مش هعمل حاجة» وولا حاجة اتغيّرت', () async {
      await seed('Concor');
      await schedule();
      final f = await flowWith(['أخدت الدوا', 'لأ']);
      await f.start();
      await f.confirmNo();
      expect(f.phase, CommandPhase.answering);
      expect(listener.listens, 1, reason: 'مفيش سماع بيبدأ لوحده بعد دوسة');
      expect(said().last, 'cmd_cancelled');
      expect(await stateOf('Concor'), DoseState.pending);
      expect(h.sink.cancelled, isEmpty);
    });

    test('«أخدت دوا الضغط» بيطابق بالغرض على القايمة المحلية — والسحابة ما اتسألتش', () async {
      await seed('Concor', purpose: MedicationPurpose.pressure);
      await seed('Glucophage', purpose: MedicationPurpose.sugar);
      await schedule();
      final reader = FakeReader();
      final f = await flowWith(['أخدت دوا الضغط'], reader: reader);
      await f.start();
      await f.confirmYes();
      expect(await stateOf('Concor'), DoseState.taken);
      expect(await stateOf('Glucophage'), isNot(DoseState.taken));
      expect(reader.transcripts, isEmpty, reason: 'المحلي فهم');
    });

    test('دواءين مستنيين ومحدش اتسمّى → «أنهي واحد؟» بأزرار — والاختيار بيأكّد', () async {
      await seed('Concor');
      await seed('Glucophage', anchor: DayAnchor.lunch);
      await schedule();
      final f = await flowWith(['أخدت الدوا', 'أيوه']);
      await f.start();
      expect(f.phase, CommandPhase.choosing);
      expect(f.candidates.map((c) => c.dose.medicationName), containsAll(['Concor', 'Glucophage']));
      expect(await stateOf('Concor'), DoseState.pending);
      await f.choose(f.candidates.firstWhere((c) => c.dose.medicationName == 'Glucophage'));
      expect(f.phase, CommandPhase.confirming);
      await f.confirmYes();
      expect(await stateOf('Glucophage'), DoseState.taken);
      expect(await stateOf('Concor'), isNot(DoseState.taken));
    });

    test('دوا اتسمّى ومفيش جرعة له مستنية → جملة على الشاشة ومفيش كتابة', () async {
      await seed('Concor');
      await schedule();
      final f = await flowWith(['أخدت دوا الفيتامين']);
      await f.start();
      expect(f.phase, CommandPhase.answering);
      expect(f.shown, contains('مفيش جرعة'));
      expect(await stateOf('Concor'), DoseState.pending);
    });
  });

  group('قراية بس', () {
    test('«إيه دوايا الجاي» → بصوت الموبايل، بساعة الجرعة الجاية — ومفيش تأكيد', () async {
      await seed('Concor');
      await schedule();
      final f = await flowWith(['إيه دوايا الجاي']);
      await f.start();
      expect(f.phase, CommandPhase.answering);
      expect(tts.spoken.single, 'معاد Concor كان الساعة ٨ بالليل — ولسه ما اتأكدش.', reason: '٨:٠٠ فاتت بخمس دقايق');
      expect(listener.listens, 1, reason: 'مفيش سماع للتأكيد');
    });

    test('«الدوا الجاي إمتى» قبل معاده → «دواك الجاي … الساعة …»، ومن غير حاجة النهارده → بكرة', () async {
      await seed('Concor');
      await schedule();
      final f = await flowWith(['الدوا الجاي إمتى']);
      // الساعة ٧ بالليل — قبل العشا
      final early = CommandFlow(
        voice: voice, services: f.services, routineDay: aug31, clock: () => DateTime(2026, 8, 31, 19),
        onOpenAdd: (_) async => false,
      );
      await early.start();
      expect(tts.spoken.single, 'دواك الجاي Concor الساعة ٨ بالليل.');
    });

    test('«إيه أدويتي النهارده» → قايمة بحد أقصى خمسة و«حاجات تانية على الشاشة»', () async {
      for (final (i, a) in [DayAnchor.wake, DayAnchor.breakfast, DayAnchor.lunch, DayAnchor.dinner, DayAnchor.sleep].indexed) {
        await h.meds.addMedication(patientId: h.services.patientId, name: 'M$i', timing: AnchorTiming(a, 0), startDate: aug31);
        await h.meds.addMedication(patientId: h.services.patientId, name: 'X$i', timing: AnchorTiming(a, 15), startDate: aug31);
      }
      await schedule();
      final f = await flowWith(['إيه أدويتي النهارده']);
      await f.start();
      expect(tts.spoken.single, contains('النهارده عندك ١٠ جرعات'));
      expect(tts.spoken.single, contains('وحاجات تانية على الشاشة'));
      expect('M0 M1 M2 M3 M4 X0 X1 X2 X3 X4'.split(' ').where((n) => tts.spoken.single.contains(n)).length, 5);
    });

    test('سؤال طبي → «دي حاجة لازم تسأل فيها الدكتور» وبس', () async {
      final f = await flowWith(['أزود الجرعة؟']);
      await f.start();
      expect(said().last, 'gen_no_medical');
      expect(tts.spoken, isEmpty);
    });
  });

  group('ضيفلي دوا', () {
    test('«ضيفلي دوا الضغط الصبح بعد الفطار» → «فهمت» → «أيوه» → الفورم متعبّي، **وولا صف اتكتب**', () async {
      final f = await flowWith(['ضيفلي دوا الضغط الصبح بعد الفطار']);
      await f.start();
      expect(f.shown, contains('تضيف دوا ضغط'));
      expect(f.shown, contains('بعد الفطار'));
      expect(tts.spoken, isEmpty);
      await f.confirmYes();
      expect(f.phase, CommandPhase.done);
      expect(opened, hasLength(1));
      expect(opened.single.purpose, MedicationPurpose.pressure);
      expect(opened.single.timings, [const AnchorTiming(DayAnchor.breakfast, 30)]);
      expect(await h.meds.currentMedicines(h.services.patientId), isEmpty, reason: 'الفورم هو اللي بيحفظ');
      expect(said().last, 'cmd_done', reason: 'الفورم رجّع «اتحفظ»');
    });

    test('رجع من الفورم من غير حفظ → مفيش «عملتها»', () async {
      saveResult = false;
      final f = await flowWith(['ضيفلي دوا اسمه زنك مرتين في اليوم']);
      await f.start();
      await f.confirmYes();
      expect(opened.single.name, 'اسمه زنك');
      expect(opened.single.timings, [const AnchorTiming(DayAnchor.breakfast, -30), const AnchorTiming(DayAnchor.dinner, -30)]);
      expect(said().where((s) => s == 'cmd_done'), isEmpty);
    });
  });

  group('مش مفهوم والسحابة', () {
    test('مش مفهوم ومفيش سحابة → «مافهمتش»، والتانية ورا بعض «كمّل بإيدك»', () async {
      final f = await flowWith(['الجو حر', 'الجو حر']);
      await f.start();
      expect(said().last, 'lis_not_understood');
      await f.again();
      expect(said().last, 'gen_try_hands');
    });

    test('مش مفهوم محلي → «ثانية واحدة» → السحابة بتاخد الكلام المكتوب بس → وبعدها زي المحلي', () async {
      await seed('Concor');
      await schedule();
      final reader = FakeReader(result: const CloudReadResult(command: CloudCommand(intent: 'mark_taken', medNameAsSpoken: null)));
      var used = 0;
      final f = await flowWith(['خلصت الحباية بتاعتي'], reader: reader, onCloudUsed: () => used++);
      await f.start();
      await f.confirmYes();
      expect(reader.transcripts, ['خلصت الحباية بتاعتي'], reason: 'المحلي ما فهمش — والكلام المكتوب بس هو اللي راح');
      expect(await stateOf('Concor'), DoseState.taken);
      expect(said(), containsAllInOrder(['cmd_thinking', 'lis_confirm', 'help_confirm_done']));
      expect(used, 1);
    });

    test('السحابة وقعت (مهلة) → «كمّل بإيدك»', () async {
      final reader = FakeReader(result: const CloudReadResult(error: 'timeout'));
      final f = await flowWith(['كلام غريب خالص'], reader: reader);
      await f.start();
      expect(said().last, 'gen_try_hands');
    });

    test('السحابة ما فهمتش → «مافهمتش»', () async {
      final reader = FakeReader(result: const CloudReadResult(command: null));
      final f = await flowWith(['كلام غريب خالص'], reader: reader);
      await f.start();
      expect(said().last, 'lis_not_understood');
    });

    test('الحد اليومي خلص → «كفاية كده النهارده» والسحابة ما اتسألتش', () async {
      final reader = FakeReader();
      final f = await flowWith(['كلام غريب خالص'], reader: reader, cloudAllowed: () => false);
      await f.start();
      expect(said().last, 'cmd_limit');
      expect(reader.transcripts, isEmpty);
    });

    test('العلم مقفول → السحابة ما اتسألتش حتى لو موجودة', () async {
      voiceCommandsCloud = false;
      final reader = FakeReader();
      final f = await flowWith(['كلام غريب خالص'], reader: reader);
      await f.start();
      expect(reader.transcripts, isEmpty);
      expect(said().last, 'lis_not_understood');
    });

    test('السحابة رجّعت ضيفلي بكلمات → بتتفهم محلي وبتتطابق على الموبايل', () async {
      final reader = FakeReader(
          result: const CloudReadResult(
              command: CloudCommand(intent: 'add_med', medNameAsSpoken: 'السكر', timingWords: 'بعد الغدا', patternWords: null)));
      final f = await flowWith(['xyz'], reader: reader);
      await f.start();
      await f.confirmYes();
      expect(opened.single.purpose, MedicationPurpose.sugar);
      expect(opened.single.timings, [const AnchorTiming(DayAnchor.lunch, 30)]);
    });
  });

  test('أول دوسة خالص: «تقدر تقولّي مثلاً…» **مكتوبة** تحت «سامعك…» — ما بتتقالش قبل المايك', () async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true});
    final f = await flowWith(const []);
    listener.hold = true;
    final run = f.start();
    await listener.untilListening();
    expect(f.phase, CommandPhase.listening);
    expect(f.shown, 'سامعك…');
    expect(f.hint, voiceLine('cmd_hint'));
    expect(said(), isEmpty, reason: 'ولا جملة قبل المايك');
    expect(voice.cmdHintDone, isTrue);
    listener.hear(null);
    await run;
  });

  test('الكلام بيتكتب وهو بيتقال', () async {
    final f = await flowWith(const []);
    listener.hold = true;
    final run = f.start();
    await listener.untilListening();
    listener.partial('أخدت');
    expect(f.partial, 'أخدت');
    listener.hear(null);
    await run;
  });

  test('الدوسة بتكسب: «أيوه» و«صح كده؟» لسه بتتقال → اتكتبت على طول والجملة وقفت', () async {
    await seed('Concor');
    await schedule();
    final f = await flowWith(['أخدت الدوا']);
    player.holdPlayback = true;
    final run = f.start();
    for (var i = 0; i < 80 && f.phase != CommandPhase.confirming; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(f.phase, CommandPhase.confirming);
    expect(voice.speaking, isTrue);
    player.holdPlayback = false;
    await f.confirmYes();
    expect(await stateOf('Concor'), DoseState.taken);
    await run;
    expect(f.sessions, 1, reason: 'سماع واحد لكل دوسة');
  });

  test('الصوت مقفول: نفس الجمل مكتوبة على الشاشة، ومفيش تسجيل بيتقال', () async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: false, VoiceService.cmdHintDoneKey: true});
    final f = await flowWith(['أزود الجرعة؟']);
    expect(f.available, isTrue);
    await f.start();
    expect(f.shown, voiceLine('gen_no_medical'));
    expect(player.played, isEmpty);
    expect(tts.spoken, isEmpty);
  });

  test('تنبيه الجرعة بيكسب: stop() وإحنا بنسمع → idle في صمت', () async {
    final f = await flowWith(const []);
    listener.hold = true;
    unawaited(f.start());
    await listener.untilListening();
    expect(f.phase, CommandPhase.listening);
    final alert = ValueNotifier<String?>(null);
    voice.attachAlertSignal(alert);
    alert.value = '{"v":1}';
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(f.phase, CommandPhase.idle);
    expect(said().where((s) => s == 'lis_not_understood'), isEmpty);
  });
}
