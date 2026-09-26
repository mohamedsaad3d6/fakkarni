// **كتلة «الآن» الواحدة** — العدّاد، المأجّلة، التأكيد بالسطر، والطيّ.
//
// العطل اللي الجولة دي عنه: تلات أدوية مأجّلة كانت تلات كروت مكدّسة —
// الراجل مش عارف هما كام ولا مين فيهم من غير ما ينزل ويعدّ.
//
// **الداتا هي هي.** التأجيل وجدولته والسلّم ما اتلمسوش؛ اللي اتغيّر إن
// نفس الأحداث بتتعرض في كتلة بعدّادها.
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/app/shell.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/core/widgets/patient_voice.dart';
import 'package:fakkarni/data/db/app_database.dart';
import 'package:fakkarni/data/dose_state.dart';
import 'package:fakkarni/data/repositories/dose_event_repository.dart';
import 'package:fakkarni/data/repositories/medication_repository.dart';
import 'package:fakkarni/data/repositories/routine_repository.dart';
import 'package:fakkarni/data/services/reminder_plan.dart';
import 'package:fakkarni/data/services/reminder_scheduler.dart';
import 'package:fakkarni/data/services/reminder_sink.dart';
import 'package:fakkarni/domain/patient/sex.dart';
import 'package:fakkarni/domain/scheduling/day_routine.dart';
import 'package:fakkarni/domain/scheduling/dose_schedule.dart';
import 'package:fakkarni/features/today/today_screen.dart';
import 'package:fakkarni/features/today/dose_actions.dart';
import 'package:fakkarni/features/today/widgets/now_block.dart';

import '../../support/seeded_clock.dart';

final _routine = DayRoutine(
  wake: MinuteOfDay.hm(7),
  breakfast: MinuteOfDay.hm(7, 30),
  lunch: MinuteOfDay.hm(14, 30),
  dinner: MinuteOfDay.hm(20),
  sleep: MinuteOfDay.hm(23, 30),
);

final _aug31 = DateTime(2026, 8, 31);

/// ١٠:١٥ ص — الفطار (٧:٠٠) والصحيان (٧:٠٠) عدّوا، والغدا (٢:٠٠ م) لسه جاي.
final _now = DateTime(2026, 8, 31, 10, 15);

class _Sink implements ReminderSink {
  final List<PlannedNotification> scheduled = [];
  final List<int> cancelled = [];
  @override
  Future<void> schedule(PlannedNotification n) async => scheduled.add(n);
  @override
  Future<void> cancel(int id) async => cancelled.add(id);
  @override
  Future<Set<int>> pendingIds() async => scheduled.map((n) => n.id).toSet();
  @override
  Future<void> ensurePermissions() async {}
}

