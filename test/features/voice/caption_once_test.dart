// الجملة بتتكتب **مرة واحدة**: الورقة («اتكلم» و«كلّمني») بتكتب اللي بيتقال
// بنفسها، فالترجمة المكتوبة تحت بتسكت طول ما الورقة مفتوحة. على الآيفون
// كانت «معلش، مافهمتش…» بتظهر مرتين — في الورقة وفي الكارت اللي تحتها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/voice/answer_parser.dart';
import 'package:fakkarni/domain/voice/voice_catalog.dart';
import 'package:fakkarni/features/today/today_screen.dart';
import 'package:fakkarni/features/voice/listen_button.dart';
import 'package:fakkarni/features/voice/voice_caption.dart';

import '../../data/voice/fake_listener.dart';
import '../../data/voice/voice_service_test.dart' show FakePlayer, FakeTts;
import '../scan/scan_test_support.dart';

void main() {
  late Harness h;
  late FakePlayer player;
  late FakeListener listener;
  late VoiceService voice;

  Future<void> setUpWith(List<Object?> answers) async {
    SharedPreferences.setMockInitialValues({
      VoiceService.enabledKey: true,
      VoiceService.listenIntroDoneKey: true,
      VoiceService.cmdHintDoneKey: true,
    });
    h = Harness();
    await h.setUp();
    player = FakePlayer();
    listener = FakeListener(answers: answers);
    voice = VoiceService(player: player, tts: FakeTts(), listener: listener);
    await voice.load();
    final s = h.services;
    h.services = AppServices(
      db: s.db, routines: s.routines, medications: s.medications, events: s.events,
      scheduler: s.scheduler, patientId: s.patientId, voice: voice,
    );
  }

  tearDown(() => h.tearDown());

  /// زي `main`: الترجمة المكتوبة في جذر التطبيق، فوق كل الشاشات والأوراق.
  Future<void> pumpWithCaption(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppScope(
      services: h.services,
      child: MaterialApp(
        theme: F.light,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: VoiceCaptionOverlay(child: child!),
        ),
        home: screen,
      ),
    ));
    await settle(tester);
  }

  screenTest('الترجمة بتشتغل عادي برّه الورقة — الحارس ده مش ساكت على طول', (tester) async {
    await setUpWith(const []);
    player.holdPlayback = true;
    await pumpWithCaption(tester, const Scaffold(body: SizedBox()));
    // جملة من غير ورقة: الكارت اللي تحت هو المكان الوحيد اللي بتتكتب فيه
    voice.speakLine('help_today');
    await settle(tester);
    expect(find.byKey(const ValueKey('voice-caption')), findsOneWidget);
    expect(find.text(voiceLine('help_today')), findsOneWidget);
    await voice.stop();
    await tester.pump();
  });

  screenTest('«اتكلم»: «معلش، مافهمتش…» مكتوبة مرة — في الورقة، مش في الكارت كمان', (tester) async {
    await setUpWith([null]); // المايك اشتغل وما سمعش حاجة
    await pumpWithCaption(
      tester,
      Scaffold(
        body: Center(
          child: ListenButton<SpokenTime>(
            tag: 'wake',
            parse: (h) => parseTime(h),
            describe: (t) => '${t.hour}',
            onApply: (_) async {},
          ),
        ),
      ),
    );
    // المايك مفتوح (hold): «سامعك…» في الورقة، ومفيش حاجة بتتقال
    listener.hold = true;
    await tester.tap(find.byKey(const ValueKey('listen-wake')));
    await settle(tester);
    expect(find.text('سامعك…'), findsOneWidget);
    expect(voice.caption.value, isNull, reason: 'ولا جملة قبل المايك');

    // سكوت ← «مافهمتش» بتتقال — والتسجيل طويل
    player.holdPlayback = true;
    listener.hear(null);
    await settle(tester);
    expect(voice.caption.value, voiceLine('lis_not_understood'), reason: 'الجملة لسه بتتقال');
    expect(find.text(voiceLine('lis_not_understood')), findsOneWidget, reason: 'مرة واحدة');
    expect(find.byKey(const ValueKey('voice-caption')), findsNothing, reason: 'الورقة هي اللي كاتباها');
    player.holdPlayback = false;
    await player.stop();
    await settle(tester);

    // الورقة اتقفلت → الترجمة ترجع لشغلها
    await tester.tap(find.text('اقفل'));
    await settle(tester);
    expect(voice.captionHolds.value, 0);
  });

  screenTest('«كلّمني»: «مافهمتش» مكتوبة مرة — في الورقة، مش في الكارت كمان', (tester) async {
    await setUpWith([null]);
    await pumpWithCaption(tester, TodayScreen(routine: normalDay, now: DateTime(2026, 8, 31, 8)));
    player.holdPlayback = true;
    await tester.tap(find.byKey(const ValueKey('talk-button')));
    await settle(tester);
    expect(voice.caption.value, voiceLine('lis_not_understood'));
    expect(find.text(voiceLine('lis_not_understood')), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-caption')), findsNothing);
    await voice.stop();
    await tester.pump();
  });
}
