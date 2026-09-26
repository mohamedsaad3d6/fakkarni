import 'package:flutter/material.dart';

import '../../core/format/arabic_time.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/f_wheels.dart';
import '../../core/widgets/primitives.dart';
import '../../domain/patient/sex.dart';
import 'routine_question_page.dart' show ProgressDots;

/// «نتعرّف عليك» (المخطط 21) — أول خطوة قبل «ظبّط يومك».
///
/// **تلات صفحات، سؤال في كل صفحة** (٢٦ سبتمبر ٢٠٢٦): الاسم ← راجل ولا ست
/// ← السن. نفس البيانات اللي كانت بتتحفظ من الشاشة الواحدة، بتتحفظ مرة
/// واحدة بعد السن. الصفحة الحالية جاية من برّه ([step]) عشان «رجوع» فوق
/// يرجع صفحة، والمكتوب بيفضل في الـState هنا بين الصفحات.
///
/// الجنس هو اللي بيخلّي باقي الكلام يطلع صح («بتفطر» / «بتفطري»)، فالأسئلة
/// اللي بعدها بتتكتب بيه. السن اختياري: لو ما اختارش، بيتحفظ null — مش
/// بنكتب رقم ما قالهوش.
///
/// الجزء التاني في التصميم («الروشتة لو مش مكتوب فيها ميعاد؟») مش هنا:
/// اختياره التالت «افترض من غير ما تسأل» بيكسر القاعدة ٤.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.onDone,
    this.initialName,
    this.step = 0,
    this.onStep,
    this.onInteract,
    super.key,
  });

  final String? initialName;
  final Future<void> Function({required String name, required Sex sex, int? age}) onDone;

  /// ٠ الاسم، ١ الجنس، ٢ السن.
  final int step;

  /// «كمّل» على صفحة قبل الأخيرة بتطلب الصفحة اللي بعدها.
  final ValueChanged<int>? onStep;

  /// أي لمسة (كتابة، اختيار، بكرة) — الصوت بيسكت.
  final VoidCallback? onInteract;

  static const int steps = 3;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

/// حالة الصفحة.
class ProfilePageState extends State<ProfilePage> {
  late final _name = TextEditingController(
    // «أنا» اللي ensurePatient بيحطّه مش اسم — الحقل يبدأ فاضي
    text: widget.initialName == 'أنا' ? '' : (widget.initialName ?? ''),
  );
  Sex? _sex;

  /// null لحد ما يحرّك البكرة بنفسه — السؤال اختياري، والبكرة واقفة على
  /// ٦٠ مش معناه إنه قال ٦٠.
  int? _age;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => switch (widget.step) {
        0 => _name.text.trim().isNotEmpty,
        1 => _sex != null,
        _ => _name.text.trim().isNotEmpty && _sex != null,
      };

  Future<void> _next() async {
    if (!_ready || _busy) return;
    widget.onInteract?.call();
    if (widget.step < ProfilePage.steps - 1) {
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onStep?.call(widget.step + 1);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onDone(name: _name.text.trim(), sex: _sex!, age: _age);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _touch() => widget.onInteract?.call();

  List<Widget> _page(Say say) => switch (widget.step) {
        0 => [
            Text(
              'تلات حاجات بس عشان نكلّمك صح. لو بتظبط الموبايل لحد تاني، اكتب بياناته هو.',
              style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.35),
            ),
            const SizedBox(height: F.gap),
            const _Label('اسمك إيه؟'),
            TextField(
              key: const ValueKey('profile-name'),
              textInputAction: TextInputAction.done,
              controller: _name,
              onChanged: (_) {
                _touch();
                setState(() {});
              },
              onSubmitted: (_) => _next(),
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: F.minBodySize, color: F.ink),
              decoration: InputDecoration(
                hintText: 'اكتب اسمك — زي «الحاج أحمد»',
                hintStyle: TextStyle(fontSize: F.minTextSize, color: F.placeholder),
                filled: true,
                fillColor: F.fieldGround,
                contentPadding: const EdgeInsets.symmetric(horizontal: F.s14, vertical: F.s16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(F.radiusCard),
                  borderSide: BorderSide(color: F.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(F.radiusCard),
                  borderSide: BorderSide(color: F.green, width: 2),
                ),
              ),
            ),
          ],
        1 => [
            const _Label('راجل ولا ست؟'),
            Row(
              children: [
                Expanded(
                  child: AnchorChip(
                    key: const ValueKey('sex-m'),
                    label: 'راجل',
                    selected: _sex == Sex.m,
                    onTap: () {
                      _touch();
                      setState(() => _sex = Sex.m);
                    },
                  ),
                ),
                const SizedBox(width: F.s10),
                Expanded(
                  child: AnchorChip(
                    key: const ValueKey('sex-f'),
                    label: 'ست',
                    selected: _sex == Sex.f,
                    onTap: () {
                      _touch();
                      setState(() => _sex = Sex.f);
                    },
                  ),
                ),
              ],
            ),
          ],
        _ => [
            _Label(say.pick('سنّك كام؟ (لو حابب)', 'سنّك كام؟ (لو حابّة)')),
            AgeWheel(
              value: _age,
              clearLabel: say.pick('مش عايز أقول', 'مش عايزة أقول'),
              onChanged: (v) {
                _touch();
                setState(() => _age = v);
              },
            ),
            const SizedBox(height: F.gap),
            FCard(
              tone: FCardTone.warm,
              child: Text(
                'البيانات دي بتفضل على الموبايل ده. بنستخدمها عشان الكلام يطلع مظبوط — '
                'زي «${say.breakfastQuestion}»',
                style: TextStyle(fontSize: F.minTextSize, color: F.ink, height: 1.6),
              ),
            ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    // الكلام بيتبع الجنس أول ما يتختار — حتى على الصفحة دي نفسها
    final say = Say(_sex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: ValueKey('profile-step-${widget.step}'),
            padding: const EdgeInsets.fromLTRB(F.gap, F.s8, F.gap, F.gap),
            children: _page(say),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(F.gap, 0, F.gap, F.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FPrimaryButton(
                key: const ValueKey('profile-next'),
                label: _busy ? 'ثواني…' : 'كمّل',
                onPressed: _ready && !_busy ? _next : null,
              ),
              const SizedBox(height: F.s8),
              ProgressDots(current: widget.step + 1, total: ProfilePage.steps),
            ],
          ),
        ),
      ],
    );
  }
}

