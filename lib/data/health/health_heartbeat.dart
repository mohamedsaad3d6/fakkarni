import '../app_version.dart';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics.dart';
import '../../domain/health/health_check.dart';
import '../../domain/health/health_report.dart';
import '../../domain/health/health_snapshot.dart';

/// صف واحد لكل (مريض، تنزيلة) في السحابة.
///
/// **أكواد سلامة وبس**: مفيش اسم دوا، ولا محتوى جرعة، ولا أي حاجة طبية.
/// الجدول ده بيجاوب على سؤال واحد — أنهي حسابات مكسورة دلوقتي وعلى إيه —
/// ومن غير ما حد يمسك موبايل.
abstract interface class HealthRemote {
  Future<void> upsert(Map<String, dynamic> row);
}

/// **مش كل فتحة للتطبيق.**
///
/// بيترفع صف في حالتين بس: لما مجموعة الأكواد المكسورة **تتغيّر**، أو
/// لما تعدّي [heartbeatEvery] من غير أي تغيير. ده قاعدة بيانات على خطة
/// مجانية وبطارية راجل كبير — وكتابة على كل فتحة بتصرف الاتنين على
/// معلومة ما اتغيّرتش.
///
/// ست ساعات: عتبة «مكسور» للمدى ٢٤ ساعة، فأسوأ تأخير في رؤية عطل هو
/// ربع النافذة اللي بنتصرف فيها. وأربع صفوف في اليوم للجهاز الواحد =
/// أربعة آلاف صف يومياً لألف مستخدم، وده مفيش حاجة.
const Duration heartbeatEvery = Duration(hours: 6);

class HealthHeartbeat {
  const HealthHeartbeat({required this.remote, required this.patientUuid, this.eligible});

  final HealthRemote remote;
  final String patientUuid;

  /// الصف مسموح يتكتب؟ — `SyncService.cloudOwnsPatient`. false = ولا نداء:
  /// مريض مش في السحابة (مش مربوط) أو مش بتاع الجلسة دي، والسياسة هترفض.
  final Future<bool> Function()? eligible;

  static const _codesKey = 'health.lastCodes';
  static const _sentKey = 'health.lastSentMs';
  static const _installKey = 'health.installId';

  /// بترجّع true لو الصف اترفع فعلاً.
  ///
  /// **عمرها ما بترمي**: نبضة فاشلة مالهاش أي حق توقّع فتحة تطبيق.
  Future<bool> report(HealthReport report, HealthSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codes = (report.brokenCodes.map((c) => c.name).toList()..sort());
      final previous = prefs.getStringList(_codesKey);
      final lastMs = prefs.getInt(_sentKey);
      final last =
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);

      final changed = previous == null || !_sameCodes(previous, codes);
      final due = last == null || snapshot.now.difference(last) >= heartbeatEvery;
      if (!changed && !due) return false;
      if (eligible != null && !await eligible!()) {
        diag('Health: النبضة مستنية — المريض مش في السحابة لسه أو مش بتاع الجلسة دي');
        return false;
      }

      await remote.upsert({
        'patient_uuid': patientUuid,
        'install_id': await _installId(prefs),
        'checked_at': snapshot.now.toUtc().toIso8601String(),
        // الحقيقية من الحزمة لو اتقرت — التعريف لو لأ
        'app_version': AppVersion.current ?? appVersion,
        'platform': snapshot.platform.name,
        'os_version': _osVersion(),
        'tz': snapshot.deviceTimezone,
        'notif_permission': snapshot.permission.name,
        'pending_count': snapshot.pendingCount,
        'horizon_until': snapshot.horizonUntil?.toUtc().toIso8601String(),
        'has_token': snapshot.hasPushToken,
        'has_caregiver': snapshot.hasCaregiver,
        'last_sync_at': snapshot.lastSyncedAt?.toUtc().toIso8601String(),
        'dirty_count': snapshot.dirtyRowCount,
        // تلات حالات، مش اتنين: «ما قدرناش نبص» لازم يتعدّ لوحده
        'battery_state': snapshot.batteryState.name,
        'failing_codes': codes,
      });

      await prefs.setStringList(_codesKey, codes);
      await prefs.setInt(_sentKey, snapshot.now.millisecondsSinceEpoch);
      diag('Health: نبضة اترفعت — ${codes.isEmpty ? 'كله تمام' : codes.join(',')}');
      return true;
    } catch (error) {
      diag('Health: النبضة ما اترفعتش ($error)');
      return false;
    }
  }

  static bool _sameCodes(List<String> a, List<String> b) =>
      a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);

  Future<String> _installId(SharedPreferences prefs) async {
    final existing = prefs.getString(_installKey);
    if (existing != null) return existing;
    // التنزيلة دي، مش الحساب: مسح بيانات التطبيق بيدّي واحدة جديدة، وده
    // صح — بقى جهاز تاني من ناحية التذكيرات.
    final minted = '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
        '-${identityHashCode(prefs).toRadixString(16)}';
    await prefs.setString(_installKey, minted);
    return minted;
  }

  static String _osVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '';
    }
  }
}

/// نسخة التطبيق من `--dart-define=APP_VERSION=…` — من غير إضافة جديدة
/// عشان رقم. غيابه بيقول `dev`، وده صادق.
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// كل الأكواد اللي السيرفر ممكن يشوفها — عقد بين دارت وSQL.
List<String> get allHealthCodeNames =>
    [for (final code in HealthCode.values) code.name]..sort();
