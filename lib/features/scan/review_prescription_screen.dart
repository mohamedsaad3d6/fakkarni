import '../voice/help_button.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../ai/prescription_reading.dart';
import '../../app/app_scope.dart';
import '../../data/repositories/not_bought_repository.dart';
import '../../core/format/arabic_time.dart';
import '../../core/format/name_direction.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/f_sheet.dart';
import '../../core/widgets/primitives.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/records_repository.dart';
import '../../domain/escalation/alert_mode.dart';
import '../../domain/medication/medication_purpose.dart';
import '../../domain/scheduling/day_routine.dart';
import '../../domain/scheduling/dose_schedule.dart';
import '../../domain/scheduling/schedule_engine.dart';
import '../medication/add_medication_screen.dart';
import '../routine/ask_anchor_time.dart';
import '../../core/widgets/patient_voice.dart';
import '../medication/medication_draft.dart';
import 'debug_panel.dart';

enum ReviewResult { confirmed, retake }

/// «الذكاء يقترح، وأنت تؤكّد» (المخطط 06) — أهم شاشة في التطبيق.
///
/// ولا سطر بيتحفظ قبل دوسة. صف لكل **دوا**: الاسم، الوقت المحسوب للعرض
/// بس (عمره ما بيتخزّن)، وشريحة بتعرض **القاعدة** مش الساعة.
///
/// الصف اللي الذكاء مش متأكد منه بياخد حافة ذهبية على الجنب وسطر «مش
/// متأكد من دي — راجعها» وتحته الحقل وملاحظته. ده اعتراف بالشك — ميزة،
/// فبيتصمّم مدروس، مش مكسور.
///
/// المجهول نوعين (القاعدة ٤): اسم أو توقيت مش واضح بيقفل «تمام، ظبّطهم»؛
/// جرعة مش معروفة ما بتقفلش. و«أعدّل» بنفس الوزن البصري بالظبط — زرار
/// مليان بنفس المقاس والخط — محدش بيتدفع يأكّد جدول دوا ما قراهوش.
class ReviewPrescriptionScreen extends StatefulWidget {
  const ReviewPrescriptionScreen({
    required this.reading,
    required this.routine,
    this.image,
    this.today,
    this.records,
    this.onSaved,
    super.key,
  });

  final PrescriptionReading reading;
  final DayRoutine routine;

  /// الورقة زي ما الكاميرا (أو معرض الصور) دتها — **مش** النسخة المصغّرة
  /// اللي راحت للموديل. الصغيرة للقراية، ودي للعين البشرية.
  final Uint8List? image;

  final DateTime? today;

  /// للاختبارات — الافتراضي مستودع على قاعدة التطبيق.
  final RecordsRepository? records;

  /// بيتندَه بالـid بتاع سجل الروشتة اللي اتكتب — «تابع زيارة» بتبدأ منه.
  final void Function(int recordId)? onSaved;

  @override
  State<ReviewPrescriptionScreen> createState() => _ReviewPrescriptionScreenState();
}

class _ReviewPrescriptionScreenState extends State<ReviewPrescriptionScreen> {
  /// **الشاشة دي مسوّدة.** كل سطر هنا في الذاكرة لحد ما «تمام، ظبّطهم»
  /// تتداس — وساعتها بس بيتكتبوا كلهم مرة واحدة.
  ///
  /// قبل كده «عدّل» كانت بتحفظ فوراً و«تمام» بتحفظ الباقي، فروشتة واحدة
  /// كانت بتتكتب على مرتين من زرارين مختلفين — وده اللي خبّى ضياع الجرعات.
  late final List<_DraftLine> _lines = [
    for (final read in widget.reading.lines) _DraftLine.fromRead(read),
  ];

  bool _busy = false;

  /// الأدوية اتحفظت بس صف الروشتة في الملف الصحي وقع.
  ///
  /// الوعد اتنفّذ (الدوا هيرنّ)، فمش هنرجّع حاجة — بس **بنقول**. قبل كده
  /// الفشل ده كان `debugPrint` وبس: المستخدم بيقفل الشاشة وهو فاكر إن
  /// روشتته اتسجّلت، وبيلاقي الملف الصحي فاضي من غير ما يعرف ليه.
  bool _fileFailed = false;

  /// ترويسة الورقة زي ما الإنسان سابها: الدكتور، العيادة، وتاريخها.
  ///
  /// روشتة من غير مين وإمتى مش سجل طبي — «ملخص زيارة الطبيب» بيبص عليها
  /// ومفيش حاجة يقولها. الثلاثة دي بتتعدّل هنا زي أي سطر دوا.
  late String? _doctor = widget.reading.doctor.value;
  late String? _clinic = widget.reading.clinic.value;
  late DateTime? _issuedAt = widget.reading.issuedAt.value;

  /// الإنسان عدّل الحقل ده بإيده — فالشك بتاع الذكاء خلص.
  final Set<String> _headerEdited = {};

  /// حقل التعديل بتاع الشيت — **واحد للشاشة كلها، بيتقفل مع الشاشة**.
  ///
  /// كان بيتعمل جوّه `_editText` وبيتقفل أول ما `FSheet.show` ترجع. بس
  /// الشيت وقتها لسه بيطلع من الشاشة: الرسمة اللي بعدها بتبني الـTextField
  /// تاني بكنترولر متقفل وبترمي «A TextEditingController was used after
  /// being disposed». اختبار «عدّل العيادة» هو اللي مسكها.
  final TextEditingController _headerController = TextEditingController();

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  /// التاريخ هيتسجّل النهاردة لأن الورقة ما قالتش تاريخ.
  bool get _dateFallback => _issuedAt == null;

