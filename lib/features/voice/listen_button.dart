import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/f_sheet.dart';
import '../../core/widgets/primitives.dart';
import '../../domain/voice/voice_catalog.dart';
import 'listen_flow.dart';
import 'mic_orb.dart';

/// «🎤 اتكلم» — **على شاشة التذكير بس** («كلّمني» ليه زراره). اتشال من كل
/// صفحات البداية (٢٦ سبتمبر ٢٠٢٦): هناك بالإيد والكتابة بس.
///
/// دوسة = سماع واحد على طول (شوف [ListenFlow]): ورقة فوقها الدايرة
/// ([MicOrb]) بكلمة حالتها، والكلام بيتكتب وهو بيتقال ← الكلام كبير + «صح
/// كده؟» المسجّلة + «أيوه»/«لأ» بالإيد (أو الدايرة وقولها) ← اتطبّق. أي دوسة
/// بتقفل المايك على طول، ودوسة الدايرة والموبايل بيتكلم بتقاطعه.
///
/// **بيظهر لما فيه مايك في النسخة، والصوت شغّال، والإذن مش مرفوض.** من غير
/// `AppScope` أو من غير خدمة صوت = مفيش زرار (زي «ساعدني»).
class ListenButton<T> extends StatefulWidget {
  const ListenButton({
    required this.tag,
    required this.parse,
    required this.describe,
    required this.onApply,
    this.force = false,
    this.elder = false,
    this.onDark = false,
    this.hint,
    this.gapBelow = 0,
    super.key,
  });

  /// مسافة تحت الزرار — **مع الزرار وبس**: لو مش ظاهر الشاشة زي ما كانت
  /// بالبكسل (فجوة فاضية كانت بتزقّ أزرار التذكير لتحت).
  final double gapBelow;


  /// كلمة جنب الزرار بتقول إيه اللي يتقال («قول «أخدته» أو دوس») — بتظهر
  /// وتختفي مع الزرار نفسه، وأكبر في نمط كبار السن.
  final String? hint;

  /// بيدخل في مفتاح الزرار: `listen-<tag>`.
  final String tag;
  final T? Function(String heard) parse;
  final String Function(T value) describe;

  /// **نفس الدالة اللي الزرار العادي بيندهها.**
  final Future<void> Function(T value) onApply;

  /// المقدمة — الصوت لسه ما اتشغّلش.
  final bool force;
  final bool elder;
  final bool onDark;

  @override
  State<ListenButton<T>> createState() => _ListenButtonState<T>();
}

class _ListenButtonState<T> extends State<ListenButton<T>> with WidgetsBindingObserver {
  ListenFlow<T>? _flow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final voice = AppScope.maybeOf(context)?.voice;
    if (voice == null || _flow != null) return;
    // **الدوال بتتقري من الودجت الحالي وقت النداء**، مش وقت الإنشاء: صفحات
    // المواعيد الخمسة بتشارك نفس الـState (نفس النوع في نفس المكان)، فالنسخة
    // القديمة كانت بتفضل ماسكة سؤال الصحيان وهو على الفطار.
    _flow = ListenFlow<T>(
      voice: voice,
      parse: (heard) => widget.parse(heard),
      describe: (v) => widget.describe(v),
      onApply: (v) => widget.onApply(v),
      force: widget.force,
      autoApply: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // **عمرنا ما نسمع في الخلفية**
    if (state != AppLifecycleState.resumed) unawaited(_flow?.cancel());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow?.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final flow = _flow!;
    final sheet = showListenSheet(context, flow);
    unawaited(flow.start());
    await sheet;
    // اتقفلت بالسحب أو بـ«اقفل» — من غير تطبيق
    if (flow.phase != ListenPhase.done) {
      await flow.cancel();
      return;
    }
    // الورقة اتقفلت الأول، وبعدين التطبيق — بنفس سكّة الزرار
    await flow.applyConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    if (flow == null) return const SizedBox.shrink();
    return ListenableBuilder(
      // الخدمة (مقفول/مرفوض) والدورة نفسها (المايك ما اشتغلش = الزرار يختفي)
      listenable: Listenable.merge([flow.voice, flow]),
      builder: (context, _) {
        if (!flow.available) return const SizedBox.shrink();
        return Padding(padding: EdgeInsets.only(bottom: widget.gapBelow), child: _button(flow));
      },
    );
  }

  Widget _button(ListenFlow<T> flow) {
    final size = widget.elder ? F.elderTextSize : F.minTextSize;
    final height = widget.elder ? F.primaryButtonHeight : F.minTapTarget;
    final ink = widget.onDark ? F.onDark : F.ink;
    final hint = widget.hint;
    final button = Semantics(
      button: true,
      label: 'اتكلم',
      child: Material(
        key: ValueKey('listen-${widget.tag}'),
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(F.radiusCard),
          side: BorderSide(color: widget.onDark ? F.onDarkMuted : F.line, width: 1.5),
        ),
        child: InkWell(
          onTap: _tap,
          borderRadius: BorderRadius.circular(F.radiusCard),
          child: Container(
            constraints: BoxConstraints(minHeight: height, minWidth: height),
            padding: EdgeInsets.symmetric(horizontal: widget.elder ? F.s14 : F.s10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_none_outlined, size: widget.elder ? 28 : 22, color: ink),
                const SizedBox(width: F.s6),
                Text('اتكلم', style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
    if (hint == null) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            hint,
            key: ValueKey('listen-hint-${widget.tag}'),
            style: TextStyle(fontSize: widget.elder ? F.elderTextSize : F.minBodySize, color: ink, height: 1.4),
          ),
        ),
        const SizedBox(width: F.s10),
        button,
      ],
    );
  }
}

