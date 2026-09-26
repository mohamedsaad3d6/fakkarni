import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../ai/command_reader.dart';
import '../../app/app_scope.dart';
import '../../core/diagnostics.dart';
import '../../core/format/arabic_time.dart';
import '../../data/repositories/dose_event_repository.dart';
import '../../data/voice/listen_health.dart';
import '../../data/voice/speech_listener.dart';
import '../../data/voice/voice_service.dart';
import '../../domain/medication/medication_purpose.dart';
import '../../domain/scheduling/day_routine.dart';
import '../../domain/scheduling/dose_schedule.dart';
import '../../domain/voice/answer_parser.dart';
import '../../domain/voice/voice_catalog.dart';
import '../../domain/voice/voice_time.dart';
import '../../domain/wording/rule_wording.dart';
import '../today/dose_actions.dart';
import 'command_parser.dart';
import 'voice_flags.dart';

/// مراحل «كلّمني».
enum CommandPhase {
  idle,
  listening,

  /// «ثانية واحدة» — بنسأل السحابة.
  thinking,

  /// «فهمت: … صح كده؟» — مستنيين «أيوه».
  confirming,

  /// كذا جرعة تنفع — «أنهي واحد؟» بأزرار كبيرة.
  choosing,

  /// جملة بتتقال وتتقري (رد، أو «مافهمتش»، أو «للدكتور») — وخلاص.
  answering,
  done,
}

/// جرعة ممكن يكون قصدها — من نافذة «أخدته» نفسها.
class DoseCandidate {
  const DoseCandidate(this.dose, this.routineDay);
  final DoseEventView dose;
  final DateTime routineDay;
  String get label => '${dose.medicationName} — الساعة ${voiceTime(dose.scheduledAt)}';
}

/// «ضيفلي دوا» → الفورم العادي **متعبّي** — ولا حاجة بتتحفظ غير من «احفظ».
class AddMedPrefill {
  const AddMedPrefill({this.name, this.purpose, this.timings = const [], this.once = false});
  final String? name;
  final MedicationPurpose? purpose;
  final List<DoseTiming> timings;
  final bool once;
}

/// «كلّمني» — طلب مفتوح: اسمع ← افهم على الموبايل ← (السحابة لو ما فهمناش)
/// ← قول اللي فهمته ← «صح كده؟» ← نفّذ **بنفس سكّة الزرار**.
///
/// - «أخدت …»: [confirmGroup] بالحرف — نفس الصف ونفس الإلغاء ونفس
///   `help_confirm_done` بتوع «أخدته». مفيش تأكيد = مفيش كتابة.
/// - «ضيفلي …»: بيفتح فورم «ضيف دوا» متعبّي ([onOpenAdd]) — الاقتراح
///   عمره ما يبقى تذكير من غير «احفظ» بإيده.
/// - «الدوا الجاي» / «أدويتي النهارده»: رد محلي بصوت الموبايل — قراية بس.
/// - أي سؤال طبي: `gen_no_medical` — ولا كلمة تانية.
/// - مش مفهوم: `lis_not_understood`، والتانية ورا بعض `gen_try_hands`.
///
/// الصوت مقفول = نفس الجمل مكتوبة على الشاشة ([shown]) من غير ما تتقال.
class CommandFlow extends ChangeNotifier {
  CommandFlow({
    required this.voice,
    required this.services,
    required this.routineDay,
    required this.onOpenAdd,
    this.reader,
    this.cloudAllowed,
    this.onCloudUsed,
    DateTime Function()? clock,
    Future<List<DoseEventView>> Function(DateTime day)? dosesFor,
    Future<Map<String, MedicationPurpose?>> Function()? purposesFor,
    Future<void> Function(String reason)? onStartFailure,
  })  : _clock = clock ?? DateTime.now,
        _onStartFailure = onStartFailure ?? recordListenProblem,
        _dosesFor = dosesFor ?? ((day) => services.events.watchDay(day).first),
        _purposesFor = purposesFor ??
            (() async => {
                  for (final s in await services.medications.watchActiveSummaries(services.patientId).first)
                    s.medication.name: MedicationPurpose.fromStorage(s.medication.purpose),
                });

  final VoiceService voice;
  final AppServices services;
  final DateTime routineDay;
  final Future<void> Function(String reason) _onStartFailure;

  /// المايك ما اشتغلش (مش الإذن) — «كلّمني» بيختفي من الشاشة دي.
  bool startFailed = false;

  /// بيفتح الفورم متعبّي وبيرجّع «اتحفظ؟» — «تمام، عملتها» بعدها بس.
  final Future<bool> Function(AddMedPrefill prefill) onOpenAdd;

