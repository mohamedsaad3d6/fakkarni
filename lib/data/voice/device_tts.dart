import 'package:flutter_tts/flutter_tts.dart';

import '../../core/diagnostics.dart';
import 'voice_pick.dart';
import 'voice_service.dart';

/// صوت الموبايل — **الملف الوحيد اللي بيستورد `flutter_tts`.**
///
/// عربي، والمصري (`ar-EG`) لو الموبايل عنده، وإلا أي عربي. لو مفيش عربي
/// خالص، الكلام بيطلع باللغة الافتراضية للموبايل — أحسن من السكوت،
/// والترجمة المكتوبة على الشاشة بتغطّي.
class DeviceTts implements VoiceTts {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _prepare() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      // أحسن صوت عربي متسطّب (premium ← enhanced ← العادي) — [pickArabicVoice]
      final raw = await _tts.getVoices;
      final voices = [
        if (raw is List)
          for (final v in raw)
            if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
      ];
      final voice = pickArabicVoice(voices);
      if (voice != null) {
        await _tts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? '',
          'identifier': ?voice['identifier'],
        });
        diag('Voice: صوت الموبايل ${voice['name']} (${voice['locale']}، ${voice['quality'] ?? '؟'})');
      } else {
        await _tts.setLanguage('ar');
        diag('Voice: مفيش صوت عربي متسطّب — لغة «ar» والنظام يختار');
      }
    } catch (e) {
      diag('Voice: تجهيز صوت الموبايل ($e)');
    }
  }

  @override
  Future<void> speak(String text, {required double rate, required double volume}) async {
    await _prepare();
    // أبطأ شوية — الردود بتتولّد، ومش متسجّلة
    await _tts.setSpeechRate(rate * ttsAnswerRateFactor);
    await _tts.setVolume(volume);
    await _tts.speak(text, focus: true);
  }

  @override
  Future<void> stop() => _tts.stop();
}
