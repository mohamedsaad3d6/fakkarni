import 'speech_listener.dart';
import 'stt_driver.dart';

/// التعرّف في السحابة — **كعب حقيقي، مقفول عن قصد** (`cloudStt.js` هناك).
///
/// موجود دلوقتي عشان التحويل بعدين يبقى اسم في البناء + الملف ده بس، لو
/// تعرّف المصري على الموبايل طلع هو العطل (أكتر حاجة متوقّعة). **مفيش مفاتيح
/// ولا شبكة هنا** — `stt_driver_test` بيقفل على ده. لما يتبني: تسجيل قصير ←
/// دالة حافة بجلسة المستخدم ← كلام مكتوب، وسياسة الخصوصية بتتغيّر معاه.
class CloudSttDriver implements SttDriver {
  const CloudSttDriver();

  @override
  String get name => 'cloud';

  /// اقلبها لما الدالة تتبني.
  @override
  bool get isSupported => false;

  @override
  bool? get lastOnDevice => null;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<ListenFailed?> prepare() async => const ListenFailed('cloud_stt_disabled');

  @override
  Future<ListenResult> listen({
    Duration silence = ListenTimings.silence,
    Duration maxLength = ListenTimings.maxLength,
    Duration firstWordWithin = ListenTimings.firstWordWithin,
    void Function(String partial)? onPartial,
  }) async =>
      const ListenFailed('cloud_stt_disabled');

  @override
  Future<void> stop() async {}
}
