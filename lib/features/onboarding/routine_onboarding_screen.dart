import 'dart:async';
import '../voice/help_button.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/patient_voice.dart';
import '../../core/widgets/primitives.dart';
import '../../domain/patient/sex.dart';
import '../../domain/scheduling/day_routine.dart';
import 'onboarding_voice.dart';
import 'profile_page.dart';
import 'routine_presets.dart';
import 'routine_question_page.dart';

/// خمس أسئلة، كل سؤال لوحده على شاشة.
///
/// سؤال واحد في المرة عن قصد: المستخدم عنده ٧٢ سنة وبيقرا بنضارة، وشاشة
/// فيها خمس أسئلة مع بعض بتبقى حيطة.
class RoutineOnboardingScreen extends StatefulWidget {
  const RoutineOnboardingScreen({
    this.onDone,
    this.askProfile = true,
    this.onBack,
    super.key,
  });

  /// بيتندَه بعد ما الروتين يتحفظ وتتعاد جدولة التذكيرات.
  final VoidCallback? onDone;

  /// «نتعرّف عليك» قبل الأسئلة لو الجنس لسه ما اتسألش. false = الأسئلة على
  /// طول (اختبارات الأسئلة نفسها).
  final bool askProfile;

  /// الرجوع لشاشة البداية — موجود بس قبل ما يبقى فيه مريض (اختيار غلط
  /// ما يحبسش حد في مسار مش بتاعه).
  final VoidCallback? onBack;

  @override
  State<RoutineOnboardingScreen> createState() =>
      _RoutineOnboardingScreenState();
}

class _RoutineOnboardingScreenState extends State<RoutineOnboardingScreen> {
  final _controller = PageController();
  final _profile = GlobalKey<ProfilePageState>();
  final Map<DayAnchor, MinuteOfDay> _answers = {};
  int _index = 0;
  bool _saving = false;

  /// null = لسه بنقرا صف المريض. true = «نتعرّف عليك» الأول.
  bool? _needsProfile;
  Sex? _sex;
  String? _name;

  /// صفحة «نتعرّف عليك» الحالية: ٠ الاسم، ١ الجنس، ٢ السن.
  int _profileStep = 0;

  /// جمل البداية اللي بتتقال لوحدها — لو قال «أيوه، اتكلّم» بس.
  OnboardingVoice _voice = OnboardingVoice(null);

  /// آخر سؤال اتجاوب — «تمام كده…» بتكمّل حتى والشاشة بتتقفل.
  bool _finishing = false;

  static const _profileLines = ['onb_name', 'onb_gender', 'onb_age'];
  static const _routineLines = {
    DayAnchor.wake: 'onb_wake',
    DayAnchor.breakfast: 'onb_breakfast',
    DayAnchor.lunch: 'onb_lunch',
    DayAnchor.dinner: 'onb_dinner',
    DayAnchor.sleep: 'onb_sleep',
  };

  /// جملة الصفحة اللي قدّامه دلوقتي — «ساعدني» فوق بيعيدها.
  String get _pageLine => _needsProfile == true
      ? _profileLines[_profileStep]
      : _routineLines[routineQuestions[_index].anchor]!;

