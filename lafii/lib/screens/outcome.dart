import 'package:card_codec/card_codec.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:reports/reports.dart';
import 'package:rules/rules.dart' as rules;
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';

void _home(BuildContext context) => Navigator.popUntil(context, (r) => r.isFirst);

String _signOff() => rules.kMidwifeSignedOff
    ? 'Signed off by the team midwife.'
    : 'Awaiting sign-off by the team midwife.';

/// Full-width finding banner. A banner, not a badge.
class _Banner extends StatelessWidget {
  const _Banner({required this.eyebrow, required this.title, required this.bg, required this.fg, this.titleColor});
  final String eyebrow;
  final String title;
  final Color bg;
  final Color fg;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: Sp.page, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(),
              style: T.ui(14, w: FontWeight.w600, color: fg).copyWith(letterSpacing: 0.56)),
          const SizedBox(height: 4),
          Text(title, style: T.display(26, color: titleColor ?? fg, height: 1.2)),
        ],
      ),
    );
  }
}

/// 08 Assessment (4.1 to 4.3). Finding in plain words, the exact inputs that
/// triggered it, the rule, and what was left out.
class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({super.key, required this.visit});
  final AncVisit visit;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = s.outcomes[visit.id]!;
    final a = o.assessment;
    final spec = rules.ruleSpecs[a.ruleId]!;
    final emergency = a.urgency == Urgency.emergency;

    return AppScreen(
      header: _Banner(
        eyebrow: emergency ? 'Emergency · refer now' : 'Urgent · refer today',
        title: a.ruleTitle,
        bg: emergency ? C.red : C.yellowBg,
        fg: emergency ? C.surface : C.yellowDeep,
      ),
      bodyPadding: const EdgeInsets.fromLTRB(Sp.page, 18, Sp.page, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Because you recorded', size: 15),
          ListCard(children: [for (final t in a.triggeredBy) PlainRow(t)]),
          const SizedBox(height: 18),
          const SectionTitle('Protocol rule', size: 15),
          Text('${spec.id}: ${spec.threshold} ${_signOff()}', style: T.ui(14, height: 1.5)),
          if (o.notUsed.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionTitle('Not used', size: 15),
            Text(o.notUsed.join('\n'), style: T.ui(14, height: 1.5)),
          ],
        ],
      ),
      bottom: BottomBar(children: [
        Expanded(
          flex: 10,
          child: SecondaryButton('I disagree',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DisagreeScreen(visit: visit)))),
        ),
        Expanded(
          flex: 14,
          child: PrimaryButton('Issue referral', onPressed: () async {
            await s.issueReferral(visit);
            if (!context.mounted) return;
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ReferralIssuedScreen(visit: visit)));
          }),
        ),
      ]),
    );
  }
}

const _reasons = [
  'Reading taken before she rested',
  'Value was recorded wrongly',
  'She is already under hospital care',
  'Other reason',
];

/// 09 Record disagreement (4.3). The officer decides; the rule is recorded
/// alongside.
class DisagreeScreen extends StatefulWidget {
  const DisagreeScreen({super.key, required this.visit});
  final AncVisit visit;

  @override
  State<DisagreeScreen> createState() => _DisagreeScreenState();
}

class _DisagreeScreenState extends State<DisagreeScreen> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide(bool refer) async {
    final s = AppScope.read(context);
    s.recordDisagreement(widget.visit, reason: _reason!, note: _note.text.trim(), refer: refer);
    if (refer) await s.issueReferral(widget.visit);
    if (!mounted) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => refer
                ? ReferralIssuedScreen(visit: widget.visit)
                : RoutineScreen(visit: widget.visit)));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _reason != null;
    return AppScreen(
      header: ScreenHeader(
        title: 'Why do you disagree?',
        sub: Text('Your judgement is recorded alongside the rule. You decide what happens next.',
            style: T.bodyText),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          for (final r in _reasons) ...[
            _ReasonOption(
              label: r,
              selected: r == _reason,
              onTap: () => setState(() => _reason = r),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          LabeledField(
            label: 'Note',
            child: TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              style: T.ui(15, color: C.strong, height: 1.45),
            ),
          ),
        ],
      ),
      bottom: BottomBar(children: [
        SecondaryButton('Refer anyway', fontSize: 14, onPressed: ready ? () => _decide(true) : null),
        PrimaryButton('Do not refer', onPressed: ready ? () => _decide(false) : null),
      ]),
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sp.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: Sp.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: selected ? C.infoTint : C.surface,
            border: Border.all(color: selected ? C.navy : C.input, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(Sp.radius),
          ),
          child: Text(label,
              style: T.ui(15, w: FontWeight.w500, color: selected ? C.navy : C.strong)),
        ),
      ),
    );
  }
}

