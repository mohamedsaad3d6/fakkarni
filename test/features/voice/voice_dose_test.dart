// «أخدته» بالصوت على شاشة التذكير = نفس سكّة الزرار بالحرف: نفس الصف، نفس
// الإلغاء (القاعدة الخامسة)، ونفس «تمام، سجّلت إن حضرتك أخدته».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/data/dose_state.dart';
import 'package:fakkarni/data/services/reminder_plan.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/escalation/escalation_ladder.dart';
import 'package:fakkarni/domain/scheduling/day_routine.dart';
import 'package:fakkarni/domain/scheduling/dose_schedule.dart';
import 'package:fakkarni/features/reminder/reminder_screen.dart';

import '../../data/voice/fake_listener.dart';
import '../../data/voice/voice_service_test.dart' show FakePlayer, FakeTts;
import '../scan/scan_test_support.dart';

void main() {
  late Harness h;
  late FakePlayer player;
  late FakeListener listener;

  setUp(() async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true, VoiceService.listenIntroDoneKey: true});
    h = Harness();
    await h.setUp();
  });

  Future<void> setUpWith(List<Object?> answers) async {
    player = FakePlayer();
    listener = FakeListener(answers: answers);
    final voice = VoiceService(player: player, tts: FakeTts(), listener: listener);
    await voice.load();
    final s = h.services;
    h.services = AppServices(
      db: s.db, routines: s.routines, medications: s.medications, events: s.events,
      scheduler: s.scheduler, patientId: s.patientId, voice: voice,
    );
  }

  tearDown(() => h.tearDown());

  /// قراية تدفق drift من جوّه testWidgets — لازم الحلقة الحقيقية (runAsync)،
  /// وإلا `.first` عمرها ما ترجع (شوف «The test harness has a required shape»).
  Future<DoseState> stateOf(WidgetTester tester) async =>
      (await tester.runAsync(() => h.services.events.watchDay(aug31).first))!.single.state;

  List<String> said() => [for (final p in player.played) p.split('/').last.replaceAll('.mp3', '')];

  Future<int> seedDinner() async {
    final id = await h.meds.addMedication(
      patientId: h.services.patientId,
      name: 'Concor',
      timing: const AnchorTiming(DayAnchor.dinner, 0),
      startDate: aug31,
    );
    await h.services.scheduler.rescheduleAll(now: DateTime(2026, 8, 31, 19, 55));
    return id;
  }

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('listen-dose')));
    await settle(tester);
  }

  screenTest('«أخدته» بالصوت → مكتوبة كبير + «صح كده؟» → دوسة «أيوه» → الصف taken والخانة كلها اتلغت', (tester) async {
    await setUpWith(['أخدته']);
    final id = await seedDinner();
    final at = DateTime(2026, 8, 31, 20);
    expect(h.sink.scheduled.keys, contains(notificationIdFor(at)));

    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    expect(find.byKey(const ValueKey('listen-dose')), findsOneWidget, reason: 'المايك على شاشة التذكير');
    await tapMic(tester);
    expect(find.byKey(const ValueKey('listen-heard')), findsOneWidget);
    expect(await stateOf(tester), DoseState.pending, reason: 'مفيش كتابة من غير دوسة «أيوه»');
    await tester.tap(find.byKey(const ValueKey('listen-yes')));
    await settle(tester);

    expect(await stateOf(tester), DoseState.taken);
    expect(h.sink.cancelled, containsAll([notificationIdFor(at), escalationIdFor(at, EscalationRung.first), repeatIdFor(at, 0)]),
        reason: 'القاعدة الخامسة — نفس إلغاء الزرار');
    expect(said(), containsAllInOrder(['lis_confirm', 'help_confirm_done']));
    expect(listener.listens, 1, reason: 'سماع واحد للدوسة');
    expect(find.byKey(const ValueKey('listen-heard')), findsNothing, reason: 'الورقة اتقفلت');
  });

  screenTest('«فكّرني بعدين» بالصوت → «أيوه» → نفس التأجيل بتاع الزرار', (tester) async {
    await setUpWith(['فكرني بعدين']);
    final id = await seedDinner();
    final at = DateTime(2026, 8, 31, 20);
    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    await tapMic(tester);
    await tester.tap(find.byKey(const ValueKey('listen-yes')));
    await settle(tester);
    expect(h.sink.scheduled.keys, contains(snoozeIdFor(at)));
    expect(await stateOf(tester), isNot(DoseState.taken));
  });

  screenTest('«لأ ماخدتش» = مافهمتش — ولا حاجة اتكتبت، والشاشة فاضلة', (tester) async {
    await setUpWith(['لأ ماخدتش']);
    final id = await seedDinner();
    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    await tapMic(tester);
    expect(find.byKey(const ValueKey('listen-not-understood')), findsOneWidget);
    expect(await stateOf(tester), DoseState.pending);
    expect(h.sink.cancelled, isEmpty);
  });

  screenTest('«لأ» ← ولا كتابة ولا سماع لوحده؛ «اتكلم تاني» دوسة = سماع جديد', (tester) async {
    await setUpWith(['أخدته', 'أخدته']);
    final id = await seedDinner();
    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    await tapMic(tester);
    await tester.tap(find.byKey(const ValueKey('listen-no')));
    await settle(tester);
    expect(find.byKey(const ValueKey('listen-declined')), findsOneWidget);
    expect(listener.listens, 1, reason: 'مفيش سماع بيبدأ لوحده بعد دوسة');
    expect(await stateOf(tester), DoseState.pending);
    await tester.tap(find.byKey(const ValueKey('listen-again')));
    await settle(tester);
    expect(listener.listens, 2);
    expect(find.byKey(const ValueKey('listen-heard')), findsOneWidget);
  });

  screenTest('«اقفل» وهو بيسمع ← المايك يقف على طول، ومفيش كتابة', (tester) async {
    await setUpWith(const []);
    listener.hold = true;
    final id = await seedDinner();
    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    await tester.tap(find.byKey(const ValueKey('listen-dose')));
    await settle(tester); // الورقة تطلع — والمايك لسه مفتوح (hold)
    expect(find.byKey(const ValueKey('listen-listening')), findsOneWidget);
    expect(find.byKey(const ValueKey('listen-pulse')), findsOneWidget, reason: 'مايك بينبض لحظة ما بيسمع');
    await tester.tap(find.byKey(const ValueKey('listen-close')));
    await settle(tester);
    expect(listener.stops, greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('listen-listening')), findsNothing);
    expect(await stateOf(tester), DoseState.pending);
  });

  screenTest('«قول «أخدته» أو دوس» جنب المايك — وأكبر في نمط كبار السن', (tester) async {
    await setUpWith(const []);
    final id = await seedDinner();
    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    final hint = find.byKey(const ValueKey('listen-hint-dose'));
    expect(hint, findsOneWidget);
    expect(tester.widget<Text>(hint).data, 'قول «أخدته» أو دوس');
    expect(tester.widget<Text>(hint).style!.fontSize, F.minBodySize);
    expect(tester.getTopLeft(hint).dy, lessThan(tester.getTopLeft(find.text('تم التناول ✅')).dy), reason: 'فوق الزرارين');

    await h.services.preferences.setElderMode(true);
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const ValueKey('listen-hint-dose'))).style!.fontSize, F.elderTextSize);
  });

  screenTest('الصوت مقفول: ولا مايك ولا كلمته', (tester) async {
    await setUpWith(const []);
    await h.services.voice!.setEnabled(false);
    final id = await seedDinner();
    await h.pump(tester, ReminderScreen(routineDay: aug31, scheduleIds: ['$id'], now: DateTime(2026, 8, 31, 20, 5)));
    expect(find.byKey(const ValueKey('listen-hint-dose')), findsNothing);
    expect(find.byKey(const ValueKey('listen-dose')), findsNothing);
  });
}
