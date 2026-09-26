import '../voice/briefing_card.dart';
import '../voice/help_button.dart';
import '../voice/talk_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format/arabic_time.dart';
import '../../core/format/name_direction.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/keyboard_dismiss.dart';
import '../../core/widgets/shell_bottom_extra.dart';
import '../../data/services/appointment_card.dart';
import '../../core/widgets/patient_voice.dart';
import '../../core/widgets/primitives.dart';
import '../../data/db/app_database.dart';
import '../../data/dose_state.dart';
import '../../data/repositories/dose_event_repository.dart';
import '../../data/repositories/readings_repository.dart';
import '../../data/services/checkup_service.dart';
import '../../domain/care/follower_profile.dart';
import '../../domain/health/follow_display.dart';
import '../../data/services/reminder_plan.dart';
import '../../domain/health/follow_up.dart';
import '../../domain/scheduling/day_routine.dart';
import '../../domain/scheduling/dose_schedule.dart';
import '../../domain/scheduling/schedule_engine.dart';
import '../health/glucose_screen.dart';
import '../link/sign_in_screen.dart';
import '../medication/edit_medication_screen.dart';
import '../nearby/nearby_screen.dart';
import '../records/checkup_screen.dart';
import '../reminder/reminder_screen.dart';
import '../adherence/patient_adherence_card.dart';
import '../medication/not_bought.dart';
import 'dose_actions.dart';
import 'widgets/day_rail.dart';
import 'widgets/glucose_home_card.dart';
import 'widgets/now_block.dart';
import 'widgets/tip_card.dart';
import 'tips/tip_picker.dart';
import '../../data/repositories/medication_repository.dart' show MedicationSummary;
import '../../domain/medication/medication_purpose.dart';
import 'notifications_off_line.dart';
import '../billing/family_notice_cards.dart';
import 'widgets/circle_notices.dart';
import 'widgets/refill_lines.dart';

/// «جدول النهاردة» (المخطط 24) — الجرعة الجاية مثبّتة فوق، وباقي اليوم
/// تحتها على سكة. العنوان في جسم الصفحة — الشريط العلوي للهيكل ([AppShell]).
class TodayScreen extends StatefulWidget {
  const TodayScreen({required this.routine, this.now, super.key});

  final DayRoutine routine;

  /// للاختبارات — الشاشة بتستخدم دلوقتي الحقيقي في التطبيق.
  final DateTime? now;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  StreamSubscription<List<DoseSchedule>>? _schedulesSub;
  List<DoseSchedule> _schedules = const [];

  /// البث بيتعمل مرة واحدة هنا مش جوّه build.
  ///
  /// لو اتعمل جوّه build، كل إشعار من البث بيعيد البناء، وإعادة البناء
  /// بتعمل بث جديد بيبعت إشعار تاني — لفة مالهاش آخر.
  Stream<List<DoseEventView>>? _events;

  /// جرعات بكرة — «خلال ٤٨ ساعة».
  Stream<List<DoseEventView>>? _tomorrow;

  /// الاسم والسن للترحيب.
  Stream<PatientRow?>? _patient;

  /// مجموعات اتأجّلت من الشاشة دي — بنقول «هنفكّرك تاني» تحتها.
  /// دقيقة الجرعة → الموبايل هيفكّره إمتى تاني.
  ///
  /// **قراية للي التأجيل عمله، مش قرار تاني**: اللحظة بتتحسب من
  /// [snoozeTimeFrom]، نفس اللي `ReminderScheduler.snooze` بتجدول عليها،
  /// ومفيش هنا أي تغيير في التأجيل نفسه.
  ///
  /// في الذاكرة زي ما كانت: الشاشة بتعرف اللي اتأجّل **من عندها**. تأجيل
  /// من شاشة القفل ما بيوصلش هنا — ده حدّها، وهو زي ما هو من قبل.
  final Map<DateTime, DateTime> _snoozed = {};

  /// الأدوية اللي جرعتها مش معروفة — سؤال هادي للصيدلي، مش تنبيه.
  Stream<List<MedicationRow>>? _amountUnknown;

  /// قياسات السكر (D3.6) — لكارت السكر.
  StreamSubscription<List<ReadingRow>>? _readingsSub;
  List<ReadingRow> _readings = const [];

  /// متابعات التحاليل المفتوحة — **متابعة محدش شايفها متابعة محدش بيعملها**.
  Stream<List<RecordRow>>? _followUps;

  /// «معلومة ليك»: أدويته الشغّالة (الغرض والتعليمات والمدة) وآخر أسبوع
  /// جرعات — محلي بالكامل.
  StreamSubscription<List<MedicationSummary>>? _summariesSub;
  StreamSubscription<List<DoseEventView>>? _weekSub;
  List<MedicationSummary> _summaries = const [];
  List<DoseEventView> _lastWeek = const [];

  /// لملخص اليوم: ما بنقولش ملخص قبل ما كل مصادره توصل.
  bool _schedulesLoaded = false;
  bool _weekLoaded = false;
  bool _followUpsLoaded = false;
  StreamSubscription<List<RecordRow>>? _followUpsSub;
  List<RecordRow> _openFollowUps = const [];

