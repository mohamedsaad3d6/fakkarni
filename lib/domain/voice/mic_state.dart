// حالة المايك — نفس ماكينة `MicOrb` بتاعة jarvis-ai-finance: كل حالة ليها
// **كلمة مكتوبة**، فاللي مش شايف النبض أو مقفّل الحركة عارف المايك مفتوح ولا
// لأ. دارت نقية.

/// idle ← listening ← thinking ← confirming/speaking ← idle. السماع بيبدأ من
/// idle بس (أو من speaking بدوسة — مقاطعة)، ومفيش حاجة بترجع للسماع لوحدها.
enum MicState {
  /// «دوس واتكلم».
  idle,

  /// المايك مفتوح — «سامعك…».
  listening,

  /// بنفهم اللي اتقال — «بفكّر…».
  thinking,

  /// الموبايل بيتكلم — دوسة المايك بتقطعه وبتفتح المايك في نفس الدوسة.
  speaking,

  /// مستنيين «أيوه» أو «لأ».
  confirming,

  /// المايك مقفول على الشاشة دي (الإذن، أو القاطع اشتغل).
  off,
}

/// الكلمة اللي تحت المايك.
String micStateLabel(MicState s) => switch (s) {
      MicState.idle => 'دوس واتكلم',
      MicState.listening => 'سامعك…',
      MicState.thinking => 'بفكّر…',
      MicState.speaking => 'برد عليك — دوس عشان تقاطعني',
      MicState.confirming => 'قول «أيوه» أو «لأ» — أو دوس',
      MicState.off => micOffLine,
    };

/// المايك اتقفل على الشاشة دي.
const micOffLine = 'اكتب أو دوس بدل الصوت';

/// **قاطع**: ٥ وقعات في ١٠ ثواني = المايك يتقفل على الشاشة دي
/// (`tripBreaker` في `webSpeechStt.js`). السكوت مش وقعة — «مفيش كلام» مش عطل.
class MicBreaker {
  MicBreaker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const window = Duration(seconds: 10);
  static const limit = 5;

  final DateTime Function() _clock;
  final List<DateTime> _recent = [];

  /// اتقفل.
  bool get tripped => _tripped;
  bool _tripped = false;

  /// وقعة. بترجّع true لو القاطع اشتغل دلوقتي.
  bool fail() {
    final now = _clock();
    _recent.removeWhere((t) => now.difference(t) >= window);
    _recent.add(now);
    if (_recent.length >= limit) _tripped = true;
    return _tripped;
  }
}
