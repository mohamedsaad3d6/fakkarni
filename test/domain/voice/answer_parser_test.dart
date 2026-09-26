// فهم الإجابات القصيرة بالمصري — بكلام حقيقي، وبكلام غلط لازم يطلع «مافهمتش».
import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/domain/voice/answer_parser.dart';

void main() {
  group('أيوه / لأ', () {
    for (final s in ['أيوه', 'ايوه', 'أيوا', 'آه', 'اه', 'اها', 'تمام', 'ماشي', 'أكيد', 'صح', 'نعم', 'طبعاً', 'ايوه تمام', 'أيوه يا باشا']) {
      test('«$s» = أيوه', () => expect(parseYesNo(s), isTrue));
    }
    for (final s in ['لأ', 'لا', 'لاء', 'مش دلوقتي', 'بعدين', 'لسه', 'لا مش كده', 'مش عايز', 'غلط']) {
      test('«$s» = لأ', () => expect(parseYesNo(s), isFalse));
    }
    for (final s in ['', 'الساعة تمانية', 'يمكن', 'الله أعلم']) {
      test('«$s» = مش مفهوم', () => expect(parseYesNo(s), isNull));
    }
    test('«يمكن» و«مش عارف» مش إجابة — نسأل تاني (زي affirm.js)', () {
      expect(parseYesNo('يمكن'), isNull);
      expect(parseYesNo('مش عارف'), isNull);
    });
  });

  group('راجل / ست', () {
    for (final s in ['راجل', 'أنا راجل', 'رجل', 'ذكر', 'ولد']) {
      test('«$s» = راجل', () => expect(parseSex(s), SpokenSex.male));
    }
    for (final s in ['ست', 'أنا ست', 'سيدة', 'أنثى', 'بنت', 'مدام', 'حرمة']) {
      test('«$s» = ست', () => expect(parseSex(s), SpokenSex.female));
    }
    test('غير كده مش مفهوم', () {
      expect(parseSex('تمانية'), isNull);
      expect(parseSex('أيوه'), isNull);
      expect(parseSex(''), isNull);
    });
  });

  group('الأرقام والسن', () {
    final cases = <String, int>{
      'خمسة وسبعين': 75,
      'خمسه و سبعين': 75,
      'خمسة وسبعين سنة': 75,
      'عندي ستين سنة': 60,
      'عمري تمانية وستين': 68,
      'اتنين وعشرين': 22,
      'تسعتاشر': 19,
      'ميه': 100,
      'مية وعشرة': 110,
      '٧٥': 75,
      '75 سنة': 75,
      'سبعين وخمسة': 75,
      'تلاتين': 30,
      'أربعة وأربعين': 44,
    };
    cases.forEach((s, n) {
      test('«$s» = $n', () => expect(parseNumber(s), n));
    });
    test('السن بين ١٨ و١١٠', () {
      expect(parseAge('خمسة وسبعين'), 75);
      expect(parseAge('عشرة'), isNull, reason: 'أقل من ١٨ — مش سن مريض هنا');
      expect(parseAge('ميه وعشرين'), isNull);
      expect(parseAge('أيوه'), isNull);
      expect(parseAge('خمسة خمسة'), isNull, reason: 'رقمين من غير تركيب');
      expect(parseAge('تمانية الصبح'), isNull, reason: 'ساعة مش سن — ٨ أقل من ١٨');
    });
  });

  group('الساعة — بجزء اليوم مقول', () {
    final cases = <String, SpokenTime>{
      'تمانية الصبح': const SpokenTime(8, 0),
      'تمانيه الصبح': const SpokenTime(8, 0),
      'الساعة تمانية الصبح': const SpokenTime(8, 0),
      '٨ ونص الصبح': const SpokenTime(8, 30),
      'تمانية ونص الصبح': const SpokenTime(8, 30),
      'تمانية و نص الصبح': const SpokenTime(8, 30),
      'تسعة إلا ربع الصبح': const SpokenTime(8, 45),
      'تسعه الا ربع الصبح': const SpokenTime(8, 45),
      'عشرة إلا تلت الصبح': const SpokenTime(9, 40),
      'تمانية وربع الصبح': const SpokenTime(8, 15),
      'تمانية وتلت الصبح': const SpokenTime(8, 20),
      'تمانية وخمسة الصبح': const SpokenTime(8, 5),
      'تمانية وعشرين الصبح': const SpokenTime(8, 20),
      'تمانية وخمسة وعشرين الصبح': const SpokenTime(8, 25),
      'تمانية إلا خمسة الصبح': const SpokenTime(7, 55),
      'اتناشر الضهر': const SpokenTime(12, 0),
      'واحدة الضهر': const SpokenTime(13, 0),
      'اتنين ونص الضهر': const SpokenTime(14, 30),
      '٣ العصر': const SpokenTime(15, 0),
      'تلاتة العصر': const SpokenTime(15, 0),
      'خمسة العصر': const SpokenTime(17, 0),
      'سبعة المغرب': const SpokenTime(19, 0),
      'تمانية بالليل': const SpokenTime(20, 0),
      'عشرة بالليل': const SpokenTime(22, 0),
      'عشره بليل': const SpokenTime(22, 0),
      'حداشر ونص بالليل': const SpokenTime(23, 30),
      'اتناشر بالليل': const SpokenTime(0, 0),
      'واحدة بالليل': const SpokenTime(1, 0),
      'اتنين بالليل': const SpokenTime(2, 0),
      'خمسة الفجر': const SpokenTime(5, 0),
      'اتناشر الصبح': const SpokenTime(0, 0),
      'تلاتة بعد الضهر': const SpokenTime(15, 0),
      '20:30': const SpokenTime(20, 30),
      '٢٠:٣٠': const SpokenTime(20, 30),
      '8:30 الصبح': const SpokenTime(8, 30),
      '0:30': const SpokenTime(0, 30),
      '15': const SpokenTime(15, 0),
      'الساعة سبعة وربع المسا': const SpokenTime(19, 15),
      'حوالي تمانية الصبح كده': const SpokenTime(8, 0),
    };
    cases.forEach((s, t) {
      test('«$s» = $t', () => expect(parseTime(s), t));
    });
  });

  group('الساعة — من غير جزء يوم', () {
    test('من غير سؤال بيقول = مش مفهوم (مش هنخمّن)', () {
      expect(parseTime('تمانية'), isNull);
      expect(parseTime('تمانية ونص'), isNull);
      expect(parseTime('٨'), isNull);
    });
    test('سؤال الفطار = الصبح', () {
      expect(parseTime('تمانية', hint: DayPartHint.morning), const SpokenTime(8, 0));
      expect(parseTime('تمانية ونص', hint: DayPartHint.morning), const SpokenTime(8, 30));
      expect(parseTime('اتناشر', hint: DayPartHint.morning), const SpokenTime(12, 0));
      expect(parseTime('٦', hint: DayPartHint.morning), const SpokenTime(6, 0));
    });
    test('سؤال الغدا = الضهر', () {
      expect(parseTime('تلاتة', hint: DayPartHint.noon), const SpokenTime(15, 0));
      expect(parseTime('اتناشر', hint: DayPartHint.noon), const SpokenTime(12, 0));
      expect(parseTime('حداشر', hint: DayPartHint.noon), const SpokenTime(11, 0));
      expect(parseTime('واحدة ونص', hint: DayPartHint.afternoon), const SpokenTime(13, 30));
    });
    test('سؤال العشا = بالليل', () {
      expect(parseTime('تسعة', hint: DayPartHint.evening), const SpokenTime(21, 0));
      expect(parseTime('سبعة ونص', hint: DayPartHint.evening), const SpokenTime(19, 30));
      expect(parseTime('اتناشر', hint: DayPartHint.evening), const SpokenTime(0, 0));
    });
    test('سؤال النوم = بالليل، وبعد نص الليل بالساعات الصغيرة', () {
      expect(parseTime('حداشر', hint: DayPartHint.night), const SpokenTime(23, 0));
      expect(parseTime('اتناشر', hint: DayPartHint.night), const SpokenTime(0, 0));
      expect(parseTime('واحدة', hint: DayPartHint.night), const SpokenTime(1, 0));
      expect(parseTime('اتنين ونص', hint: DayPartHint.night), const SpokenTime(2, 30));
    });
    test('الجزء المقول بيكسب على السؤال', () {
      expect(parseTime('تسعة الصبح', hint: DayPartHint.night), const SpokenTime(9, 0));
      expect(parseTime('سبعة بالليل', hint: DayPartHint.morning), const SpokenTime(19, 0));
    });
  });

  group('الساعة — كلام غلط', () {
    for (final s in ['', 'أيوه', 'الصبح', 'تلتاشر الصبح', 'تمانية وستين الصبح', 'تمانية إلا الصبح', 'راجل', '25:00', '8:75']) {
      test('«$s» = مش مفهوم', () => expect(parseTime(s, hint: DayPartHint.morning), isNull));
    }
  });

  group('رد التذكير', () {
    for (final s in ['أخدته', 'اخدته', 'خدته', 'خدتها', 'أيوه أخدت الدوا', 'أخدت', 'اخدتهم', 'أيوه', 'تمام', 'تم', 'شربته']) {
      test('«$s» = أخدته', () => expect(parseDoseAnswer(s), DoseAnswer.taken));
    }
    for (final s in ['فكّرني بعدين', 'فكرني بعدين', 'بعدين', 'مش دلوقتي', 'بعد شوية', 'كمان شوية', 'أجّلها', 'لسه']) {
      test('«$s» = بعدين', () => expect(parseDoseAnswer(s), DoseAnswer.later));
    }
    test('«ماخدتش» و«لأ» لوحدها = مش مفهوم — القرار بإيده', () {
      expect(parseDoseAnswer('ماخدتش'), isNull);
      expect(parseDoseAnswer('لأ ماخدتهوش'), isNull);
      expect(parseDoseAnswer('لأ'), isNull);
      expect(parseDoseAnswer(''), isNull);
      expect(parseDoseAnswer('الساعة تمانية'), isNull);
    });
  });

  group('الاسم', () {
    test('زي ما اتقال، من غير «اسمي»', () {
      expect(parseName('الحاج أحمد'), 'الحاج أحمد');
      expect(parseName('اسمي أحمد محمود'), 'أحمد محمود');
      expect(parseName('أنا اسمي فاطمة'), 'فاطمة');
      expect(parseName('  محمد  '), 'محمد');
      expect(parseName('Ahmed'), 'Ahmed');
    });
    test('فاضي أو أيوه/لأ لوحدها = مش اسم', () {
      expect(parseName(''), isNull);
      expect(parseName('أيوه'), isNull);
      expect(parseName('لأ'), isNull);
      expect(parseName('اسمي'), isNull);
    });
  });

  test('التطبيع: أرقام عربية وهمزات وتاء مربوطة وتشكيل', () {
    expect(normalizeArabic('تَمانِيَة ٨ الأُولى'), 'تمانيه 8 الاولي');
    expect(normalizeArabic('لأ، مش كده!'), 'لا مش كده');
  });

  test('صفحة الجنس: «راجل / ست / راجل أنا / ست أنا / ذكر / أنثى»', () {
    for (final t in ['راجل', 'راجل أنا', 'أنا راجل', 'ذكر']) {
      expect(parseSex(t), SpokenSex.male, reason: t);
    }
    for (final t in ['ست', 'ست أنا', 'أنا ست', 'أنثى']) {
      expect(parseSex(t), SpokenSex.female, reason: t);
    }
  });
}