  DateTime get _now => widget.now ?? DateTime.now();
  DateTime get _routineDay => currentRoutineDay(widget.routine, _now);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_events != null) return;

    final services = AppScope.of(context);
    _events = services.events.watchDay(_routineDay);
    _tomorrow = services.events.watchDay(
      DateTime(_routineDay.year, _routineDay.month, _routineDay.day + 1),
    );
    _patient = services.routines.watchPatient(services.patientId);
    unawaited(_loadFollowers(services));
    _amountUnknown = services.medications.watchAmountUnknown(services.patientId);
    _followUps = services.checkups.watchOpen(services.patientId);
    _followUpsSub = _followUps!.listen((rows) {
      if (mounted) {
        setState(() {
          _openFollowUps = rows;
          _followUpsLoaded = true;
        });
      }
    });
    _readingsSub = ReadingsRepository(services.db).watchRecent(services.patientId).listen((rows) {
      if (mounted) setState(() => _readings = rows);
    });
    _summariesSub = services.medications.watchActiveSummaries(services.patientId).listen((rows) {
      if (mounted) setState(() => _summaries = rows);
    });
    _weekSub = services.events
        .watchBetween(DateTime(_now.year, _now.month, _now.day - 7), DateTime(_now.year, _now.month, _now.day))
        .listen((rows) {
      if (mounted) {
        setState(() {
          _lastWeek = rows;
          _weekLoaded = true;
        });
      }
    });

    // أول ما الأدوية تتغيّر بنولّد أحداث اليوم من جديد — الإضافة بتظهر
    // فوراً، والإيقاف بيختفي، من غير ما حد يعمل refresh.
    _schedulesSub = services.medications
        .watchActiveSchedules(services.patientId)
        .listen(_onSchedules);
  }

  Future<void> _onSchedules(List<DoseSchedule> schedules) async {
    if (!mounted) return;
    setState(() {
      _schedules = schedules;
      _schedulesLoaded = true;
    });

    final services = AppScope.of(context);
    final engine = ScheduleEngine(widget.routine);
    await services.events.materializeDay(
      _routineDay,
      engine.remindersForDay(schedules, _routineDay),
    );
    // «خلال ٤٨ ساعة» بتقرا صفوف بكرة — rescheduleAll بينزّلها أصلاً، وده
    // idempotent لو الشاشة اتفتحت قبله.
    final tomorrow = DateTime(_routineDay.year, _routineDay.month, _routineDay.day + 1);
    await services.events.materializeDay(tomorrow, engine.remindersForDay(schedules, tomorrow));
  }

  @override
  void didUpdateWidget(TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // الروتين اتغيّر → ساعات اليوم بتتحرك، فبنعيد التوليد.
    if (oldWidget.routine != widget.routine) {
      unawaited(_onSchedules(_schedules));
    }
  }

  @override
  void dispose() {
    _schedulesSub?.cancel();
    _summariesSub?.cancel();
    _weekSub?.cancel();
    _followUpsSub?.cancel();
    _readingsSub?.cancel();
    super.dispose();
  }

  /// **مين بيتابعه** — الاسم والصلة من السحابة، مرة عند الفتح.
  ///
  /// بتفشل في صمت زي المزامنة: الأب بيقرا «محدش بيتابعك لسه» زي ما كان،
  /// والتذكير مش متعلّق بيها في أي اتجاه. الدالة على السيرفر بترجّع
  /// **الاسم والصلة وبس** — سياسة عمود مش ممكنة في بوستجرس، فالحد
  /// متفروض بالدالة.
  Future<void> _loadFollowers(AppServices services) async {
    final preferences = services.caregiverPreferences;
    if (preferences == null) return;
    final patient = await services.routines.getPatient(services.patientId);
    final uuid = patient?.uuid;
    if (uuid == null) return;
    try {
      final followers = await preferences.followers(uuid);
      if (mounted) {
        setState(() {
          _followers = followers;
          _followersKnown = true;
        });
      }
    } catch (_) {
      // مفيش جلسة، أوفلاين، أو مش مالك — كلهم «محدش بيتابعك لسه».
    }
  }

  List<FollowerProfile> _followers = const [];

  /// القايمة اتقرت فعلاً — فاضية معناها «محدش»، مش «ما عرفناش».
  bool _followersKnown = false;

  Future<void> _markTaken(List<DoseEventView> group) =>
      confirmGroup(AppScope.of(context), _routineDay, group);

  /// «لاحقًا» = التأجيل الحقيقي (ربع ساعة)، نفس «تأجيل ١٥ د» في شاشة التذكير.
  Future<void> _later(List<DoseEventView> group) async {
    await snoozeGroup(AppScope.of(context), _routineDay, group, now: _now);
    if (mounted) {
      setState(() => _snoozed[group.first.scheduledAt] = snoozeTimeFrom(_now));
    }
  }

  /// «لاحقًا» على الكتلة: كل مجموعة دقيقة لسه مستنية بتتأجّل — **نفس
  /// النداء بالظبط** اللي الكارت الواحد كان بيعمله، بس الكتلة بقت واحدة
  /// فالزرار بقى واحد.
  Future<void> _laterAll(List<NowLine> due) async {
    for (final group in _distinctGroups(due)) {
      await _later(group);
    }
  }

  /// «تأكيد الكل» — سطر سطر، عشان كل دوا ياخد قراره حتى لو في دقايق مختلفة.
  Future<void> _confirmAll(List<NowLine> lines) async {
    for (final group in _distinctGroups(lines)) {
      await _markTaken(group);
    }
  }

  /// مجموعات الدقايق اللي السطور دي فيها، كل واحدة مرة.
  List<List<DoseEventView>> _distinctGroups(List<NowLine> lines) {
    final seen = <DateTime>{};
    return [
      for (final line in lines)
        if (seen.add(line.group.first.scheduledAt)) line.group,
    ];
  }

  void _openEdit(int medicationId) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditMedicationScreen(medicationId: medicationId),
        ),
      );

  String? _ruleLabelFor(int doseScheduleId) {
    for (final schedule in _schedules) {
      if (schedule.id == doseScheduleId.toString()) return schedule.ruleLabel;
    }
    return null;
  }

  List<AnchorMark> get _anchors {
    final engine = ScheduleEngine(widget.routine);
    return [
      for (final anchor in DayAnchor.values)
        AnchorMark(
          anchor,
          engine.resolveTime(
            anchor: anchor,
            offsetMinutes: 0,
            onDay: _routineDay,
          ),
        ),
    ];
  }

  /// صف الدايرة بيفتح باب الربط الموجود — نفس الشاشة، نفس النداء الوحيد.
  void _openCircle() {
    final services = AppScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          auth: services.auth,
          caregiver: services.caregiver,
          push: services.push,
        ),
      ),
    );
  }

  void _openNearby() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NearbyScreen()),
      );

  void _openGlucose() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GlucoseScreen()),
      );

  void _openCheckup(int recordId) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CheckupScreen(recordId: recordId)),
      );

  List<List<DoseEventView>> _group(List<DoseEventView> events) => groupByMinute(events);

  /// الدوسة على كارت في السكة بتفتح شاشة التذكير بتاعته — أخدته / فكّرني /
  /// مش هاخده — بدل زرار أساسي على كل كارت.
  void _openReminder(List<DoseEventView> group) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReminderScreen(
            routineDay: _routineDay,
            scheduleIds: [for (final d in group) d.doseScheduleId.toString()],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Scaffold جوّه تبويب الهيكل: الأرضية، وMaterial للـInkWell لما الشاشة
    // تتبني لوحدها في الاختبار.
    return Scaffold(
      // «القريب مني» عايم في آخر السطر (ناحية الشمال في RTL)، **ظاهر دايماً**
      // (المالك، ٢٦ سبتمبر ٢٠٢٦ — زي نسخة 1.13.1) — ثانوي، مش أساسي: الأساسي
      // الوحيد على الشاشة دي «تأكيد الجرعة». وعمره ما يغطّي آخر كارت: القايمة
      // بتسيب تحتها مكان البيل + «ضيف» + الدوك ([_NearbyPill.clearance] فوق
      // `padding.bottom`)، فآخر صف بيتزحلق لحد ما يطلع فوقه كله. وبيختفي
      // والكيبورد مرفوع — شوف `keyboard_dismiss.dart`.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: keyboardIsUp(context)
          ? null
          : Padding(
              // الهدف ٥٦ والشكل ٤٤ — الهامش بيقل بنص الفرق، فالبيل في مكانه بالظبط؛
              // ومسافة الهيكل لـ«ضيف» بتتطرح عشان يفضل فوق الدوك بنفس المسافة القديمة
              padding: EdgeInsets.only(bottom: F.s10 - _NearbyPill.hitSlop + MediaQuery.of(context).padding.bottom - ShellBottomExtra.of(context)),
              child: _NearbyPill(onTap: _openNearby),
            ),
      body: StreamBuilder<List<DoseEventView>>(
        stream: _events,
        builder: (context, snapshot) {
          final events = snapshot.data ?? const <DoseEventView>[];
          final groups = _group(events);

          final nowCards = nowGroups(groups, _now);
          final lines = nowLines(nowCards, _snoozed);
          final glucoseNow = latestOutsideUsual(_readings);

          return ListView(
            // مساحة تحت عشان آخر كارت يعدّي من تحت الدوك من غير ما يتخبّى
            // تحته. `padding.bottom` جوّه جسم الـScaffold المفرود بيساوي
            // طول الدوك — Flutter بيحطه هناك بالظبط للسبب ده.
            // **وآخر صف عمره ما يبقى تحت «القريب مني».** الزرار العايم بيقعد
            // فوق الدوك بمقاسه وهامشه؛ من غير المسافة دي كان بيغطّي صف العشا
            // في «جدول النهاردة» على شاشة قصيرة. الحساب من مقاس الزرار نفسه
            // ومن هامش الـFAB بتاع Material — مش رقم مكتوب. والكيبورد مرفوع
            // الزرار مش موجود، فالمسافة بتختفي معاه.
            padding: EdgeInsets.fromLTRB(
              F.gap,
              F.gap,
              F.gap,
              // الدوك (`padding.bottom` جوّه الهيكل) + طلعة «ضيف» (اللي الهيكل
              // زوّدها) + البيل بهامشه — فآخر كارت بيطلع فوق التلاتة
              F.gap + MediaQuery.of(context).padding.bottom + (keyboardIsUp(context) ? 0 : _NearbyPill.clearance),
            ),
            children: [
              StreamBuilder<PatientRow?>(
                stream: _patient,
                builder: (context, snap) => _HomeHeader(
                  patient: snap.data,
                  now: _now,
                  followers: _followers,
                  onOpenCircle: _openCircle,
                  // «كلّمني» (المرحلة ٣): تحت التحية، فوق كل حاجة — طلب مفتوح
                  // بالصوت. جوّه الترويسة مش ولد لوحده في القايمة: ولد بصفر
                  // ارتفاع كان بيحرّك اختبار لفّ SE.
                  talk: TalkButton(routine: widget.routine, routineDay: _routineDay, now: widget.now, gapAbove: F.s12),
                ),
              ),
              // ملخص اليوم بالصوت — أول فتحة في يوم الروتين، من البيانات
              // المحلية، ومكتوب هنا بنفس الكلام. مش موجود من غير صوت.
              if (AppScope.of(context).voice case final voice?)
                BriefingCard(
                  voice: voice,
                  dayKey: briefingDayKey(_routineDay),
                  ready: snapshot.hasData && _schedulesLoaded && _weekLoaded && _followUpsLoaded,
                  input: briefingInputFor(
                    now: _now,
                    routineDay: _routineDay,
                    today: events,
                    schedules: _schedules,
                    openFollowUps: _openFollowUps,
                    lastWeek: _lastWeek,
                  ),
                ),
              SizedBox(height: nowCards.isNotEmpty ? F.s8 : F.gap),
              // **كارت المواعيد — من ساعة الحجز لحد ما اليوم يعدّي.**
              //
              // الإشعارين (هادي امبارحه وواحد بيرن في يومه) ممكن يكونوا
              // لسه برّه نافذة iOS المتدحرجة — الكارت ده هو شبكة الأمان:
              // بيعرض الميعاد **دايماً**، وبيعدّ التنازلي، وبيقول إن
              // الموبايل هيفكّره امبارحه. عمره ما يرن.
              //
              // **وتحت «الآن» عن قصد**: الجرعة هي اللي بتفضل أول حاجة
              // على الشاشة، والميعاد اللي بعد تلات أيام مش أعجل منها.
              StreamBuilder<List<RecordRow>>(
                stream: _followUps,
                builder: (context, snap) {
                  final soon = upcomingAppointments(snap.data ?? const [], now: _now);
                  if (soon.isEmpty) return const SizedBox.shrink();
                  // في الوضع المضغوط مفيش فجوة زيادة: القياس على SE
                  // بيقول إن كل ١٠ بكسل هنا بتفرق مع زرار «ضيف» العايم.
                  return Padding(
                    // في الوضع المضغوط مفيش فجوة زيادة خالص: الكارت
                    // الذهبي بحدوده هو الفاصل، والستّة بكسل دي هي الفرق
                    // بين زرار التأكيد كامل وزرار مقطوع على SE.
                    padding: EdgeInsets.only(
                        bottom: nowCards.isNotEmpty ? 0 : F.gap),
                    child: _AppointmentsCard(
                      appointments: soon,
                      now: _now,
                      onOpen: _openCheckup,
                      // **جرعة مستنية تأكيد = الكتلة بتتقلّص.** المواعيد
                      // فوق كارت الجرعة بقرار المالك، والضمانة إن القرار
                      // ده ما يزقّش «تأكيد الجرعة» برّه أول شاشة على
                      // أصغر آيفون. لما مفيش جرعة مستنية، فيه مكان.
                      compact: nowCards.isNotEmpty,
                    ),
                  );
                },
              ),
              if (nowCards.isNotEmpty || glucoseNow) ...[
                // **العدد في العنوان.** تلات كروت مكدّسة كانت بتخلّي
                // السؤال «هما كام؟» محتاج نزول وعدّ؛ دلوقتي الإجابة في
                // أول سطر بيقع عليه العين.
                HelpRow(
                  id: 'help_next_dose',
                  child: _SectionTitle(nowCountLabel(lines.due.length + lines.postponed.length),
                      attention: true),
                ),
                const SizedBox(height: F.s8),
                if (nowCards.isNotEmpty) ...[
                  NowBlock(
                    lines: lines,
                    now: _now,
                    onConfirmLine: (line) => _markTaken([line.dose]),
                    onConfirmAll: () =>
                        _confirmAll([...lines.due, ...lines.postponed]),
                    onLater: () => _laterAll(lines.due),
                  ),
                  const SizedBox(height: F.s10),
                ],
                // سكر برّه المعتاد ليه هو — في «الآن»، ذهبي ومن غير لوم
                if (glucoseNow) ...[
                  GlucoseHomeCard(readings: _readings, onOpen: _openGlucose),
                  const SizedBox(height: F.s10),
                ],
                const SizedBox(height: F.s8),
              ],
              if (nowCards.isEmpty && events.isNotEmpty) ...[
                const _AllDonePanel(),
                const SizedBox(height: F.gap),
              ],
              // «إنت ماشي إزاي» — **تحت** كارت الجرعة، مش فوقه: التأكيد أعجل.
              // قراية بس، وبيستخبّى أول يومين.
              PatientAdherenceCard(routineDay: _routineDay, now: _now),
              Text(
                'جدول النهاردة',
                style: TextStyle(
                  fontFamily: F.displayFamily,
                  fontSize: F.subtitleSize,
                  fontWeight: FontWeight.w700,
                  color: F.ink,
                ),
              ),
              const SizedBox(height: F.s4),
              Text(
                'مواعيد يومك، وأدويتك مربوطة بيها.',
                style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
              ),
              const SizedBox(height: F.s12),
              if (events.isEmpty)
                _EmptyPanel(hasMedications: _schedules.isNotEmpty)
              else
                DayRail(
                  anchors: _anchors,
                  groups: groups,
                  now: _now,
                  ruleLabelFor: _ruleLabelFor,
                  onOpen: _openReminder,
                ),
              // نفس المسافة بين كل كارت والتاني — «معلومة تهمك» كانت لازقة
              // في السكة لما مفيش بكرة ولا متابعات ولا سكر بينهم.
              const SizedBox(height: F.gap),
              // «تنبيهات محمد هتقف يوم …» / «اللي بيتابعوك مش بيتبلّغوا
              // دلوقتي». **تحت الجدول عن قصد**: فوق كان هيزقّ «تأكيد
              // الجرعة» تحت الزرار العايم على SE — وده كلام عن المتابعين،
              // مش عن دوا دلوقتي.
              // «كونكور فاضله ٤ أيام» — تحت الجدول: مش جرعة دلوقتي، وفوق كان
              // هيزقّ «تأكيد الجرعة» على SE
              const RefillLines(),
              // «فيه دوا لسه ماتشترتش» — سطر هادي، ويختفي لما القايمة تفضى
              const NotBoughtLine(),
              PatientFamilyNotice(
                followerNames: [for (final f in _followers) f.name],
                followersKnown: _followersKnown,
                now: _now,
              ),
              // «مفيش حد من عيلتك أو ممرضك لسه — ضيفه من هنا» — دعوة، مش شغل
              // دلوقتي؛ مكانها تحت الجدول عشان ما تزقّش زرار التأكيد.
              if (_followers.isEmpty) ...[
                CareCircleRow(onOpen: _openCircle, followers: const []),
                const SizedBox(height: F.gap),
              ],
              StreamBuilder<List<DoseEventView>>(
                stream: _tomorrow,
                builder: (context, snap) {
                  final tomorrow = _group(snap.data ?? const []);
                  if (tomorrow.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: F.gap),
                    child: _Upcoming(groups: tomorrow),
                  );
                },
              ),
              // متابعات التحاليل المفتوحة: اسم التحليل والمرحلة، والدوسة
              // بتفتحها. مفيش حاجة بتتعرض لما مفيش متابعات.
              StreamBuilder<List<RecordRow>>(
                stream: _followUps,
                builder: (context, snap) {
                  // **مفيش تكرار بين الكتلتين.** متابعة ليها ميعاد جاي
                  // بتتعرض في «مواعيدك الجاية» وبس؛ اللي فاضل هنا هو اللي
                  // مستني حركة من الأب ومالوش ميعاد — يحطّ ميعاد، يضيف
                  // نتيجة… ولما مايفضلش حاجة، القسم بيختفي خالص.
                  final open = needsActionFollowUps(
                    snap.data ?? const <RecordRow>[],
                    now: _now,
                  );
                  if (open.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: F.gap),
                    child: _OpenFollowUps(
                      records: open,
                      now: _now,
                      onOpen: _openCheckup,
                    ),
                  );
                },
              ),
              if (_readings.isNotEmpty && !glucoseNow) ...[
                GlucoseHomeCard(readings: _readings, onOpen: _openGlucose),
                const SizedBox(height: F.gap),
              ],
              // «معلومة تهمك» مكان كارت المية — نفس الخانة، نفس الوزن
              TipCard(
                tip: pickTip(
                  today: _now,
                  medications: [
                    for (final m in _summaries)
                      TipMedication(
                        id: m.medication.id,
                        name: m.medication.name,
                        purpose: MedicationPurpose.fromStorage(m.medication.purpose),
                        instructions: m.medication.instructions,
                        endsOn: m.schedules.map((sch) => sch.lastActiveDay).whereType<DateTime>().fold<DateTime?>(
                            null, (a, b) => a == null || b.isAfter(a) ? b : a),
                      ),
                  ],
                  lastWeek: [
                    for (final e in _lastWeek)
                      TipDose(
                        scheduledAt: e.scheduledAt,
                        taken: e.state == DoseState.taken,
                        missed: e.state == DoseState.missed,
                        actedAt: e.actedAt,
                      ),
                  ],
                ),
                onOpenMedication: (id) => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => EditMedicationScreen(medicationId: id)),
                ),
              ),
              const SizedBox(height: F.gap),
              // القاعدة ٤: مجهول اتسجّل لازم يفضل ظاهر هنا — سؤال هادي للصيدلي
              StreamBuilder<List<MedicationRow>>(
                stream: _amountUnknown,
                builder: (context, snapshot) {
                  final meds = snapshot.data ?? const <MedicationRow>[];
                  return StreamBuilder<List<RecordRow>>(
                    stream: _followUps,
                    builder: (context, followSnap) {
                      // متابعة واقفة عند مرحلة بتسأل عن ميعاد، ومفيش ميعاد،
                      // وعدّى أسبوع. حد عرض — مش حكم على المعمل.
                      final stalled = [
                        for (final r in followSnap.data ?? const <RecordRow>[])
                          if (CheckupService.stageOf(r) case final stage?)
                            if (followIsStalled(
                              stage: stage,
                              stageSince: r.checkupStageSince,
                              stageDate: CheckupService.stageDateOf(r, stage),
                              now: _now,
                            ))
                              (
                                // النوع بالاسم: «متابعة زيارة د. حسام واقفة»
                                // تتقري صح، و«متابعة تحليل صورة دم واقفة»
                                // كمان — قايمة واحدة فيها الاتنين.
                                label: '${followRowName(CheckupService.kindOf(r), r.title)} '
                                    'واقفة عند ${stage.label}',
                                onTap: () => _openCheckup(r.id),
                              ),
                      ];
                      final items = [
                        for (final m in meds)
                          (label: 'اسأل الصيدلي عن جرعة ${m.name}', onTap: () => _openEdit(m.id)),
                        ...stalled,
                      ];
                      if (items.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: F.gap),
                        child: _FollowUpPanel(items: items),
                      );
                    },
                  );
                },
              ),
              // مسافة تحت عشان آخر سطر ما يستخبّاش ورا زرار «ضيف»
              const SizedBox(height: F.s30 * 2),
            ],
          );
        },
      ),
    );
  }
}

