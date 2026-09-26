// «بيسمع» — فهم الإجابات القصيرة بالمصري. دارت نقية، من غير ذكاء ولا شبكة.
//
// الكلام جاي من متعرّف الكلام بتاع الموبايل زي ما هو («تمانيه ونص الصبح»،
// «٨:٣٠»، «خمسه وسبعين سنه»). كل دالة بترجّع **null لما ما تفهمش** — والشاشة
// بتقول «معلش، مافهمتش» وبتسيبه يدوس بإيده. ومفيش تخمين: إجابة ناقصة
// (ساعة من غير الصبح ولا بالليل ومفيش سؤال بيقول) = ما فهمناش.
//
// **ما بيستوردش الجدولة**: الساعة بترجع [SpokenTime] (ساعة ودقيقة)، واللي
// بينده بيحوّلها لـ`MinuteOfDay` — `voice_alert_stop_test` بيقفل على ده.

/// ساعة اليوم زي ما اتقالت — ٠–٢٣ و٠–٥٩.
class SpokenTime {
  const SpokenTime(this.hour, this.minute);
  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  @override
  bool operator ==(Object other) => other is SpokenTime && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
  @override
  String toString() => '$hour:${minute.toString().padLeft(2, '0')}';
}

/// جزء اليوم اللي السؤال نفسه بيقوله («بتفطر الساعة كام؟» = الصبح) — بيكمّل
/// ساعة اتقالت من غير «الصبح» ولا «بالليل». من غيره الساعة الناقصة = null.
enum DayPartHint { morning, noon, afternoon, evening, night }

enum SpokenSex { male, female }

/// رد على تذكير الجرعة.
enum DoseAnswer { taken, later }

// ---------------------------------------------------------------- التطبيع

const _tashkeel = 'ًٌٍَُِّْٰـ';

