import 'package:flutter/material.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'chase.dart';
import 'find.dart';
import 'report.dart';
import 'scan_flows.dart';
import 'setup.dart';
import 'visit.dart';

/// 02 Home. Never empty: referrals to chase, then women due this week.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = s.officer!;
    final open = s.openReferrals;
    final due = s.dueThisWeek;

    return AppScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${o.facility} · ${o.name}', style: T.ui(14)),
            Text(longDay(s.now), style: T.display(24)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (open.isNotEmpty) ...[
            SectionTitle(
              'Referrals not yet confirmed',
              trailing: open.length > 2
                  ? InkWell(
                      onTap: () => _push(context, const ChaseScreen()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('See all ${open.length}',
                            style: T.ui(14, w: FontWeight.w500, color: C.navy).copyWith(
                                decoration: TextDecoration.underline)),
                      ),
                    )
                  : null,
            ),
            ListCard(children: [
              for (final r in open.take(2)) _ReferralRow(r, s),
            ]),
            const SizedBox(height: 20),
          ],
          SectionTitle('Due this week · ${due.length}'),
          ListCard(children: [
            if (due.isEmpty)
              const PlainRow('No visits due this week')
            else
              for (final d in due) _DueRow(d, s),
          ]),
          const SizedBox(height: 20),
          ListCard(children: [
            ChevronRow(
              title: 'Register a new woman',
              meta: 'First visit, not yet on this phone',
              onTap: () => _push(context, const RegisterScreen()),
            ),
            ChevronRow(
              title: '${monthName(s.now.month)} report',
              meta: 'Register lines and monthly figures',
              onTap: () => _push(context, const ReportScreen()),
            ),
            if (open.length <= 2)
              ChevronRow(
                title: 'Not yet arrived',
                meta: 'Scan an acknowledgement to close a referral',
                onTap: () => _push(context, const ChaseScreen()),
              ),
            ChevronRow(
              title: 'Settings',
              meta: 'Name, facility, refer or receive',
              onTap: () => _push(context, const SetupScreen(editing: true)),
            ),
          ]),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Scan card', onPressed: () => scanCardFromHome(context)),
        SecondaryButton('Find by name', onPressed: () => _push(context, const FindScreen())),
      ]),
    );
  }
}

void _push(BuildContext context, Widget w) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => w));

class _ReferralRow extends StatelessWidget {
  const _ReferralRow(this.r, this.s);
  final Referral r;
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final p = s.patients[r.patientId]!;
    return UrgencyEdge(
      urgency: r.urgency,
      child: InkWell(
        onTap: () => _push(context, const ChaseScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName, style: T.ui(15, w: FontWeight.w600, color: C.strong)),
                    Text('${urgencyWord(r.urgency)} · $kReferralDestination',
                        style: T.ui(13, w: FontWeight.w500, color: C.urgency(r.urgency))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(elapsedDays(r.raisedAt, s.now), style: T.ui(14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow(this.d, this.s);
  final DueItem d;
  final AppState s;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openVisitFor(context, d.patient),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.patient.fullName,
                      style: T.ui(15, w: FontWeight.w600, color: C.strong)),
                  Text(
                      '${d.patient.community} · ${d.pregnancy.gestationalWeeks} weeks · '
                      'visit ${d.nextContactNumber}',
                      style: T.ui(13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(dueWhen(d.due, s.now), style: T.ui(14, w: FontWeight.w500, color: C.navy)),
          ],
        ),
      ),
    );
  }
}
