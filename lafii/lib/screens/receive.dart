import 'package:card_codec/card_codec.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../data/card_findings.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'scan_flows.dart';
import 'setup.dart';

/// Receive-mode home. Scan first.
class ReceiveHomeScreen extends StatelessWidget {
  const ReceiveHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.receivedList;
    return AppScreen(
      header: Container(
        color: C.navy,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.officer!.facility} · ${s.officer!.name}', style: T.ui(14, color: C.surface)),
            Text(longDay(s.now), style: T.display(24, color: C.surface)),
          ],
        ),
      ),
      bodyPadding: const EdgeInsets.fromLTRB(Sp.page, 20, Sp.page, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Cards read on this phone'),
          ListCard(children: [
            if (list.isEmpty)
              const PlainRow('None yet. Scan the card she carries.')
            else
              for (final r in list)
                UrgencyEdge(
                  urgency: Urgency.values[r.card.urgency],
                  child: InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => r.arrivedAt == null
                                ? ArrivalScreen(received: r)
                                : AcknowledgementScreen(received: r))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 12, 14, 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r.card.givenName} ${r.card.familyName}',
                                style: T.ui(15, w: FontWeight.w600, color: C.strong)),
                            Text(
                                '${urgencyWord(Urgency.values[r.card.urgency])} · '
                                '${groupCode(r.card.referralId)}',
                                style: T.ui(13,
                                    w: FontWeight.w500,
                                    color: C.urgency(Urgency.values[r.card.urgency]))),
                          ]),
                        ),
                        Text(r.arrivedAt == null ? 'Not confirmed' : 'Arrived ${clock(r.arrivedAt!)}',
                            style: T.ui(14)),
                      ]),
                    ),
                  ),
                ),
          ]),
          const SizedBox(height: 20),
          ListCard(children: [
            ChevronRow(
              title: 'Settings',
              meta: 'Name, facility, refer or receive',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SetupScreen(editing: true))),
            ),
          ]),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Scan arriving card', height: 56, onPressed: () => scanArrivingCard(context)),
      ]),
    );
  }
}

const _signLabels = [
  'Fits or convulsions',
  'Vaginal bleeding',
  'Severe headache',
  'Blurred vision',
  'Swelling of face or hands',
  'Severe abdominal pain',
  'Fever',
  'Reduced fetal movement',
  'Severe pallor',
];

/// 11 Arriving patient, and 18 Signature not valid. Read from her card with
/// no network and nothing synced in advance (6.2). One tap to confirm (6.3).
class ArrivalScreen extends StatelessWidget {
  const ArrivalScreen({super.key, required this.received, this.actions});
  final ReceivedReferral received;

  /// Replaces "Confirm arrival" when the card is read on a refer-mode phone.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = received.card;
    final valid = received.signatureValid;
    final urgency = Urgency.values[c.urgency];
    final age = c.birthYear == null ? null : c.issuedAt.year - c.birthYear!;
    final findings = findingsFromCard(c);

    final rows = <KvRow>[
      KvRow('Blood pressure',
          c.systolic == null && c.diastolic == null
              ? 'Missing'
              : '${c.systolic ?? 'Missing'}/${c.diastolic ?? 'Missing'}'),
      if (c.temperatureC != null) KvRow('Temperature', '${num1(c.temperatureC!)} °C'),
      if (c.urineProtein != null)
        KvRow('Urine protein', c.urineProtein == 0 ? 'Nil' : '${c.urineProtein}+'),
      for (var i = 0; i < c.signs.length && i < _signLabels.length; i++)
        if (c.signs[i] == 1) KvRow(_signLabels[i], 'Yes'),
      KvRow('Weeks pregnant', '${c.gestationalWeeks}'),
      KvRow('Gravida / para', '${c.gravida} / ${c.para}'),
      KvRow('Visits this pregnancy', '${c.contactNumber}'),
      KvRow('Haemoglobin', c.haemoglobin == null ? 'Missing' : '${num1(c.haemoglobin!)} g/dL',
          valueColor: c.haemoglobin == null ? C.red : null),
      KvRow('Community', c.community),
    ];