/// أرقام عربية → لاتينية، همزات → ا، ة → ه، ى → ي، من غير تشكيل ولا علامات.
String normalizeArabic(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x660 && r <= 0x669) {
      b.writeCharCode(0x30 + r - 0x660);
    } else if (r >= 0x6F0 && r <= 0x6F9) {
      b.writeCharCode(0x30 + r - 0x6F0);
    } else if (_tashkeel.runes.contains(r)) {
      continue;
    } else {
      b.writeCharCode(switch (r) {
        0x623 || 0x625 || 0x622 => 0x627, // أ إ آ → ا
        0x629 => 0x647, // ة → ه
        0x649 => 0x64A, // ى → ي
        0x624 => 0x648, // ؤ → و
        0x626 => 0x64A, // ئ → ي
        _ => r,
      });
    }
  }
  return b
      .toString()
      .toLowerCase()
      .replaceAll(RegExp('[،,؟?!؛;()«»"\']'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const _units = <String, int>{
  'صفر': 0, 'زيرو': 0,
  'واحد': 1, 'واحده': 1, 'وحده': 1, 'وحدا': 1,
  'اتنين': 2, 'اثنين': 2, 'اتنان': 2, 'اثنان': 2, 'تنين': 2,
  'تلاته': 3, 'ثلاثه': 3, 'تلات': 3, 'ثلاث': 3, 'تلاثه': 3, 'تلاتا': 3,
  'اربعه': 4, 'اربع': 4, 'اربعا': 4,
  'خمسه': 5, 'خمس': 5, 'خمسا': 5,
  'سته': 6, 'ست': 6, 'ستا': 6,
  'سبعه': 7, 'سبع': 7, 'سبعا': 7,
  'تمانيه': 8, 'ثمانيه': 8, 'تمنيه': 8, 'تمان': 8, 'ثمان': 8, 'تمن': 8, 'تمانا': 8, 'ثمانا': 8,
  'تسعه': 9, 'تسع': 9, 'تسعا': 9,
  'عشره': 10, 'عشر': 10, 'عشرا': 10,
  'حداشر': 11, 'احداشر': 11, 'حدعشر': 11, 'احدعشر': 11, 'حداشرا': 11, 'حداش': 11,
  'اتناشر': 12, 'اثناشر': 12, 'اطناشر': 12, 'اتنعشر': 12, 'اثنعشر': 12, 'اتناشرا': 12, 'اتناش': 12,
  'تلتاشر': 13, 'ثلتاشر': 13, 'تلاتاشر': 13, 'ثلاثتاشر': 13, 'تلتاش': 13,
  'اربعتاشر': 14, 'اربعطاشر': 14, 'اربعتاش': 14,
  'خمستاشر': 15, 'خمسطاشر': 15, 'خمستاش': 15,
  'ستاشر': 16, 'سطاشر': 16, 'ستاش': 16,
  'سبعتاشر': 17, 'سبعطاشر': 17, 'سبعتاش': 17,
  'تمنتاشر': 18, 'تمانتاشر': 18, 'ثمنتاشر': 18, 'تمنطاشر': 18, 'تمنتاش': 18,
  'تسعتاشر': 19, 'تسعطاشر': 19, 'تسعتاش': 19,
};

const _tens = <String, int>{
  'عشرين': 20, 'تلاتين': 30, 'ثلاثين': 30, 'اربعين': 40, 'خمسين': 50,
  'ستين': 60, 'سبعين': 70, 'تمانين': 80, 'ثمانين': 80, 'تسعين': 90,
};

const _hundreds = <String, int>{'ميه': 100, 'مايه': 100, 'مائه': 100, 'ميت': 100};

const _fractions = <String, int>{'نص': 30, 'ربع': 15, 'تلت': 20};

/// كلمات حشو بتتساب زي ما هي.
const _filler = {
  'الساعه', 'ساعه', 'حوالي', 'تقريبا', 'يعني', 'انا', 'عندي', 'عمري', 'سني', 'سنه', 'سنين', 'سن',
  'دقيقه', 'دقايق', 'دقائق', 'كده', 'بالظبط', 'زي', 'او', 'هو', 'هي', 'ده', 'دي', 'ال',
};

int? _numberToken(String t) => _units[t] ?? _tens[t] ?? _hundreds[t];

/// «ونص» → «و نص»، «وسبعين» → «و سبعين» — الواو الملزوقة بتتفصل لما اللي
/// بعدها كلمة معروفة، و«وخمسه» رقم مش كلمة تانية.
List<String> _tokens(String text) {
  final out = <String>[];
  for (final raw in normalizeArabic(text).split(' ')) {
    if (raw.isEmpty) continue;
    // ٨:٣٠ / 8.30 — رقمين بينهم فاصل
    final clock = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(raw);
    if (clock != null) {
      out.add('${clock.group(1)}:${clock.group(2)}');
      continue;
    }
    if (raw.length > 2 && raw.startsWith('و')) {
      final rest = raw.substring(1);
      if (_numberToken(rest) != null || _fractions.containsKey(rest) || RegExp(r'^\d+$').hasMatch(rest)) {
        out
          ..add('و')
          ..add(rest);
        continue;
      }
    }
    out.add(raw);
  }
  return out;
}

/// رقم من كلمات مصرية أو أرقام: «خمسه وسبعين» = ٧٥، «ميه وعشره» = ١١٠،
/// «٨» = ٨. ما يفهمش لو مفيش رقم أو فيه تركيبة مش مفهومة.
int? parseNumber(String text) => _composeNumber(_numberRun(_tokens(text), 0).values);

/// السن: رقم من ١٨ لـ١١٠ — نفس حدود بكرة السن.
int? parseAge(String text) {
  final n = parseNumber(text);
  if (n == null || n < 18 || n > 110) return null;
  return n;
}

typedef _Run = ({List<int> values, int end});

/// بيلمّ أول سلسلة أرقام من [from] (بيتخطّى الحشو و«و» بين رقمين).
_Run _numberRun(List<String> tokens, int from) {
  final values = <int>[];
  var i = from;
  var started = false;
  while (i < tokens.length) {
    final t = tokens[i];
    final n = RegExp(r'^\d+$').hasMatch(t) ? int.tryParse(t) : _numberToken(t);
    if (n != null) {
      values.add(n);
      started = true;
      i++;
      continue;
    }
    if (!started && _filler.contains(t)) {
      i++;
      continue;
    }
    if (started && t == 'و' && i + 1 < tokens.length) {
      final next = tokens[i + 1];
      final nn = RegExp(r'^\d+$').hasMatch(next) ? int.tryParse(next) : _numberToken(next);
      if (nn != null) {
        i++;
        continue;
      }
    }
    if (started) break;
    i++;
  }
  return (values: values, end: i);
}

int? _composeNumber(List<int> v) {
  switch (v.length) {
    case 0:
      return null;
    case 1:
      return v[0];
    case 2:
      final (a, b) = (v[0], v[1]);
      if (a < 10 && _tens.containsValue(b)) return a + b; // خمسه وسبعين
      if (_tens.containsValue(a) && b < 10) return a + b; // سبعين وخمسه
      if (a == 100 && b < 100) return a + b; // ميه وعشره
      return null;
    case 3:
      if (v[0] == 100 && v[1] < 10 && _tens.containsValue(v[2])) return 100 + v[1] + v[2];
      return null;
    default:
      return null;
  }
}

// ---------------------------------------------------------------- أيوه / لأ

/// رد على «صح كده؟».
enum ReplyClass { affirm, deny, unclear }

// **بورت `affirm.js` بتاع jarvis-ai-finance، مدموج مع قايمتنا.** قرار حتمي —
// عمره ما يبقى ذكاء: التأكيد اللي بيكتب في القاعدة ما يتحكمش فيه موديل.
// - **أول كلمة (أو أول كلمتين) هي اللي بتحكم** — `^\s*(...)` هناك. «ايوه»
//   في آخر الجملة مش تأكيد.
// - **الرفض قبل القبول**: «لا ماشي خليها» رفض.
// - المطابقة على الكلمة كلها (زي `(?![\p{L}\p{N}])` هناك): «لازم» مش «لا»،
//   و«ماشيش» مش «ماشي».
// - أي حاجة تانية = [ReplyClass.unclear] — **بنسأل تاني**، عمرها ما تأكّد.

/// القبول — `AFFIRM` بالحرف (بعد التطبيع: أ→ا، ة→ه، ى→ي، من غير تشكيل)،
/// وقايمتنا القديمة.
const affirmWords = {
  // affirm.js
  'ايوه', 'اوكي', 'اوك', 'تمام', 'ماشي', 'اكد', 'نعم', 'اه',
  'okay', 'ok', 'yes', 'yep', 'yeah', 'sure', 'confirm',
  // فكّرني
  'ايوا', 'اها', 'اهه', 'اكيد', 'صح', 'موافق', 'طبعا', 'خلاص', 'يس',
};

/// الرفض — `DENY` بالحرف، وقايمتنا القديمة.
const denyWords = {
  // affirm.js
  'ماتعملش', 'متعملش', 'الغاء', 'الغي', 'بلاش', 'كنسل', 'سيبك', 'لاه', 'لا',
  'nevermind', 'nope', 'cancel', 'stop', 'dont', 'nah', 'no',
  // فكّرني
  'لاء', 'بعدين', 'لسه', 'غلط', 'نو', 'خطا', 'ماشيش',
};

/// عبارات من كلمتين — `do it` / `go ahead` / `never mind`. **«مش» لوحدها مش
/// رفض** («مش عارف» = مش واضح، زي `affirm.js`) — في العبارات دي بس.
const _affirmPhrases = {'do it', 'go ahead'};
const _denyPhrases = {'never mind', 'مش دلوقتي', 'مش كده', 'مش عايز', 'مش عايزه', 'مش صح', 'مش ده', 'مش دي', 'مش هو', 'مش هي'};

/// التطبيع للمطابقة بس — الكلام الأصلي بيتعرض زي ما هو. `normalizeForMatch`
/// هناك: من غير علامات عرض الاتجاه ولا المسافات الصفرية، و«don't» = «dont».
String normalizeReply(String text) =>
    normalizeArabic(text.replaceAll(RegExp('[\u200B-\u200F\u202A-\u202E\u2066-\u2069]'), '').replaceAll(RegExp("['’]"), ''));

/// «صح كده؟» ← أيوه / لأ / مش واضح. الرفض بيتفحص الأول.
ReplyClass classifyReply(String text) {
  final words = normalizeReply(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return ReplyClass.unclear;
  final first = words.first;
  final two = words.length > 1 ? '${words[0]} ${words[1]}' : '';
  if (denyWords.contains(first) || _denyPhrases.contains(two)) return ReplyClass.deny;
  if (affirmWords.contains(first) || _affirmPhrases.contains(two)) return ReplyClass.affirm;
  return ReplyClass.unclear;
}

/// أيوه = true، لأ = false، مش واضح = null — [classifyReply] نفسها.
bool? parseYesNo(String text) => switch (classifyReply(text)) {
      ReplyClass.affirm => true,
      ReplyClass.deny => false,
      ReplyClass.unclear => null,
    };

// ---------------------------------------------------------------- راجل / ست

const _male = {'راجل', 'رجل', 'ذكر', 'راجيل', 'رجال', 'ولد'};
const _female = {'ست', 'سيده', 'انثي', 'مرا', 'مراه', 'امراه', 'بنت', 'ستات', 'حرمه', 'مدام'};

SpokenSex? parseSex(String text) {
  for (final t in _tokens(text)) {
    if (_male.contains(t)) return SpokenSex.male;
    if (_female.contains(t)) return SpokenSex.female;
  }
  return null;
}

// ---------------------------------------------------------------- الساعة

enum _Period { morning, dawn, noon, afternoon, evening, night }

const _periodWords = <String, _Period>{
  'الصبح': _Period.morning, 'صباحا': _Period.morning, 'صباح': _Period.morning, 'صبح': _Period.morning, 'ص': _Period.morning, 'am': _Period.morning, 'الصبحيه': _Period.morning,
  'الفجر': _Period.dawn, 'فجرا': _Period.dawn, 'فجر': _Period.dawn,
  'الضهر': _Period.noon, 'الظهر': _Period.noon, 'ظهرا': _Period.noon, 'ضهرا': _Period.noon, 'الضهريه': _Period.noon, 'ضهر': _Period.noon, 'ظهر': _Period.noon,
  'العصر': _Period.afternoon, 'عصرا': _Period.afternoon, 'عصر': _Period.afternoon, 'العصريه': _Period.afternoon,
  'المغرب': _Period.evening, 'مغرب': _Period.evening, 'العشا': _Period.evening, 'العشاء': _Period.evening, 'عشاء': _Period.evening, 'مساء': _Period.evening, 'مساءا': _Period.evening, 'المسا': _Period.evening, 'م': _Period.evening, 'pm': _Period.evening,
  'بالليل': _Period.night, 'الليل': _Period.night, 'ليلا': _Period.night, 'بليل': _Period.night, 'ليل': _Period.night, 'بالليلا': _Period.night,
};

/// الساعة من الكلام: «تمانيه الصبح»، «٨ ونص»، «تسعه الا ربع»، «اتناشر الضهر»،
/// «٣ العصر»، «عشره بالليل»، «20:30». من غير جزء يوم ولا [hint] (وهي مش
/// بصيغة ٢٤ ساعة) = null — مش هنخمّن الصبح ولا بالليل.
SpokenTime? parseTime(String text, {DayPartHint? hint}) {
  final tokens = _tokens(text);

  // «بعد الضهر» = العصر — كلمتين
  _Period? period;
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i] == 'بعد' && i + 1 < tokens.length && (tokens[i + 1] == 'الضهر' || tokens[i + 1] == 'الظهر')) {
      period = _Period.afternoon;
      break;
    }
    final p = _periodWords[tokens[i]];
    if (p != null) {
      period = p;
      break;
    }
  }

  int? hour;
  int minute = 0;
  var explicit24 = false;
  var i = 0;
  // الساعة: hh:mm أو أول رقم
  for (; i < tokens.length; i++) {
    final t = tokens[i];
    if (_periodWords.containsKey(t)) continue;
    final clock = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
    if (clock != null) {
      hour = int.parse(clock.group(1)!);
      minute = int.parse(clock.group(2)!);
      explicit24 = hour > 12 || hour == 0;
      i++;
      break;
    }
    if (RegExp(r'^\d+$').hasMatch(t)) {
      hour = int.parse(t);
      explicit24 = hour > 12 || hour == 0;
      i++;
      break;
    }
    final n = _units[t];
    if (n != null) {
      if (n == 0 || n > 12) return null; // «تلتاشر» مش ساعة
      hour = n;
      i++;
      break;
    }
    if (_tens.containsKey(t) || _hundreds.containsKey(t)) return null;
  }
  if (hour == null || hour > 23 || minute > 59) return null;

  // الدقايق: «و نص» / «و ربع» / «و عشرين» / «الا ربع» / «الا خمسه» / «نص» على طول
  var minus = false;
  var sawMinutes = false;
  for (; i < tokens.length; i++) {
    final t = tokens[i];
    if (_periodWords.containsKey(t) || _filler.contains(t) || t == 'بعد') continue;
    if (t == 'و' && !sawMinutes) continue;
    if (t == 'الا' && !sawMinutes) {
      minus = true;
      continue;
    }
    if (_fractions.containsKey(t) && !sawMinutes) {
      minute = _fractions[t]!;
      sawMinutes = true;
      continue;
    }
    if (!sawMinutes && (RegExp(r'^\d+$').hasMatch(t) || _numberToken(t) != null)) {
      final run = _numberRun(tokens, i);
      final n = _composeNumber(run.values);
      if (n == null || n > 59) return null;
      minute = n;
      sawMinutes = true;
      i = run.end - 1;
      continue;
    }
    // كلمة مش معروفة بعد الساعة — بنعدّي عليها (متعرّف الكلام بيزوّد كلام)
  }
  if (minus) {
    if (!sawMinutes) return null; // «الا» من غير حاجة بعدها
    hour = (hour - 1 + 24) % 24;
    minute = 60 - minute;
    if (minute == 60) minute = 0;
  }
  if (explicit24) return SpokenTime(hour, minute);

  // ١–١٢ → ٠–٢٣ بجزء اليوم اللي اتقال، وإلا باللي السؤال بيقوله
  final h = hour;
  int? full;
  switch (period) {
    case _Period.morning:
      full = h == 12 ? 0 : h;
    case _Period.dawn:
      full = h == 12 ? 0 : h;
    case _Period.noon:
      full = h == 12 ? 12 : (h <= 4 ? h + 12 : h);
    case _Period.afternoon:
      full = h == 12 ? 12 : (h < 8 ? h + 12 : h);
    case _Period.evening:
      full = h == 12 ? 0 : h + 12;
    case _Period.night:
      full = h == 12 ? 0 : (h <= 5 ? h : h + 12);
    case null:
      switch (hint) {
        case DayPartHint.morning:
          full = h; // «اتناشر» = الضهر
        case DayPartHint.noon:
        case DayPartHint.afternoon:
          full = h == 12 ? 12 : (h <= 6 ? h + 12 : h);
        case DayPartHint.evening:
          full = h == 12 ? 0 : h + 12;
        case DayPartHint.night:
          full = h == 12 ? 0 : (h <= 5 ? h : h + 12);
        case null:
          return null;
      }
  }
  return SpokenTime(full % 24, minute);
}

