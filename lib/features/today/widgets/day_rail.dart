import '../../../domain/escalation/dose_moment.dart';
import 'package:flutter/material.dart';

import '../../../core/format/arabic_time.dart';
import '../../../core/format/name_direction.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/care/follower_role.dart';
import '../../../core/widgets/patient_voice.dart';
import '../../../domain/patient/sex.dart';
import '../../../data/dose_state.dart';
import '../../../data/repositories/dose_event_repository.dart';
import '../../../domain/scheduling/day_routine.dart';

/// علامة مرساة على الشريط — «الفطار · ٧:٣٠ ص».
class AnchorMark {
  const AnchorMark(this.anchor, this.at);
  final DayAnchor anchor;
  final DateTime at;
}

/// سكة اليوم (المخطط 24): خط رأسي على **اليمين**، المراسي عُقد خضرا
/// بالاسم والوقت، والجرعات كروت متعلّقة بالسكة بينهم بترتيب الوقت.
///
/// قاعدة اللون: الذهبي معناه «دي لسه عايزاك» — الجرعة المنتظرة والفايتة
/// الاتنين بحافة ذهبية، والفايتة بتقول «لسه ما اتأكدتش» من غير لوم. مفيش
/// رمادي للفايتة ومفيش أحمر. المأخوذة بتنطوي لسطر ✓ هادي وما بتتشالش.
///
/// الكروت مفيهاش زرار «أخدته» — الزرار الأساسي الوحيد هو اللي في الكارت
/// المثبّت فوق. الدوسة على كارت بتفتح شاشة التذكير بتاعته — والكارت
/// موصوف بالكلام (الاسم والوقت والقاعدة)، فمش محتاج كلمة «افتح».
class DayRail extends StatelessWidget {
  const DayRail({
    required this.anchors,
    required this.groups,
    required this.now,
    required this.ruleLabelFor,
    required this.onOpen,
    super.key,
  });

  final List<AnchorMark> anchors;

  /// الجرعات متجمّعة بالوقت — كل مجموعة دقيقة واحدة.
  final List<List<DoseEventView>> groups;
  final DateTime now;
  final String? Function(int doseScheduleId) ruleLabelFor;
  final void Function(List<DoseEventView> group) onOpen;

  /// عرض عمود السكة، ومقاس العقدة.
  static const double _railWidth = 28;
  static const double _node = 14;
  static const double _doneNode = 20;
  static const double _doseNode = 10;

