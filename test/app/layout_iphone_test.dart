// تخطيط على آيفون SE (٣٧٥×٦٦٧) بالخطوط الحقيقية — من تجربة الجهاز (٢٦
// سبتمبر ٢٠٢٦): كلمات الدوك راكبة على بعض، «ضيف» و«القريب مني» فوق كارت
// الجرعة وفوق «امسح حسابي»، والشريط العلوي شفّاف والصفحة بتعدّي تحته.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/app/shell.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/data/db/app_database.dart';
import 'package:fakkarni/data/repositories/dose_event_repository.dart';
import 'package:fakkarni/data/repositories/medication_repository.dart';
import 'package:fakkarni/data/repositories/routine_repository.dart';
import 'package:fakkarni/data/services/reminder_scheduler.dart';
import 'package:fakkarni/domain/scheduling/day_routine.dart';
import 'package:fakkarni/domain/scheduling/dose_schedule.dart';

import '../features/scan/scan_test_support.dart' show normalDay, RecordingSink;
import '../support/seeded_clock.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await load('IBM Plex Sans Arabic', [
    'IBMPlexSansArabic-Regular.ttf',
    'IBMPlexSansArabic-Medium.ttf',
    'IBMPlexSansArabic-SemiBold.ttf',
    'IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('Alexandria', ['Alexandria-Medium.ttf', 'Alexandria-Bold.ttf']);
  await load('IBM Plex Mono', ['IBMPlexMono-Medium.ttf', 'IBMPlexMono-SemiBold.ttf']);
}