/// ورقة السماع: اللي بيحصل بالكلام الكبير — وبتتقفل لوحدها لما الإجابة
/// تتطبّق.
Future<void> showListenSheet(BuildContext context, ListenFlow flow) => FSheet.show<void>(
      context,
      title: 'اتكلم',
      children: [_ListenBody(flow: flow)],
    );

class _ListenBody extends StatefulWidget {
  const _ListenBody({required this.flow});
  final ListenFlow flow;

  @override
  State<_ListenBody> createState() => _ListenBodyState();
}

class _ListenBodyState extends State<_ListenBody> {
  @override
  void initState() {
    super.initState();
    // الورقة بتكتب الجملة بنفسها — الترجمة اللي تحت تسكت، عشان تتكتب مرة.
    // بعد الفريم: التنبيه وسط البناء ممنوع.
    final voice = widget.flow.voice;
    scheduleMicrotask(voice.holdCaption);
    widget.flow.addListener(_onPhase);
    // خلص قبل ما الورقة تتبني (إجابة جاهزة فوراً) — تتقفل برضه
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPhase());
  }

  void _onPhase() {
    if (widget.flow.phase == ListenPhase.done && mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    widget.flow.removeListener(_onPhase);
    final voice = widget.flow.voice;
    scheduleMicrotask(voice.releaseCaption);
    super.dispose();
  }

  /// «اقفل»: المايك يقف **الأول**، وبعدين الورقة.
  Future<void> _close() async {
    unawaited(widget.flow.cancel());
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final body = TextStyle(fontSize: F.minBodySize, color: F.ink, height: 1.5);
    final big = TextStyle(fontSize: F.subtitleSize, fontWeight: FontWeight.w700, color: F.ink, height: 1.5);
    Widget close() => FSecondaryButton(key: const ValueKey('listen-close'), label: 'اقفل', onPressed: _close);
    Widget noteLine() => flow.note == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: F.s10),
            child: Text(flow.note!, key: const ValueKey('listen-note'), textAlign: TextAlign.center, style: body),
          );
    return ListenableBuilder(
      // الدورة، و«بيتكلم» (الدايرة بتقول «برد عليك — دوس عشان تقاطعني»)
      listenable: Listenable.merge([flow, flow.voice.caption]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الدايرة: دوسة واحدة لكل حالة — الدورة بتقرر ([ListenFlow.tapMic])
          Center(child: MicOrb(state: flow.mic, onTap: flow.tapMic)),
          const SizedBox(height: F.s12),
          ...switch (flow.phase) {
            ListenPhase.listening => [
                // الكلام وهو بيتقال
                Text(
                  flow.partial,
                  key: const ValueKey('listen-partial'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: F.subtitleSize, color: F.ink, height: 1.4),
                ),
                const SizedBox(height: F.gap),
                close(),
              ],
            ListenPhase.confirming => [
                Text(flow.confirmText, key: const ValueKey('listen-heard'), style: big.copyWith(fontSize: F.screenTitleSize)),
                const SizedBox(height: F.s4),
                Text(voiceLine('lis_confirm'), style: body),
                noteLine(),
                const SizedBox(height: F.gap),
                FPrimaryButton(key: const ValueKey('listen-yes'), label: 'أيوه', onPressed: flow.confirmYes),
                const SizedBox(height: F.s10),
                FSecondaryButton(key: const ValueKey('listen-no'), label: 'لأ', onPressed: flow.confirmNo),
              ],
            ListenPhase.notUnderstood => [
                Text(voiceLine(flow.missLine), key: const ValueKey('listen-not-understood'), style: body),
                const SizedBox(height: F.gap),
                close(),
              ],
            ListenPhase.declined => [
                Text('ماشي — دوس المايك وقولها تاني، أو دوس بإيدك.', key: const ValueKey('listen-declined'), style: body),
                const SizedBox(height: F.gap),
                close(),
              ],
            // المايك اتقفل على الشاشة دي — الدايرة بتقول «اكتب أو دوس بدل الصوت»
            ListenPhase.unavailable => [
                Text(voiceLine('gen_try_hands'), key: const ValueKey('listen-unavailable'), style: body),
                const SizedBox(height: F.gap),
                close(),
              ],
            ListenPhase.idle || ListenPhase.thinking || ListenPhase.done => [
                noteLine(),
                const SizedBox(height: F.gap),
                close(),
              ],
          },
        ],
      ),
    );
  }
}
