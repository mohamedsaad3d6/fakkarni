// خدمة الصوت بمزيّفات: التسجيل الأول وصوت الموبايل بداله، الصمت لما
// مقفول، وتنبيه الجرعة بيوقّف كل حاجة.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/data/voice/voice_service.dart';
import 'package:fakkarni/domain/voice/voice_catalog.dart';

class FakePlayer implements VoicePlayer {
  final played = <String>[];
  int stops = 0;
  bool ok = true;
  bool throws = false;

  /// التسجيل «بيفضل شغّال» لحد ما `stop()` تتنده — زي ملف طويل على الجهاز.
  bool holdPlayback = false;
  Completer<void>? _hold;
  @override
  Future<bool> play(String assetPath, {required double volume}) async {
    played.add(assetPath);
    if (throws) throw StateError('no player');
    if (holdPlayback) {
      final c = _hold = Completer<void>();
      await c.future;
    }
    return ok;
  }

  int releases = 0;
  @override
  Future<void> release() async {
    releases++;
    await stop();
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _hold;
    if (c != null && !c.isCompleted) c.complete();
    _hold = null;
  }
}

class FakeTts implements VoiceTts {
  final spoken = <String>[];
  int stops = 0;
  double? rate;

  /// الكلام «بيفضل شغّال» لحد ما `stop()` تتنده.
  bool hold = false;
  Completer<void>? _hold;
  @override
  Future<void> speak(String text, {required double rate, required double volume}) async {
    spoken.add(text);
    this.rate = rate;
    if (hold) await (_hold = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _hold;
    if (c != null && !c.isCompleted) c.complete();
    _hold = null;
  }
}

class FakeFocus implements VoiceAudioFocus {
  int begins = 0, ends = 0;
  @override
  Future<void> begin() async => begins++;
  @override
  Future<void> end() async => ends++;
}

void main() {
  late FakePlayer player;
  late FakeTts tts;
  late FakeFocus focus;
  late VoiceService voice;

  setUp(() async {
    SharedPreferences.setMockInitialValues({VoiceService.enabledKey: true});
    player = FakePlayer();
    tts = FakeTts();
    focus = FakeFocus();
    voice = VoiceService(player: player, tts: tts, focus: focus);
    await voice.load();
  });

  test('التسجيل شغّال: بيتقال منه، وصوت الموبايل ما بيتندهش', () async {
    await voice.speakLine('help_today');
    expect(player.played, ['assets/voices/help_today.mp3']);
    expect(tts.spoken, isEmpty);
    expect(voice.caption.value, isNull, reason: 'الترجمة بتختفي بعد ما يخلص');
    expect(focus.begins, 1);
    expect(focus.ends, greaterThanOrEqualTo(1), reason: 'الجلسة بتتسلّم بعد الكلام');
  });

  test('التسجيل ناقص (false) أو وقع (throw) → صوت الموبايل بنفس النص', () async {
    player.ok = false;
    await voice.speakLine('help_today');
    expect(tts.spoken, [voiceLine('help_today')]);

    player.throws = true;
    await voice.speakLine('help_tip');
    expect(tts.spoken.last, voiceLine('help_tip'));
    expect(tts.rate, VoiceSpeed.slow.rate, reason: 'البطيء هو الافتراضي');
  });

  test('ملخص اليوم بصوت الموبايل بس — التسجيل ما بيتلمسش', () async {
    await voice.speakText('صباح الخير. النهارده عندك ٣ أدوية.');
    expect(player.played, isEmpty);
    expect(tts.spoken, ['صباح الخير. النهارده عندك ٣ أدوية.']);
  });

  test('الصوت مقفول = صمت — إلا المقدمة (force)', () async {
    await voice.setEnabled(false);
    await voice.speakLine('help_today');
    await voice.speakText('ملخص');
    expect(player.played, isEmpty);
    expect(tts.spoken, isEmpty);
    await voice.speakLine('intro_01', force: true);
    expect(player.played, ['assets/voices/intro_01.mp3']);
  });

  test('تنبيه الجرعة بيكسب: إشارة الإشعار بتوقّف التسجيل والترجمة فوراً', () async {
    final alert = ValueNotifier<String?>(null);
    voice.attachAlertSignal(alert);
    player.holdPlayback = true;
    final speaking = voice.speakLine('help_routine');
    await Future<void>.delayed(Duration.zero);
    expect(voice.caption.value, voiceLine('help_routine'));

    alert.value = '{"v":1}'; // دوسة على إشعار جرعة
    await Future<void>.delayed(Duration.zero);
    expect(player.stops, greaterThanOrEqualTo(1));
    expect(tts.stops, greaterThanOrEqualTo(1));
    expect(voice.caption.value, isNull);
    await speaking;
    expect(tts.spoken, isEmpty, reason: 'اتقطع — ما يرجعش يكمّل بصوت الموبايل');
  });

  test('كلام جديد بيوقّف اللي قبله، والمقدمة بتقف في النص لو اتقطعت', () async {
    player.holdPlayback = true;
    final intro = voice.speakLines(introSequence, force: true);
    await Future<void>.delayed(Duration.zero);
    await voice.stop();
    await intro;
    expect(player.played, ['assets/voices/intro_01.mp3'], reason: 'وقفت عند الأولى');
  });

  test('الإعدادات بتتحفظ وبتترجع', () async {
    await voice.setSpeed(VoiceSpeed.fast);
    await voice.setVolume(VoiceVolume.high);
    await voice.markIntroDone();
    await voice.markBriefed('2026-09-25');
    final again = VoiceService(player: player, tts: tts);
    await again.load();
    expect(again.speed, VoiceSpeed.fast);
    expect(again.volume, VoiceVolume.high);
    expect(again.introDone, isTrue);
    expect(again.shouldBrief('2026-09-25'), isFalse);
    expect(again.shouldBrief('2026-09-26'), isTrue);
  });

  test('speakQueued: بيستنّى اللي بيتقال يخلص، وبيقول بالترتيب، وstop() من برّه بيلغي اللي لسه ما بدأش', () async {
    player.holdPlayback = true;
    final first = voice.speakLine('help_today');
    await Future<void>.delayed(Duration.zero);
    final queued = voice.speakQueued(['help_tip']);
    await Future<void>.delayed(Duration.zero);
    expect(player.played, ['assets/voices/help_today.mp3'], reason: 'لسه مستني');
    player.holdPlayback = false;
    await player.stop(); // التسجيل الأول خلص
    await first;
    await queued;
    expect(player.played, ['assets/voices/help_today.mp3', 'assets/voices/help_tip.mp3']);

    // من غير حاجة بتتقال: بيقول على طول
    await voice.speakQueued(['help_later']);
    expect(player.played.last, 'assets/voices/help_later.mp3');

    // stop() بعد ما اتحطّ في الطابور وقبل ما يبدأ = ما بيتقالش
    player.holdPlayback = true;
    final held = voice.speakLine('help_today');
    await Future<void>.delayed(Duration.zero);
    final cancelled = voice.speakQueued(['help_scan']);
    await voice.stop();
    await held;
    await cancelled;
    expect(player.played.where((p) => p.contains('help_scan')), isEmpty);
  });
}