  @override
  Widget build(BuildContext context) {
    final entries = <({DateTime at, bool isAnchor, _RailNode node, Widget child})>[
      for (final anchor in anchors)
        (at: anchor.at, isAnchor: true, node: _RailNode.anchor, child: _anchorLabel(anchor)),
      for (final group in groups)
        (
          at: group.first.scheduledAt,
          isAnchor: false,
          // كل جرعة ليها علامتها على السكة: ✓ للي اتاخدت، ونقطة ذهبية للي لسه
          node: group.every((d) => d.isDone) ? _RailNode.done : _RailNode.dose,
          child: _dose(group, PatientVoice.of(context)),
        ),
    ]..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        // مرساة وجرعة في نفس الدقيقة: المرساة الأول
        if (byTime != 0) return byTime;
        return a.isAnchor == b.isAnchor ? 0 : (a.isAnchor ? -1 : 1);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _railRow(
            node: entries[i].node,
            first: i == 0,
            last: i == entries.length - 1,
            child: entries[i].child,
          ),
      ],
    );
  }

  /// صف واحد: عمود السكة على اليمين (أول ابن في RTL) والمحتوى جنبه.
  Widget _railRow({
    required _RailNode node,
    required bool first,
    required bool last,
    required Widget child,
  }) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _railWidth,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // الخط — متصل من أول صف لآخر صف
                  Positioned(
                    top: first ? F.s20 : 0,
                    bottom: last ? null : 0,
                    height: last ? F.s20 : null,
                    child: Container(width: 2, color: F.line),
                  ),
                  switch (node) {
                    _RailNode.anchor => Positioned(
                        top: F.s20 - _node / 2,
                        child: Container(
                          width: _node,
                          height: _node,
                          decoration: BoxDecoration(color: F.green, shape: BoxShape.circle),
                        ),
                      ),
                    // اتاخدت: الصح على السكة نفسها (المخطط ٢٤) — مش جوّه السطر
                    _RailNode.done => Positioned(
                        top: F.s20 - _doneNode / 2,
                        child: Container(
                          width: _doneNode,
                          height: _doneNode,
                          decoration: BoxDecoration(color: F.pageGround, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Icon(Icons.check, size: _doneNode - 4, color: F.greenOk),
                        ),
                      ),
                    // لسه عايزاك: نقطة ذهبية صغيرة — نفس معنى حافة الكارت
                    _RailNode.dose => Positioned(
                        top: F.s20 - _doseNode / 2,
                        child: Container(
                          width: _doseNode,
                          height: _doseNode,
                          decoration: const BoxDecoration(color: F.gold, shape: BoxShape.circle),
                        ),
                      ),
                  },
                ],
              ),
            ),
            const SizedBox(width: F.s10),
            Expanded(child: child),
          ],
        ),
      );

  Widget _anchorLabel(AnchorMark mark) => Padding(
        padding: const EdgeInsets.symmetric(vertical: F.s8),
        child: SizedBox(
          height: F.s20 + F.s4,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${mark.anchor.label} — ${arabicTime(mark.at)}',
              style: TextStyle(
                fontSize: F.minTextSize,
                fontWeight: FontWeight.w700,
                color: F.ink,
              ),
            ),
          ),
        ),
      );

  Widget _dose(List<DoseEventView> group, Say say) => Padding(
        padding: const EdgeInsets.only(bottom: F.s10),
        child: group.every((d) => d.isDone) ? _quietLine(group, say) : _card(group),
      );

  /// جرعة اتاخدت: سطر هادي بعلامة صح. **ما بتتشالش من السكة أبداً** —
  /// المريض لازم يشوف إنه خدها، مش يلاقي السطر اختفى ويشك إنه نسي.
  Widget _quietLine(List<DoseEventView> group, Say say) => Padding(
        padding: const EdgeInsets.symmetric(vertical: F.s8),
        child: Row(
          children: [
            // الصح على السكة (شوف _railRow) — هنا الاسم ووقته جنب بعض، سطر واحد
            Flexible(
              child: Text(
                group.map((d) => d.medicationName).join(' + '),
                textDirection: nameDirection(group.first.medicationName),
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: F.minTextSize,
                  color: F.mutedDark,
                  fontFamily: F.monoFamily,
                  fontFamilyFallback: F.monoFallback,
                ),
              ),
            ),
            const SizedBox(width: F.s8),
            Text(
              group.first.state == DoseState.skipped
                  ? 'اتأجّل'
                  // حد تاني أكّدها (الممرض، ٠٠٢٣): بنقول مين، مش «أخدته»
                  : group.first.actedBy != null
                      ? '${proxyConfirmedLine(group.first.actedBy)} ${arabicTime(group.first.actedAt ?? group.first.scheduledAt)}'
                      : say.takenAt(arabicTime(group.first.actedAt ?? group.first.scheduledAt)),
              key: ValueKey('taken-line-${group.first.doseScheduleId}'),
              style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
            ),
          ],
        ),
      );

  /// جرعة لسه عايزاك — منتظرة أو فايتة، نفس الحافة الذهبية.
  Widget _card(List<DoseEventView> group) {
    final at = group.first.scheduledAt;
    // فات معادها أو جهازه كتب «اتنست» — نفس الجملة الهادية. نسي، ما فشلش.
    final moment = doseMomentOf(
        scheduledAt: at, now: now, markedMissed: group.any((d) => d.state == DoseState.missed));
    // «لسه ما اتأكدتش» بعد المهلة بس؛ في معادها «معادها دلوقتي»
    final unconfirmed = moment == DoseMoment.missed;
    final dueNow = moment == DoseMoment.dueNow;

    return Material(
      color: F.cardGround,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(F.radiusCard),
        side: const BorderSide(color: F.gold, width: 2),
      ),
      child: InkWell(
        onTap: () => onOpen(group),
        borderRadius: BorderRadius.circular(F.radiusCard),
        child: Container(
          constraints: const BoxConstraints(minHeight: F.minTapTarget),
          padding: const EdgeInsets.all(F.s14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final dose in group)
                      Text(
                        dose.medicationName,
                        textDirection: nameDirection(dose.medicationName),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: F.minBodySize,
                          fontWeight: FontWeight.w600,
                          color: F.ink,
                          fontFamily: F.monoFamily,
                          fontFamilyFallback: F.monoFallback,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: F.s4),
                    Text(
                      [
                        arabicTime(at),
                        ruleLabelFor(group.first.doseScheduleId),
                      ].nonNulls.join(' — '),
                      style: TextStyle(fontSize: F.minTextSize, color: F.mutedDark),
                    ),
                    if (unconfirmed || dueNow) ...[
                      const SizedBox(height: F.s4),
                      Text(
                        unconfirmed ? 'لسه ما اتأكدتش' : 'معادها دلوقتي',
                        style: TextStyle(
                          fontSize: F.minTextSize,
                          fontWeight: FontWeight.w700,
                          color: F.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// علامة الصف على السكة: عقدة مرساة خضرا، ✓ لجرعة اتاخدت، نقطة ذهبية لجرعة لسه.
enum _RailNode { anchor, done, dose }
