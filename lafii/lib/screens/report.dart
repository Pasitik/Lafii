import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reports/reports.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';

/// 14 Monthly report (8.1 to 8.4). Every figure comes from visits captured
/// on this phone.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  Future<void> _export(BuildContext context, AppState s) async {
    final now = s.now;
    final period = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final monthVisits = s.completedVisits
        .where((v) => v.visitDate.year == now.year && v.visitDate.month == now.month)
        .toList();
    final dir = await getTemporaryDirectory();
    final reg = File('${dir.path}/register_$period.csv')
      ..writeAsStringSync(registerCsv([for (final v in monthVisits) s.registerEntry(v)]));
    final agg = File('${dir.path}/anc_aggregate_$period.csv')
      ..writeAsStringSync(aggregateCsv(
          monthlyAggregate(
              year: now.year,
              month: now.month,
              visits: s.completedVisits,
              referrals: s.referrals.values.toList()),
          period: period));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(reg.path), XFile(agg.path)],
      subject: '${monthName(now.month)} ${now.year} register and ANC report',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = s.now;
    final visits = s.completedVisits;
    final monthCount =
        visits.where((v) => v.visitDate.year == now.year && v.visitDate.month == now.month).length;
    final today = visits.where((v) => dateOnly(v.visitDate) == dateOnly(now)).toList();
    final rows = monthlyAggregate(
        year: now.year, month: now.month, visits: visits, referrals: s.referrals.values.toList());

    return AppScreen(
      header: ScreenHeader(
        title: '${monthName(now.month)} report',
        sub: Text('Filled from the $monthCount visit${monthCount == 1 ? '' : 's'} you captured',
            style: T.ui(14)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle("Today's register lines", size: 15),
          if (today.isEmpty)
            Text('No visits finished today.', style: T.ui(14))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.card,
                border: Border.all(color: C.border),
                borderRadius: BorderRadius.circular(Sp.radius),
              ),
              child: SelectableText(
                today.map((v) => registerLine(s.registerEntry(v))).join('\n\n'),
                style: T.mono(13, height: 1.6),
              ),
            ),
          const SizedBox(height: 16),
          const SectionTitle('DHIMS2 data elements', size: 15),
          if (!kDhimsLabelsVerified)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Element names still to be checked against the DHIMS2 form.',
                  style: T.ui(13, color: C.muted)),
            ),
          ListCard(children: [
            for (final r in rows) KvRow(r.element, '${r.value}', mono: true),
          ]),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Export register and report', onPressed: () => _export(context, s)),
      ]),
    );
  }
}
