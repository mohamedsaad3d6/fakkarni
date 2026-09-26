// «كلّمني» على «يومك» تحت التحية، وأكبر في نمط كبار السن، وبيظهر حتى والصوت
// مقفول — ساعتها الجمل مكتوبة في الورقة بدل ما تتقال.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/voice/voice_catalog.dart';
import 'package:fakkarni/features/elder/elder_home_screen.dart';
import 'package:fakkarni/features/today/today_screen.dart';

import '../../data/voice/fake_listener.dart';
import '../../data/voice/voice_service_test.dart' show FakePlayer, FakeTts;
import '../scan/scan_test_support.dart';

void main() {
  late Harness h;
  late FakePlayer player;

  Future<void> setUpWith({required bool voiceOn, List<String?> answers = const [], bool mic = true}) async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: voiceOn, VoiceService.cmdHintDoneKey: true});
    h = Harness();
    await h.setUp();
    player = FakePlayer();
    final voice = VoiceService(player: player, tts: FakeTts(), listener: mic ? FakeListener(answers: answers) : null);
    await voice.load();
    final s = h.services;
    h.services = AppServices(
      db: s.db, routines: s.routines, medications: s.medications, events: s.events,
      scheduler: s.scheduler, patientId: s.patientId, voice: voice,
    );
  }

  tearDown(() => h.tearDown());

  screenTest('على «يومك»: تحت التحية، فوق كل حاجة', (tester) async {
    await setUpWith(voiceOn: true);
    await h.pump(tester, TodayScreen(routine: normalDay, now: DateTime(2026, 8, 31, 8)));
    final button = find.byKey(const ValueKey('talk-button'));
    expect(button, findsOneWidget);
    expect(find.text('كلّمني'), findsOneWidget);
    expect(tester.getTopLeft(button).dy, greaterThan(tester.getTopLeft(find.text('يومك')).dy));
    expect(tester.getTopLeft(button).dy, lessThan(tester.getTopLeft(find.text('جدول النهاردة')).dy));
    expect(tester.getSize(button).height, 64);
  });

  screenTest('نمط كبار السن: أكبر (٨٠)', (tester) async {
    await setUpWith(voiceOn: true);
    await h.pump(tester, ElderHomeScreen(routine: normalDay, now: DateTime(2026, 8, 31, 8)));
    expect(tester.getSize(find.byKey(const ValueKey('talk-button'))).height, 80);
  });

  screenTest('من غير مايك في النسخة = مفيش زرار', (tester) async {
    await setUpWith(voiceOn: true, mic: false);
    await h.pump(tester, TodayScreen(routine: normalDay, now: DateTime(2026, 8, 31, 8)));
    expect(find.byKey(const ValueKey('talk-button')), findsNothing);
  });

  screenTest('الصوت مقفول: الزرار موجود، والورقة بتكتب الجملة بدل ما تقولها', (tester) async {
    await setUpWith(voiceOn: false, answers: ['الجو حر النهارده']);
    await h.pump(tester, TodayScreen(routine: normalDay, now: DateTime(2026, 8, 31, 8)));
    await tester.tap(find.byKey(const ValueKey('talk-button')));
    await settle(tester);
    expect(find.byKey(const ValueKey('talk-shown')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('talk-shown'))).data, voiceLine('lis_not_understood'));
    expect(player.played, isEmpty, reason: 'مقفول = مكتوب مش مسموع');
    // «قول تاني» هي الدايرة نفسها — بكلمتها
    expect(find.byKey(const ValueKey('mic-orb')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('mic-orb-label'))).data, 'دوس واتكلم');
  });
}
