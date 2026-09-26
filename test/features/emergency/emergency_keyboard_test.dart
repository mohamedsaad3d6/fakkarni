import 'dart:async' show unawaited;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/app/app_scope.dart';
import 'package:fakkarni/app/shell.dart';
import 'package:fakkarni/core/theme/tokens.dart';
import 'package:fakkarni/core/widgets/keyboard_dismiss.dart';
import 'package:fakkarni/data/db/app_database.dart';
import 'package:fakkarni/data/repositories/dose_event_repository.dart';
import 'package:fakkarni/data/repositories/medication_repository.dart';
import 'package:fakkarni/data/repositories/preferences_repository.dart';
import 'package:fakkarni/data/repositories/routine_repository.dart';
import 'package:fakkarni/data/services/reminder_plan.dart';
import 'package:fakkarni/data/services/reminder_scheduler.dart';
import 'package:fakkarni/data/services/reminder_sink.dart';
import 'package:fakkarni/features/emergency/emergency_edit_screen.dart';

import '../../support/seeded_clock.dart';
import '../scan/scan_test_support.dart' show screenTest, settle;
import 'emergency_test.dart' show normalDay;

class _Sink implements ReminderSink {
  @override
  Future<void> schedule(PlannedNotification n) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<Set<int>> pendingIds() async => {};
  @override
  Future<void> ensurePermissions() async {}
}

/// **العطل اللي على الآيفون، من أوله لآخره.**
///
/// «بيانات الطوارئ» بتحفظ وبتعمل `pop` وهي سايبة التركيز على حقل نص.
/// الحقل بيروح مع الشاشة، والكيبورد بيفضل مفتوح على «يومك» من غير حاجة
/// تقفله — والدوك المرفوع بيحط «ضيف» فوق «تأكيد الجرعة».
void main() {
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
        routines: routines,
        medications: meds,
        events: DoseEventRepository(db),
        patientId: patientId,
        sink: _Sink(),
        preferences: PreferencesRepository(db),
      ),
      patientId: patientId,
    );
  });

  tearDown(() => db.close());

  /// الهيكل الحقيقي جوّه نفس تركيب الجذر — المراقب والدّاعس مع بعض.
  Future<NavigatorState> pumpShell(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          navigatorKey: key,
          theme: F.light,
          navigatorObservers: [FakkarniNavigatorObserver()],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: KeyboardDismiss(child: child ?? const SizedBox.shrink()),
          ),
          home: AppShell(routine: normalDay, now: DateTime(2026, 8, 31, 14)),
        ),
      ),
    );
    await settle(tester);
    return key.currentState!;
  }

  screenTest('بعد الحفظ في «بيانات الطوارئ»: مفيش كيبورد ولا تركيز على «يومك»',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final nav = await pumpShell(tester);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const EmergencyEditScreen())));
    await settle(tester);

    // الواحد بيكتب — الكيبورد بيطلع
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'بنسلين');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    // وبيحفظ
    await tester.tap(find.text('احفظ'));
    await settle(tester);
    await settle(tester);

    expect(find.byType(EmergencyEditScreen), findsNothing, reason: 'الشاشة المفروض قفلت');
    expect(tester.testTextInput.isVisible, isFalse,
        reason: 'الكيبورد فضل مفتوح على «يومك» — ده العطل نفسه');
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
      reason: 'التركيز فاضل على حقل مشالت شاشته',
    );
  });

  screenTest('الدوك و«ضيف» بيختفوا والكيبورد مرفوع — مش بيقعدوا فوق «تأكيد الجرعة»',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShell(tester);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);

    // الكيبورد بيطلع → الحشو من تحت بيزيد
    tester.view.viewInsets = const FakeViewPadding(bottom: 700);
    addTearDown(() => tester.view.resetViewInsets());
    // **`pump` واحدة مش كفاية**: `Scaffold` بيطلّع الزرار العايم بحركة
    // تصغير، فالزرار القديم بيفضل في الشجرة لحد ما الحركة تخلص. نبضة
    // واحدة كانت بتلاقيه لسه موجود ويقع الاختبار على حاجة صح.
    await settle(tester);

    expect(find.text('ضيف'), findsNothing, reason: '«ضيف» فضل فوق المحتوى');
    expect(find.text('اليوم'), findsNothing, reason: 'الدوك فضل مرفوع فوق المحتوى');
    expect(find.text('القريب مني'), findsNothing);

    // وبيرجعوا لما يقفل
    tester.view.resetViewInsets();
    await settle(tester);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);
  });
}