void main() {
  setUpAll(_loadFonts);

  late AppDatabase db;
  late AppServices services;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final routines = RoutineRepository(db);
    final meds = MedicationRepository(db, clock: seededLongAgo);
    final patientId = await routines.ensurePatient();
    await routines.saveRoutine(patientId, normalDay);
    services = AppServices(
      db: db,
      routines: routines,
      medications: meds,
      events: DoseEventRepository(db),
      scheduler: ReminderScheduler(
          routines: routines, medications: meds, events: DoseEventRepository(db), patientId: patientId, sink: RecordingSink()),
      patientId: patientId,
    );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  Future<void> pumpSe(WidgetTester tester, Widget home, {double scale = 1.0}) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AppScope(
      services: services,
      child: MaterialApp(
        theme: F.light,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
        home: home,
      ),
    ));
    await settle(tester);
  }

  /// ولا كلمتين في الدوك بيلمسوا بعض — وبينهم ٤ بكسل على الأقل.
  void expectLabelsApart(WidgetTester tester, List<String> labels) {
    final rects = [for (final l in labels) tester.getRect(find.text(l).last)];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        final a = rects[i], b = rects[j];
        // المسافة بين الصندوقين (سالب = راكبين)
        final gap = (a.left - b.right) > (b.left - a.right) ? a.left - b.right : b.left - a.right;
        expect(gap, greaterThanOrEqualTo(4), reason: '«${labels[i]}» و«${labels[j]}» لازقين/راكبين ($gap بكسل)');
      }
      expect(rects[i].left, greaterThanOrEqualTo(0));
      expect(rects[i].right, lessThanOrEqualTo(375));
    }
  }

  for (final scale in [1.0, 1.3]) {
    screenTestish('الدوك على ٣٧٥ (خط ×$scale): «الملف الطبي» و«الإعدادات» ما بيركبوش على بعض', (tester) async {
      await pumpSe(tester, AppShell(routine: normalDay, now: DateTime(2026, 8, 31, 6)), scale: scale);
      expectLabelsApart(tester, AppShell.tabs);
    });
  }

  screenTestish('نمط كبار السن على ٣٧٥: كلمتين الدوك بعيد عن بعض', (tester) async {
    await services.preferences.setElderMode(true);
    await pumpSe(tester, AppShell(routine: normalDay, now: DateTime(2026, 8, 31, 6)), scale: 1.3);
    expectLabelsApart(tester, AppShell.elderTabs);
  });

  screenTestish('الشريط العلوي مصمت بلون الصفحة — من غير خط ولا ظل، حتى بعد اللفّ (المالك رجّعهم)', (tester) async {
    await pumpSe(tester, AppShell(routine: normalDay, now: DateTime(2026, 8, 31, 6)));
    final bar = tester.getRect(find.byType(AppBar).first);
    Material barMaterial() => tester.widget<Material>(
        find.descendant(of: find.byType(AppBar).first, matching: find.byType(Material)).first);
    expect(barMaterial().color, F.pageGround, reason: 'نفس لون الصفحة، مصمت');
    expect(barMaterial().color?.a, 1.0);
    expect(barMaterial().shape, isNot(isA<Border>()), reason: 'الخط اللي تحت اترجع');
    // المحتوى بيتقصّ عند حافة الشريط — مش تحته
    expect(tester.getRect(find.byType(ListView).first).top, greaterThanOrEqualTo(bar.bottom));
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await settle(tester);
    expect(barMaterial().elevation, 0, reason: 'ولا ظل بعد اللفّ');
  });

  for (final scale in [1.0, 1.3]) {
    screenTestish('«القريب مني» عايم وظاهر دايماً (×$scale) — وآخر صف بيطلع فوقه كله بعد اللفّ', (tester) async {
      final meds = services.medications;
      for (final (n, a) in [('Concor', DayAnchor.breakfast), ('Telfast', DayAnchor.lunch), ('Aspocid', DayAnchor.dinner)]) {
        await meds.addMedicationWithDoses(patientId: services.patientId, name: n, timings: [AnchorTiming(a, -30)], startDate: DateTime(2026, 8, 1));
      }
      await pumpSe(tester, AppShell(routine: normalDay, now: DateTime(2026, 8, 31, 7, 35)), scale: scale);
      final pillFinder = find.byKey(const ValueKey('nearby-pill'));
      expect(find.ancestor(of: pillFinder, matching: find.byType(ListView)), findsNothing, reason: 'عايم، مش سطر');
      expect(find.ancestor(of: pillFinder, matching: find.byType(AnimatedOpacity)), findsNothing, reason: 'ظاهر دايماً — مفيش إخفا');
      final pill = tester.getRect(pillFinder);
      final dock = tester.getRect(find.text('اليوم').last);
      expect(pill.bottom, lessThan(dock.top), reason: 'فوق الدوك، في مكانه القديم');

      // لحد الآخر فعلاً — القايمة بتبني صفوفها وهي بتتلف، فطولها بيكبر
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
        await settle(tester);
      }
      final texts = find.descendant(of: find.byType(ListView).first, matching: find.byType(Text));
      final under = [
        for (final e in texts.evaluate())
          if (tester.getRect(find.byWidget(e.widget)).overlaps(pill)) (e.widget as Text).data ?? '',
      ];
      expect(under, isEmpty, reason: 'ولا نص تحت «القريب مني» بعد اللفّ للآخر');
      // وهدف اللمس ٥٦ والشكل ٤٤
      expect(tester.getSize(find.ancestor(of: pillFinder, matching: find.byType(GestureDetector)).first).height, greaterThanOrEqualTo(56));
      expect(pill.height, 44);
    });
  }

  for (final scale in [1.0, 1.3]) {
    screenTestish('الإعدادات على SE (×$scale): «امسح حسابي» بيطلع كله فوق «ضيف»', (tester) async {
      await pumpSe(tester, AppShell(routine: normalDay, now: DateTime(2026, 8, 31, 6)), scale: scale);
      await tester.tap(find.text('الإعدادات').last);
      await settle(tester);
      final list = find.byType(ListView).last;
      await tester.drag(list, const Offset(0, -6000));
      await settle(tester);
      final delete = tester.getRect(find.byKey(const ValueKey('settings-delete-account')));
      final add = tester.getRect(find.byType(FloatingActionButton));
      final dockTop = tester.getRect(find.text('اليوم').last).top;
      expect(delete.bottom, lessThanOrEqualTo(add.top), reason: '«ضيف» فوق «امسح حسابي»');
      expect(delete.bottom, lessThanOrEqualTo(dockTop));
    });
  }

}

/// زي screenTest: شجرة فاضية بتصرّف مؤقّتات drift قبل ما الاختبار يقفل.
void screenTestish(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