/// 17 Routine outcome (4.4, 8.1). Also used when the officer decided not to
/// refer, with the banner saying so.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key, required this.visit});
  final AncVisit visit;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = s.outcomes[visit.id]!;
    final notReferred = o.decision == Decision.notReferred;
    final next = o.nextContact!;
    final g = s.pregnancies[visit.pregnancyId]!;
    final weeksAway = (daysBetween(visit.visitDate, next) / 7).round();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
      },
      child: AppScreen(
        header: notReferred
            ? _Banner(
                eyebrow: 'Not referred · your decision',
                title: o.assessment.ruleTitle,
                bg: C.infoTint,
                fg: C.navy)
            : const _Banner(
                eyebrow: 'Routine',
                title: 'No danger signs recorded',
                bg: C.greenBg,
                fg: C.greenDeep,
                titleColor: C.navy),
        bodyPadding: const EdgeInsets.fromLTRB(Sp.page, 18, Sp.page, 20),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notReferred) ...[
              Text('Your reason is recorded alongside rule ${o.assessment.ruleId}.',
                  style: T.ui(14, height: 1.5)),
              const SizedBox(height: 18),
            ],
            LabeledField(
              label: 'Next contact',
              caption: '$weeksAway week${weeksAway == 1 ? '' : 's'} from today, '
                  'by protocol for ${g.gestationalWeeks} weeks',
              child: ValueBox('${dayMonthYear(next)} · visit ${visit.contactNumber + 1}'),
            ),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Register line',
              child: _MonoCard(registerLine(s.registerEntry(visit))),
            ),
            if (o.notUsed.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionTitle('Not used in the assessment', size: 15),
              Text(o.notUsed.join('\n'), style: T.ui(14, height: 1.5)),
            ],
          ],
        ),
        bottom: BottomBar(children: [
          PrimaryButton('Finish visit', onPressed: () => _home(context)),
        ]),
      ),
    );
  }
}

class _MonoCard extends StatelessWidget {
  const _MonoCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.card,
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(Sp.radius),
        ),
        child: SelectableText(text, style: T.mono(13, height: 1.6)),
      );
}

/// 10 Referral issued (5.1 to 5.5). The code goes on her paper card; the
/// signed QR is scanned from this screen at the hospital.
class ReferralIssuedScreen extends StatelessWidget {
  const ReferralIssuedScreen({super.key, required this.visit});
  final AncVisit visit;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final o = s.outcomes[visit.id]!;
    final r = s.referrals[o.referralId]!;
    final p = s.patients[visit.patientId]!;
    final spec = rules.ruleSpecs[r.ruleId]!;
    final when = r.urgency == Urgency.emergency ? 'now' : 'today';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
      },
      child: AppScreen(
        header: ScreenHeader(
          context_: '${p.fullName} → $kReferralDestination',
          title: 'Write this code on her card',
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashedBox(
              width: 2,
              padding: const EdgeInsets.all(14),
              child: Text(groupCode(r.id),
                  textAlign: TextAlign.center,
                  style: T.mono(40, w: FontWeight.w700, color: C.navy, height: 1)
                      .copyWith(letterSpacing: 3.2)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: C.card,
                border: Border.all(color: C.border),
                borderRadius: BorderRadius.circular(Sp.radius),
              ),
              child: QrImageView(
                data: o.referralQr!,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.navy),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: C.navy),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The hospital scans this from your screen. It holds her essentials, '
              'signed on this phone, and needs no network.',
              style: T.ui(13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Callout(
              kind: CalloutKind.info,
              title: 'Tell ${p.givenName}',
              body: '${spec.tellHer} She should go to $kReferralDestination $when '
                  'and show this card at the front desk.',
            ),
          ],
        ),
        bottom: BottomBar(children: [
          PrimaryButton('Code written on the card', onPressed: () => _home(context)),
        ]),
      ),
    );
  }
}
