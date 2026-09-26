// كل جملة في الكتالوج ليها مكان، وكل «ساعدني» على جملة موجودة، وكل جملة في
// المكان اللي معناها بيقوله. الخريطة تحت هي جدول المراجعة (٢٦ سبتمبر ٢٠٢٦):
// نقل جملة لمكان تاني = تعديل هنا بالعين، مش سهو.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/app/root.dart';
import 'package:fakkarni/app/shell.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/core/widgets/f_wheels.dart';
import 'package:fakkarni/data/db/app_database.dart';
import 'package:fakkarni/data/repositories/dose_event_repository.dart';
import 'package:fakkarni/data/repositories/medication_repository.dart';
import 'package:fakkarni/data/repositories/routine_repository.dart';
import 'package:fakkarni/data/services/reminder_scheduler.dart';
import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/voice/voice_catalog.dart';
import 'package:fakkarni/features/link/sign_in_screen.dart';

import '../../app/root_test.dart' show SilentSink;
import '../../data/voice/voice_service_test.dart' show FakeTts;
import '../../support/seeded_clock.dart';

/// مشغّل بمدد حقيقية: كل جملة بتاخد [seconds] ثانية، وبيتقطع بـ`stop`.
/// المشغّل المزيّف العادي بيخلّص فوراً — وده بالظبط اللي خبّى إن الجملة
/// بتبدأ وتتقطع وتبدأ تاني.
class TimedPlayer implements VoicePlayer {
  TimedPlayer({this.seconds = 3});
  final int seconds;
  final played = <String>[];
  final cut = <String>[];
  Completer<bool>? _c;
  String? _now;

  @override
  Future<bool> play(String assetPath, {required double volume}) {
    final id = assetPath.split('/').last.replaceAll('.mp3', '');
    played.add(id);
    final c = _c = Completer<bool>();
    _now = id;
    Timer(Duration(seconds: seconds), () {
      if (!c.isCompleted) c.complete(true);
    });
    return c.future;
  }

  @override
  Future<void> release() => stop();

  @override
  Future<void> stop() async {
    final c = _c;
    if (c != null && !c.isCompleted) {
      cut.add(_now!);
      c.complete(true);
    }
  }
}