// ---------------------------------------------------------------- الجرعة

const _taken = {
  'اخدته', 'اخدتها', 'خدته', 'خدتها', 'اخدت', 'خدت', 'اخدتهم', 'خدتهم', 'اخذته', 'اخذتها', 'اخذت',
  'تناولت', 'تناولته', 'بلعته', 'بلعتها', 'شربته', 'شربتها', 'اخدتو', 'خدتو', 'تم',
};
const _later = {'بعدين', 'فكرني', 'شويه', 'اجل', 'اجلها', 'اجله', 'استنى', 'استني', 'كمان', 'لسه', 'مش'};

/// «أخدته» / «خدته» / «أيوه أخدت الدوا» → أخدته. «فكّرني بعدين» / «بعدين» /
/// «مش دلوقتي» → بعدين. «ماخدتش» ولا «لأ» لوحدها = مش مفهوم — القرار ده
/// (تخطّي؟ تأجيل؟) بإيده.
DoseAnswer? parseDoseAnswer(String text) {
  final tokens = _tokens(text);
  for (final t in tokens) {
    // «ماخدتش» / «ماخدتهوش» — نفي، مش تأكيد ولا تأجيل
    if (t.startsWith('ما') && t.contains('خد') && t.endsWith('ش')) return null;
  }
  for (final t in tokens) {
    if (_taken.contains(t)) return DoseAnswer.taken;
    if (_later.contains(t)) return DoseAnswer.later;
  }
  // «أيوه» / «تمام» على سؤال «أخدته؟» = أخدته
  if (parseYesNo(text) == true) return DoseAnswer.taken;
  return null;
}

// ---------------------------------------------------------------- الاسم

const _namePrefixes = ['اسمي هو', 'اسمي', 'انا اسمي', 'انا'];

/// الاسم زي ما اتقال — من غير «اسمي» في أوله. فاضي أو «أيوه»/«لأ» لوحدها = null.
String? parseName(String text) {
  var name = text.trim().replaceAll(RegExp(r'[،,؟?!.]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.isEmpty) return null;
  final norm = normalizeArabic(name);
  if (_namePrefixes.contains(norm)) return null; // «اسمي» لوحدها مش اسم
  for (final p in _namePrefixes) {
    if (norm.startsWith('$p ')) {
      name = name.split(' ').skip(p.split(' ').length).join(' ').trim();
      break;
    }
  }
  if (name.isEmpty || name.length > 40) return null;
  final words = normalizeArabic(name).split(' ');
  if (words.every((w) => affirmWords.contains(w) || denyWords.contains(w))) return null;
  return name;
}