  /// السحابة — null = مفيش (مفتاح ناقص).
  final VoiceCommandReader? reader;

  /// الحد اليومي (المرحلة ٤): false = `cmd_limit`.
  final bool Function()? cloudAllowed;
  final void Function()? onCloudUsed;

  final DateTime Function() _clock;
  final Future<List<DoseEventView>> Function(DateTime day) _dosesFor;
  final Future<Map<String, MedicationPurpose?>> Function() _purposesFor;

  CommandPhase phase = CommandPhase.idle;

  /// الجملة اللي على الشاشة دلوقتي — نفس اللي بيتقال.
  String shown = '';

  /// الكلام وهو بيتقال — بيتكتب في الورقة لحظة بلحظة.
  String partial = '';

  /// «تقدر تقولّي مثلاً…» — **مكتوبة** تحت «سامعك…» أول مرة خالص (ما بتتقالش:
  /// ولا جملة قبل المايك).
  String? hint;

  /// سماعات اتفتحت — دوسة واحدة = سماع واحد.
  int sessions = 0;
  VoiceCommand? command;
  List<DoseCandidate> candidates = const [];
  DoseCandidate? chosen;
  AddMedPrefill? prefill;

  /// أول تعثّر «مافهمتش»، والتاني ورا بعض «كمّل بإيدك».
  int failures = 0;
  bool _busy = false;
  bool _disposed = false;

  bool get available => voice.listener != null && !voice.micDenied && !startFailed;

  void _set(CommandPhase p, [String? text]) {
    if (_disposed) return;
    phase = p;
    if (text != null) shown = text;
    notifyListeners();
  }

  bool _interrupted(int gen) {
    if (gen == voice.interrupts) return false;
    if (phase != CommandPhase.idle) _set(CommandPhase.idle, '');
    return true;
  }

  /// جملة من الكتالوج: بتتكتب على الشاشة، وبتتقال لو الصوت شغّال.
  Future<void> _say(String id, {CommandPhase? phase}) async {
    _set(phase ?? this.phase, voiceLine(id));
    await voice.speakLine(id);
  }

  Future<void> _sayText(String text, {CommandPhase? phase}) async {
    _set(phase ?? this.phase, text);
    await voice.speakText(text);
  }

  /// دوسة «كلّمني».
  Future<void> start() async {
    final listener = voice.listener;
    if (listener == null || _busy) return;
    _busy = true;
    try {
      final wasSpeaking = voice.speaking;
      await voice.stop();
      final gen = voice.interrupts;
      if (!await listener.hasPermission()) {
        await _say('lis_mic_permission', phase: CommandPhase.listening);
        if (_interrupted(gen)) return;
      }
      final failed = await listener.prepare();
      if (_interrupted(gen)) return;
      if (failed != null) {
        await _cantListen(failed);
        return;
      }
      // أول مرة خالص: «تقدر تقولّي مثلاً…» **مكتوبة** تحت «سامعك…» — مرة
      // واحدة في عمر التنزيلة، ومن غير ما تتقال قبل المايك
      hint = null;
      if (!voice.cmdHintDone) {
        await voice.markCmdHintDone();
        hint = voiceLine('cmd_hint');
      }
      await _round(gen, settle: wasSpeaking);
    } finally {
      _busy = false;
    }
  }

  Future<void> _round(int gen, {bool settle = false}) async {
    final listener = voice.listener!;
    command = null;
    candidates = const [];
    chosen = null;
    prefill = null;
    partial = '';
    // **الدوسة ← المايك على طول**: مفيش جملة قبله؛ النغمة من المتعرّف نفسه
    await voice.yieldToMic(settle: settle);
    if (_interrupted(gen)) return;
    sessions++;
    _set(CommandPhase.listening, 'سامعك…');
    final result = await listener.listen(onPartial: (t) {
      if (phase != CommandPhase.listening || _disposed) return;
      partial = t;
      notifyListeners();
    });
    if (_interrupted(gen) || phase != CommandPhase.listening) return; // دوسة كسبت
    // المايك ما اشتغلش ≠ «مافهمتش»؛ اشتغل ووقع في النص = تعثّرة
    if (result is ListenFailed && (!result.started || result.permission)) return _cantListen(result);
    if (result is ListenFailed) return _fail(gen);
    unawaited(clearListenProblem());
    final text = result is ListenHeard ? result.text : null;
    if (text == null || text.trim().isEmpty) return _fail(gen);

    final started = _clock();
    var cmd = parseCommand(text);
    var source = 'local';
    if (cmd.intent == CommandIntent.unknown && reader != null && voiceCommandsCloud) {
      if (cloudAllowed?.call() == false) {
        diag('Cmd: intent=unknown source=local — الحد اليومي خلص، مفيش سحابة');
        await _say('cmd_limit', phase: CommandPhase.answering);
        return;
      }
      source = 'cloud';
      await _say('cmd_thinking', phase: CommandPhase.thinking);
      if (_interrupted(gen)) return;
      onCloudUsed?.call();
      final result = await reader!.read(text);
      if (_interrupted(gen)) return;
      if (result.failed) {
        diag('Cmd: intent=unknown source=cloud latency=${result.latency.inMilliseconds}ms error=${result.error}');
        await _say('gen_try_hands', phase: CommandPhase.answering);
        return;
      }
      cmd = _fromCloud(result.command);
      diag('Cmd: intent=${cmd.intent.name} source=cloud latency=${result.latency.inMilliseconds}ms');
    } else {
      diag('Cmd: intent=${cmd.intent.name} source=$source latency=${_clock().difference(started).inMilliseconds}ms');
    }
    command = cmd;
    await _handle(cmd, gen);
  }

