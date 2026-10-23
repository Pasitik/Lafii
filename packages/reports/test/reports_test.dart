import 'package:reports/reports.dart';
import 'package:test/test.dart';
import 'package:visit_schema/visit_schema.dart';

final _patient = Patient(
    id: 'p1', givenName: 'Fati', familyName: 'Alhassan', community: 'Kpasenkpe', birthYear: 1998);
final _preg = Pregnancy(id: 'g1', patientId: 'p1', gravida: 3, para: 2, gestationalWeeks: 32);

AncVisit _visit({int contact = 4, int day = 17}) => AncVisit(
      id: 'v$contact$day',
      patientId: 'p1',
      pregnancyId: 'g1',
      visitDate: DateTime(2026, 10, day),
      contactNumber: contact,
    );

void main() {
  test('register line for a referred visit', () {
    final v = _visit()
      ..systolic = Field.manual(140)
      ..diastolic = Field.confirmed(95);
    final r = Referral(
        id: 'K7M4QP', patientId: 'p1', visitId: v.id, ruleId: 'R4',
        urgency: Urgency.urgent, raisedAt: v.visitDate, raisedBy: 'Amina Mahama');
    final line = registerLine(RegisterEntry(
        visit: v, patient: _patient, pregnancy: _preg, referral: r,
        referredTo: 'Walewale Hospital'));
    expect(line,
        '17/10 · Fati Alhassan · 28 · ANC4 · GA 32 · BP 140/95 · Ref: Walewale (K7M 4QP)');
  });

  test('unconfirmed values are written as Missing, never imputed', () {
    final v = _visit()
      ..systolic = Field.extracted(140)
      ..diastolic = Field.manual(90);
    final line = registerLine(RegisterEntry(
        visit: v, patient: _patient, pregnancy: _preg,
        nextContact: DateTime(2026, 11, 14)));
    expect(line, contains('BP Missing/90'));
    expect(line, endsWith('Next 14/11'));
  });

  test('monthly aggregate counts only the month', () {
    final visits = [
      _visit(contact: 1, day: 2),
      _visit(contact: 4, day: 17)..systolic = Field.manual(150),
      _visit(contact: 2)..visitDate = DateTime(2026, 9, 30),
    ];
    final rows = monthlyAggregate(year: 2026, month: 10, visits: visits, referrals: []);
    int value(String k) => rows.firstWhere((r) => r.element == k).value;
    expect(value('ANC attendances'), 2);
    expect(value('ANC registrants'), 1);
    expect(value('ANC 4th visit'), 1);
    expect(value('BP 140/90 or higher'), 1);
    expect(aggregateCsv(rows, period: '202610'), startsWith('Period,Data element,Value'));
  });
}
