import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/widgets/shell_bottom_extra.dart';
import '../core/widgets/keyboard_dismiss.dart';
import '../core/widgets/fa_mark.dart';
import '../core/widgets/dark_mode_toggle.dart';
import '../data/repositories/preferences_repository.dart';
import '../domain/scheduling/day_routine.dart';
import '../features/care/caregiver_medications_screen.dart';
import '../features/care/caregiver_health_screen.dart';
import '../features/care/caregiver_screen.dart';
import '../data/care/caregiver_remote.dart' show CaregiverPatient, MultiPatientRemote;
import '../features/nurse/nurse_controller.dart';
import '../features/nurse/nurse_header.dart';
import '../features/nurse/nurse_medications_screen.dart';
import '../features/nurse/nurse_records_screen.dart';
import '../features/nurse/nurse_reminders.dart';
import '../features/nurse/nurse_today_screen.dart';
import '../features/care/onboarding/caregiver_onboarding_screen.dart';
import '../features/care/onboarding/onboarding_gate.dart';
import '../features/care/caregiver_snapshot_holder.dart';
import '../features/care/caregiver_settings_screen.dart';
import '../features/elder/elder_home_screen.dart';
import '../features/emergency/emergency_pill.dart';
import '../features/medication/add_sheet.dart';
import '../features/medication/medications_screen.dart';
import '../features/records/health_file_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'app_scope.dart';

/// هيكل التطبيق: شريط علوي + أربع تبويبات + زرار «ضيف» في النص.
///
/// التبويبات: اليوم · الأدوية · العائلة · الإعدادات. «الملف» بتاع التصميم
/// مش موجود لأنه مالوش باك إند — مكانه «الإعدادات». زرار «طوارئ» فوق
/// (D3.4) بيفتح البطاقة بلمسة، بحدّ حبر مش أحمر.
///
/// كل زرار هنا بكلمة — حتى الـ«+». القاعدة: مفيش زرار أيقونة من غير كلمة.
/// الشريط العلوي علامة ف بس.
///
/// **نمط كبار السن** (D3.3، المخطط 18): تبويبتين بس — «الرئيسية» (كارت جرعة
/// واحد) و«الإعدادات» — ومن غير «ضيف». التبويب التاني هو الإعدادات عشان
/// ده الطريق الوحيد للخروج من النمط؛ «📞 اتصل» بتاع التصميم مش مبني.
class AppShell extends StatefulWidget {
  const AppShell({required this.routine, this.now, super.key});

  final DayRoutine routine;

  /// للاختبارات.
  final DateTime? now;