  /// رد السحابة → نفس القارئ المحلي: الكلمات اللي رجعت بتتفهم هنا، والاسم
  /// بيتطابق على قايمة الموبايل — السحابة ما شافتهاش.
  VoiceCommand _fromCloud(CloudCommand? c) {
    if (c == null) return VoiceCommand.unknown;
    switch (c.intent) {
      case 'mark_taken':
        return VoiceCommand(CommandIntent.markTaken, medWords: c.medNameAsSpoken == null ? null : normalizeArabic(c.medNameAsSpoken!));
      case 'next_dose':
        return const VoiceCommand(CommandIntent.nextDose);
      case 'today_list':
        return const VoiceCommand(CommandIntent.todayList);
      case 'medical_question':
        return VoiceCommand.medical;
      case 'add_med':
        final parsed = parseCommand('ضيفلي دوا ${c.medNameAsSpoken ?? ''} ${c.timingWords ?? ''} ${c.patternWords ?? ''}');
        return parsed.intent == CommandIntent.addMed ? parsed : const VoiceCommand(CommandIntent.addMed);
      default:
        return VoiceCommand.unknown;
    }
  }

  /// المايك ما اشتغلش. الإذن = «كمّل بإيدك» ومش هنسأل تاني؛ أي سبب تاني =
  /// `gen_try_hands` مرة، و«كلّمني» يختفي، والسبب للسجل والأدمن بس.
  Future<void> _cantListen(ListenFailed failed) async {
    if (failed.permission) {
      voice.markMicDenied();
      await _say('lis_mic_denied', phase: CommandPhase.answering);
      return;
    }
    startFailed = true;
    diag('Cmd: intent=none source=none — المايك ما اشتغلش');
    await _onStartFailure(failed.reason);
    await _say('gen_try_hands', phase: CommandPhase.answering);
  }

  Future<void> _fail(int gen) async {
    failures++;
    await _say(failures >= 2 ? 'gen_try_hands' : 'lis_not_understood', phase: CommandPhase.answering);
  }

  Future<void> _handle(VoiceCommand cmd, int gen) async {
    switch (cmd.intent) {
      case CommandIntent.unknown:
        return _fail(gen);
      case CommandIntent.medicalQuestion:
        failures = 0;
        return _say('gen_no_medical', phase: CommandPhase.answering);
      case CommandIntent.nextDose:
        failures = 0;
        return _sayText(await _nextDoseText(), phase: CommandPhase.answering);
      case CommandIntent.todayList:
        failures = 0;
        return _sayText(await _todayListText(), phase: CommandPhase.answering);
      case CommandIntent.markTaken:
        failures = 0;
        return _markTaken(cmd, gen);
      case CommandIntent.addMed:
        failures = 0;
        return _addMed(cmd, gen);
    }
  }

  // ---------------------------------------------------------------- الردود

  Future<List<DoseEventView>> _today() => _dosesFor(routineDay);

