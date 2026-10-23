import 'package:card_codec/card_codec.dart';
import 'package:rules/rules.dart' as rules;
import 'package:visit_schema/visit_schema.dart';

/// Why she was referred, rebuilt on the receiving phone from the card.
///
/// The card carries only values the referring officer confirmed, and the
/// rule that fired. Running the same deterministic rule engine on those
/// values gives the same "Because you recorded" list the officer saw. If the
/// result does not match the rule on the card (an older app version, or a
/// changed card), [triggers] is null and the screen says so instead of
/// showing a list that might be wrong.
class CardFindings {
  final List<String>? triggers;
  final String ruleTitle;
  const CardFindings(this.triggers, this.ruleTitle);
}

CardFindings findingsFromCard(ReferralCard c) {
  // Same order as DangerSign in visit_schema and packSigns in card_codec.
  Field<TriState> sign(int i) => switch (i < c.signs.length ? c.signs[i] : 0) {
        1 => Field.confirmed(TriState.yes),
        2 => Field.confirmed(TriState.no),
        _ => Field.missing(),
      };
  Field<T> f<T>(T? v) => v == null ? Field<T>.missing() : Field<T>.confirmed(v);

  final visit = AncVisit(
    id: c.referralId,
    patientId: c.patientId,
    pregnancyId: c.patientId,
    visitDate: c.issuedAt,
    contactNumber: c.contactNumber,
    systolic: f(c.systolic),
    diastolic: f(c.diastolic),
    temperatureC: f(c.temperatureC),
    convulsions: sign(0),
    vaginalBleeding: sign(1),
    headache: sign(2),
    visualDisturbance: sign(3),
    oedema: sign(4),
    severeAbdominalPain: sign(5),
    fever: sign(6),
    reducedFetalMovement: sign(7),
    severePallor: sign(8),
    urineProtein: c.urineProtein == null ? null : Field.confirmed(c.urineProtein!),
    haemoglobin: c.haemoglobin == null ? null : Field.confirmed(c.haemoglobin!),
  );
  final pregnancy = Pregnancy(
      id: c.patientId,
      patientId: c.patientId,
      gravida: c.gravida,
      para: c.para,
      gestationalWeeks: c.gestationalWeeks);

  final a = rules.assess(RuleInput.from(visit, pregnancy));
  final title = rules.ruleSpecs[c.ruleId]?.title ?? c.ruleId;
  return CardFindings(a.ruleId == c.ruleId ? a.triggeredBy : null, title);
}
