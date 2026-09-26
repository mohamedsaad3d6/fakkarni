import 'speech_listener.dart';

/// **الوصلة** (`voice/index.js` بتاع jarvis-ai-finance): التعرّف على الكلام
/// ورا واجهة، والشاشات عمرها ما بتلمس محرّك بعينه. النهارده محرّكين:
/// - `device` — متعرّف الموبايل (`speech_to_text`، الملف الوحيد اللي بيستوردها).
/// - `cloud` — **كعب مقفول** (`cloud_stt.dart`): لو تعرّف المصري على الموبايل
///   طلع مش كفاية، الإصلاح هناك، ومفيش شاشة بتتغيّر.
///
/// الشاشات بتاخد [MicListener] (`mic_listener.dart`) فوق المحرّك — هو اللي
/// ماسك «سماع واحد في المرة» ونهاية الكلام بتاعتنا.
abstract interface class SttDriver implements SpeechListener {
  /// `device` / `cloud` — بيتكتب في سجل التشخيص.
  String get name;

  /// المحرّك ده شغّال في النسخة دي؟ false = مفيش مايك خالص، والشاشة بالإيد
  /// والكتابة — **حالة عادية مش عطل**.
  bool get isSupported;
}

/// المحرّك من اسمه (`--dart-define=STT_DRIVER=cloud`)؛ الاسم الافتراضي
/// `device`، واسم مش معروف = `device`. null = المحرّك اللي اتختار مش شغّال.
SttDriver? pickSttDriver(String name, {required SttDriver Function() device, required SttDriver Function() cloud}) {
  final driver = name == 'cloud' ? cloud() : device();
  return driver.isSupported ? driver : null;
}

/// اسم المحرّك من البناء.
const sttDriverName = String.fromEnvironment('STT_DRIVER', defaultValue: 'device');