/// نفس نبرة «التذكير هيفضل شغال لحد ما توقفه بنفسك»: سطر هادي، مش تنبيه.
///
/// مجهول اتسجّل ونقدر نتابعه كويس؛ اللي مش كويس هو مجهول اتنسي في صمت.
class _FollowUpPanel extends StatelessWidget {
  const _FollowUpPanel({required this.items});

  final List<({String label, VoidCallback onTap})> items;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: F.railGround,
          borderRadius: BorderRadius.circular(F.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              // الدوسة بتفتح التعديل — السؤال ليه مكان يتجاوب فيه.
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(F.radius),
                child: Container(
                  constraints: const BoxConstraints(minHeight: F.minTapTarget),
                  padding: const EdgeInsets.symmetric(horizontal: F.gap, vertical: 10),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.6),
                        ),
                      ),
                      Text(
                        'اكتبها',
                        style: TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w600, color: F.green),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

/// الترحيب (المخطط 4): kicker، «صباح الخير يا محمد» بجنسه، وصف الدايرة.
///
/// **مفيش عنوان كبير**: لا «ماذا أفعل الآن؟» (فصحى) ولا «تعمل إيه دلوقتي؟» —
/// التحية بتوصّل للأقسام على طول. الشاشة دي بتاعة صاحب الموبايل، فالكلام
/// كله بيخاطبه هو («مين بيتابعك»)، مش «ملف والدك» بتاع التصميم.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.patient,
    required this.now,
    required this.onOpenCircle,
    this.followers = const [],
    this.talk,
  });

  /// «كلّمني» — تحت التحية مباشرة.
  final Widget? talk;
  final PatientRow? patient;
  final DateTime now;
  final List<FollowerProfile> followers;
  final VoidCallback onOpenCircle;

  @override
  Widget build(BuildContext context) {
    final name = patient?.name;
    final hasName = name != null && name.isNotEmpty && name != 'أنا';
    final greeting = now.hour >= 4 && now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // «يومك» بحجم العنوان — هي عنوان الشاشة، مش سطر فوقها.
        // `height` مش زينة: خط العناوين طالع فوق السطر، وبالارتفاع
        // الافتراضي كان نص «يومك» الأعلى بيتقص.
        HelpRow(
          id: 'help_today',
          child: Text(
            'يومك',
            style: TextStyle(
              fontFamily: F.displayFamily,
              fontSize: F.screenTitleSize,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: F.green,
            ),
          ),
        ),
        const SizedBox(height: F.s4),
        Text(
          hasName ? '$greeting يا $name' : greeting,
          style: TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w600, color: F.ink),
        ),
        if (hasName && patient?.age != null)
          Text(
            '$name — ${arabicNumber(patient!.age!)} سنة',
            style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
          ),
        ?talk,
        const SizedBox(height: F.s12),
        // الاستثناء الوحيد اللي المريض بيشوفه: إذن التنبيهات مقفول.
        // أي مشكلة تانية بتتصلّح لوحدها أو بتروح للأدمن — مش هنا.
        const NotificationsOffLine(),
        // اللي الممرض غيّره واتطبّق هنا (المرحلة ب) — بيتقال بالاسم
        const CircleNotices(),
        // مين بيتابعه — **بأساميهم** فوق. الدعوة لما محدش مربوط اتنقلت تحت
        // الجدول: جملتها أطول وبتلفّ سطرين على SE، وده كان بيزقّ «تأكيد
        // الجرعة» تحت «ضيف» العايم (هامش القياس بكسل ونص).
        if (followers.isNotEmpty) CareCircleRow(onOpen: onOpenCircle, followers: followers),
      ],
    );
  }
}

