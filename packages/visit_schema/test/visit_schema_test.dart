import 'package:test/test.dart';
import 'package:visit_schema/visit_schema.dart';

AncVisit _visit() => AncVisit(
      id: 'v1',
      patientId: 'p1',
      pregnancyId: 'g1',
      visitDate: DateTime(2026, 10, 17),
      contactNumber: 4,
    );

Pregnancy _preg() =>
    Pregnancy(id: 'g1', patientId: 'p1', gravida: 2, para: 1, gestationalWeeks: 32);

void main() {
  group('RuleInput provenance boundary', () {
    test('extracted values are treated as missing', () {
      final v = _visit()
        ..systolic = Field.extracted(170)
        ..convulsions = Field.extracted(TriState.yes);
      final input = RuleInput.from(v, _preg());
      expect(input.systolic, isNull);
      expect(input.sign(DangerSign.convulsions), TriState.notAsked);
      expect(
        input.notUsed.map((n) => n.text),
        containsAll([
          'Systolic blood pressure: not confirmed',
          'Fits or convulsions: not confirmed',
        ]),
      );
    });

    test('confirmed and manual values pass through', () {
      final v = _visit()
        ..systolic = Field.confirmed(140)
        ..diastolic = Field.manual(95)
        ..headache = Field.manual(TriState.yes);
      final input = RuleInput.from(v, _preg());
      expect(input.systolic, 140);
      expect(input.diastolic, 95);
      expect(input.has(DangerSign.headache), isTrue);
    });

    test('unconfirming a value removes it from the rules', () {
      final f = Field.manual(140)..unconfirm();
      expect(f.usableByRules, isFalse);
      f.confirm();
      expect(f.usableByRules, isTrue);
    });
  });

  test('visit JSON round trip keeps provenance', () {
    final v = _visit()
      ..systolic = Field.extracted(140)
      ..haemoglobin = Field.confirmed(10.5)
      ..oedema = Field.manual(TriState.no);
    final back = AncVisit.fromJson(v.toJson());
    expect(back.systolic.provenance, Provenance.extracted);
    expect(back.haemoglobin!.value, 10.5);
    expect(back.oedema.value, TriState.no);
    expect(back.fever.provenance, Provenance.missing);
  });

  group('mergeEventLogs', () {
    ClinicalEvent e(String id, int minute) => ClinicalEvent(
        id: id, at: DateTime(2026, 10, 17, 10, minute), kind: 'obs', entityId: 'v1');

    test('clinical events are never deleted on merge', () {
      final local = [e('a', 1), e('b', 2)];
      final remote = [e('b', 2), e('c', 3)];
      final merged = mergeEventLogs(local, remote);
      expect(merged.map((x) => x.id), ['a', 'b', 'c']);
      expect(mergeEventLogs(local, []).length, 2);
      expect(mergeEventLogs([], remote).length, 2);
    });
  });
}
