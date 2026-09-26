// الكتالوج مرآة للسكريبت والتسجيلات — التلاتة لازم يتطابقوا بالحرف.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/domain/voice/voice_catalog.dart';

void main() {
  final script = File('docs/voice/script_ar.md').readAsStringSync();
  final rows = RegExp(r'^\| `([a-z_0-9]+)` \| (.+?) \|$', multiLine: true)
      .allMatches(script)
      .map((m) => (id: m.group(1)!, text: m.group(2)!))
      .toList();

  test('كل جملة في الكتالوج هي نفس جملة السكريبت بالحرف — لا زيادة ولا نقصان', () {
    expect(rows, hasLength(65), reason: 'السكريبت بيقول ٦٥ جملة ثابتة');
    expect(voiceLines.keys.toList(), [for (final r in rows) r.id], reason: 'نفس الأرقام بنفس الترتيب');
    for (final r in rows) {
      expect(voiceLines[r.id], r.text, reason: 'الجملة ${r.id} اتغيّرت عن السكريبت');
    }
  });

  test('لكل رقم ملف mp3، ومفيش ملف من غير رقم', () {
    // تسجيل سبق الكود بتاعه مش يتيم لو رقمه مكتوب في سكريبت تاني تحت
    // docs/voice/ (مرحلة جاية) — أي ملف تاني برّه الكتالوج بيوقّع.
    final waiting = <String>{
      for (final f in Directory('docs/voice').listSync().whereType<File>())
        if (f.path.endsWith('.md') && !f.path.endsWith('/script_ar.md'))
          for (final m in RegExp(r'^\| `([a-z_0-9]+)` \|', multiLine: true).allMatches(f.readAsStringSync()))
            if (!voiceLines.containsKey(m.group(1))) '${m.group(1)}.mp3',
    };
    final files = Directory('assets/voices')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => !n.startsWith('.'))
        .where((n) => !waiting.contains(n))
        .toSet();
    final expected = {for (final id in voiceLines.keys) '$id.mp3'};
    expect(expected.difference(files), isEmpty, reason: 'تسجيلات ناقصة');
    expect(files.difference(expected), isEmpty, reason: 'ملفات يتيمة في assets/voices');
    for (final f in expected) {
      expect(File('assets/voices/$f').lengthSync(), greaterThan(1000), reason: '$f فاضي');
    }
  });

  test('الفولدر مسجّل في pubspec، والمسار من دالة واحدة', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/voices/'));
    expect(voiceAssetPath('intro_01'), 'assets/voices/intro_01.mp3');
    expect(() => voiceLine('help_nothing'), throwsArgumentError);
    expect(introSequence.every(voiceLines.containsKey), isTrue);
    expect(helpIds, hasLength(34), reason: '٦٥ − ٧ مقدمة − ٤ عامة − ١١ بداية − ٤ سماع − ٥ أوامر');
  });
}