/// **بكرة السن — من ١٨ لـ١١٠، على [FNumberWheel] المشتركة.**
///
/// كانت شرايح نطاقات كلها فوق الستين («٦٠–٦٤» … «٨٥+»): واحد عنده ٤٠ سنة
/// وبياخد دوا ضغط مكانش يلاقي نفسه. البكرة بتبدأ واقفة على [restAge]
/// **من غير ما تكتب حاجة** — [value] بيفضل null لحد ما يحرّكها بإيده،
/// لأن السؤال اختياري و«واقفة على ٦٠» مش إجابة. «مش عايز أقول» بترجّعها
/// للراحة وبتمسح القيمة. اللي هنا بس التلميح والزرار؛ البكرة نفسها هي
/// بكرة كل رقم في التطبيق.
class AgeWheel extends StatelessWidget {
  const AgeWheel({
    required this.value,
    required this.onChanged,
    required this.clearLabel,
    super.key,
  });

  /// null = لسه ما قالش.
  final int? value;
  final ValueChanged<int?> onChanged;

  /// «مش عايز أقول» / «مش عايزة أقول» — بتيجي من [Say.pick].
  final String clearLabel;

  static const int minAge = 18;
  static const int maxAge = 110;

  /// فين البكرة بتقف لما مفيش إجابة. **مش قيمة افتراضية** — مفيش سن
  /// بيتكتب من غير ما يتحرّك لها.
  static const int restAge = 60;

  static const double itemExtent = FNumberWheel.itemExtent;

  /// **مقاس iPhone SE هو اللي حدده**: الاسم والجنس والبكرة وسطرها و«كمّل»
  /// كلهم لازم يبانوا من غير لفّ على ٦٦٧ بكسل.
  static const double wheelHeight = FNumberWheel.defaultHeight;

  static const String hint = 'حرّك البكرة لحد سنّك';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FNumberWheel(
            key: const ValueKey('age-wheel'),
            value: value,
            rest: restAge,
            min: minAge,
            max: maxAge,
            unit: 'سنة',
            semanticsLabel: 'السن',
            height: wheelHeight,
            onChanged: onChanged,
          ),
          const SizedBox(height: F.s4),
          // التلميح والزرار في صف واحد تحت البكرة — سطرين فوق بعض كانوا
          // بيزقّوا الزرار تحت حافة SE
          Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? hint : 'سنّك ${arabicNumber(value!)} سنة',
                  key: const ValueKey('age-hint'),
                  style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark, height: 1.4),
                ),
              ),
              SizedBox(
                height: F.minTapTarget,
                child: TextButton(
                  onPressed: () => onChanged(null),
                  child: Text(
                    clearLabel,
                    style: TextStyle(
                      fontSize: F.minTextSize,
                      fontWeight: FontWeight.w600,
                      color: F.mutedDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: F.s8),
        child: Text(
          text,
          style: TextStyle(fontSize: F.minBodySize, fontWeight: FontWeight.w700, color: F.ink, height: 1.3),
        ),
      );
}