/// «مين بيتابعك» (المخطط ٤ — صف الصور تحت التحية).
///
/// دي الشفافية اللي الأب يستاهلها: مين شايف بياناته، على شاشته الأولى، من
/// غير ما يدوّر في الإعدادات. من غير حد مربوط بتبقى **دعوة** مش صف فاضي.
/// اللمسة بتفتح القايمة. الشارة اللي في التصميم جنب الصور مش مبنية — مش
/// واضح بتعدّ إيه.
class CareCircleRow extends StatelessWidget {
  const CareCircleRow({required this.onOpen, this.followers = const [], super.key});

  /// اللي بيتابعوا — فاضية لحد ما الربط يحصل، ولحد ما المتابع يكتب اسمه.
  final List<FollowerProfile> followers;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
        color: F.cardGround,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(F.radiusCard),
          side: BorderSide(color: F.line),
        ),
        child: InkWell(
          key: const ValueKey('care-circle-row'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(F.radiusCard),
          child: Container(
            constraints: const BoxConstraints(minHeight: F.minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: F.s12, vertical: F.s8),
            child: Row(
              children: [
                if (followers.isEmpty)
                  Icon(Icons.person_add_alt, size: 26, color: F.green)
                else
                  for (final (i, follower) in followers.indexed)
                    Padding(
                      padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : F.s4),
                      child: _Avatar(name: follower.name),
                    ),
                const SizedBox(width: F.s10),
                Expanded(
                  child: Text(
                    // **الصيغة بتمشي مع الصلة**: «محمد ابنك بيتابعك» /
                    // «سارة بنتك بتتابعك». الاسم ما بيقولش ولد ولا بنت،
                    // والتخمين منه غلط في ناس حقيقيين — فالابن هو اللي
                    // بيقول صلته وقت ما بيتابع.
                    followersLine(followers),
                    style: TextStyle(fontSize: F.minTextSize, color: F.ink, height: 1.4),
                  ),
                ),
                Icon(Icons.chevron_left, size: 24, color: F.mutedDark),
              ],
            ),
          ),
        ),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: F.greenDeep, shape: BoxShape.circle),
        child: Text(
          name.characters.first,
          style: const TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w700, color: F.onDark),
        ),
      );
}

