import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fakkarni/data/health/health_heartbeat.dart';
import 'package:fakkarni/domain/health/health_check.dart';
import 'package:fakkarni/domain/health/health_report.dart';
import 'package:fakkarni/domain/health/health_snapshot.dart';

/// **مش كل فتحة للتطبيق.** الجدول ده على خطة مجانية والموبايل بتاع راجل
/// كبير — كتابة على كل فتحة بتصرف الاتنين على معلومة ما اتغيّرتش.
class _Recording implements HealthRemote {
  final List<Map<String, dynamic>> rows = [];

  @override
  Future<void> upsert(Map<String, dynamic> row) async => rows.add(row);
}

class _Failing implements HealthRemote {
  @override
  Future<void> upsert(Map<String, dynamic> row) async =>
      throw Exception('السحابة وقعت');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 9, 20, 10);

  HealthSnapshot snap(DateTime now, {NotificationPermission? permission}) =>
      HealthSnapshot(
        now: now,
        platform: HealthPlatform.ios,
        permission: permission ?? NotificationPermission.granted,
        activeDoseCount: 2,
        plannedDoseCount: 4,
        pendingDoseCount: 4,
        horizonUntil: now.add(const Duration(days: 5)),
        deviceTimezone: 'Africa/Cairo',
        scheduledTimezone: 'Africa/Cairo',
        hasCaregiver: true,
        hasPushToken: true,
        cloudConfigured: true,
        signedIn: true,
        lastSyncedAt: now,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('أول فحص بيرفع صف — مفيش حاجة نقارن بيها', () async {
    final remote = _Recording();
    final beat = HealthHeartbeat(remote: remote, patientUuid: 'p1');

    expect(await beat.report(runHealthChecks(snap(start)), snap(start)), isTrue);
    expect(remote.rows, hasLength(1));
  });

  test('نفس الحالة بعد ساعة → مفيش رفع', () async {
    final remote = _Recording();
    final beat = HealthHeartbeat(remote: remote, patientUuid: 'p1');
    await beat.report(runHealthChecks(snap(start)), snap(start));

    final later = start.add(const Duration(hours: 1));
    expect(await beat.report(runHealthChecks(snap(later)), snap(later)), isFalse);
    expect(remote.rows, hasLength(1));
  });

  test('عدّت مهلة النبضة من غير أي تغيير → بيرفع', () async {
    final remote = _Recording();
    final beat = HealthHeartbeat(remote: remote, patientUuid: 'p1');
    await beat.report(runHealthChecks(snap(start)), snap(start));

    final later = start.add(heartbeatEvery + const Duration(minutes: 1));
    expect(await beat.report(runHealthChecks(snap(later)), snap(later)), isTrue);
    expect(remote.rows, hasLength(2));
  });

  test('اتكسرت حاجة → بيرفع حالاً، من غير ما يستنى المهلة', () async {
    final remote = _Recording();
    final beat = HealthHeartbeat(remote: remote, patientUuid: 'p1');
    await beat.report(runHealthChecks(snap(start)), snap(start));

    final later = start.add(const Duration(minutes: 3));
    final broken = snap(later, permission: NotificationPermission.denied);
    expect(await beat.report(runHealthChecks(broken), broken), isTrue);
    expect(remote.rows.last['failing_codes'],
        contains(HealthCode.notificationPermission.name));
  });

  test('«ما قدرناش نبص» بتتسجّل لوحدها — مش زي «تمام»', () async {
    final remote = _Recording();
    final unknown = HealthSnapshot(
      now: start,
      platform: HealthPlatform.android,
      permission: NotificationPermission.granted,
      activeDoseCount: 2,
      horizonUntil: start.add(const Duration(days: 5)),
      batteryState: BatteryState.unknown,
    );
    await HealthHeartbeat(remote: remote, patientUuid: 'p1')
        .report(runHealthChecks(unknown), unknown);

    expect(remote.rows.single['battery_state'], 'unknown');
    expect(remote.rows.single['failing_codes'],
        isNot(contains(HealthCode.batteryOptimisation.name)),
        reason: 'مش عطل — بس مش «تمام» كمان');
  });

  test('الصف فيه أكواد سلامة بس — ولا اسم دوا ولا أي حاجة طبية', () async {
    final remote = _Recording();
    await HealthHeartbeat(remote: remote, patientUuid: 'p1')
        .report(runHealthChecks(snap(start)), snap(start));

    const allowed = {
      'patient_uuid', 'install_id', 'checked_at', 'app_version', 'platform',
      'os_version', 'tz', 'notif_permission', 'pending_count', 'horizon_until',
      'has_token', 'has_caregiver', 'last_sync_at', 'dirty_count',
      'failing_codes', 'battery_state',
    };
    expect(remote.rows.single.keys.toSet(), allowed);

    final codes = remote.rows.single['failing_codes'] as List<String>;
    expect(codes.every(allHealthCodeNames.contains), isTrue,
        reason: 'مفيش حاجة بتتبعت غير أكواد معروفة');
  });

  test('النبضة وقعت → بترجّع false ومفيش رمي، والفتحة الجاية بتعيد', () async {
    final beat = HealthHeartbeat(remote: _Failing(), patientUuid: 'p1');
    expect(await beat.report(runHealthChecks(snap(start)), snap(start)), isFalse);

    // ما اتسجّلش إنها اترفعت، فالمحاولة الجاية بتشتغل
    final remote = _Recording();
    final retry = HealthHeartbeat(remote: remote, patientUuid: 'p1');
    final later = start.add(const Duration(minutes: 1));
    expect(await retry.report(runHealthChecks(snap(later)), snap(later)), isTrue);
  });

  test('مريض مش في السحابة (مش مربوط / حساب تاني): ولا نداء — كان 42501 على كل فتحة', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _Recording();
    final beat = HealthHeartbeat(remote: remote, patientUuid: 'p1', eligible: () async => false);
    expect(await beat.report(runHealthChecks(snap(start)), snap(start)), isFalse);
    expect(remote.rows, isEmpty);

    final ok = HealthHeartbeat(remote: remote, patientUuid: 'p1', eligible: () async => true);
    expect(await ok.report(runHealthChecks(snap(start)), snap(start)), isTrue);
    expect(remote.rows, hasLength(1));
  });
}