/// الرقم → الملفات اللي بتقوله (زرار «ساعدني» أو بعد فعل أو لوحدها في
/// البداية). intro_01…05 بتتقال من `introSequence`، مش بالاسم.
const placement = <String, Set<String>>{
    'intro_yes': {'features/voice/voice_intro_screen.dart'},
    'intro_no': {'features/voice/voice_intro_screen.dart'},
    'help_routine': {'features/routine/edit_routine_screen.dart'},
    'help_routine_skip': {'features/onboarding/routine_onboarding_screen.dart'},
    'help_today': {'features/elder/elder_home_screen.dart', 'features/today/today_screen.dart'},
    'help_next_dose': {'features/elder/elder_home_screen.dart', 'features/today/today_screen.dart'},
    'help_confirm_done': {'features/reminder/reminder_screen.dart', 'features/today/dose_actions.dart'},
    // «كلّمني» بيعدّي من confirmGroup نفسها — الجملة بتتقال من dose_actions
    'help_later': {'features/today/dose_actions.dart'},
    'help_progress': {'features/adherence/adherence_card.dart'},
    'help_progress_missed': {'features/adherence/adherence_card.dart'},
    'help_tip': {'features/today/widgets/tip_card.dart'},
    'help_appointments': {'features/records/health_file_screen.dart', 'features/today/today_screen.dart'},
    'help_stock_low': {'features/today/widgets/refill_lines.dart'},
    'help_not_bought': {'features/medication/not_bought.dart'},
    'help_add_med': {'features/medication/add_sheet.dart'},
    'help_scan': {'features/medication/scan_package_screen.dart', 'features/scan/scan_prescription_screen.dart'},
    'help_review': {'features/scan/review_prescription_screen.dart'},
    'help_bought': {'features/scan/review_prescription_screen.dart'},
    'help_purpose': {'features/medication/add_medication_screen.dart'},
    'help_pattern': {'features/medication/add_medication_screen.dart'},
    'help_timing': {'features/medication/add_medication_screen.dart'},
    'help_start_date': {'features/medication/add_medication_screen.dart'},
    'help_alert_mode': {'features/medication/add_medication_screen.dart'},
    'help_photo': {'features/medication/med_photo.dart'},
    'help_instructions': {'features/medication/edit_medication_screen.dart'},
    'help_papers': {'features/records/health_file_screen.dart'},
    'help_doctor': {'features/doctor/doctor_page_screen.dart', 'features/records/health_file_screen.dart'},
    'help_vitals': {'features/health/vitals/vital_history_screen.dart', 'features/records/health_file_screen.dart'},
    'help_vitals_add': {'features/health/vitals/vital_entry_sheet.dart'},
    'help_family': {'features/settings/settings_screen.dart'},
    'help_invite_code': {'features/link/link_code_screen.dart'},
    'help_nurse': {'features/link/link_code_screen.dart'},
    'help_family_plan': {'features/billing/family_plan_screen.dart'},
    'help_emergency': {'features/emergency/emergency_card_screen.dart'},
    'help_settings_voice': {'features/voice/voice_settings_screen.dart'},
    'help_elder_mode': {'features/settings/settings_screen.dart'},
    'gen_no_medical': {'features/health/vitals/vital_history.dart', 'features/voice/command_flow.dart'},
    'gen_saved': {'features/health/vitals/vital_entry_sheet.dart', 'features/medication/add_medication_screen.dart', 'features/medication/edit_medication_screen.dart'},
    // + «اتكلم» لما المايك ما يشتغلش (مش الإذن) — مرة، والزرار بيختفي
    'gen_try_hands': {'features/medication/scan_package_screen.dart', 'features/scan/scan_prescription_screen.dart', 'features/voice/command_flow.dart', 'features/voice/listen_button.dart', 'features/voice/listen_flow.dart'},
    'gen_goodbye': {'features/voice/voice_settings_screen.dart'},
    'lis_not_understood': {'features/voice/listen_flow.dart', 'features/voice/command_flow.dart'},
    // «صح كده؟» المسجّلة بتتقال من الدورتين، ومكتوبة تحت الكلام الكبير في الورقتين
    'lis_confirm': {'features/voice/listen_flow.dart', 'features/voice/command_flow.dart', 'features/voice/listen_button.dart', 'features/voice/talk_button.dart'},
    'lis_mic_permission': {'features/voice/listen_flow.dart', 'features/voice/command_flow.dart'},
    'lis_mic_denied': {'features/voice/listen_flow.dart', 'features/voice/command_flow.dart'},
    // «كلّمني» — كل جمل الأوامر في الدورة الواحدة
    'cmd_hint': {'features/voice/command_flow.dart'},
    'cmd_thinking': {'features/voice/command_flow.dart'},
    'cmd_cancelled': {'features/voice/command_flow.dart'},
    'cmd_done': {'features/voice/command_flow.dart'},
    'cmd_limit': {'features/voice/command_flow.dart'},
    'onb_entry': {'features/entry/entry_screen.dart'},
    'onb_name': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_gender': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_age': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_wake': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_breakfast': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_lunch': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_dinner': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_sleep': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_routine_skip': {'features/onboarding/routine_onboarding_screen.dart'},
    'onb_routine_done': {'features/onboarding/routine_onboarding_screen.dart'},
};

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('voice_catalog.dart'))
      .toList();
  String rel(File f) => f.path.replaceFirst(RegExp(r'^lib/'), '');
  final src = {for (final f in files) rel(f): f.readAsStringSync()};
  final literal = RegExp(r"'((?:help|gen|intro|onb)_[a-z_0-9]+)'");

  test('كل رقم في الكتالوج بيتقال من مكان — ومفيش رقم من غير مكان', () {
    final unused = <String>[];
    for (final id in voiceLines.keys) {
      if (introSequence.contains(id)) continue;
      if (!src.values.any((s) => s.contains("'$id'"))) unused.add(id);
    }
    expect(unused, isEmpty, reason: 'جمل مسجّلة ومحدش بيقولها');
    expect(src.values.where((s) => s.contains('introSequence')), isNotEmpty, reason: 'المقدمة بتتقال');
    // المقدمة أول شاشة في تنزيلة جديدة (الجذر) — مش جوّه أسئلة البداية
    expect(src['app/root.dart'], contains('VoiceIntroScreen('));
    expect(src['features/onboarding/routine_onboarding_screen.dart'], isNot(contains('VoiceIntroScreen')));
  });

  test('كل «ساعدني» وكل speakLine على رقم موجود في الكتالوج', () {
    final missing = <String>[];
    for (final e in src.entries) {
      for (final m in literal.allMatches(e.value)) {
        if (!voiceLines.containsKey(m.group(1))) missing.add('${e.key}: ${m.group(1)}');
      }
    }
    expect(missing, isEmpty, reason: 'زرار بيدوّر على جملة مش موجودة = زرار ساكت');
  });

  test('كل جملة في مكانها بالظبط — زي جدول المراجعة', () {
    expect(placement.keys.toSet(), {...voiceLines.keys}.difference(introSequence.toSet()));
    for (final entry in placement.entries) {
      final actual = {
        for (final e in src.entries)
          if (e.value.contains("'${entry.key}'")) e.key,
      };
      expect(actual, entry.value, reason: '${entry.key} اتنقل أو اتضاف في مكان تاني');
    }
  });

  test('برّه البداية مفيش حاجة بتتقال لوحدها', () {
    final users = [
      for (final e in src.entries)
        if (e.value.contains('OnboardingVoice(')) e.key,
    ];
    expect(users.every((f) => f.startsWith('features/onboarding/') || f.startsWith('features/entry/')), isTrue,
        reason: users.join(', '));
    for (final e in src.entries) {
      if (e.key.startsWith('features/onboarding/') || e.key.startsWith('features/entry/')) continue;
      expect(e.value.contains("'onb_"), isFalse, reason: '${e.key} بيقول جملة بداية');
    }
  });

  // ── التطبيق الحقيقي، بالترتيب الحقيقي ─────────────────────────────────
  //
  // **ليه الجدول فوق ما مسكش «onb_name على شاشة التسجيل»**: هو بيقرا المصدر
  // — «الرقم ده مكتوب في أنهي ملف» — و`onb_name` مكتوب فعلاً في ملف أسئلة
  // البداية، في الصفحة الصح. العطل كان **وقت التشغيل**: الجذر كان بيبني أسئلة
  // البداية **تحت** شاشة التسجيل (`_patientPath` قبل الـpush)، فجملة الاسم
  // بتتقال والمريض لسه قدّام التسجيل. وحفظ الجنس كان بيقلب فرع الجذر ويبني
  // أسئلة البداية تاني — State تانية بتعيد جملة الصفحة والأولى لسه بتتقال.
  // واختبار البداية القديم كان بيبني الشاشة لوحدها، من غير الجذر ولا شاشة
  // التسجيل ولا الفرع — فالاتنين كانوا برّه عينه. الاختبار ده بيمشي من
  // «مين ماسك التليفون ده؟» لحد «يومك»، بجمل بتاخد وقت.
  testWidgets('المسار الحقيقي: كل شاشة بجملتها بس، مرة — ولا جملة بتتقطع وتتعاد، والبكرة وإعادة البناء ما بيعيدوش حاجة',
      (tester) async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true, VoiceService.introDoneKey: true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final routines = RoutineRepository(db);
    final meds = MedicationRepository(db, clock: seededLongAgo);
    final patientId = await routines.ensurePatient();
    final player = TimedPlayer();
    final voice = VoiceService(player: player, tts: FakeTts());
    await voice.load();
    final services = AppServices(
      db: db,
      routines: routines,
      medications: meds,
      events: DoseEventRepository(db),
      scheduler: ReminderScheduler(
          routines: routines, medications: meds, events: DoseEventRepository(db), patientId: patientId, sink: SilentSink()),
      patientId: patientId,
      voice: voice,
    );
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget app() => AppScope(
          services: services,
          child: MaterialApp(
            theme: F.light,
            builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
            home: const AppRoot(),
          ),
        );
    // الجملة بتاخد ٣ ثواني — بنستنّاها تخلص قبل أي دوسة، زي حد بيسمع
    Future<void> wait([int seconds = 4]) async {
      for (var i = 0; i < seconds * 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    var seen = 0;
    /// الجمل اللي اتقالت من آخر مرة — بالظبط.
    List<String> fresh() {
      final out = player.played.sublist(seen);
      seen = player.played.length;
      return out;
    }

    await tester.pumpWidget(app());
    await wait();
    expect(fresh(), ['onb_entry'], reason: 'شاشة البداية');

    await tester.tap(find.byKey(const ValueKey('entry-self')));
    await wait(1);
    await tester.tap(find.byKey(const ValueKey('entry-start')));
    await wait();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(fresh(), isEmpty, reason: 'شاشة التسجيل مالهاش جملة — و«اسمك إيه؟» مش هنا');

    await tester.tap(find.text('كمّل من غير حساب'));
    await wait();
    expect(find.text('اسمك إيه؟'), findsOneWidget);
    expect(fresh(), ['onb_name'], reason: 'جملة الاسم على صفحة الاسم');

    await tester.enterText(find.byType(TextField), 'أحمد');
    await wait(1);
    await tester.tap(find.text('كمّل'));
    await wait();
    expect(fresh(), ['onb_gender']);

    await tester.tap(find.text('راجل'));
    await wait(1);
    await tester.tap(find.text('كمّل'));
    await wait();
    expect(fresh(), ['onb_age']);

    await tester.tap(find.text('كمّل'));
    await wait(8);
    expect(fresh(), ['onb_wake', 'onb_routine_skip'], reason: 'حفظ الجنس ما بيبنيش الأسئلة تاني');

    for (final line in ['onb_breakfast', 'onb_lunch', 'onb_dinner', 'onb_sleep']) {
      await tester.tap(find.text('تمام'));
      await wait();
      expect(fresh(), [line]);
      // بكرة، إعادة بناء الشجرة كلها، وسكوت طويل — ولا حاجة بتتعاد
      await tester.drag(find.byKey(FTimeWheel.minutesKey).last, const Offset(0, -120));
      await wait(1);
      await tester.pumpWidget(app());
      await wait(30);
      expect(fresh(), isEmpty, reason: '$line اتعادت لوحدها');
    }

    await tester.tap(find.text('تمام'));
    await wait(6);
    expect(fresh(), ['onb_routine_done']);
    expect(find.byType(AppShell), findsOneWidget);
    expect(player.cut, isEmpty, reason: 'ولا جملة اتقطعت عشان جملة تانية تبدأ مكانها');

    // زي screenTest: شجرة فاضية تصرّف مؤقّتات drift قبل ما الاختبار يقفل
    await tester.pumpWidget(const SizedBox.shrink());
    await wait(2);
  });

  test('المايك في مكانين بس: شاشة التذكير («اتكلم») و«كلّمني» — ومفيش مايك في البداية', () {
    final listen = {
      for (final e in src.entries)
        if (e.value.contains('ListenButton<') && e.key != 'features/voice/listen_button.dart') e.key,
    };
    expect(listen, {'features/reminder/reminder_screen.dart'});
    final talk = {
      for (final e in src.entries)
        if (e.value.contains('TalkButton(') && e.key != 'features/voice/talk_button.dart') e.key,
    };
    expect(talk, {'features/today/today_screen.dart', 'features/elder/elder_home_screen.dart'});
    for (final f in src.keys.where((k) => k.startsWith('features/onboarding/') || k.startsWith('features/entry/'))) {
      expect(src[f], isNot(contains('ListenButton')), reason: f);
      expect(src[f], isNot(contains('listen_button.dart')), reason: f);
    }
  });
}