  /// أول جرعة لسه ما اتأكدتش — لو فات معادها بنقول كده (هي اللي «جاية»
  /// فعلاً بالنسبة له)، وإلا الجاية النهارده، وإلا أول واحدة بكرة.
  Future<String> _nextDoseText() async {
    final now = _clock();
    final today = await _today();
    var open = [for (final d in today) if (!d.isDone) d];
    var tomorrow = false;
    if (open.isEmpty) {
      final next = await _dosesFor(DateTime(routineDay.year, routineDay.month, routineDay.day + 1));
      open = [for (final d in next) if (!d.isDone) d];
      tomorrow = true;
    }
    if (open.isEmpty) return 'مفيش جرعات جاية متسجّلة النهارده ولا بكرة.';
    open.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final at = open.first.scheduledAt;
    final names = [for (final d in open) if (d.scheduledAt == at) d.medicationName].join(' و');
    if (!tomorrow && at.isBefore(now)) return 'معاد $names كان الساعة ${voiceTime(at)} — ولسه ما اتأكدش.';
    return 'دواك الجاي $names ${tomorrow ? 'بكرة ' : ''}الساعة ${voiceTime(at)}.';
  }

  Future<String> _todayListText() async {
    final today = await _today();
    if (today.isEmpty) return 'مفيش أدوية متسجّلة النهارده.';
    final groups = groupByMinute(today);
    final items = <String>[];
    for (final g in groups) {
      final names = [for (final d in g) d.medicationName].join(' و');
      final taken = g.every((d) => d.isDone);
      items.add('$names الساعة ${voiceTime(g.first.scheduledAt)}${taken ? ' — أخدته' : ''}');
    }
    final shownItems = items.take(5).toList();
    final more = items.length > 5 ? '، وحاجات تانية على الشاشة' : '';
    return 'النهارده عندك ${arabicNumber(groups.length)} ${groups.length == 1 ? 'جرعة' : groups.length == 2 ? 'جرعتين' : 'جرعات'}: ${shownItems.join('، ')}$more.';
  }

  // ---------------------------------------------------------------- أخدته

  Future<void> _markTaken(VoiceCommand cmd, int gen) async {
    final now = _clock();
    final today = await _today();
    // نفس نافذة زرار «أخدته»: اللي فات معاده من غير تأكيد، وأقرب جاية
    final window = [for (final g in nowGroups(groupByMinute(today), now)) for (final d in g) if (!d.isDone) d];
    var picks = window;
    if (cmd.medWords != null) {
      final purposes = await _purposesFor();
      final names = {for (final d in window) d.medicationName}.toList();
      final match = matchMedication(cmd.medWords, names, purposes: {
        for (final e in purposes.entries)
          if (e.value != null) e.key: e.value!.label,
      });
      picks = [for (final d in window) if (match.names.contains(d.medicationName)) d];
      if (picks.isEmpty) {
        return _sayText('مفيش جرعة ${cmd.medWords} مستنية دلوقتي — بص على الشاشة.', phase: CommandPhase.answering);
      }
    }
    if (_interrupted(gen)) return;
    if (picks.isEmpty) return _sayText('مفيش جرعة مستنية دلوقتي.', phase: CommandPhase.answering);
    candidates = [for (final d in picks.take(3)) DoseCandidate(d, d.routineDay ?? routineDay)];
    if (candidates.length > 1) {
      return _sayText('أنهي واحد؟', phase: CommandPhase.choosing);
    }
    await _confirm(candidates.single, gen);
  }

  /// اختيار واحدة من الأزرار الكبيرة.
  Future<void> choose(DoseCandidate c) async {
    if (phase != CommandPhase.choosing) return;
    chosen = c;
    await _confirm(c, voice.interrupts);
  }

  Future<void> _confirm(DoseCandidate c, int gen) async {
    chosen = c;
    await _askYes('أخدت ${c.dose.medicationName} بتاع الساعة ${voiceTime(c.dose.scheduledAt)}');
  }

  /// التأكيد: اللي اتفهم **مكتوب كبير** و«صح كده؟» **المسجّلة** — مفيش «فهمت:
  /// …» بصوت الموبايل، ومفيش سماع لـ«أيوه»: الزرارين قدّامه، والدوسة بتكسب.
  Future<void> _askYes(String understood) async {
    _set(CommandPhase.confirming, understood);
    await voice.speakLine('lis_confirm');
  }

  /// «أيوه» — التنفيذ الوحيد. «أخدته» بيعدّي من [confirmGroup] نفسها.
  Future<void> confirmYes() async {
    if (phase != CommandPhase.confirming) return;
    final cmd = command;
    _set(CommandPhase.done);
    // الدوسة بتكسب: «صح كده؟» والمايك بيقفوا على طول
    unawaited(voice.stop());
    if (cmd?.intent == CommandIntent.markTaken && chosen != null) {
      final c = chosen!;
      await confirmGroup(services, c.routineDay, [c.dose]);
      return;
    }
    if (cmd?.intent == CommandIntent.addMed && prefill != null) {
      final saved = await onOpenAdd(prefill!);
      if (saved) await _say('cmd_done', phase: CommandPhase.done);
    }
  }