  /// بتتقال لوحدها أول ما الصفحة تفتح، مرة واحدة. «مش دلوقتي» على أول سؤال
  /// في المواعيد بتتقال مرة بس، بعد الصحيان.
  void _announce() {
    if (_needsProfile == null) return;
    final line = _pageLine;
    unawaited(_voice.auto(line == 'onb_wake' ? const ['onb_wake', 'onb_routine_skip'] : [line], key: line));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voice.voice == null) _voice = OnboardingVoice(AppScope.of(context).voice);
    if (_needsProfile != null) return;
    if (!widget.askProfile) {
      _needsProfile = false;
      return;
    }
    final services = AppScope.of(context);
    services.routines.getPatient(services.patientId).then((row) {
      if (!mounted) return;
      setState(() {
        _sex = row?.sex;
        _name = row?.name;
        _needsProfile = row?.sex == null;
      });
      _announce();
    });
  }

  Future<void> _saveProfile({required String name, required Sex sex, int? age}) async {
    final services = AppScope.of(context);
    await services.routines.saveProfile(services.patientId, name: name, sex: sex, age: age);
    if (mounted) {
      setState(() {
        _sex = sex;
        _needsProfile = false;
      });
      _announce();
    }
  }

  @override
  void dispose() {
    // سابت الصفحة = الكلام يسكت — إلا «تمام كده…» بعد آخر سؤال
    if (!_finishing) _voice.hush();
    _controller.dispose();
    super.dispose();
  }

  void _profileTo(int step) {
    _voice.hush();
    setState(() => _profileStep = step);
    _announce();
  }

  /// «رجوع» فوق: صفحة لورا جوّه «نتعرّف عليك»، وإلا لشاشة البداية.
  VoidCallback? get _back {
    if (_needsProfile == true && _profileStep > 0) return () => _profileTo(_profileStep - 1);
    final out = widget.onBack;
    if (out == null) return null;
    return () {
      _voice.hush();
      out();
    };
  }

  MinuteOfDay _valueFor(RoutineQuestion question) =>
      _answers[question.anchor] ?? question.fallback;

  Future<void> _advance({List<String> before = const []}) async {
    if (_index < routineQuestions.length - 1) {
      setState(() => _index++);
      final line = _pageLine;
      unawaited(_voice.auto([...before, line], key: line));
      await _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    await _finish(before: before);
  }

  Future<void> _finish({List<String> before = const []}) async {
    if (_saving) return;
    setState(() => _saving = true);
    _finishing = _voice.on;
    unawaited(_voice.auto([...before, 'onb_routine_done']));

    final services = AppScope.of(context);
    await services.routines
        .saveRoutine(services.patientId, routineFromAnswers(_answers));

    // الأذونات بتتطلب هنا مش عند أول فتح — دلوقتي بقى واضح ليه التطبيق
    // محتاجها.
    await services.scheduler.ensurePermissions();
    await services.scheduler.rescheduleAll();

    if (!mounted) return;
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _needsProfile == true;
    return Scaffold(
      body: SafeArea(
        child: _needsProfile == null
            ? const SizedBox.shrink()
            // الأسئلة بتتكتب بجنس المريض اللي لسه مختاره — مش مستنية القاعدة
            : PatientVoice(
                say: Say(_sex),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(F.gap, F.gap, F.gap, F.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_back != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SizedBox(
                                height: F.minTapTarget,
                                child: TextButton.icon(
                                  key: const ValueKey('onboarding-back'),
                                  onPressed: _back,
                                  icon: const Icon(Icons.arrow_back, size: 22),
                                  label: const Text('رجوع'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: F.green,
                                    minimumSize: const Size(0, F.minTapTarget),
                                    textStyle: const TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          Kicker(profile ? 'أول خطوة' : 'مرة واحدة بس'),
                          const SizedBox(height: F.s4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile ? 'نتعرّف عليك' : Say(_sex).routineTitle,
                                  style: TextStyle(
                                    fontFamily: F.displayFamily,
                                    fontSize: F.screenTitleSize,
                                    fontWeight: FontWeight.w700,
                                    color: F.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: F.s8),
                              // مفيش «اتكلم» هنا (٢٦ سبتمبر ٢٠٢٦): البداية بالإيد والكتابة بس
                              // جملة الصفحة نفسها — نفس اللي اتقالت لوحدها
                              HelpButton(_pageLine),
                            ],
                          ),
                          if (!profile) ...[
                            const SizedBox(height: F.s4),
                            Text(
                              Say(_sex).routineSubtitle,
                              style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: profile
                          ? ProfilePage(
                              key: _profile,
                              initialName: _name,
                              onDone: _saveProfile,
                              step: _profileStep,
                              onStep: _profileTo,
                              onInteract: _voice.hush,
                            )
                          : PageView.builder(
                              controller: _controller,
                              // مفيش سحب بالإيد: كل سؤال بيتقفل بـ«تمام» أو «مش متأكد»،
                              // عشان محدش يعدّي سؤال من غير ما ياخد باله.
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: routineQuestions.length,
                              itemBuilder: (context, i) {
                                final question = routineQuestions[i];
                                return RoutineQuestionPage(
                                  question: question,
                                  stepNumber: i + 1,
                                  totalSteps: routineQuestions.length,
                                  value: _valueFor(question),
                                  onChanged: (value) {
                                    _voice.hush();
                                    setState(() => _answers[question.anchor] = value);
                                  },
                                  onConfirm: () {
                                    _voice.hush();
                                    _answers[question.anchor] = _valueFor(question);
                                    _advance();
                                  },
                                  onNotSure: () {
                                    // «مش دلوقتي» بتعدّي من غير إجابة — المرساة
                                    // بتتحفظ **مش متحددة**، ومفيش افتراضي بيتكتب
                                    // كأنه اختاره. بيحدّدها بعدين من «عدّل يومك»
                                    // أو أول ما دوا يحتاجها.
                                    _answers.remove(question.anchor);
                                    // «مفيش مشكلة لو سيبتها دلوقتي» — بيتقال قبل
                                    // جملة السؤال اللي بعده، مش فوقها
                                    _voice.hush();
                                    final voice = AppScope.of(context).voice;
                                    final reassure = voice?.enabled == true ? ['help_routine_skip'] : <String>[];
                                    _advance(before: reassure);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