    return AppScreen(
      header: Container(
        color: C.navy,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Sp.page, 14, Sp.page, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c.givenName} ${c.familyName}${age == null ? '' : ', $age'}',
              style: T.display(24, color: C.surface)),
          const SizedBox(height: 6),
          Text('Referral ${groupCode(c.referralId)} · from ${c.officer}, ${c.fromFacility}',
              style: T.ui(14, color: C.surface)),
          if (c.officerPhone != null) ...[
            const SizedBox(height: 2),
            Text('Officer’s phone ${showPhone(c.officerPhone!)}',
                style: T.ui(14, w: FontWeight.w600, color: C.surface)),
          ],
        ]),
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: valid ? C.greenBg : C.redBg,
            padding: const EdgeInsets.symmetric(horizontal: Sp.page, vertical: 12),
            child: valid
                ? Text('Signature valid · issued ${dayMonthYear(c.issuedAt)} ${clock(c.issuedAt)}',
                    style: T.ui(14, w: FontWeight.w600, color: C.greenDeep))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Signature not valid', style: T.ui(14, w: FontWeight.w600, color: C.red)),
                    const SizedBox(height: 2),
                    Text(
                        'This card may have been changed after it was issued. '
                        'Check her history with her directly.',
                        style: T.ui(13, color: C.bodyStrong, height: 1.45)),
                  ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.page, 16, Sp.page, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UrgencyEdge(
                  urgency: urgency,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(urgencyWord(urgency).toUpperCase(),
                          style: T.ui(13, w: FontWeight.w600, color: C.urgency(urgency))
                              .copyWith(letterSpacing: 0.52)),
                      Text(findings.ruleTitle, style: T.display(20)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(valid ? 'Referred because the officer recorded' : 'Referred because, per the card',
                    size: 15),
                if (findings.triggers == null)
                  Text(
                      'These values do not match rule ${c.ruleId} on the card. '
                      'Ask her what was found at the CHPS.',
                      style: T.ui(14, color: C.red, height: 1.5))
                else
                  ListCard(children: [for (final t in findings.triggers!) PlainRow(t)]),
                const SizedBox(height: 18),
                const SectionTitle('Everything on her card', size: 15),
                ListCard(children: rows),
                const SizedBox(height: 16),
                Text(
                    valid
                        ? 'Read from her card. Nothing was synced in advance.'
                        : 'Values are shown as read from the card. Treat them as unverified.',
                    style: T.ui(13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
      bottom: actions ?? BottomBar(children: [
        if (received.arrivedAt == null)
          PrimaryButton('Confirm arrival', height: 56, onPressed: () {
            s.confirmArrival(received);
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => AcknowledgementScreen(received: received)));
          })
        else
          PrimaryButton('Open acknowledgement',
              height: 56,
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => AcknowledgementScreen(received: received)))),
      ]),
    );
  }
}

/// 12 Acknowledgement (6.4, 6.5). The QR exists as soon as arrival is
/// confirmed; the outcome is optional and regenerates it.
class AcknowledgementScreen extends StatefulWidget {
  const AcknowledgementScreen({super.key, required this.received});
  final ReceivedReferral received;

  @override
  State<AcknowledgementScreen> createState() => _AcknowledgementScreenState();
}

class _AcknowledgementScreenState extends State<AcknowledgementScreen> {
  ReceivedReferral get r => widget.received;
  String? _qr;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final qr = await AppScope.read(context).ackQr(r);
    if (mounted) setState(() => _qr = qr);
  }

  void _set({String? outcome, DateTime? followUp}) {
    AppScope.read(context).setReceivedOutcome(r, outcome: outcome, followUp: followUp);
    _refresh();
  }

  Future<void> _pickDate() async {
    final s = AppScope.read(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: r.followUp ?? s.now.add(const Duration(days: 7)),
      firstDate: dateOnly(s.now),
      lastDate: s.now.add(const Duration(days: 180)),
    );
    if (picked != null) _set(outcome: r.outcome, followUp: picked);
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final c = r.card;
    return AppScreen(
      header: ScreenHeader(
        eyebrow: Text('Arrival confirmed · ${clock(r.arrivedAt!)}',
            style: T.ui(14, w: FontWeight.w600, color: C.green)),
        title: 'Add an outcome',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: 'Outcome',
            caption: 'Optional. Tap again to clear.',
            child: Segmented<String>(
              options: [for (final o in outcomeCodes.values) (o, o)],
              value: r.outcome,
              allowClear: true,
              fontSize: 14,
              onChanged: (o) => _set(outcome: o, followUp: r.followUp),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Follow-up at CHPS',
            child: Row(children: [
              Expanded(
                child: ValueBox(r.followUp == null ? 'Not set' : dayMonthYear(r.followUp!),
                    onTap: _pickDate,
                    style: T.ui(16, color: r.followUp == null ? C.muted : C.strong)),
              ),
              if (r.followUp != null) ...[
                const SizedBox(width: 10),
                SecondaryButton('Clear',
                    height: 48, onPressed: () => _set(outcome: r.outcome)),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          if (_qr != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: C.card,
                border: Border.all(color: C.border),
                borderRadius: BorderRadius.circular(Sp.radius),
              ),
              child: QrImageView(
                data: _qr!,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.navy),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: C.navy),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Acknowledgement for ${c.officer}. ${c.givenName} can show this on her card '
            'when she returns, or ${c.officer} can scan it here.',
            style: T.ui(13, height: 1.5),
          ),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Done', onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ]),
    );
  }
}