  /// القيمة اللي بتتحفظ فعلاً — **والتخمين ما بيدخلش ملف حد**.
  ///
  /// الذكاء مش متأكد والإنسان ما راجعهاش؟ يبقى العمود يفضل فاضي. المستخدم
  /// دوس «تمام» على الأدوية، مش بالضرورة قرا الترويسة — و«د. هشـ؟» في ملف
  /// طبي أوحش من خانة فاضية. عدّلها بإيده؟ يبقى دي بتاعته وبتتحفظ.
  String? _confirmedHeader(String key, String? value, ReadField<String> read) =>
      _headerEdited.contains(key) || !read.needsReview ? value : null;

  DateTime get _today => widget.today ?? DateTime.now();

  /// الروتين الحي — بيتحدّث لما «حدّد ميعاد الفطار» يتحفظ.
  late DayRoutine _routine = widget.routine;

  /// **اقتراح الذكاء على مرساة ما اتحددتش ما بيتملاش لوحده.** «قبل الفطار»
  /// والفطار مش متحدد = سؤال للإنسان هنا، مش رقم من الافتراضي. بيقفل
  /// «تمام» لحد ما يجاوب، والإجابة بتتحفظ في روتينه متحددة.
  Set<DayAnchor> _unsetAnchorsOf(_DraftLine line) => {
        for (final t in line.timings)
          if (t case AnchorTiming(:final anchor) when !_routine.isSet(anchor)) anchor,
      };

  Future<void> _askAnchor(DayAnchor anchor) async {
    final services = AppScope.of(context);
    final picked = await askAnchorTime(context, anchor: anchor, say: PatientVoice.of(context));
    if (picked == null || !mounted) return;
    await services.routines.setAnchor(services.patientId, anchor, picked);
    if (mounted) setState(() => _routine = _routine.withAnchor(anchor, picked));
  }

  /// السطور اللي هتتحفظ فعلاً — اللي اتشال مش فيها.
  List<_DraftLine> get _keep => [for (final l in _lines) if (!l.deleted) l];

  /// **«تمام» دايماً مفتوحة** (٢٦ سبتمبر ٢٠٢٦ — تعليق المختبِر). اللي مش
  /// واضح بيتحفظ «مش معروف» ومش بيتخمّن: الجرعة «مش معروفة»، والاسم بثقة
  /// قليلة بيفضل مظلّل «اتأكد من الاسم»، والمرساة اللي ما اتحددتش بتتسأل
  /// **بعد** «تمام» مرة واحدة (وممكن تتعدّى) — لحد ما تتحدد جرعاتها بس
  /// هي اللي ساكتة وعليها «؟»، والباقي بيتجدول عادي.
  ///
  /// اللي **ما ينفعش يتحفظ أصلاً** — من غير اسم خالص أو من غير ولا ميعاد —
  /// مفيش حاجة تتكتب منه، فبيتساب برّه العدّ وبيتقال بالكلام؛ الباقي بيتحفظ.
  List<_DraftLine> get _saveable => [for (final l in _keep) if (!l.blocks) l];
  bool get _hasUnsaveable => _keep.any((l) => l.blocks);

  /// جرعة مش معروفة بس — بتتحفظ «مش معروفة» ونسأل عنها بعدين.
  bool get _hasUnknownAmount => _keep.any((l) => l.amountUnknown);

  /// أول سطر «أعدّل» هيروح له: اللي بيقفل، وإلا اللي محتاج مراجعة، وإلا الأول.
  int? get _firstToEdit {
    for (final (i, l) in _lines.indexed) {
      if (!l.deleted && l.blocks) return i;
    }
    for (final (i, l) in _lines.indexed) {
      if (!l.deleted && l.needsReview) return i;
    }
    for (final (i, l) in _lines.indexed) {
      if (!l.deleted) return i;
    }
    return null;
  }

