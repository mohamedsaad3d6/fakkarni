// جمل البداية (onb_*) بتتقال لوحدها أول ما كل صفحة تفتح — لو قال «أيوه،
// اتكلّم» بس — وبتسكت أول ما يلمس حاجة، و«ساعدني» على الصفحة بيعيدها.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/data/db/app_database.dart';
import 'package:fakkarni/data/repositories/dose_event_repository.dart';
import 'package:fakkarni/data/repositories/medication_repository.dart';
import 'package:fakkarni/data/repositories/routine_repository.dart';
import 'package:fakkarni/data/services/reminder_scheduler.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/features/entry/entry_screen.dart';
import 'package:fakkarni/features/onboarding/routine_onboarding_screen.dart';

import '../../data/voice/fake_listener.dart';
import '../../data/voice/voice_service_test.dart' show FakePlayer, FakeTts;
import '../../support/seeded_clock.dart';
import 'routine_onboarding_test.dart' show SilentSink;

void main() {
  late AppDatabase db;
  late AppServices services;
  late FakePlayer player;
  late VoiceService voice;
  FakeListener? listener;

  Future<void> setUpWith({required bool voiceOn, List<String?>? answers}) async {
    SharedPreferences.setMockInitialValues({
      VoiceService.enabledKey: voiceOn,
      VoiceService.introDoneKey: true,
    });
    listener = answers == null ? null : FakeListener(answers: answers);
    db = AppDatabase(NativeDatabase.memory());
    final routines = RoutineRepository(db);
    final medications = MedicationRepository(db, clock: seededLongAgo);
    final patientId = await routines.ensurePatient();
    player = FakePlayer();
    voice = VoiceService(player: player, tts: FakeTts(), listener: listener);
    await voice.load();
    services = AppServices(
      db: db,
      routines: routines,
      medications: medications,
      events: DoseEventRepository(db),
      scheduler: ReminderScheduler(
        routines: routines,
        medications: medications,
        events: DoseEventRepository(db),
        patientId: patientId,
        sink: SilentSink(),
      ),
      patientId: patientId,
      voice: voice,
    );
  }

  tearDown(() => db.close());

  List<String> said() => [for (final p in player.played) p.split('/').last.replaceAll('.mp3', '')];

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppScope(
      services: services,
      child: MaterialApp(
        theme: F.light,
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('كل صفحة بجملتها مرة، و«مش دلوقتي» بعد الصحيان بس، و«تمام كده» بعد آخر سؤال', (tester) async {
    await setUpWith(voiceOn: true);
    await pump(tester, const RoutineOnboardingScreen());
    expect(said(), ['onb_name']);

    await tester.enterText(find.byType(TextField), 'الحاج أحمد');
    await tester.pumpAndSettle();
    await tap(tester, 'كمّل');
    await tap(tester, 'راجل');
    await tap(tester, 'كمّل');
    await tap(tester, 'كمّل');
    for (var i = 0; i < 5; i++) {
      await tap(tester, 'تمام');
    }
    expect(said(), [
      'onb_name',
      'onb_gender',
      'onb_age',
      'onb_wake',
      'onb_routine_skip',
      'onb_breakfast',
      'onb_lunch',
      'onb_dinner',
      'onb_sleep',
      'onb_routine_done',
    ]);
  });

  testWidgets('بيسكت أول ما يكتب — و«ساعدني» بيعيد جملة الصفحة، والرجوع ما بيعيدهاش لوحده', (tester) async {
    await setUpWith(voiceOn: true);
    player.holdPlayback = true;
    await pump(tester, const RoutineOnboardingScreen());
    expect(voice.speaking, isTrue, reason: 'onb_name لسه بيتقال');

    await tester.enterText(find.byType(TextField), 'ا');
    await tester.pump();
    expect(voice.speaking, isFalse, reason: 'كتب — الكلام وقف');

    player.holdPlayback = false;
    await tester.tap(find.byKey(const ValueKey('help-onb_name')));
    await tester.pumpAndSettle();
    expect(said().where((id) => id == 'onb_name'), hasLength(2));

    await tester.enterText(find.byType(TextField), 'الحاج أحمد');
    await tap(tester, 'كمّل');
    expect(said().last, 'onb_gender');
    expect(find.byKey(const ValueKey('help-onb_gender')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    expect(said().last, 'onb_gender', reason: 'مرة واحدة لكل صفحة');
  });

  testWidgets('«مش دلوقتي» بتطمّن الأول وبعدين سؤال الصفحة اللي بعدها', (tester) async {
    await setUpWith(voiceOn: true);
    await pump(tester, const RoutineOnboardingScreen(askProfile: false));
    expect(said(), isEmpty, reason: 'من غير صفحة البداية الكاملة (اختبار الأسئلة) مفيش إعلان');
    await tap(tester, 'تمام'); // الصحيان
    await tap(tester, 'مش دلوقتي'); // الفطار
    expect(said(), ['onb_breakfast', 'help_routine_skip', 'onb_lunch']);
  });

  testWidgets('الصوت مقفول: ولا جملة بتتقال لوحدها، ومفيش «ساعدني»', (tester) async {
    await setUpWith(voiceOn: false);
    await pump(tester, const RoutineOnboardingScreen());
    await tester.enterText(find.byType(TextField), 'الحاج أحمد');
    await tap(tester, 'كمّل');
    expect(player.played, isEmpty);
    expect(find.text('ساعدني'), findsNothing);
  });

  testWidgets('شاشة البداية: onb_entry لوحدها، وبتسكت أول ما يختار', (tester) async {
    await setUpWith(voiceOn: true);
    player.holdPlayback = true;
    await pump(tester, EntryScreen(onSelf: () {}, onHaveCode: () {}, onNurse: () {}));
    expect(said(), ['onb_entry']);
    expect(voice.speaking, isTrue);
    await tester.tap(find.byKey(const ValueKey('entry-self')));
    await tester.pump();
    expect(voice.speaking, isFalse);
    expect(find.byKey(const ValueKey('help-onb_entry')), findsOneWidget);
  });

  testWidgets('شاشة البداية والصوت مقفول: ساكتة', (tester) async {
    await setUpWith(voiceOn: false);
    await pump(tester, EntryScreen(onSelf: () {}, onHaveCode: () {}));
    expect(player.played, isEmpty);
  });

  testWidgets('مفيش «اتكلم» في البداية خالص — الاسم والجنس والسن والمواعيد بالإيد والكتابة بس', (tester) async {
    await setUpWith(voiceOn: true, answers: const []);
    await pump(tester, const RoutineOnboardingScreen());
    expect(find.text('اتكلم'), findsNothing, reason: 'صفحة الاسم');
    expect(find.text('ساعدني'), findsOneWidget, reason: 'جملة الصفحة فاضلة');
    await tester.enterText(find.byType(TextField), 'أحمد');
    await tester.pumpAndSettle();
    await tap(tester, 'كمّل');
    expect(find.text('اتكلم'), findsNothing, reason: 'صفحة الجنس');
    await tap(tester, 'راجل');
    await tap(tester, 'كمّل');
    expect(find.text('اتكلم'), findsNothing, reason: 'صفحة السن');
    await tap(tester, 'كمّل');
    for (var i = 0; i < 5; i++) {
      expect(find.text('اتكلم'), findsNothing, reason: 'سؤال المواعيد ${i + 1}');
      await tap(tester, 'تمام');
    }
    expect(listener!.listens, 0);
    expect(said(), isNot(contains('lis_intro')));
  });

  testWidgets('من غير مايك في النسخة = مفيش زرار «اتكلم» في البداية', (tester) async {
    await setUpWith(voiceOn: true);
    await pump(tester, const RoutineOnboardingScreen());
    expect(find.text('اتكلم'), findsNothing);
    expect(find.text('ساعدني'), findsOneWidget);
  });
}