  /// المخطط ٤: «الملف» مكان «الإعدادات». الإعدادات ما اختفتش — بقت أيقونة
  /// الشخص في الشريط العلوي (نفس اسمها، ومفيش صف بيضيع).
  static const tabs = ['اليوم', 'الأدوية', 'الملف الطبي', 'الإعدادات'];
  static const elderTabs = ['الرئيسية', 'الإعدادات'];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _elderTab = 0;
  Stream<DeviceSettings>? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings ??= AppScope.of(context).preferences.watch();
  }

  /// الشيت نفسه معرّف مرة واحدة في `add_sheet.dart` — بيتفتح من هنا ومن
  /// كارت «ضيف دوا» في جدول الأدوية.
  void _openAdd() => showAddSheet(context, routine: widget.routine);

  @override
  Widget build(BuildContext context) => StreamBuilder<DeviceSettings>(
        stream: _settings,
        builder: (context, snap) =>
            snap.data?.elderMode ?? false ? _buildElder(context) : _buildNormal(context),
      );

  AppBar _appBar() => AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: F.gap,
        actions: [
          // الفولدر سابه للدوك («الملف»)، ومكان الشخص بقى مفتاح الوضع الليلي.
          const DarkModeToggle(),
          const Padding(
            padding: EdgeInsetsDirectional.only(end: F.gap),
            child: EmergencyPill(),
          ),
        ],
        // علامة ف بس. «الإعدادات» تبويب تحت — زرار فوق كان تكرار.
        title: Row(
          children: [
            // على بلاطة خضرا عشان العاجي يبان
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: F.greenDeep,
                borderRadius: BorderRadius.circular(F.radiusTile),
              ),
              alignment: Alignment.center,
              child: const FaMark(size: 24, breathing: true),
            ),
          ],
        ),
      );

  Widget _buildElder(BuildContext context) => Scaffold(
        // الشاشة بتعدّي من تحت الدوك — من غير كده الزجاج مالوش حاجة يشفّ
        // عليها غير أرضية الصفحة، فبيبان مصمت.
        extendBody: true,
        appBar: _appBar(),
        body: IndexedStack(
          index: _elderTab,
          children: [
            ElderHomeScreen(routine: widget.routine, now: widget.now),
            const SettingsScreen(),
          ],
        ),
        // **الدوك بيختفي والكيبورد مرفوع** — الكيبورد بيزقّه لفوق فبيقعد
        // فوق المحتوى. شوف `keyboard_dismiss.dart`.
        bottomNavigationBar: keyboardIsUp(context)
            ? null
            : _TabBar(
          labels: AppShell.elderTabs,
          icons: const [Icons.home_outlined, Icons.settings_outlined],
          gapForAdd: false,
          labelSize: F.elderTextSize,
          current: _elderTab,
          onSelect: (i) => setState(() => _elderTab = i),
        ),
      );

  Widget _buildNormal(BuildContext context) {
    final pages = [
      TodayScreen(routine: widget.routine, now: widget.now),
      const MedicationsScreen(),
      const HealthFileScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: _appBar(),
      // **«ضيف» طالع فوق الدوك** (مركزه على حافته)، فكل تبويب بياخد طوله
      // الزيادة في `padding.bottom` — آخر حاجة في أي صفحة («امسح حسابي» في
      // الإعدادات) بتتزحلق لحد فوقه (آيفون، ٢٦ سبتمبر ٢٠٢٦: كان بيغطّيها).
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          final extra = keyboardIsUp(context) ? 0.0 : _AddButton.overhang;
          return MediaQuery(
            data: mq.copyWith(padding: mq.padding.copyWith(bottom: mq.padding.bottom + extra)),
            child: ShellBottomExtra(extra: extra, child: IndexedStack(index: _tab, children: pages)),
          );
        },
      ),
      // **الدوك و«ضيف» بيختفوا والكيبورد مرفوع** — ده اللي كان بيحط «ضيف»
      // فوق «تأكيد الجرعة».
      floatingActionButton: keyboardIsUp(context) ? null : _AddButton(onPressed: _openAdd),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: keyboardIsUp(context)
          ? null
          : _TabBar(
        labels: AppShell.tabs,
        icons: const [
          Icons.today_outlined,
          Icons.medication_outlined,
          Icons.folder_outlined,
          Icons.settings_outlined,
        ],
        gapForAdd: true,
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// هيكل تطبيق الابن (D4): تبويبين بس — «متابعة» و«الإعدادات».
///
/// **الابن مش مريض**: مفيش «يومك» ولا «ضيف» ولا محرر جرعة ولا رمضان ولا
/// اختصار «طوارئ» (بيانات طوارئ الأب محلية على موبايل الأب، وهنا كانت هتفتح
/// على شاشة فاضية). المتابعة للقراية بس — أي زرار بيغيّر بيانات الأب مش
/// موجود هنا خالص (`caregiver_shell_test` بيمشي على الشجرة ويثبت ده).
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({required this.onNotLinked, this.now, this.nurseSink, super.key});

  /// جهاز تذكيرات الممرض — null = الحقيقي (Flutter Local Notifications).
  final NurseReminderSink? nurseSink;

  /// السحابة قالت «مفيش مريض مربوط» → الجذر يرجّع لشاشة البداية.
  final VoidCallback onNotLinked;

  /// للاختبارات.
  final DateTime? now;

  /// «الأدوية» تبويب لوحده (جولة ٢٩): القايمة دي مرجع مش حالة، وكانت
  /// بتتزاحم مع شاشة «هو كويس؟» في آخرها. بنفس اسم وأيقونة تبويب الأب.
  static const tabs = ['متابعة', 'الأدوية', 'الملف الطبي', 'الإعدادات'];

  /// **حساب الممرض (٢٤ سبتمبر ٢٠٢٦، قرار المالك): مرآة كاملة لتطبيق
  /// المريض** — «يومك» و«أدويته» و«السجل» بمقاسات المريض، وترويسة ثابتة
  /// «بتتابع: {اسم}» فوق كل شاشة. مش متابع بصلاحيات زيادة.
  static const nurseTabs = ['يومك', 'أدويته', 'الملف الطبي', 'الإعدادات'];

  /// تبويبات البيانات — السؤال الدوري شغّال وواحد منهم ظاهر.
  static const dataTabs = {0, 1, 2};

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _tab = 0;

  /// صورة واحدة للتبويبين (D5.2): سحبة واحدة لكل تحديث، مش سحبة لكل تبويب.
  CaregiverSnapshotHolder? _holder;

  /// أفعال الممرض — بتتبني مع الحامل، وبتتستخدم بس لو المريض المختار
  /// علاقته «ممرض».
  NurseController? _nurse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_holder != null) return;
    final remote = AppScope.of(context).caregiver;
    if (remote == null) {
      // جلسة من غير سحابة مش ممكنة عملياً — بس لو حصلت، مفيش حاجة تتتابع
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onNotLinked());
      return;
    }
    // جهاز الإشعارات بتاع موبايل الابن — مواعيد الأب بتتجدول عليه
    // محلياً، لأن مفيش دفع من السيرفر لسه (iOS مستني APNs).
    _holder = CaregiverSnapshotHolder(
      remote,
      onNotLinked: widget.onNotLinked,
      sink: AppScope.of(context).scheduler.sink,
    )
      ..addListener(_onSnapshot)
      ..setActive(CaregiverShell.dataTabs.contains(_tab));
    _nurse = NurseController(holder: _holder!, services: AppScope.of(context));
    _nurseReminders = NurseReminders(
      sink: widget.nurseSink ?? const DeviceNurseReminderSink(),
      remote: remote is MultiPatientRemote ? remote as MultiPatientRemote : null,
      clock: widget.now == null ? null : () => widget.now!,
    );
  }

  NurseReminders? _nurseReminders;

  /// «فكّرني بمواعيده» — بعد كل صورة. المتابع العادي ما بيجدولش حاجة هنا.
  void _syncNurseReminders() {
    final holder = _holder;
    final reminders = _nurseReminders;
    if (holder == null || reminders == null) return;
    final anyNurse = holder.patients.any((p) => p.isNurse) || (holder.snapshot?.patient.isNurse ?? false);
    if (!anyNurse) return;
    unawaited(reminders.sync(
      patients: holder.patients.isEmpty ? [?holder.snapshot?.patient] : holder.patients,
      current: holder.snapshot,
      allowed: _nurse?.writesAllowed ?? true,
    ));
  }

  /// **الشِل بيسمع للصورة عشان البوابة تعرف المريض.**
  ///
  /// التبويبات بتسمع كل واحد لوحده، فالشِل نفسه ماكانش بيسمع — يعني كان
  /// بيتبني مرة والصورة لسه `null`، والبوابة عمرها ما تشوف uuid المريض.
  /// ده كان هيخلّي التوصيل «موجود» وهو مش شغّال.
  void _onSnapshot() {
    _syncNurseReminders();
    final patient = _holder?.snapshot?.patient;
    if (patient != null) {
      unawaited(_checkOnboarding(patient.uuid));
      // اشتراك العيلة على المريض المتابَع — الابن بيقرا حالته من هنا
      final sub = AppScope.of(context).subscription;
      if (sub != null && sub.patientUuid != patient.uuid) {
        sub.patientUuid = patient.uuid;
        unawaited(sub.refresh());
      }
    }
  }

  /// **بوابة أسئلة المتابع — ودي هي المدخل (أ) و(ب) مع بعض.**
  ///
  /// مكان واحد عن قصد: «بعد استبدال الكود» و«أول ما يفتح المتابعة» هما
  /// نفس اللحظة من ناحية الشاشة — الجذر بيبني الشِل في الحالتين. مدخلين
  /// منفصلين كانوا هيبقوا مكانين لنفس القرار، حر إن واحد فيهم يتنسي —
  /// وده بالظبط اللي حصل في الجولة اللي فاتت لما الشاشة اتبنت وما
  /// اتوصّلتش بحاجة.
  OnboardingDecision _onboarding = OnboardingDecision.unknown;
  String? _askedFor;

  /// بيسأل مرة لكل مريض في عمر الشاشة دي.
  Future<void> _checkOnboarding(String patientUuid) async {
    if (_askedFor == patientUuid) return;
    _askedFor = patientUuid;
    final decision = await decideOnboarding(
      patientUuid: patientUuid,
      preferences: AppScope.of(context).caregiverPreferences,
      seenLocally: onboardingSeen,
    );
    if (!mounted) return;
    // **القراءة فشلت؟ ما بنسألش وما بنسجّلش** — نجرّب تاني المرة الجاية.
    if (decision == OnboardingDecision.unknown) {
      _askedFor = null;
      return;
    }
    setState(() => _onboarding = decision);
  }

  void _select(int i) {
    setState(() => _tab = i);
    final holder = _holder;
    if (holder == null) return;
    final data = CaregiverShell.dataTabs.contains(i);
    // دخول تبويب بيانات = صورة طازة على طول، حتى لو جاي من التبويب التاني
    if (data && holder.active) holder.refresh();
    holder.setActive(data);
  }

  @override
  void dispose() {
    _holder?.removeListener(_onSnapshot);
    _nurse?.dispose();
    _holder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holder = _holder;
    if (holder == null) return const Scaffold();

    // المريض بيوصل مع أول صورة من السحابة — البوابة بتستنّاه.
    final patient = holder.snapshot?.patient;
    if (patient != null) {
      if (_onboarding == OnboardingDecision.ask) {
        // **قبل ما يشوف البيت، مش فوقه**: الشِل بيرسم الأسئلة بدل
        // التبويبات، فالمدخل (أ) «قبل ما يوصل شاشة المتابعة» متحقّق.
        return CaregiverOnboardingScreen(
          patientUuid: patient.uuid,
          patientName: patient.name,
          preferences: AppScope.of(context).caregiverPreferences!,
          onDone: () async {
            // خلّص — سواء جاوب أو تخطّى. **التسجيل المحلي هو اللي بيمنع
            // النقّ** كل فتحة على اللي تخطّى.
            await markOnboardingSeen(patient.uuid);
            if (mounted) setState(() => _onboarding = OnboardingDecision.skip);
          },
        );
      }
    }

    final isNurse = patient?.isNurse ?? false;
    if (isNurse) return _nurseApp(holder, patient);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          CaregiverScreen(
            remote: holder.remote,
            now: widget.now,
            onNotLinked: widget.onNotLinked,
            holder: holder,
          ),
          CaregiverMedicationsScreen(holder: holder),
          CaregiverHealthScreen(holder: holder, now: widget.now),
          Scaffold(body: SafeArea(child: CaregiverSettingsScreen(patient: patient))),
        ],
      ),
      // نفس القاعدة عند الابن: «الملف الصحي» عنده فيه بحث.
      bottomNavigationBar: keyboardIsUp(context)
          ? null
          : _TabBar(
        labels: CaregiverShell.tabs,
        icons: [
          Icons.visibility_outlined,
          Icons.medication_outlined,
          Icons.folder_outlined,
          Icons.settings_outlined,
        ],
        gapForAdd: false,
        current: _tab,
        onSelect: _select,
      ),
    );
  }

  /// **تطبيق الممرض** — تطبيق المريض بداتا المريض: «يومك» / «أدويته» /
  /// «السجل» بمقاسات المريض، و«بتتابع: {اسم}» ثابتة فوق كل تبويب بيانات.
  Widget _nurseApp(CaregiverSnapshotHolder holder, CaregiverPatient? patient) {
    final nurse = _nurse!;
    return Scaffold(
      extendBody: true,
      appBar: _tab == 3 ? null : NurseHeader(holder: holder),
      body: IndexedStack(
        index: _tab,
        children: [
          NurseTodayScreen(controller: nurse, now: widget.now),
          NurseMedicationsScreen(controller: nurse, now: widget.now),
          NurseRecordsScreen(controller: nurse, now: widget.now),
          Scaffold(
            body: SafeArea(
              child: CaregiverSettingsScreen(
                patient: patient,
                nurseReminders: true,
                onNurseRemindersChanged: _syncNurseReminders,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: keyboardIsUp(context)
          ? null
          : _TabBar(
              labels: CaregiverShell.nurseTabs,
              icons: const [
                Icons.today_outlined,
                Icons.medication_outlined,
                Icons.folder_outlined,
                Icons.settings_outlined,
              ],
              gapForAdd: false,
              current: _tab,
              onSelect: _select,
            ),
    );
  }
}

/// «ضيف» — دايرة زيتي بحد دهبي وعلامة + دهبي، **والكلمة تحتها**.
///
/// الشكل من طلب المالك؛ الكلمة باقية لأن «مفيش زرار أيقونة من غير كلمة»
/// اتكتبت لراجل عنده ٧٢ سنة. الكورال بتاع التصميم (`#F58A8E`) مش مستعمل:
/// بيقع بين الدهبي والأحمر وبياخد انتباه «دي لسه عايزاك».
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  static const double _circle = 62;

  /// قد إيه الزرار طالع فوق حافة الدوك: `centerDocked` بيحط **نص** الزرار
  /// (الدايرة + الكلمة تحتها) فوق الحافة — ونفَس.
  static const double overhang = (_circle + F.s4 + F.minTextSize * 1.6) / 2 + F.s8;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'ضيف',
        button: true,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _circle,
              height: _circle,
              child: FloatingActionButton(
                onPressed: onPressed,
                backgroundColor: F.greenDeep,
                foregroundColor: F.gold,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(31),
                  side: BorderSide(color: F.gold, width: 2.5),
                ),
                child: const Icon(Icons.add, size: 32),
              ),
            ),
            const SizedBox(height: F.s4),
            Text(
              'ضيف',
              style: TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w700, color: F.green),
            ),
          ],
        ),
      );
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.labels,
    required this.icons,
    required this.gapForAdd,
    required this.current,
    required this.onSelect,
    this.labelSize = F.minTextSize,
  });

  /// نمط كبار السن: ٢٤ — حتى في شريط التبويبات.
  final double labelSize;

  /// بين كل كلمة والتبويب اللي جنبها — مجموعهم فاصل ٨ بكسل على الأقل.
  static const double _labelInset = F.s4;

  /// سطر الكلمة — والشريط بيتحسب بيه، فالعمود ما بيفيضش.
  static const double _labelLineHeight = 1.3;

  final List<String> labels;
  final List<IconData> icons;

  /// فجوة في النص لزرار «ضيف» — نمط كبار السن مالوش «ضيف».
  final bool gapForAdd;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // دوك زي الماك: عايم، حوافه مستديرة بالكامل، زجاج شفّاف — والشاشة
    // بتعدّي من تحته وبتبان. كل أيقونة قاعدة على بلاطة مربعة مستديرة
    // (زي أيقونات الدوك)، واللي إنت فيه بلاطته خضرا.
    final radius = BorderRadius.circular(F.s30);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(F.s12, 0, F.s12, F.s10),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: F.pageGround.withValues(alpha: 0.35),
                borderRadius: radius,
                // حافة فاتحة من فوق زي حرف الزجاج في الماك
                border: Border.all(color: F.onDark.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: F.ink.withValues(alpha: 0.14), blurRadius: 26, offset: const Offset(0, 10)),
                ],
              ),
              child: SizedBox(
                // الطول بيتحسب من البلاطة + الكلمة بمقاسها الحقيقي (نمط كبار
                // السن ٢٤، وخط النظام ممكن يكبّرها كمان) — رقمين ثابتين كانوا
                // بيفيضوا ٦ بكسل أول ما البلاطة كبرت.
                height: 40 + F.s4 + MediaQuery.textScalerOf(context).scale(labelSize) * _labelLineHeight + F.s10,
                child: Row(
                  children: [
                    for (var i = 0; i < labels.length; i++) ...[
                      // فجوة في النص لزرار «ضيف»
                      if (gapForAdd && i == 2) const SizedBox(width: 96),
                      Expanded(
                        child: InkWell(
                          onTap: () => onSelect(i),
                          borderRadius: BorderRadius.circular(F.radiusCard),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // بلاطة أيقونة الدوك: مربع مستدير ٤٢، بتدرّج
                              // خفيف — اللي إنت فيه أخضر مصمت وأيقونته بيضا.
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    // البلاطة الهادية بأسطح دلالية عشان
                                    // تقلب مع الوضع الليلي — لون فاتح ثابت
                                    // كان هيبقى بلاطة بيضا بأيقونة فاتحة
                                    // عليها في الليل.
                                    colors: i == current
                                        ? [F.green, F.greenDeep]
                                        : [
                                            F.railGround.withValues(alpha: 0.75),
                                            F.cardGround.withValues(alpha: 0.75),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(F.s12),
                                  border: Border.all(
                                    color: i == current ? F.greenDeep : F.line.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Icon(icons[i], size: 24, color: i == current ? F.onDark : F.mutedDark),
                              ),
                              const SizedBox(height: F.s4),
                              // خط النظام الكبير كان بيلف «الإعدادات» سطرين ويفيض من
                              // الشريط — سطر واحد بيصغر بس لو ما دخلش.
                              // **وهامش على الجنبين**: الكلمة كانت بتصغر لحد عرض
                              // التبويب بالظبط، فـ«الملف الطبي» و«الإعدادات» كانوا
                              // لازقين على ٣٧٥ (آيفون، ٢٦ سبتمبر ٢٠٢٦).
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: _labelInset),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: labelSize,
                                      // نفس المعامل اللي طول الشريط بيتحسب بيه —
                                      // الخط العربي سطره أطول من ١٫٣ لوحده
                                      height: _labelLineHeight,
                                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                                      color: i == current ? F.green : F.mutedDark,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