  /// «لأ» / «إلغي» — ولا حاجة بتتغيّر.
  Future<void> confirmNo() async {
    if (phase != CommandPhase.confirming && phase != CommandPhase.choosing) return;
    chosen = null;
    prefill = null;
    await voice.stop();
    await _say('cmd_cancelled', phase: CommandPhase.answering);
  }

  /// «قول تاني» بعد «مافهمتش».
  Future<void> again() => start();

  /// «اقفل» — المايك بيقف على طول.
  Future<void> cancel() async {
    _set(CommandPhase.idle, '');
    await voice.stop();
  }

  // ---------------------------------------------------------------- ضيفلي

  Future<void> _addMed(VoiceCommand cmd, int gen) async {
    final purpose = _purposeFromWords(cmd.medWords);
    final timings = _timingsFor(cmd);
    prefill = AddMedPrefill(
      name: purpose == null ? cmd.medWords : null,
      purpose: purpose,
      timings: timings,
      once: cmd.once,
    );
    final what = purpose != null ? 'دوا ${purpose.label}' : (cmd.medWords == null ? 'دوا' : 'دوا ${cmd.medWords}');
    final when = _timingWords(cmd);
    await _askYes('تضيف $what${when.isEmpty ? '' : ' $when'} — وهتراجعه وتحفظه بإيدك');
  }

  static MedicationPurpose? _purposeFromWords(String? words) {
    if (words == null) return null;
    final key = medKey(words);
    for (final p in MedicationPurpose.values) {
      if (p == MedicationPurpose.other) continue;
      if (medKey(p.label).split(' ').any((w) => key.split(' ').contains(w))) return p;
    }
    return null;
  }

  static DayAnchor? _anchorOf(String? word) => switch (word) {
        'الصحيان' => DayAnchor.wake,
        'الفطار' => DayAnchor.breakfast,
        'الغدا' => DayAnchor.lunch,
        'العشا' => DayAnchor.dinner,
        'النوم' => DayAnchor.sleep,
        _ => null,
      };

  static int _offset(DayAnchor anchor, MealRelation? r) => switch (r) {
        MealRelation.before || null => -defaultOffsetBefore(anchor),
        MealRelation.with_ => 0,
        MealRelation.after => 30,
      };

  /// كلمات المواعيد → مراسي الفورم (نفس عُرف «ضيف دوا»: ١× الفطار، ٢× +العشا،
  /// ٣× +الغدا). الفورم بيعرضها والمريض بيعدّلها — ومفيش حفظ هنا.
  static List<DoseTiming> _timingsFor(VoiceCommand cmd) {
    final out = <DoseTiming>[];
    MealRelation? relationOnly;
    for (final t in cmd.timings) {
      if (t.fixed != null) {
        out.add(FixedTiming(MinuteOfDay(t.fixed!.minutes)));
        continue;
      }
      final anchor = _anchorOf(t.anchorWord);
      if (anchor == null) {
        relationOnly ??= t.relation;
        continue;
      }
      out.add(AnchorTiming(anchor, _offset(anchor, t.relation)));
    }
    if (out.isEmpty && (cmd.timesPerDay != null || relationOnly != null)) {
      const order = [DayAnchor.breakfast, DayAnchor.dinner, DayAnchor.lunch, DayAnchor.sleep, DayAnchor.wake];
      final n = (cmd.timesPerDay ?? 1).clamp(1, order.length);
      for (final a in order.take(n)) {
        out.add(AnchorTiming(a, _offset(a, relationOnly)));
      }
    }
    return out;
  }

  static String _timingWords(VoiceCommand cmd) {
    final parts = <String>[];
    for (final t in cmd.timings) {
      if (t.fixed != null) {
        parts.add('الساعة ${voiceTime(DateTime(2026, 1, 1, t.fixed!.hour, t.fixed!.minute))}');
      } else if (t.anchorWord != null) {
        final anchor = _anchorOf(t.anchorWord);
        parts.add(anchor == null ? t.anchorWord! : spokenTimingWording(t.anchorWord!, _offset(anchor, t.relation)));
      }
    }
    if (cmd.timesPerDay != null) parts.add('${arabicNumber(cmd.timesPerDay!)} ${cmd.timesPerDay == 1 ? 'مرة' : cmd.timesPerDay == 2 ? 'مرتين' : 'مرات'} في اليوم');
    if (cmd.everyHours != null) parts.add('كل ${arabicNumber(cmd.everyHours!)} ساعات');
    if (cmd.once) parts.add('مرة واحدة');
    return parts.join('، ');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(voice.listener?.stop());
    super.dispose();
  }
}
