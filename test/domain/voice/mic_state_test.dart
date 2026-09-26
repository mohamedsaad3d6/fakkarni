import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/domain/voice/mic_state.dart';

void main() {
  test('كل حالة ليها كلمة — زي MicOrb', () {
    expect(micStateLabel(MicState.idle), 'دوس واتكلم');
    expect(micStateLabel(MicState.listening), 'سامعك…');
    expect(micStateLabel(MicState.thinking), 'بفكّر…');
    expect(micStateLabel(MicState.speaking), 'برد عليك — دوس عشان تقاطعني');
    expect(micStateLabel(MicState.off), 'اكتب أو دوس بدل الصوت');
    for (final s in MicState.values) {
      expect(micStateLabel(s), isNotEmpty);
    }
  });

  group('القاطع: ٥ في ١٠ ثواني', () {
    test('٤ وقعات ما بتقفلش، الخامسة بتقفل', () {
      var now = DateTime(2026, 9, 26, 10);
      final b = MicBreaker(clock: () => now);
      for (var i = 0; i < 4; i++) {
        expect(b.fail(), isFalse);
        now = now.add(const Duration(seconds: 1));
      }
      expect(b.fail(), isTrue);
      expect(b.tripped, isTrue);
    });

    test('وقعات متفرّقة (كل ٣ ثواني) عمرها ما تقفل', () {
      var now = DateTime(2026, 9, 26, 10);
      final b = MicBreaker(clock: () => now);
      for (var i = 0; i < 20; i++) {
        expect(b.fail(), isFalse);
        now = now.add(const Duration(seconds: 3));
      }
    });
  });
}
