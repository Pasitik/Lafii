/// Danger sign rule engine. First match wins.
///
/// Thresholds are CLAUDE.md section 7 verbatim. They, the titles and the
/// plain-language text below all need sign-off from the team midwife before
/// shipping. Do not change any of them without that sign-off.
library;

import 'package:visit_schema/visit_schema.dart';

export 'package:visit_schema/visit_schema.dart' show RuleInput, Assessment, Urgency;

/// Flip to true only once the team midwife has signed off every rule here.
const bool kMidwifeSignedOff = false;

/// Static description of one rule, for the "Protocol rule" section.
class RuleSpec {
  final String id;
  final String title;
  final Urgency urgency;
  final String threshold;
  final String recommendation;

  /// Why she is travelling, in words the mother understands.
  final String tellHer;

  const RuleSpec(this.id, this.title, this.urgency, this.threshold,
      this.recommendation, this.tellHer);
}

const ruleSpecs = <String, RuleSpec>{
  'R1': RuleSpec('R1', 'Convulsions in pregnancy', Urgency.emergency,
      'Fits or convulsions recorded as Yes.',
      'Refer now.',
      'She has had a fit, which is dangerous in pregnancy.'),
  'R2': RuleSpec('R2', 'Bleeding in pregnancy', Urgency.emergency,
      'Vaginal bleeding recorded as Yes.',
      'Refer now.',
      'Bleeding in pregnancy is a warning sign.'),
  'R3': RuleSpec('R3', 'Severe high blood pressure', Urgency.emergency,
      'Systolic 160 or higher, or diastolic 110 or higher.',
      'Refer now.',
      'Her blood pressure is very high.'),
  'R4': RuleSpec('R4', 'Signs of pre-eclampsia', Urgency.urgent,
      'Systolic 140 or higher, or diastolic 90 or higher, with severe '
          'headache, blurred vision, swelling, severe abdominal pain, or '
          'urine protein 2+ or more.',
      'Refer today.',
      'Her blood pressure is high and she has a warning sign.'),
  'R5': RuleSpec('R5', 'High blood pressure', Urgency.urgent,
      'Systolic 140 or higher, or diastolic 90 or higher, with no other sign.',
      'Refer today.',
      'Her blood pressure is high.'),
  'R6': RuleSpec('R6', 'Fever', Urgency.urgent,
      'Temperature 38.0 °C or higher.',
      'Refer today.',
      'She has a fever.'),
  'R7': RuleSpec('R7', 'Reduced fetal movement', Urgency.urgent,
      'Reduced fetal movement at 28 weeks or more.',
      'Refer today.',
      'The baby is moving less than it should.'),
  'R8': RuleSpec('R8', 'Severe anaemia', Urgency.urgent,
      'Severe pallor, or haemoglobin below 7 g/dL where measured.',
      'Refer today.',
      'Her blood is very low.'),
  'R9': RuleSpec('R9', 'Severe abdominal pain', Urgency.urgent,
      'Severe abdominal pain with no other sign.',
      'Refer today.',
      'She has severe pain in her belly.'),
  'R10': RuleSpec('R10', 'No danger signs recorded', Urgency.routine,
      'None of rules R1 to R9 matched the confirmed values.',
      'Schedule the next contact.',
      ''),
};

String _fmt(num v) =>
    v is double && v != v.roundToDouble() ? v.toStringAsFixed(1) : '${v.round()}';

String _bpText(int? sys, int? dia) {
  if (sys != null && dia != null) return 'Blood pressure $sys/$dia';
  if (sys != null) return 'Systolic blood pressure $sys';
  return 'Diastolic blood pressure $dia';
}

String _yes(DangerSign s) => '${s.label}: Yes';

Assessment _make(String id, List<String> triggers) {
  final spec = ruleSpecs[id]!;
  return Assessment(
    ruleId: spec.id,
    ruleTitle: spec.title,
    urgency: spec.urgency,
    triggeredBy: triggers,
    recommendation: spec.recommendation,
  );
}

/// Runs the rules on confirmed and manual values only.
///
/// [RuleInput] can only be built through `RuleInput.from`, which already
/// strips unconfirmed values, so nothing here needs to check provenance.
Assessment assess(RuleInput i) {
  final sys = i.systolic;
  final dia = i.diastolic;

  if (i.has(DangerSign.convulsions)) {
    return _make('R1', [_yes(DangerSign.convulsions)]);
  }
  if (i.has(DangerSign.vaginalBleeding)) {
    return _make('R2', [_yes(DangerSign.vaginalBleeding)]);
  }
  if ((sys != null && sys >= 160) || (dia != null && dia >= 110)) {
    return _make('R3', [_bpText(sys, dia)]);
  }

  final highBp = (sys != null && sys >= 140) || (dia != null && dia >= 90);
  if (highBp) {
    final extra = <String>[
      for (final s in const [
        DangerSign.headache,
        DangerSign.visualDisturbance,
        DangerSign.oedema,
        DangerSign.severeAbdominalPain,
      ])
        if (i.has(s)) _yes(s),
      if (i.urineProtein != null && i.urineProtein! >= 2)
        'Urine protein ${i.urineProtein}+',
    ];
    if (extra.isNotEmpty) return _make('R4', [_bpText(sys, dia), ...extra]);
    return _make('R5', [_bpText(sys, dia)]);
  }

  final t = i.temperatureC;
  if (t != null && t >= 38.0) {
    return _make('R6', ['Temperature ${_fmt(t)} °C']);
  }
  if (i.has(DangerSign.reducedFetalMovement) && i.gestationalWeeks >= 28) {
    return _make('R7', [
      _yes(DangerSign.reducedFetalMovement),
      '${i.gestationalWeeks} weeks pregnant',
    ]);
  }
  final hb = i.haemoglobin;
  if (i.has(DangerSign.severePallor) || (hb != null && hb < 7)) {
    return _make('R8', [
      if (i.has(DangerSign.severePallor)) _yes(DangerSign.severePallor),
      if (hb != null && hb < 7) 'Haemoglobin ${_fmt(hb)} g/dL',
    ]);
  }
  if (i.has(DangerSign.severeAbdominalPain)) {
    return _make('R9', [_yes(DangerSign.severeAbdominalPain)]);
  }
  return _make('R10', const []);
}

/// WHO 2016 eight-contact schedule, in gestational weeks.
/// Needs midwife sign-off alongside the rules.
const ancContactWeeks = [12, 20, 26, 30, 34, 36, 38, 40];

/// Next routine contact date after a visit at [gestationalWeeks].
/// Returns the gestational week of that contact as well, for the caption.
({DateTime date, int atWeeks}) nextContact(DateTime visitDate, int gestationalWeeks) {
  final next = ancContactWeeks.firstWhere((w) => w > gestationalWeeks,
      orElse: () => gestationalWeeks + 1);
  final days = (next - gestationalWeeks) * 7;
  final d = DateTime(visitDate.year, visitDate.month, visitDate.day + days);
  return (date: d, atWeeks: next);
}