/// عنوان قسم بنقطة صغيرة — «الآن» / «خلال ٤٨ ساعة».
///
/// التصميم بيحط نقطة **حمرا** على «الآن». عندنا الأحمر للطوارئ بس، وجرعة
/// فايتة مش خطر — هو نسي، ما فشلش. فالنقطة ذهبي: «دي لسه عايزاك». والقسم
/// اللي جاي نقطته خضرا هادية.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.attention = false});
  final String text;
  final bool attention;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: attention ? F.gold : F.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: F.s8),
          // **`Flexible` مش زينة**: العنوان بقى بيشيل عدّاد («الآن — ٣
          // أدوية»)، وعلى SE بخط ×١٫٣ الصف كان بيفيض ٢١ بكسل. النقطة
          // مقاسها ثابت، والكلام هو اللي بيلفّ.
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: F.sectionHeadSize, fontWeight: FontWeight.w700, color: F.green),
              key: ValueKey('section-$text'),
            ),
          ),
        ],
      );
}

/// «خلال ٤٨ ساعة»: جرعات بكرة — صف لكل دقيقة. مفيش سكر ولا تحاليل هنا لسه
/// (D3.6).
class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.groups});

  final List<List<DoseEventView>> groups;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('خلال ٤٨ ساعة'),
          const SizedBox(height: F.s8),
          FCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, g) in groups.indexed) ...[
                  if (i > 0) Divider(height: 1, color: F.lineSoft),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: F.s14, vertical: F.s12),
                    // الاسم الأول، وبعده اليوم والساعة (المخطط ٠٤)
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.map((d) => d.medicationName).join(' + '),
                            textDirection: nameDirection(g.first.medicationName),
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: F.minTextSize,
                              fontWeight: FontWeight.w700,
                              color: F.ink,
                              fontFamily: F.monoFamily,
                              fontFamilyFallback: F.monoFallback,
                            ),
                          ),
                        ),
                        const SizedBox(width: F.s12),
                        Text(
                          'بكرة ${arabicTime(g.first.scheduledAt)}',
                          style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

class _AllDonePanel extends StatelessWidget {
  const _AllDonePanel();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(F.gap),
        decoration: BoxDecoration(
          color: F.railGround,
          borderRadius: BorderRadius.circular(F.radius),
        ),
        child: Text(
          PatientVoice.of(context).allDone,
          style: const TextStyle(
            fontSize: F.minBodySize,
            fontWeight: FontWeight.w600,
            color: F.greenDeep,
          ),
        ),
      );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.hasMedications});

  /// فيه دوا بس مفيش جرعة النهارده — اتضاف بعد ميعادها (`active_from`) أو
  /// بيبدأ بكرة. «مفيش أدوية» ساعتها كانت هتبقى كدب.
  final bool hasMedications;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(F.gap),
        decoration: BoxDecoration(
          color: F.cardGround,
          borderRadius: BorderRadius.circular(F.radius),
          border: Border.all(color: F.line),
        ),
        child: Text(
          hasMedications
              ? 'مفيش جرعات فاضلة النهارده. الجرعة الجاية مكتوبة فوق في «خلال ٤٨ ساعة».'
              : 'مفيش أدوية لسه. دوس «ضيف» تحت وإحنا نفكّرك بيه.',
          style: TextStyle(
            fontSize: F.minBodySize,
            color: F.ink,
            height: 1.6,
          ),
        ),
      );
}