  /// «عدّل»: بيعدّل السطر **في الذاكرة** وبيرجع — ولا بايت بيتكتب.
  Future<void> _edit(int index) async {
    final line = _lines[index];
    // **كل** جرعات السطر — مش أولها. دوا مرتين في اليوم بيتعدّل مرتين.
    final draft = await Navigator.of(context).push<MedicationDraft>(
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(
          draft: true,
          routine: _routine,
          today: widget.today,
          initialName: line.name,
          initialAmount: line.amountLabel,
          initialTimings: line.timings,
          initialDurationDays: line.durationDays,
          initialOnce: line.once,
          initialAlertMode: line.alertMode,
          initialPurpose: line.purpose,
          initialInstructions: line.instructions,
          initialStartDate: line.startDate,
          // جرعة الورقة مش واضحة → تفضل «مش معروفة» لو سابها فاضية
          initialAmountUnknown: line.amountUnknown,
        ),
      ),
    );
    if (draft != null && mounted) setState(() => _lines[index].applyDraft(draft));
  }

  /// سطر ما اتقراش خالص — بيتكتب بإيد إنسان، وبيدخل المسوّدة زي أي سطر.
  Future<void> _addUnread() async {
    final draft = await Navigator.of(context).push<MedicationDraft>(
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(draft: true, routine: _routine, today: widget.today),
      ),
    );
    if (draft != null && mounted) setState(() => _lines.add(_DraftLine.fromDraft(draft)));
  }

  /// تعديل حقل نصي في الترويسة — شيت صغير بحقل واحد.
  ///
  /// فاضي = «مش مكتوب»، مش نص فاضي: الملف الصحي بيعرض «لسه ما اتملاش»،
  /// وما بنخترعش قيمة عشان نملا خانة.
  Future<void> _editText({
    required String title,
    required String? initial,
    required void Function(String?) onSave,
  }) async {
    final controller = _headerController..text = initial ?? '';
    final navigator = Navigator.of(context);
    await FSheet.show<void>(
      context,
      title: title,
      children: [
        TextField(
          textInputAction: TextInputAction.done,
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: F.minBodySize),
          decoration: InputDecoration(
            hintText: 'زي ما هو مكتوب على الورقة',
            hintStyle: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
            filled: true,
            fillColor: F.fieldGround,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(F.radiusCard)),
          ),
        ),
        const SizedBox(height: F.gap),
        FPrimaryButton(
          label: 'احفظ',
          onPressed: () {
            final text = controller.text.trim();
            onSave(text.isEmpty ? null : text);
            navigator.pop();
          },
        ),
      ],
    );
  }

  /// تاريخ الورقة — منتقي تواريخ، ومش بيسمح بتاريخ في المستقبل.
  Future<void> _pickIssuedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issuedAt ?? _today,
      firstDate: DateTime(_today.year - 5),
      lastDate: _today,
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() {
        _issuedAt = DateTime(picked.year, picked.month, picked.day);
        _headerEdited.add('date');
      });
    }
  }

  /// «شيله»: بيطلع من المسوّدة — والتراجع **مكانه في القايمة**، مش SnackBar.
  ///
  /// دوا الدكتور ما كتبهوش، أو تكرار الذكاء اخترعه، لازم ينشال من هنا — من
  /// غير ما حد يسيب الشاشة ولا يمسح دوا اتحفظ بالغلط بعدين.
  ///
  /// والتراجع بيفضل ظاهر لحد ما يخلّص: شريط بيختفي بعد ٦ ثواني بيطلب من راجل
  /// في السبعين إنه يسابق الوقت، وبيغطّي زرار «تمام» اللي تحته وهو ظاهر.
  void _delete(int index) => setState(() => _lines[index].deleted = true);

  void _undoDelete(int index) => setState(() => _lines[index].deleted = false);

  /// «تمام، ظبّطهم»: **الكتابة الوحيدة في الشاشة دي** — كل السطور الباقية
  /// في معاملة واحدة، وبعدها الجدولة. ولا حاجة بتوصل القاعدة قبل الدوسة دي.
  Future<void> _confirm() async {
    final keep = _saveable;
    if (_busy || keep.isEmpty) return;
    setState(() => _busy = true);

    final services = AppScope.of(context);
    final navigator = Navigator.of(context);

    final ids = await services.medications.addMedicationsWithDoses(
      patientId: services.patientId,
      startDate: _today,
      onceAt: {for (final (i, l) in keep.indexed) if (l.once) i},
      medications: [
        for (final l in keep)
          (
            name: l.name!,
            timings: l.timings,
            // جرعة مش واضحة → null + «مش معروفة». مش بنخترع قيمة عشان نكمّل.
            amountLabel: l.amountUnknown ? null : l.amountLabel,
            amountUnknown: l.amountUnknown,
            durationDays: l.durationDays, // null = مفتوحة، زي ما الورقة سابتها
            alertMode: l.alertMode,
            purpose: l.purpose,
            instructions: l.instructions,
            startDate: l.startDate,
          ),
      ],
    );
    await services.scheduler.rescheduleAll();

    // **مرساة ما اتحددتش — سؤال واحد بعد الحفظ، وممكن يتعدّى.** الدوا
    // اتحفظ على مرساته زي ما الورقة قالت، والمحرّك بيسكت عن المرساة اللي
    // ما اتحددتش (`routine_unset_test`) لحد ما تتحدد — هنا أو من «عدّل
    // يومك». الإجابة بتتحفظ في روتينه وبتعيد الجدولة؛ القفل بيكتب ولا حاجة.
    final unset = {for (final l in keep) ..._unsetAnchorsOf(l)};
    var anySet = false;
    for (final anchor in unset) {
      if (!mounted) break;
      final picked = await askAnchorTime(context, anchor: anchor, say: PatientVoice.of(context));
      if (picked == null) continue;
      await services.routines.setAnchor(services.patientId, anchor, picked);
      anySet = true;
    }
    if (anySet) await services.scheduler.rescheduleAll();

    // «لسه ماتشترتش» — **بعد** الجدولة وبرّاها: علامة على الدوا وبس،
    // والتذكير اتجدول فوق زي ما هو بالظبط.
    final notBought = NotBoughtRepository(services.db);
    for (final (i, l) in keep.indexed) {
      if (!l.bought && i < ids.length) await notBought.markNotBought(ids[i]);
    }

    // الملف الصحي (D3.5): الروشتة اللي اتأكدت بتتسجّل — بالتاريخ والأدوية.
    // بعد الأدوية والجدولة (دول الوعد)؛ لو السطر ده فشل التأكيد ما بيتلغيش.
    // الدكتور بس لو القراءة واثقة منه — مفيش تخمين في ملف حد.
    final names = [for (final l in keep) l.name!];

    // الصورة الأول: لو تخزينها فشل، الروشتة بتتسجّل من غيرها — الأدوية
    // والسجل هما اللي مهمين. **والصورة بتفضل على الموبايل ده**: مفيش رفع
    // هنا، و`attachment_path` مالوش عمود في السحابة أصلاً، فالوعد اللي في
    // «دائرة الرعاية» («مش هيشوفوا الصور») بيفضل صح.
    String? path;
    final image = widget.image;
    if (image != null) {
      try {
        path = await services.attachments.save(image);
      } catch (error) {
        debugPrint('صورة الروشتة ما اتحفظتش: $error');
      }
    }

    try {
      final issued = _issuedAt;
      final recordId = await (widget.records ?? RecordsRepository(services.db)).add(
        patientId: services.patientId,
        kind: RecordKind.prescription,
        title: prescriptionRecordTitle(names.length),
        // تاريخ الورقة لو مقروء، وإلا النهاردة — والشاشة قالت كده قبل الدوسة.
        happenedAt: issued ?? DateTime(_today.year, _today.month, _today.day),
        doctor: _confirmedHeader('doctor', _doctor, widget.reading.doctor),
        place: _confirmedHeader('clinic', _clinic, widget.reading.clinic),
        notes: names.join(' — '),
        attachmentPath: path,
      );
      widget.onSaved?.call(recordId);
    } catch (error, stack) {
      // السبب الحقيقي في اللوج — والمستخدم بيشوف جملة، مش صمت.
      debugPrint('الروشتة اتحفظت بس ما اتسجّلتش في الملف الصحي: $error\n$stack');
      if (mounted) setState(() => _fileFailed = true);
      return; // الشاشة بتفضل مفتوحة بالجملة — الخروج بدوسة منه
    }

    if (mounted) navigator.pop(ReviewResult.confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final engine = ScheduleEngine(_routine);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(F.gap, 0, F.gap, F.gap),
                children: [
                  const Kicker('مراجعة وتأكيد'),
                  const SizedBox(height: F.s4),
                  HelpRow(
                    id: 'help_review',
                    child: Text(
                      'الذكاء يقترح، وأنت تؤكّد',
                      style: TextStyle(
                        fontFamily: F.displayFamily,
                        fontSize: F.screenTitleSize,
                        fontWeight: FontWeight.w700,
                        color: F.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: F.s6),
                  Text(
                    'راجع كل دوا قبل ما يتحفظ. اللي عليه علامة ذهبية الذكاء مش متأكد منه.',
                    style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.6),
                  ),
                  const SizedBox(height: F.gap),
                  // ترويسة الورقة — فوق الأدوية، لأنها بتوصف الروشتة كلها.
                  _HeaderField(
                    label: 'الدكتور',
                    value: _doctor,
                    hint: 'مش مكتوب على الورقة',
                    unsure: !_headerEdited.contains('doctor') && reading.doctor.needsReview,
                    note: reading.doctor.note,
                    onEdit: () => _editText(
                      title: 'اسم الدكتور',
                      initial: _doctor,
                      onSave: (v) => setState(() {
                        _doctor = v;
                        _headerEdited.add('doctor');
                      }),
                    ),
                  ),
                  const SizedBox(height: F.s8),
                  _HeaderField(
                    label: 'العيادة أو المستشفى',
                    value: _clinic,
                    hint: 'مش مكتوبة على الورقة',
                    unsure: !_headerEdited.contains('clinic') && reading.clinic.needsReview,
                    note: reading.clinic.note,
                    onEdit: () => _editText(
                      title: 'العيادة أو المستشفى',
                      initial: _clinic,
                      onSave: (v) => setState(() {
                        _clinic = v;
                        _headerEdited.add('clinic');
                      }),
                    ),
                  ),
                  const SizedBox(height: F.s8),
                  _HeaderField(
                    label: 'تاريخ الورقة',
                    value: _issuedAt == null ? null : arabicDate(_issuedAt!),
                    hint: 'مش مكتوب على الورقة',
                    unsure: !_headerEdited.contains('date') && reading.issuedAt.needsReview,
                    note: reading.issuedAt.note,
                    onEdit: _pickIssuedAt,
                  ),
                  if (_dateFallback) ...[
                    const SizedBox(height: F.s8),
                    // **تاريخ غلط في ملف طبي أوحش من تاريخ ناقص** — فبنقولها
                    // قبل الدوسة، مش بعدها.
                    GoldNote(
                      'الورقة مش كاتبة تاريخ — هتتسجّل بتاريخ النهاردة '
                      '(${arabicDate(_today)}). لو تاريخها غير كده، حدّده.',
                      key: const ValueKey('date-fallback'),
                    ),
                  ],
                  if (kDebugMode && reading.modelWarning != null) ...[
                    const SizedBox(height: F.s8),
                    DebugPanel(reading.modelWarning!),
                  ],
                  const SizedBox(height: F.gap),
                  if (_fileFailed) ...[
                    Container(
                      key: const ValueKey('file-failed'),
                      padding: const EdgeInsets.all(F.s12),
                      decoration: BoxDecoration(
                        color: F.railGround,
                        borderRadius: BorderRadius.circular(F.radiusTile),
                        border: Border.all(color: F.gold, width: 1.5),
                      ),
                      child: Text(
                        'الأدوية اتحفظت وهتفكّرك بيها — بس الروشتة نفسها ما اتسجّلتش '
                        'في الملف الصحي. تقدر تسجّلها بإيدك من «ضيف».',
                        style: TextStyle(fontSize: F.minTextSize, color: F.ink, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: F.gap),
                  ],
                  if (reading.isEmpty && _lines.isEmpty)
                    const _EmptyReading()
                  else
                    for (final (i, line) in _lines.indexed)
                      if (line.deleted) ...[
                        _RemovedRow(
                          name: line.name ?? 'السطر',
                          onUndo: _busy ? null : () => _undoDelete(i),
                        ),
                        const SizedBox(height: F.s12),
                      ] else ...[
                        _MedicineRow(
                          index: i,
                          line: line,
                          timeFor: (t) => switch (t) {
                            // مرساة مش متحددة: مفيش ساعة تتقال — السؤال تحت
                            AnchorTiming(:final anchor) when !_routine.isSet(anchor) =>
                              'ميعاد ${anchor.label} مش متحدد',
                            AnchorTiming(:final anchor, :final offsetMinutes) => arabicTime(
                                engine.resolveTime(anchor: anchor, offsetMinutes: offsetMinutes, onDay: _today)),
                            FixedTiming(:final minuteOfDay) =>
                              arabicTime(engine.resolveFixed(minuteOfDay: minuteOfDay, onDay: _today)),
                          },
                          unsetAnchors: _unsetAnchorsOf(line),
                          onAskAnchor: _busy ? null : _askAnchor,
                          onEdit: _busy ? null : () => _edit(i),
                          onDelete: _busy ? null : () => _delete(i),
                          onBought: _busy ? null : (v) => setState(() => line.bought = v),
                        ),
                        const SizedBox(height: F.s12),
                      ],
                  if (_keep.isEmpty && _lines.isNotEmpty) ...[
                    Container(
                      key: const ValueKey('all-removed'),
                      padding: const EdgeInsets.all(F.s12),
                      decoration: BoxDecoration(
                        color: F.railGround,
                        borderRadius: BorderRadius.circular(F.radiusTile),
                      ),
                      child: Text(
                        'شيلت كل الأدوية — مفيش حاجة تتأكّد. رجّع واحد أو صوّر تاني.',
                        style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: F.s12),
                  ],
                  _AddUnreadRow(onTap: _busy ? null : _addUnread),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(F.gap, 0, F.gap, F.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasUnsaveable)
                    Padding(
                      padding: EdgeInsets.only(bottom: F.s8),
                      child: Text(
                        key: const ValueKey('unsaveable-note'),
                        'في دوا من غير اسم أو من غير ميعاد — مش هيتحفظ لحد ما تكتبه من «أعدّل» أو تشيله. الباقي بيتحفظ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: F.minTextSize, color: F.ink, height: 1.5),
                      ),
                    )
                  else if (_hasUnknownAmount)
                    Padding(
                      padding: EdgeInsets.only(bottom: F.s8),
                      child: Text(
                        'هتتحفظ من غير الجرعة — تقدر تضيفها بعدين',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.5),
                      ),
                    ),
                  // القراءة الوحشة علاجها صورة أحسن، مش تعديل خمس حقول بالإيد.
                  SizedBox(
                    height: F.minTapTarget,
                    child: TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(ReviewResult.retake),
                      child: Text(
                        'صوّر تاني',
                        style: TextStyle(
                          fontSize: F.minBodySize,
                          fontWeight: FontWeight.w600,
                          color: F.green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: F.s4),
                  if (_fileFailed)
                    _EqualButton(
                      key: const ValueKey('close-review'),
                      label: 'تمام',
                      fill: F.green,
                      onPressed: () => Navigator.of(context).pop(ReviewResult.confirmed),
                    )
                  else
                  // الزرارين نفس الوزن بالظبط: مليانين، نفس المقاس والخط.
                  Row(
                    children: [
                      Expanded(
                        child: _EqualButton(
                          label: 'أعدّل',
                          fill: F.ink,
                          onPressed: _busy || _firstToEdit == null ? null : () => _edit(_firstToEdit!),
                        ),
                      ),
                      const SizedBox(width: F.s10),
                      Expanded(
                        child: _EqualButton(
                          key: const ValueKey('confirm-review'),
                          // العدد على الزرار: اللي بيتأكّد لازم يعرف هيحفظ كام
                          label: 'تمام — ${_countWord(_saveable.length)}',
                          fill: F.green,
                          onPressed: _busy || _saveable.isEmpty ? null : _confirm,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زرار من الاتنين — كل الفرق بينهم لون التعبئة، والاتنين غامقين.
class _EqualButton extends StatelessWidget {
  const _EqualButton({required this.label, required this.fill, required this.onPressed, super.key});

  final String label;
  final Color fill;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: F.primaryButtonHeight,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: fill,
            foregroundColor: F.onDark,
            disabledBackgroundColor: F.railGround,
            disabledForegroundColor: F.mutedDark,
            textStyle: const TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(F.radiusCard)),
            padding: const EdgeInsets.symmetric(horizontal: F.s8),
          ),
          child: Text(label, maxLines: 1),
        ),
      );
}

/// صف دوا واحد.
class _MedicineRow extends StatelessWidget {
  const _MedicineRow({
    required this.index,
    required this.line,
    required this.timeFor,
    required this.onEdit,
    required this.onDelete,
    this.unsetAnchors = const {},
    this.onAskAnchor,
    this.onBought,
  });

  /// «اشتريته؟» — null = السؤال مش معروض.
  final ValueChanged<bool>? onBought;

  /// المراسي اللي السطر ده محتاجها والمستخدم ما حدّدهاش — سؤال لكل واحدة.
  final Set<DayAnchor> unsetAnchors;
  final Future<void> Function(DayAnchor anchor)? onAskAnchor;

  /// ترتيبه في المسوّدة — بيدخل في مفاتيح أزراره عشان يتفرّق عن ترويسة الورقة.
  final int index;

  /// سطر المسوّدة — اللي هيتحفظ، مش اللي الورقة قالته بالظبط.
  final _DraftLine line;
  final String Function(DoseTiming) timeFor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final read = line.read;
    final edited = line.edited;
    final timings = line.timings;
    final unsure = line.needsReview;
    final name = line.name;

    // الاسم بثقة قليلة بيفضل مظلّل بكلمته — بيتحفظ زي ما الورقة قالته، والإنسان
    // هو اللي بيتأكد. مش بيقفل حاجة.
    final unsureName = read != null && read.name.needsReview && !line.edited;
    final unsureFields = [
      if (read != null && !edited) ...[
        if (read.name.needsReview) ('الاسم', read.name.note),
        if (read.timings.needsReview) ('التوقيت', read.timings.note),
        if (read.amount.needsReview) ('الجرعة', read.amount.note),
      ],
    ];

    final body = Padding(
      padding: const EdgeInsets.all(F.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        name ?? 'الاسم مش واضح',
                        textDirection: name == null ? null : nameDirection(name),
                        style: TextStyle(
                          fontSize: name == null ? F.minBodySize : F.medicationNameSize,
                          fontWeight: FontWeight.w700,
                          color: F.ink,
                          fontFamily: name == null ? null : F.monoFamily,
                          fontFamilyFallback: name == null ? null : F.monoFallback,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (unsureName) ...[
                      const SizedBox(height: F.s6),
                      GoldNote('اتأكد من الاسم', key: ValueKey('unsure-name-$index')),
                    ],
                    const SizedBox(height: F.s4),
                    Text(
                      [
                        line.amountUnknown
                            ? 'الجرعة مش معروفة'
                            : (line.amountLabel ?? 'الجرعة مش معروفة'),
                        switch (line.durationDays) {
                          _ when line.once => 'مرة واحدة بس',
                          null => 'مفتوحة — لحد ما توقفه',
                          final d => '${arabicNumber(d)} يوم',
                        },
                      ].join(' — '),
                      style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: F.s8),
              if (edited)
                Padding(
                  padding: const EdgeInsets.only(top: F.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: F.greenOk, size: 24),
                      const SizedBox(width: F.s4),
                      Text(
                        'اتعدّل',
                        style: TextStyle(
                          fontSize: F.minTextSize,
                          fontWeight: FontWeight.w700,
                          color: F.greenOk,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: F.s10),
          // الوقت المحسوب + شريحة القاعدة — لكل توقيت. القاعدة هي اللي
          // بتتحفظ؛ الساعة للعرض بس.
          if (timings.isEmpty)
            Text(
              'التوقيت مش واضح',
              style: TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w600, color: F.ink),
            )
          else
            Wrap(
              spacing: F.s12,
              runSpacing: F.s8,
              children: [
                for (final t in timings)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeFor(t),
                        style: TextStyle(
                          fontSize: F.minBodySize,
                          fontWeight: FontWeight.w700,
                          color: F.ink,
                        ),
                      ),
                      const SizedBox(width: F.s6),
                      StatusChip(label: t.ruleLabel),
                    ],
                  ),
              ],
            ),
          if (!unsure && !edited && read != null) ...[
            const SizedBox(height: F.s8),
            Text(
              'ثقة ${arabicNumber((line.confidence * 100).round())}٪',
              style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
            ),
          ],
          if (unsetAnchors.isNotEmpty) ...[
            const SizedBox(height: F.s12),
            // الورقة قالت «قبل الفطار» والفطار مش متحدد: مفيش رقم بيتخمّن
            // مكانه — سؤال للإنسان، والإجابة بتتحفظ في روتينه مرة واحدة.
            GoldNote(
              key: ValueKey('unset-anchor-note-$index'),
              'الورقة بتقول ${unsetAnchors.map((a) => a.label).join(' و')} — وإنت لسه '
              'ما حدّدتش ميعاده. هنسألك بعد «تمام»، ولحد ما تحدده الجرعة دي بس هتفضل ساكتة.',
            ),
            for (final anchor in unsetAnchors) ...[
              const SizedBox(height: F.s8),
              FSecondaryButton(
                key: ValueKey('ask-anchor-$index-${anchor.name}'),
                label: 'حدّد ميعاد ${anchor.label}',
                onPressed: onAskAnchor == null ? null : () => onAskAnchor!(anchor),
              ),
            ],
          ],
          if (onBought case final setBought?) ...[
            const SizedBox(height: F.s12),
            Row(
              children: [
                Expanded(
                  child: Text('اشتريته؟', style: TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w700, color: F.ink)),
                ),
                const SizedBox(width: F.s8),
                const HelpButton('help_bought'),
              ],
            ),
            const SizedBox(height: F.s6),
            Row(
              children: [
                Expanded(
                  child: _BoughtChip(
                    key: ValueKey('bought-yes-$index'),
                    label: 'أيوه',
                    selected: line.bought,
                    onTap: () => setBought(true),
                  ),
                ),
                const SizedBox(width: F.s8),
                Expanded(
                  child: _BoughtChip(
                    key: ValueKey('bought-no-$index'),
                    label: 'لسه',
                    selected: !line.bought,
                    onTap: () => setBought(false),
                  ),
                ),
              ],
            ),
            if (!line.bought) ...[
              const SizedBox(height: F.s6),
              Text(
                'هيتحط في «أدوية لسه ماتشترتش» — والتذكير بيبدأ في ميعاده عادي.',
                style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.45),
              ),
            ],
          ],
          const SizedBox(height: F.s12),
          // التعديل والشيل مع بعض في آخر الكارت: الاتنين بكلمة، والاتنين
          // على المسوّدة — ولا واحد فيهم بيكتب في القاعدة.
          Row(
            children: [
              Expanded(
                child: _RowButton(
                  key: ValueKey('edit-line-$index'),
                  icon: Icons.edit_outlined,
                  label: 'عدّل',
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: F.s8),
              Expanded(
                child: _RowButton(
                  key: ValueKey('remove-line-$index'),
                  icon: Icons.delete_outline,
                  label: 'شيله',
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
          if (unsure) ...[
            const SizedBox(height: F.s12),
            // الشك مكتوب بهدوء: عنوان، وكل حقل مش متأكد منه بملاحظته.
            Container(
              padding: const EdgeInsets.all(F.s12),
              decoration: BoxDecoration(
                color: F.railGround,
                borderRadius: BorderRadius.circular(F.radiusTile),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'مش متأكد من دي — راجعها',
                    style: TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w700, color: F.ink),
                  ),
                  for (final (label, note) in unsureFields) ...[
                    const SizedBox(height: F.s4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$label: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: note ?? 'مش واضح في الصورة'),
                        ],
                      ),
                      style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: F.cardGround,
          borderRadius: BorderRadius.circular(F.radiusCard),
          border: Border.all(color: unsure ? F.gold : F.line, width: unsure ? 1.5 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              // حافة ذهبية على جنب واحد — آخر ابن في RTL = الشمال، زي README
              if (unsure) Container(key: const ValueKey('unsure-edge'), width: 6, color: F.gold),
            ],
          ),
        ),
    );
  }
}

/// «أضف دوا ما اتعرفش عليه» — حد متقطع، زرار بكلمة وأيقونة.
class _AddUnreadRow extends StatelessWidget {
  const _AddUnreadRow({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedBorder(color: F.mutedLight, radius: F.radiusCard),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(F.radiusCard),
            child: Container(
              constraints: const BoxConstraints(minHeight: F.minTapTarget + F.s8),
              padding: const EdgeInsets.symmetric(horizontal: F.gap, vertical: F.s12),
              child: Row(
                children: [
                  Icon(Icons.add, color: F.green, size: 26),
                  SizedBox(width: F.s8),
                  Expanded(
                    child: Text(
                      'أضف دوا ما اتعرفش عليه',
                      style: TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w700, color: F.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        Radius.circular(radius),
      ));
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}

class _EmptyReading extends StatelessWidget {
  const _EmptyReading();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: F.s12),
        padding: const EdgeInsets.all(F.gap),
        decoration: BoxDecoration(
          color: F.railGround,
          borderRadius: BorderRadius.circular(F.radiusCard),
        ),
        child: Text(
          'مقدرتش ألاقي أدوية في الصورة دي. صوّر تاني والنور يكون كويس.',
          style: TextStyle(fontSize: F.minBodySize, color: F.ink, height: 1.6),
        ),
      );
}

/// «دوا واحد» / «دواءين» / «٣ أدوية» — للزرار.
String _countWord(int count) => switch (count) {
      0 => 'مفيش أدوية',
      1 => 'دوا واحد',
      2 => 'دواءين',
      _ => '${arabicNumber(count)} أدوية',
    };

/// سطر في المسوّدة: اللي الورقة قالته + اللي الإنسان غيّره، ولسه ما اتحفظش.
class _DraftLine {
  _DraftLine({
    required this.read,
    required this.name,
    required this.amountLabel,
    required this.amountUnknown,
    required this.timings,
    required this.durationDays,
    this.alertMode,
    this.purpose,
    this.instructions,
    this.edited = false,
  });

  /// نوع التنبيه — الورقة ما بتقولوش، فمن القراية دايماً null (الافتراضي)؛
  /// «عدّل» ممكن يحدده. ونفس الكلام لـ«لإيه؟» و«تعليمات».
  AlertMode? alertMode;
  MedicationPurpose? purpose;
  String? instructions;

  /// من قراية الذكاء — بثقتها وملاحظاتها زي ما هي.
  /// «هتبدأ الدوا من إمتى؟» لو اتغيّرت من «عدّل» — null = يوم التأكيد.
  DateTime? startDate;

  /// «اشتريته؟» — أيوه افتراضياً، فاللي ما ردّش ما بيتغيّرلوش حاجة. «لسه»
  /// بيحطّه في «أدوية لسه ماتشترتش» وبس — **التذكير بيبدأ زي ما هو**.
  bool bought = true;

  /// «مرة واحدة» (`DoseRepeat.once`).
  bool once = false;

  factory _DraftLine.fromRead(ReadLine read) => _DraftLine(
        read: read,
        name: read.name.value,
        amountLabel: read.amount.value,
        amountUnknown: read.amount.needsReview,
        timings: read.timings.value ?? const [],
        // «اليوم فقط» / «مرة واحدة» (القارئ بيرجّعها ١) = `DoseRepeat.once`
        // — نفس السلوك بالظبط، بكلمته
        durationDays: read.duration.value == 1 ? null : read.duration.value,
        instructions: read.instructions.needsReview ? null : read.instructions.value,
      )..once = read.duration.value == 1;

  /// «أضف دوا ما اتعرفش عليه» — إنسان كتبه، فمفيش شك فيه.
  factory _DraftLine.fromDraft(MedicationDraft d) => _DraftLine(
        read: null,
        name: d.name,
        amountLabel: d.amountLabel,
        amountUnknown: d.amountUnknown,
        timings: d.timings,
        durationDays: d.durationDays,
        alertMode: d.alertMode,
        purpose: d.purpose,
        instructions: d.instructions,
        edited: true,
      )
        ..startDate = d.startDate
        ..once = d.once;

  /// null = السطر اتكتب بالإيد، مش من الورقة.
  final ReadLine? read;

  String? name;
  String? amountLabel;
  bool amountUnknown;
  List<DoseTiming> timings;
  int? durationDays;

  /// إنسان عدّاها بإيده — فالشك بتاع الذكاء خلص.
  bool edited;

  /// اتشال من المسوّدة (وممكن يرجع من «رجّعه»).
  bool deleted = false;

  void applyDraft(MedicationDraft d) {
    name = d.name;
    amountLabel = d.amountLabel;
    amountUnknown = d.amountUnknown;
    timings = d.timings;
    durationDays = d.durationDays;
    alertMode = d.alertMode;
    purpose = d.purpose;
    instructions = d.instructions;
    startDate = d.startDate;
    once = d.once;
    edited = true;
  }

  /// من غير اسم أو من غير جرعة مفيش حاجة تتجدول — ده اللي بيقفل «تمام».
  bool get blocks => (name ?? '').trim().isEmpty || timings.isEmpty;

  /// الذكاء مش متأكد، والإنسان لسه ما راجعهاش.
  bool get needsReview => !edited && (read?.needsReview ?? false);

  /// أقل ثقة في الحقول اللي بتتحفظ.
  double get confidence => read == null
      ? 1
      : [read!.name.confidence, read!.amount.confidence, read!.timings.confidence]
          .reduce((a, b) => a < b ? a : b);
}

/// سطر اتشال — مكانه في القايمة، والتراجع جنبه ومستني.
class _RemovedRow extends StatelessWidget {
  const _RemovedRow({required this.name, required this.onUndo});

  final String name;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('removed-row'),
        padding: const EdgeInsets.fromLTRB(F.s14, F.s8, F.s14, F.s8),
        decoration: BoxDecoration(
          color: F.railGround,
          borderRadius: BorderRadius.circular(F.radiusCard),
          border: Border.all(color: F.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'اتشال $name',
                style: TextStyle(
                  fontSize: F.minBodySize,
                  color: F.mutedDark,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
            const SizedBox(width: F.s8),
            _RowButton(icon: Icons.undo, label: 'رجّعه', onPressed: onUndo),
          ],
        ),
      );
}

/// حقل من ترويسة الورقة: الاسم، القيمة، و«عدّل».
///
/// الحافة الذهبية بنفس معنى سطر الدوا: «الذكاء مش متأكد — بصّ عليها».
/// وفاضي بيتقال بالكلام («مش مكتوب على الورقة») مش بشرطة.
class _HeaderField extends StatelessWidget {
  const _HeaderField({
    required this.label,
    required this.value,
    required this.hint,
    required this.unsure,
    required this.note,
    required this.onEdit,
  });

  final String label;
  final String? value;
  final String hint;
  final bool unsure;
  final String? note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('header-$label'),
        padding: const EdgeInsets.all(F.s12),
        decoration: BoxDecoration(
          color: F.cardGround,
          borderRadius: BorderRadius.circular(F.radiusCard),
          border: Border.all(color: unsure ? F.gold : F.line, width: unsure ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
                  ),
                  const SizedBox(height: F.s4),
                  Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: F.minBodySize,
                      fontWeight: FontWeight.w700,
                      color: value == null ? F.mutedDark : F.ink,
                    ),
                  ),
                  if (unsure) ...[
                    const SizedBox(height: F.s4),
                    Text(
                      note ?? 'مش متأكد من دي — راجعها',
                      style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: F.s8),
            _RowButton(icon: Icons.edit_outlined, label: 'عدّل', onPressed: onEdit),
          ],
        ),
      );
}

/// زرار صغير على كارت السطر — بأيقونة **وكلمة**.
class _RowButton extends StatelessWidget {
  const _RowButton({required this.icon, required this.label, required this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: F.minTapTarget,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: F.ink,
            minimumSize: const Size(0, F.minTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: F.s12),
            side: BorderSide(color: F.line, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(F.radiusTile)),
          ),
          icon: Icon(icon, size: 22),
          label: Text(label, style: const TextStyle(fontSize: F.minTextSize, fontWeight: FontWeight.w700)),
        ),
      );
}

/// «روشتة — دوا واحد» / «روشتة — دواءين» / «روشتة — ٣ أدوية».
String prescriptionRecordTitle(int count) => switch (count) {
      1 => 'روشتة — دوا واحد',
      2 => 'روشتة — دواءين',
      _ => 'روشتة — ${arabicNumber(count)} أدوية',
    };

/// «أيوه» / «لسه» — أخضر خفيف للمختار (زي كروت شاشة البداية)، مش ذهبي:
/// الإجابة الافتراضية مش حاجة محتاجة انتباه.
class _BoughtChip extends StatelessWidget {
  const _BoughtChip({required this.label, required this.selected, required this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: F.minTapTarget,
        child: Material(
          color: selected ? F.greenTint : F.railGround,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(F.radiusChip),
            side: BorderSide(color: selected ? F.green : F.line, width: selected ? 2 : 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(F.radiusChip),
            child: Center(
              child: Text(label,
                  style: TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w700, color: F.ink)),
            ),
          ),
        ),
      );
}
