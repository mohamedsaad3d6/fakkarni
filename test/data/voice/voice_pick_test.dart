// صوت الموبايل للردود اللي بتتولّد بس — بأحسن صوت عربي متسطّب.
import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/data/voice/voice_pick.dart';

void main() {
  Map<String, String> v(String name, String locale, String quality, [String gender = 'female']) =>
      {'name': name, 'locale': locale, 'quality': quality, 'gender': gender, 'identifier': 'id.$name'};

  test('premium قبل enhanced قبل العادي — مهما كانت اللهجة', () {
    final pick = pickArabicVoice([
      v('Maged', 'ar-SA', 'default', 'male'),
      v('Laila', 'ar-SA', 'enhanced'),
      v('Majed', 'ar-001', 'premium', 'male'),
    ]);
    expect(pick!['name'], 'Majed');
  });

  test('نفس الجودة: المصري ← السعودي ← أي عربي، وبعدين راجل', () {
    expect(pickArabicVoice([v('A', 'ar-SA', 'enhanced'), v('B', 'ar-EG', 'enhanced')])!['name'], 'B');
    expect(pickArabicVoice([v('A', 'ar-SA', 'default'), v('B', 'ar-SA', 'default', 'male')])!['name'], 'B');
  });

  test('مفيش عربي = null (النظام يختار) — وأصوات لغات تانية ما بتتختارش', () {
    expect(pickArabicVoice([v('Samantha', 'en-US', 'premium')]), isNull);
    expect(pickArabicVoice(const []), isNull);
  });

  test('الردود أبطأ شوية', () => expect(ttsAnswerRateFactor, lessThan(1.0)));
}