/// «القريب مني» — بيل عايم صغير تحت الشمال، **في الرئيسية وبس**، ظاهر دايماً؛
/// القايمة بتسيب مكانه تحت آخر صف فعمره ما يغطّي كارت. الشكل ٤٤ والهدف ٥٦.
///
/// دهبي مليان بحد زيتي زي ما المالك طلب. الدهبي هنا حالة «تقدر تروح
/// دلوقتي» مش تنبيه، وهو الزرار الوحيد بالشكل ده على الشاشة.
class _NearbyPill extends StatelessWidget {
  const _NearbyPill({required this.onTap});

  final VoidCallback onTap;

  static const double height = 44;

  /// اللمس ٥٦ (القاعدة) والشكل ٤٤ — نص الفرق فوق ونصه تحت، مش ظاهر.
  static const double hitSlop = (F.minTapTarget - height) / 2;

  /// المسافة اللي القايمة لازم تسيبها تحت آخر صف: الزرار + هامشه تحت
  /// (`F.s10`) + هامش الـFAB بتاع Material + نفَس.
  static const double clearance = height + F.s10 + kFloatingActionButtonMargin + F.s8;

  @override
  Widget build(BuildContext context) => GestureDetector(
        // الهدف ٥٦ من غير ما الشكل يكبر
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: hitSlop),
          child: _pill(),
        ),
      );

  Widget _pill() => Material(
        color: F.gold,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(F.radiusChip),
          side: BorderSide(color: F.greenDeep, width: 1.5),
        ),
        child: InkWell(
          key: const ValueKey('nearby-pill'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(F.radiusChip),
          // من غير `alignment` — Container بـalignment بياخد كل العرض المتاح،
          // والبيل كان بيتمدّ على الشاشة كلها
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: F.s12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: F.greenDeep),
                const SizedBox(width: F.s6),
                Text(
                  'القريب مني',
                  style: TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w700, color: F.greenDeep),
                ),
              ],
            ),
          ),
        ),
      );
}

