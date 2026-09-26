// `MicListener` — الماكينة الصارمة ونهاية الكلام بتاعتنا (webSpeechStt.js).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fakkarni/data/voice/cloud_stt.dart';
import 'package:fakkarni/data/voice/mic_listener.dart';
import 'package:fakkarni/data/voice/speech_listener.dart';
import 'package:fakkarni/data/voice/stt_driver.dart';

/// محرّك مزيّف: السماع مفتوح لحد ما الاختبار يقفله، والكلام بيوصل بـ[say].
class _Driver implements SttDriver {
  int starts = 0;
  int stops = 0;
  Completer<ListenResult>? open;
  void Function(String)? _partial;

  @override
  String get name => 'fake';
  @override
  bool get isSupported => true;
  @override
  bool? get lastOnDevice => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<ListenFailed?> prepare() async => null;

  @override
  Future<ListenResult> listen({
    Duration silence = ListenTimings.silence,
    Duration maxLength = ListenTimings.maxLength,
    Duration firstWordWithin = ListenTimings.firstWordWithin,
    void Function(String partial)? onPartial,
  }) {
    starts++;
    _partial = onPartial;
    return (open = Completer<ListenResult>()).future;
  }

  void say(String t) => _partial?.call(t);

  void end(ListenResult r) {
    final c = open;
    open = null;
    if (c != null && !c.isCompleted) c.complete(r);
  }

  @override
  Future<void> stop() async {
    stops++;
    end(const ListenSilence());
  }
}

void main() {
  const eos = Duration(milliseconds: 60);
  late _Driver driver;
  late MicListener mic;

  setUp(() {
    driver = _Driver();
    mic = MicListener(driver, endOfSpeech: eos);
  });

  test('نهاية الكلام الافتراضية ١٫٢ ثانية — مش سكوت المتعرّف', () {
    expect(MicListener.defaultEndOfSpeech, const Duration(milliseconds: 1200));
    expect(MicListener(driver).endOfSpeech, const Duration(milliseconds: 1200));
  });

  test('دوستين ورا بعض = سماع واحد، ونفس النتيجة', () async {
    final a = mic.listen();
    final b = mic.listen();
    expect(driver.starts, 1, reason: 'المحرّك ما يتفتحش مرتين');
    driver.end(const ListenHeard('أخدته'));
    expect(await a, isA<ListenHeard>());
    expect(await b, isA<ListenHeard>());
  });

  test('١٫٢ ثانية من غير كلمة جديدة ← الكلام بيتقفل وبيتبعت، والمحرّك بيقف', () async {
    final partials = <String>[];
    final r = mic.listen(onPartial: partials.add);
    driver.say('أخدت');
    await Future<void>.delayed(eos ~/ 2);
    driver.say('أخدت الدوا');
    await Future<void>.delayed(eos ~/ 2);
    expect(mic.isListening, isTrue, reason: 'كلمة جديدة بتمدّ الوقت');
    final heard = await r.timeout(const Duration(seconds: 2));
    expect(heard, isA<ListenHeard>());
    expect((heard as ListenHeard).text, 'أخدت الدوا');
    expect(partials, ['أخدت', 'أخدت الدوا']);
    expect(driver.stops, 1);
    expect(mic.isListening, isFalse);
  });

  test('قبل أول كلمة مفيش مؤقّت بتاعنا — المتعرّف هو اللي بيستنى', () async {
    final r = mic.listen();
    await Future<void>.delayed(eos * 3);
    expect(mic.isListening, isTrue);
    driver.end(const ListenSilence());
    expect(await r, isA<ListenSilence>(), reason: 'سكوت مش عطل');
  });

  test('المتعرّف قفل بسكوت وإحنا سامعين كلام ← الكلام يكسب', () async {
    final r = mic.listen();
    driver.say('بعدين');
    driver.end(const ListenFailed('error_audio', started: true));
    expect(await r, isA<ListenHeard>());
  });

  test('stop() بتكسب على طول — والمؤقّت ما بيبعتش بعدها', () async {
    final r = mic.listen();
    driver.say('أيوه');
    await mic.stop();
    expect(await r, isA<ListenSilence>());
    await Future<void>.delayed(eos * 2);
    expect(mic.isListening, isFalse);
    // سماع جديد بعدها شغّال عادي
    final again = mic.listen();
    expect(driver.starts, 2);
    driver.end(const ListenHeard('لأ'));
    expect(await again, isA<ListenHeard>());
  });

  test('المحرّك رمى ← وقعة، مش تعليق', () async {
    final bad = MicListener(_Throwing());
    expect(await bad.listen(), isA<ListenFailed>());
  });

  group('الوصلة', () {
    test('الكعب السحابي مقفول ← مفيش مايك', () {
      expect(const CloudSttDriver().isSupported, isFalse);
      expect(pickSttDriver('cloud', device: () => driver, cloud: CloudSttDriver.new), isNull);
      expect(pickSttDriver('device', device: () => driver, cloud: CloudSttDriver.new), same(driver));
      expect(pickSttDriver('حاجة غريبة', device: () => driver, cloud: CloudSttDriver.new), same(driver));
    });

    test('الكعب السحابي: ولا شبكة ولا مفاتيح', () {
      final src = File('lib/data/voice/cloud_stt.dart').readAsStringSync();
      for (final banned in ['package:http', 'dart:io', 'HttpClient', 'supabase', 'API_KEY', 'fromEnvironment']) {
        expect(src, isNot(contains(banned)), reason: banned);
      }
    });

    test('الشاشات بتاخد MicListener فوق المحرّك — مش المحرّك على طول', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('listener: stt == null ? null : MicListener(stt)'));
      expect(main, isNot(contains('listener: SpeechToTextListener()')));
    });
  });
}

class _Throwing extends _Driver {
  @override
  Future<ListenResult> listen({
    Duration silence = ListenTimings.silence,
    Duration maxLength = ListenTimings.maxLength,
    Duration firstWordWithin = ListenTimings.firstWordWithin,
    void Function(String partial)? onPartial,
  }) =>
      Future.error(StateError('boom'));
}
