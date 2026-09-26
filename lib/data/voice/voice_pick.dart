/// **أحسن صوت عربي متسطّب** لصوت الموبايل — دارت نقية (الملف ده ما بيستوردش
/// `flutter_tts`).
///
/// صوت الموبايل بقى للردود اللي لازم تتولّد بس («إيه دوايا الجاي؟»، ملخص
/// اليوم)؛ «فهمت: … صح كده؟» اتشالت منه لأنها كانت بتطلع آلية (آيفون، ٢٦
/// سبتمبر ٢٠٢٦). فلما يتكلم لازم بأحسن صوت: **premium** ← **enhanced** ←
/// العادي، وجوّه نفس الجودة المصري ← السعودي ← أي عربي، وبعدين راجل (زي
/// التسجيلات). مفيش عربي = null، والنظام بيختار.
Map<String, String>? pickArabicVoice(Iterable<Map<String, String>> voices) {
  int quality(Map<String, String> v) => switch (v['quality']) {
        'premium' => 3,
        'enhanced' => 2,
        _ => 1,
      };
  int locale(Map<String, String> v) {
    final l = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
    if (l == 'ar-eg') return 3;
    if (l == 'ar-sa') return 2;
    return 1;
  }
  int male(Map<String, String> v) => v['gender'] == 'male' ? 1 : 0;

  final arabic = [
    for (final v in voices)
      if ((v['locale'] ?? '').toLowerCase().startsWith('ar')) v,
  ];
  if (arabic.isEmpty) return null;
  arabic.sort((a, b) {
    for (final c in [quality(b) - quality(a), locale(b) - locale(a), male(b) - male(a)]) {
      if (c != 0) return c;
    }
    return 0;
  });
  return arabic.first;
}

/// الردود بصوت الموبايل أبطأ شوية من السرعة المختارة.
const double ttsAnswerRateFactor = 0.9;