/// متابعات التحاليل المفتوحة: عنوان صغير، وسطر لكل واحدة باسمها ومرحلتها.
///
/// مش كارت ومش ذهبي — دي حاجة بتتعمل على مهل، مش جرعة فاتت. والدوسة
/// بتفتح شاشة المتابعة نفسها.
/// **كارت المواعيد الجاية** — «بعد ٣ أيام» / «بكرة» / «النهارده».
///
/// أكتر من ميعاد = قايمة واحدة مضغوطة، الأقرب الأول. ولا سطر هنا بيرن:
/// الرنّة بتاعة الإشعار، ودي شاشة.
class _AppointmentsCard extends StatelessWidget {
  const _AppointmentsCard({
    required this.appointments,
    required this.now,
    required this.onOpen,
    this.compact = false,
  });

  /// جرعة مستنية تأكيد على نفس الشاشة — ميعاد واحد بس، ومن غير سطر الشرح.
  final bool compact;

  final List<UpcomingAppointment> appointments;
  final DateTime now;
  final ValueChanged<int> onOpen;

  /// **الكارت بيفضل قصير عشان «تأكيد الجرعة» يفضل باين من غير سكرول.**
  ///
  /// المواعيد فوق كارت الجرعة بقرار المالك؛ والضمانة إن القرار ده ما
  /// ياكلش الشاشة هي إن الكتلة دي مقصوصة. اللي زيادة بيبقى سطر واحد
  /// بيفتح القايمة الكاملة. اختبار على أصغر آيفون بيثبت إن الزرار
  /// كامل جوّه أول شاشة.
  static const maxShown = 2;

  /// **اتنين حتى وهو مضغوط** (طلب المالك). كان بيعرض ميعاد واحد و«+١»،
  /// فالتحليل كان بيستخبى ورا رقم — ورقم لوحده ما بيقولش لراجل عنده ٧٢
  /// سنة أي حاجة.
  int get _shown => maxShown;

