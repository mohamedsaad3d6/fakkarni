// بورت `affirm.js` (jarvis-ai-finance) — نفس حالات `backend/test/gate.test.js`
// بالحرف، وحالاتنا القديمة. القرار حتمي: عمره ما يبقى ذكاء.
import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/domain/voice/answer_parser.dart';

void main() {
  group('gate.test.js بالحرف', () {
    for (final yes in ['أيوه', 'ايوه', 'آه', 'تمام', 'ماشي', 'أكد', 'أوكي', 'ok', 'yes', 'sure', 'go ahead']) {
      test('«$yes» = affirm', () => expect(classifyReply(yes), ReplyClass.affirm));
    }
    for (final no in ['لأ', 'لا', 'بلاش', 'ألغي', 'كنسل', 'no', 'cancel', 'nevermind']) {
      test('«$no» = deny', () => expect(classifyReply(no), ReplyClass.deny));
    }
    for (final unclear in ['خليها ٢٥٠ بدل ٢٠٠', 'مش عارف', 'hmm', '', '   ', 'what?']) {
      test('«$unclear» = unclear — عمره ما يأكّد', () => expect(classifyReply(unclear), ReplyClass.unclear));
    }
    test('رفض في الأول ما يتقراش قبول بعدين', () {
      expect(classifyReply('لا خلاص تمام كده'), ReplyClass.deny);
      expect(classifyReply('no, it is ok'), ReplyClass.deny);
    });
    test('التطبيع بيوحّد اللي المتعرّف بيبدّله', () {
      expect(normalizeReply('أَيْوَه'), normalizeReply('ايوه'));
      expect(normalizeReply('العمليّة'), normalizeReply('العمليه'));
    });
  });

  group('حدود الكلمة (END هناك)', () {
    test('«لازم» مش «لا»، و«ماشيش» مش «ماشي»', () {
      expect(classifyReply('لازم'), ReplyClass.unclear);
      expect(classifyReply('ماشيش'), ReplyClass.deny);
      expect(classifyReply('اهلا'), ReplyClass.unclear);
    });
    test('«أيوه» في آخر الجملة مش تأكيد — أول كلمة بتحكم', () {
      expect(classifyReply('بص يا سيدي ايوه'), ReplyClass.unclear);
      expect(classifyReply('don\'t'), ReplyClass.deny);
      expect(classifyReply('never mind'), ReplyClass.deny);
      expect(classifyReply('do it'), ReplyClass.affirm);
    });
    test('علامات الاتجاه والمسافات الصفرية ما بتبوّظش', () {
      expect(classifyReply('\u202Bأيوه\u202C'), ReplyClass.affirm);
      expect(classifyReply('\u200Bلأ'), ReplyClass.deny);
    });
    test('«مش» في عبارة رفض بس', () {
      expect(classifyReply('مش دلوقتي'), ReplyClass.deny);
      expect(classifyReply('مش كده'), ReplyClass.deny);
      expect(classifyReply('مش متأكد'), ReplyClass.unclear);
    });
  });

  test('parseYesNo = classifyReply', () {
    for (final s in ['أيوه', 'لأ', 'مش عارف', 'تمام', 'بعدين', '']) {
      final c = classifyReply(s);
      expect(parseYesNo(s), c == ReplyClass.affirm ? isTrue : c == ReplyClass.deny ? isFalse : isNull);
    }
  });
}
