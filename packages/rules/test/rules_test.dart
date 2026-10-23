import 'package:rules/rules.dart';
import 'package:test/test.dart';
import 'package:visit_schema/visit_schema.dart';

AncVisit _visit() => AncVisit(
      id: 'v1',
      patientId: 'p1',
      pregnancyId: 'g1',
      visitDate: DateTime(2026, 10, 17),
      contactNumber: 4,
    );

Assessment _run(void Function(AncVisit v) setup, {int weeks = 32}) {
  final v = _visit();
  setup(v);
  final preg = Pregnancy(
      id: 'g1', patientId: 'p1', gravida: 2, para: 1, gestationalWeeks: weeks);
  return assess(RuleInput.from(v, preg));
}

Field<TriState> get y => Field.manual(TriState.yes);

void main() {
  test('R1 convulsions is an emergency', () {
    final a = _run((v) => v.convulsions = y);
    expect(a.ruleId, 'R1');
    expect(a.urgency, Urgency.emergency);
    expect(a.triggeredBy, ['Fits or convulsions: Yes']);
  });

  test('R2 vaginal bleeding is an emergency', () {
    final a = _run((v) => v.vaginalBleeding = y);
    expect(a.ruleId, 'R2');
    expect(a.urgency, Urgency.emergency);
    expect(a.triggeredBy, ['Vaginal bleeding: Yes']);
  });

  test('R3 severe blood pressure is an emergency', () {
    final a = _run((v) => v
      ..systolic = Field.manual(162)
      ..diastolic = Field.manual(100));
    expect(a.ruleId, 'R3');
    expect(a.urgency, Urgency.emergency);
    expect(a.triggeredBy, ['Blood pressure 162/100']);

    final d = _run((v) => v.diastolic = Field.confirmed(110));
    expect(d.ruleId, 'R3');
    expect(d.triggeredBy, ['Diastolic blood pressure 110']);
  });

  test('R4 high blood pressure with headache is suspected pre-eclampsia', () {
    final a = _run((v) => v
      ..systolic = Field.manual(140)
      ..diastolic = Field.manual(95)
      ..headache = y);
    expect(a.ruleId, 'R4');
    expect(a.urgency, Urgency.urgent);
    expect(a.ruleTitle, 'Signs of pre-eclampsia');
    expect(a.triggeredBy, ['Blood pressure 140/95', 'Severe headache: Yes']);
  });

  test('R4 also fires on urine protein 2+', () {
    final a = _run((v) => v
      ..systolic = Field.manual(138)
      ..diastolic = Field.manual(92)
      ..urineProtein = Field.manual(2));
    expect(a.ruleId, 'R4');
    expect(a.triggeredBy, ['Blood pressure 138/92', 'Urine protein 2+']);
  });

  test('R5 high blood pressure alone is urgent', () {
    final a = _run((v) => v
      ..systolic = Field.manual(145)
      ..diastolic = Field.manual(85)
      ..headache = Field.manual(TriState.no));
    expect(a.ruleId, 'R5');
    expect(a.urgency, Urgency.urgent);
    expect(a.triggeredBy, ['Blood pressure 145/85']);
  });

  test('R6 fever is urgent', () {
    final a = _run((v) => v.temperatureC = Field.manual(38.0));
    expect(a.ruleId, 'R6');
    expect(a.urgency, Urgency.urgent);
    expect(a.triggeredBy, ['Temperature 38 °C']);
  });

  test('R7 reduced fetal movement only from 28 weeks', () {
    final a = _run((v) => v.reducedFetalMovement = y, weeks: 28);
    expect(a.ruleId, 'R7');
    expect(a.urgency, Urgency.urgent);
    expect(a.triggeredBy, ['Reduced fetal movement: Yes', '28 weeks pregnant']);

    final early = _run((v) => v.reducedFetalMovement = y, weeks: 26);
    expect(early.ruleId, 'R10');
  });

  test('R8 severe pallor or haemoglobin below 7 is urgent', () {
    final a = _run((v) => v.haemoglobin = Field.manual(6.5));
    expect(a.ruleId, 'R8');
    expect(a.urgency, Urgency.urgent);
    expect(a.triggeredBy, ['Haemoglobin 6.5 g/dL']);

    final p = _run((v) => v.severePallor = y);
    expect(p.ruleId, 'R8');
    expect(p.triggeredBy, ['Severe pallor: Yes']);
  });

  test('R9 severe abdominal pain alone is urgent', () {
    final a = _run((v) => v.severeAbdominalPain = y);
    expect(a.ruleId, 'R9');
    expect(a.urgency, Urgency.urgent);
    expect(a.triggeredBy, ['Severe abdominal pain: Yes']);
  });

  test('R10 nothing triggered is routine', () {
    final a = _run((v) => v
      ..systolic = Field.manual(112)
      ..diastolic = Field.manual(70)
      ..headache = Field.manual(TriState.no));
    expect(a.ruleId, 'R10');
    expect(a.urgency, Urgency.routine);
    expect(a.triggeredBy, isEmpty);
  });

  test('first match wins: convulsions outrank blood pressure', () {
    final a = _run((v) => v
      ..systolic = Field.manual(170)
      ..convulsions = y);
    expect(a.ruleId, 'R1');
  });

  test('an extracted field does not trigger a rule', () {
    final a = _run((v) => v
      ..convulsions = Field.extracted(TriState.yes)
      ..systolic = Field.extracted(170)
      ..diastolic = Field.extracted(115));
    expect(a.ruleId, 'R10');
    expect(a.urgency, Urgency.routine);
  });

  test('next contact follows the eight-contact schedule', () {
    final n = nextContact(DateTime(2026, 10, 17), 22);
    expect(n.atWeeks, 26);
    expect(n.date, DateTime(2026, 11, 14));
  });
}