  /// **الصف المضغوط بيتقاس بنصّه، والكتلة كلها هي هدف اللمس.**
  ///
  /// القياس على آيفون SE هو اللي فرض ده: الشاشة ٦٦٧ نقطة، الترويسة
  /// لوحدها ٢٥٢، وزرار «ضيف» العايم بيبدأ عند ٥٩٧٫٤. صفّين على ٥٦ كانوا
  /// بينزّلوا «تأكيد الجرعة» تحته. من غير حد أدنى، الصف بياخد ارتفاع
  /// سطره العربي (~٢٩ على ١٧ بكسل) — وصفّين بكده أطول من الصف الواحد
  /// القديم بتلات بكسل بس.
  ///
  /// **وقاعدة «هدف اللمس ٥٦» محفوظة**: الكتلة المضغوطة كلها ٦٢ بكسل
  /// وكل حتة فيها بتفتح متابعة — الهدف هو الكارت، مش السطر.
  double? get _rowHeight => compact ? null : F.minTapTarget;

  @override
  Widget build(BuildContext context) => _card(context);

  Widget _card(BuildContext context) => Column(
        key: const ValueKey('appointments-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // العنوان بمقاس عنوان القسم مش عنوان الشاشة — الكتلة دي فوق
          // كارت الجرعة، والفرق بين ٢٣ و١٩ بكسل بيتحسب في الآخر.
          // ومع جرعة مستنية تأكيد العنوان بيتشال: الكارت الذهبي بحدوده
          // وأيقونته بيقول إنه مواعيد، والبكسلات دي بتروح للزرار.
          if (!compact) ...[
            const HelpRow(id: 'help_appointments', child: _SectionTitle('مواعيدك الجاية', attention: true)),
            const SizedBox(height: F.s6),
          ],
          Container(
            decoration: BoxDecoration(
              color: F.cardGround,
              borderRadius: BorderRadius.circular(F.radius),
              // **ذهبي زي كارت «الآن»** — «التذكير والحالة النشطة بس».
              // مش كهرماني: الكهرماني لدرجات السلّم ٣ و٤ وبس.
              border: Border.all(color: F.gold, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, a) in appointments.take(_shown).indexed) ...[
                  if (i > 0 && !compact) Divider(height: 1, color: F.lineSoft),
                  InkWell(
                    onTap: () => onOpen(a.recordId),
                    child: Container(
                      // **سطر واحد لكل ميعاد.** الكتلة فوق كارت الجرعة،
                      // فكل بكسل هنا بيزقّ «تأكيد الجرعة» لتحت — واختبار
                      // على أصغر آيفون بيقيس ده.
                      constraints: BoxConstraints(minHeight: _rowHeight ?? 0),
                      padding: const EdgeInsets.symmetric(horizontal: F.gap),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 20, color: F.gold),
                          const SizedBox(width: F.s8),
                          Expanded(
                            child: Text(
                              '${a.headline} — ${a.displayTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: F.minTextSize,
                                fontWeight: FontWeight.w700,
                                color: F.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: F.s8),
                          Text(
                            countdownWord(now, a.at),
                            style: TextStyle(
                              fontSize: F.minTextSize,
                              fontWeight: FontWeight.w700,
                              color: F.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // **اللي زيادة بيتقال بالكلام، مش برقم لوحده.**
                // «+١» جنب كارت ذهبي مش بتقول لحد إن فيه ميعاد تاني
                // مستخبي — بتتقري كأنها زينة.
                if (appointments.length > _shown) ...[
                  Divider(height: 1, color: F.lineSoft),
                  InkWell(
                    key: const ValueKey('appointments-more'),
                    onTap: () => onOpen(appointments[_shown].recordId),
                    child: Container(
                      constraints: BoxConstraints(minHeight: _rowHeight ?? 0),
                      padding: const EdgeInsets.symmetric(horizontal: F.gap),
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        moreAppointmentsLabel(appointments.length - _shown),
                        style: TextStyle(
                          fontSize: F.minTextSize,
                          fontWeight: FontWeight.w700,
                          color: F.green,
                        ),
                      ),
                    ),
                  ),
                ],
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(F.gap, 0, F.gap, F.s10),
                    child: Text(
                      'هنفكّرك امبارحه وفي يومه.',
                      maxLines: 1,
                      style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class _OpenFollowUps extends StatelessWidget {
  const _OpenFollowUps({required this.records, required this.now, required this.onOpen});

  final List<RecordRow> records;
  final DateTime now;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('open-follow-ups'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المتابعات',
            style: TextStyle(
              fontFamily: F.displayFamily,
              fontSize: F.subtitleSize,
              fontWeight: FontWeight.w700,
              color: F.ink,
            ),
          ),
          const SizedBox(height: F.s8),
          Container(
            decoration: BoxDecoration(
              color: F.railGround,
              borderRadius: BorderRadius.circular(F.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in records)
                  InkWell(
                    key: ValueKey('follow-up-${r.id}'),
                    onTap: () => onOpen(r.id),
                    borderRadius: BorderRadius.circular(F.radius),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: F.minTapTarget),
                      padding: const EdgeInsets.symmetric(horizontal: F.gap, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  followDisplayTitle(CheckupService.kindOf(r), r.title),
                                  textDirection: nameDirection(r.title),
                                  style: TextStyle(
                                    fontSize: F.minBodySize,
                                    fontWeight: FontWeight.w700,
                                    color: F.ink,
                                  ),
                                ),
                                if (CheckupService.stageOf(r) case final stage?)
                                  Text(
                                    // النوع جنب المرحلة — القايمة فيها
                                    // تحاليل وزيارات، و«الزيارة تمت» لوحدها
                                    // ما بتقولش دي متابعة إيه. والميعاد
                                    // ميعاد **المرحلة**: الصفوف دي كلها
                                    // مالهاش ميعاد جاي، فالسطر بيقول كده
                                    // بالحرف بدل ما يعرض تاريخ الورقة.
                                    '${CheckupService.kindOf(r).word} — ${stage.label} — '
                                    '${followDateLine(CheckupService.stageDateOf(r, stage), now)}',
                                    style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.4),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            'افتح',
                            style: TextStyle(
                              fontSize: F.minTextSize,
                              fontWeight: FontWeight.w600,
                              color: F.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}