void main() {
  late AppDatabase db;
  late AppServices services;
  late MedicationRepository meds;
  late _Sink sink;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final routines = RoutineRepository(db);
    meds = MedicationRepository(db, clock: seededLongAgo);
    sink = _Sink();
    final patientId = await routines.ensurePatient();
    await routines.saveRoutine(patientId, _routine);
    services = AppServices(
      db: db,
      routines: routines,
      medications: meds,
      events: DoseEventRepository(db),
      scheduler: ReminderScheduler(
        routines: routines,
        medications: meds,
        events: DoseEventRepository(db),
        patientId: patientId,
        sink: sink,
      ),
      patientId: patientId,
    );
  });

  tearDown(() => db.close());

  /// جرعة على مرساة، بإزاحة — كل مرساة دقيقة مختلفة، فكل دوا سطر.
  Future<void> dose(String name, DayAnchor anchor, {int offset = 0}) =>
      meds.addMedication(
        patientId: services.patientId,
        name: name,
        timing: AnchorTiming(anchor, offset),
        startDate: _aug31,
        amountLabel: 'قرص واحد',
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  Future<void> pump(WidgetTester tester, {Size size = const Size(1000, 4000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          theme: F.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PatientVoice(
              say: Say(Sex.m),
              child: TodayScreen(routine: _routine, now: _now),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  void screenTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  /// **اسم الدوا بيتكرر على الشاشة** (السكة وجدول الأدوية)، فكل بحث عن
  /// اسم بيتقيّد بالكتلة — وإلا الاختبار بيقيس حاجة تانية.
  Finder inBlock(Finder matching) =>
      find.descendant(of: find.byType(NowBlock), matching: matching);

  /// بيأجّل كل اللي مستني من الكتلة — نفس زرار «لاحقًا».
  Future<void> postponeAll(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('now-later')));
    await settle(tester);
  }

  /// حالة كل دوا في **يوم الروتين ده** من القاعدة مباشرة.
  ///
  /// **`select` مش `watch().first`**: تيار drift بيرمي أول قيمة على نبضة
  /// مخزن الاستعلامات، والمنطقة الوهمية بتاعة `testWidgets` مش بتشغّلها —
  /// فالانتظار عليه بيعلّق من غير رسالة (الفخ المكتوب في «Testing
  /// conventions»).
  ///
  /// **وبفلتر اليوم**: `rescheduleAll` بتنزّل امبارح والنهارده وبكرة، فقراية
  /// من غير فلتر بترجّع صف بكرة `pending` وتخفي تأكيد النهارده — أداة
  /// قياس بتقيس حاجة تانية.
  Future<Map<String, String>> statesNow() async {
    final events = await (db.select(db.doseEvents)
          ..where((t) => t.routineDay.equalsValue(_aug31)))
        .get();
    final out = <String, String>{};
    for (final e in events) {
      final row = await db.customSelect(
        'SELECT m.name AS name FROM dose_schedules s '
        'JOIN medications m ON m.id = s.medication_id WHERE s.id = ?',
        variables: [Variable.withInt(e.doseScheduleId)],
      ).getSingle();
      out[row.read<String>('name')] = e.state.name;
    }
    return out;
  }

  /// رقم جدول الجرعة بتاع دوا بالاسم — لمفتاح زرار السطر.
  Future<int> scheduleOf(String name) async {
    final row = await db.customSelect(
      'SELECT s.id AS id FROM dose_schedules s '
      'JOIN medications m ON m.id = s.medication_id WHERE m.name = ?',
      variables: [Variable.withString(name)],
    ).getSingle();
    return row.read<int>('id');
  }

  group('١ — كتلة واحدة، والعدد في عنوانها', () {
    screenTest('تلات أدوية = كتلة واحدة وعنوان «الآن — ٣ أدوية»', (tester) async {
      await dose('Antodine', DayAnchor.wake);
      await dose('Concor', DayAnchor.breakfast);
      await dose('LINEX', DayAnchor.lunch, offset: -30);
      await pump(tester);

      expect(find.byType(NowBlock), findsOneWidget, reason: 'كتلة واحدة مش كارت لكل جرعة');
      expect(find.byKey(const ValueKey('now-block')), findsOneWidget);
      expect(find.text('الآن — ٣ أدوية'), findsOneWidget);
    });

    screenTest('ودوا واحد بيفضل «الآن» من غير عدّاد', (tester) async {
      await dose('Antodine', DayAnchor.breakfast);
      await pump(tester);

      expect(find.text('الآن'), findsOneWidget);
      expect(find.textContaining('أدوية'), findsNothing);
    });
  });

  group('٢ — «أجّلتها» بأساميها وبميعاد التذكير', () {
    screenTest('كل دوا مأجّل سطر، ومعاه «هيفكّرك …»', (tester) async {
      await dose('Antodine', DayAnchor.wake); // ٧:٠٠
      await dose('Concor', DayAnchor.breakfast); // ٧:٣٠
      await pump(tester);
      await postponeAll(tester);

      expect(find.byKey(const ValueKey('postponed-head')), findsOneWidget);
      expect(find.text('أجّلتها — دوايين'), findsNothing,
          reason: 'العدّاد رقم، مش مثنى — «أجّلتها — ٢»');
      expect(find.text('أجّلتها — ٢'), findsOneWidget);

      // **الميعاد اللي الإشعار اتجدول عليه بالحرف** — ١٠:١٥ + ١٥ د
      expect(find.text('هيفكّرك ١٠:٣٠ ص'), findsNWidgets(2));
      for (final name in ['Antodine', 'Concor']) {
        expect(inBlock(find.text(name)), findsOneWidget, reason: '$name مش معروض باسمه');
      }
    });

    test('واللي لسه مستني بيتحط فوق اللي اتأجّل — ترتيب نقي', () {
      final wake = DateTime(2026, 8, 31, 7);
      final lunch = DateTime(2026, 8, 31, 14);
      DoseEventView v(String name, DateTime at) => DoseEventView(
            doseScheduleId: at.hour,
            medicationName: name,
            scheduledAt: at,
            state: DoseState.pending,
          );
      final groups = [
        [v('Antodine', wake)],
        [v('LINEX', lunch)],
      ];
      // الفايتة اتأجّلت، والجاية لسه مستنية
      final lines = nowLines(groups, {wake: DateTime(2026, 8, 31, 10, 30)});
      expect(lines.due.map((l) => l.dose.medicationName), ['LINEX']);
      expect(lines.postponed.map((l) => l.dose.medicationName), ['Antodine']);
    });

    screenTest('وعنوان المجموعة فوق سطورها', (tester) async {
      await dose('Antodine', DayAnchor.wake);
      await dose('Concor', DayAnchor.breakfast);
      await pump(tester);
      await postponeAll(tester);

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('postponed-head'))).dy,
        lessThan(tester.getTopLeft(inBlock(find.text('Antodine'))).dy),
      );
    });
  });

  group('٣ — تأكيد سطر، وتأكيد الكل', () {
    screenTest('تأكيد دوا واحد بيسيب الباقي مكانه', (tester) async {
      await dose('Antodine', DayAnchor.wake);
      await dose('Concor', DayAnchor.breakfast);
      await pump(tester);

      await tester.tap(find.byKey(ValueKey('confirm-${await scheduleOf('Antodine')}')));
      await settle(tester);

      final after = await statesNow();
      expect(after['Antodine'], DoseState.taken.name);
      // **مش «pending» بالحرف**: الجرعة اللي عدّى عليها المهلة بيكتبها
      // الجهاز «اتنست» في `rescheduleAll` — الاتنين معناهم «ما اتاخدتش».
      expect(after['Concor'], isNot(DoseState.taken.name), reason: 'التاني ما اتلمسش');
      // والشاشة بقت عن دوا واحد
      expect(find.text('الآن'), findsOneWidget);
      expect(inBlock(find.text('Concor')), findsOneWidget);
    });

    screenTest('**وحتى لو في نفس الدقيقة**: التأكيد على واحد بس', (tester) async {
      // الحالة الخطرة: دواءين على نفس المرساة = نفس الدقيقة = مجموعة
      // واحدة. تأكيد سطر لازم يمشي على **جرعته هو**، مش على مجموعته —
      // وإلا دوا ما خدهوش بيتسجّل إنه اتاخد.
      await dose('Antodine', DayAnchor.breakfast);
      await dose('Vitamin D', DayAnchor.breakfast);
      await pump(tester);

      expect(find.text('الآن — دوايين'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('confirm-${await scheduleOf('Antodine')}')));
      await settle(tester);

      final after = await statesNow();
      expect(after['Antodine'], DoseState.taken.name);
      expect(after['Vitamin D'], isNot(DoseState.taken.name),
          reason: 'جاره في نفس الدقيقة اتسجّل إنه اتاخد وهو ما اتاخدش');
    });

    screenTest('«تأكيد الكل» بيأكّد كل سطر في الكتلة', (tester) async {
      await dose('Antodine', DayAnchor.wake);
      await dose('Concor', DayAnchor.breakfast);
      await dose('LINEX', DayAnchor.lunch, offset: -30);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('confirm-all')));
      await settle(tester);

      for (final MapEntry(key: name, value: state) in (await statesNow()).entries) {
        expect(state, DoseState.taken.name, reason: '$name ما اتأكدش');
      }
      expect(find.byType(NowBlock), findsNothing);
    });

    screenTest('و«تأكيد الكل» بيشمل المأجّل كمان', (tester) async {
      await dose('Antodine', DayAnchor.wake);
      await dose('Concor', DayAnchor.breakfast);
      await pump(tester);
      await postponeAll(tester);

      await tester.tap(find.byKey(const ValueKey('confirm-all')));
      await settle(tester);
      for (final state in (await statesNow()).values) {
        expect(state, DoseState.taken.name);
      }
    });

    screenTest('**ودوا واحد = زرار واحد** — مفيش تأكيدين بنفس المعنى', (tester) async {
      await dose('Antodine', DayAnchor.breakfast);
      await pump(tester);

      expect(find.byKey(const ValueKey('confirm-all')), findsOneWidget);
      expect(find.text('تأكيد الجرعة'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NowBlock),
          matching: find.widgetWithText(OutlinedButton, 'تأكيد'),
        ),
        findsNothing,
      );
    });
  });

  group('٤ — الكتلة بتفضل قصيرة', () {
    Future<void> five() async {
      await dose('Antodine', DayAnchor.wake); // ٧:٠٠
      await dose('Concor', DayAnchor.breakfast); // ٧:٣٠
      await dose('Zestril', DayAnchor.breakfast, offset: 30); // ٨:٠٠
      await dose('Glucophage', DayAnchor.breakfast, offset: 60); // ٨:٣٠
      await dose('Telfast', DayAnchor.breakfast, offset: 90); // ٩:٠٠
    }

    screenTest('خمسة = تلاتة و«+ دواين كمان»، والدوسة بتفرد', (tester) async {
      await five();
      await pump(tester);

      expect(find.text('الآن — ٥ أدوية'), findsOneWidget);
      expect(inBlock(find.text('Antodine')), findsOneWidget);
      expect(inBlock(find.text('Zestril')), findsOneWidget);
      expect(inBlock(find.text('Glucophage')), findsNothing, reason: 'الرابع اتطوى');
      expect(find.text('+ دواين كمان'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('now-more')));
      await settle(tester);
      expect(inBlock(find.text('Glucophage')), findsOneWidget);
      expect(inBlock(find.text('Telfast')), findsOneWidget);
      expect(find.byKey(const ValueKey('now-more')), findsNothing);
    });

    screenTest('وأربعة = «+ دوا كمان» بالمفرد', (tester) async {
      await dose('Antodine', DayAnchor.wake);
      await dose('Concor', DayAnchor.breakfast);
      await dose('Zestril', DayAnchor.breakfast, offset: 30);
      await dose('Glucophage', DayAnchor.breakfast, offset: 60);
      await pump(tester);

      expect(find.text('+ دوا كمان'), findsOneWidget);
      expect(find.textContaining('+١'), findsNothing, reason: 'رقم لوحده مش كلام');
    });
  });

  group('٥ — ولا زرار مغطّى على أصغر آيفون', () {
    // iPhone SE: ٣٧٥×٦٦٧ نقطة.
    const se = Size(375, 667);

    for (final scale in [1.0, 1.3]) {
      screenTest('«تأكيد الكل» مش مغطّى بالدوك ولا بزرار عايم — خط ×$scale',
          (tester) async {
        await dose('Antodine', DayAnchor.wake);
        await dose('Concor', DayAnchor.breakfast);
        await dose('LINEX', DayAnchor.lunch, offset: -30);

        tester.view.physicalSize = se;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          AppScope(
            services: services,
            child: MaterialApp(
              theme: F.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(textDirection: TextDirection.rtl, child: child!),
              ),
              home: AppShell(routine: _routine, now: _now),
            ),
          ),
        );
        await settle(tester);

        // **الكتلة أطول من شاشة SE بتلات أدوية، فالصفحة بتتزحلق.**
        // القاعدة مش «كله في أول شاشة» — القاعدة إن الزرار **مش
        // مغطّى**: بعد ما ينزل له، الدوك والزرار العايم فوقه ممنوعين.
        // **حد الكروم العايم بيتقاس من الكروم نفسه**، مش برقم مكتوب:
        // الدوك و«ضيف» و«القريب مني» بيعوموا فوق الجسم، وأول واحد فيهم
        // من فوق هو السقف اللي الزرار لازم يفضل فوقه.
        double chromeTop() {
          var top = se.height;
          for (final key in ['القريب مني', 'ضيف', 'اليوم']) {
            final f = find.text(key);
            if (f.evaluate().isEmpty) continue;
            final t = tester.getRect(f).top;
            if (t < top) top = t;
          }
          return top;
        }

        final button = find.byKey(const ValueKey('confirm-all'));
        expect(button, findsOneWidget);
        for (var i = 0; i < 12; i++) {
          final over = tester.getRect(button).bottom - chromeTop();
          if (over <= 0) break;
          await tester.drag(find.byType(ListView), Offset(0, -(over + 8)));
          await settle(tester);
        }
        final box = tester.getRect(button);
        expect(box.bottom, lessThanOrEqualTo(chromeTop()),
            reason: 'مقدرناش نوصّل الزرار فوق الكروم العايم بالزحلقة');
        expect(box.top, greaterThanOrEqualTo(0.0), reason: 'الزرار طلع برّه من فوق');
        for (final key in ['القريب مني', 'ضيف', 'اليوم']) {
          final other = find.text(key);
          if (other.evaluate().isEmpty) continue;
          expect(tester.getRect(other).overlaps(box), isFalse,
              reason: '«$key» فوق زرار التأكيد');
        }
      });
    }
  });
}
