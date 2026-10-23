import 'package:flutter/material.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'scan_flows.dart';

/// 13 Not yet arrived (7.1, 7.4, 7.5). Emergency before Urgent, then oldest.
/// Days elapsed is plain text, never a badge.
class ChaseScreen extends StatelessWidget {
  const ChaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final open = s.openReferrals;
    return AppScreen(
      header: ScreenHeader(
        title: 'Not yet arrived',
        sub: Text('Most serious first, then oldest', style: T.ui(14)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Every referral you issued has been acknowledged.', style: T.bodyText),
            ),
          for (final r in open) _ChaseRow(r, s),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Scan an acknowledgement', onPressed: () => scanAcknowledgement(context)),
      ]),
    );
  }
}

class _ChaseRow extends StatelessWidget {
  const _ChaseRow(this.r, this.s);
  final Referral r;
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final p = s.patients[r.patientId]!;
    final finding = s.outcomes[r.visitId]?.assessment.ruleTitle ?? r.ruleId;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: UrgencyEdge(
        urgency: r.urgency,
        child: Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(p.fullName, style: T.ui(16, w: FontWeight.w600, color: C.strong))),
                Text(elapsedDays(r.raisedAt, s.now), style: T.ui(15, color: C.strong)),
              ]),
              const SizedBox(height: 4),
              Text('${urgencyWord(r.urgency)} · $finding',
                  style: T.ui(13, w: FontWeight.w600, color: C.urgency(r.urgency))),
              const SizedBox(height: 4),
              Text('$kReferralDestination · ${p.community} · ${r.id.substring(0, 3)} ${r.id.substring(3)}',
                  style: T.ui(13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 19 Referral closed (7.1, 7.2). Same screen whether the acknowledgement
/// was scanned from the hospital phone or from her card.
class LoopClosedScreen extends StatelessWidget {
  const LoopClosedScreen({super.key, required this.referral});
  final Referral referral;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.patients[referral.patientId]!;
    final arrived = referral.arrivedAt!;
    final o = s.outcomes[referral.visitId];
    return AppScreen(
      header: ScreenHeader(
        eyebrow: Text('Acknowledgement scanned', style: T.ui(14, w: FontWeight.w600, color: C.green)),
        title: '${p.fullName} arrived',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListCard(children: [
            KvRow('Arrived', '${dayMonthYear(arrived)} · ${clock(arrived)}'),
            KvRow('Outcome', referral.outcomeNote ?? 'Not recorded'),
            KvRow('Follow-up at CHPS',
                referral.followUpDate == null ? 'Not set' : dayMonthYear(referral.followUpDate!)),
            KvRow('Received at', referral.arrivedFacility ?? kReferralDestination),
            if (o?.receivedBy != null) KvRow('Confirmed by', o!.receivedBy!),
            if (o?.receiverPhone != null) KvRow('Their phone', showPhone(o!.receiverPhone!)),
          ]),
          const SizedBox(height: 16),
          Text(
            referral.followUpDate == null
                ? 'Removed from your unconfirmed list.'
                : 'Removed from your unconfirmed list. The follow-up is added to your due list.',
            style: T.ui(14, height: 1.5),
          ),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Back to home', onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ]),
    );
  }
}
