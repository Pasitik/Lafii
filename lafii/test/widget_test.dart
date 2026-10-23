import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_codec/card_codec.dart';
import 'package:lafii/data/app_state.dart';
import 'package:lafii/data/card_findings.dart';
import 'package:lafii/data/seed.dart';
import 'package:lafii/main.dart';
import 'package:lafii/screens/confirm.dart';
import 'package:lafii/theme.dart';
import 'package:visit_schema/visit_schema.dart';

AppState _seeded() {
  final s = AppState(null, clock: () => DateTime(2026, 10, 17, 9, 41));
  s.saveOfficer(const Officer(
      name: 'Amina Mahama', zone: 'Kpasenkpe', facility: 'Kpasenkpe CHPS', mode: AppMode.refer,
      phone: '0244112233'));
  seedDemo(s);
  return s;
}

Widget _wrap(AppState s, Widget child) =>
    AppScope(state: s, child: MaterialApp(theme: buildTheme(), home: child));

void main() {
  testWidgets('home shows referrals to chase and women due', (tester) async {
    final s = _seeded();
    await tester.pumpWidget(LafiiApp(state: s));
    expect(find.text('Referrals not yet confirmed'), findsOneWidget);
    expect(find.text('Fati Alhassan'), findsOneWidget);
    expect(find.text('Scan card'), findsOneWidget);
    expect(find.text('Find by name'), findsOneWidget);
  });

  testWidgets('confirm screen has one Confirm per value and no confirm-all', (tester) async {
    final s = _seeded();
    final p = s.patients.values.firstWhere((p) => p.fullName == 'Fati Alhassan');
    final v = s.startVisit(p)
      ..systolic = Field.extracted(140)
      ..diastolic = Field.extracted(95)
      ..headache = Field.extracted(TriState.yes);
    await tester.pumpWidget(_wrap(s, ConfirmScreen(visit: v)));

    expect(find.text('Confirm'), findsNWidgets(3));
    expect(find.textContaining(RegExp('all', caseSensitive: false)), findsNothing);
    expect(find.text('3 of 3 values still need you · 7 missing'), findsOneWidget);

    await tester.tap(find.text('Confirm').first);
    await tester.pump();
    expect(find.text('Confirm'), findsNWidgets(2));
    expect(v.systolic.provenance, Provenance.confirmed);
  });

  testWidgets('a first-time woman can be registered from Home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = _seeded();
    final before = s.patients.length;
    await tester.pumpWidget(LafiiApp(state: s));

    await tester.scrollUntilVisible(find.text('Register a new woman'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Register a new woman'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Still needed: given name, family name, community'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Hawa');
    await tester.enterText(fields.at(1), 'Issahaku');
    await tester.tap(find.text('Choose her community'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another community'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Gbintiri');
    await tester.tap(find.text('Use this'));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(2), '22'); // age
    await tester.enterText(fields.at(3), '16'); // weeks
    await tester.enterText(fields.at(4), '1'); // gravida
    await tester.enterText(fields.at(5), '0'); // para
    await tester.pump();
    expect(find.textContaining('Still needed'), findsNothing);

    await tester.tap(find.text('Register and start visit'));
    await tester.pumpAndSettle();
    expect(s.patients.length, before + 1);
    expect(find.text('Antenatal visit 1'), findsOneWidget);
    expect(find.text('Hawa Issahaku · 22 · Gbintiri'), findsOneWidget);
  });

  test('extracted values do not trigger a referral; confirmed ones do', () {
    final s = _seeded();
    final p = s.patients.values.firstWhere((p) => p.fullName == 'Fati Alhassan');
    final v = s.startVisit(p)
      ..systolic = Field.extracted(150)
      ..diastolic = Field.extracted(100)
      ..headache = Field.extracted(TriState.yes);
    expect(s.assess(v).assessment.ruleId, 'R10');

    v.systolic.confirm();
    v.diastolic.confirm();
    v.headache.confirm();
    expect(s.assess(v).assessment.ruleId, 'R4');
  });

  test('speech fills values as extracted; they count only once confirmed', () {
    final s = _seeded();
    final p = s.patients.values.firstWhere((p) => p.fullName == 'Fati Alhassan');
    final v = s.startVisit(p);
    final notes = s.applySpeech(
        v, 'blood pressure one forty over ninety five she has a severe headache no bleeding no fits');
    expect(notes, isEmpty);
    expect(v.systolic.value, 140);
    expect(v.systolic.provenance, Provenance.extracted);
    expect(v.vaginalBleeding.value, TriState.no);
    expect(s.assess(v).assessment.ruleId, 'R10');

    v.systolic.confirm();
    v.diastolic.confirm();
    v.headache.confirm();
    expect(s.assess(v).assessment.ruleId, 'R4');
  });

  test('silence produces a note, not values', () {
    final s = _seeded();
    final p = s.patients.values.first;
    final v = s.startVisit(p);
    expect(s.applySpeech(v, ''), ['Nothing usable was heard. Enter the values by tap.']);
  });

  test('the hospital sees the same triggers the officer saw', () async {
    final s = _seeded();
    final p = s.patients.values.firstWhere((p) => p.fullName == 'Rukaya Alhassan');
    final v = s.startVisit(p)
      ..temperatureC = Field.manual(38.4)
      ..convulsions = Field.manual(TriState.no);
    final o = s.assess(v);
    expect(o.assessment.ruleId, 'R6');
    final r = await s.issueReferral(v);

    final d = await decodeReferral(s.outcomes[v.id]!.referralQr!);
    expect(d.signatureValid, isTrue);
    final f = findingsFromCard(d.card);
    expect(f.ruleTitle, 'Fever');
    expect(f.triggers, o.assessment.triggeredBy);
    expect(f.triggers, ['Temperature 38.4 °C']);
    expect(r.ruleId, 'R6');
  });

  test('pre-eclampsia triggers survive the card, including urine protein', () async {
    final s = _seeded();
    final p = s.patients.values.firstWhere((p) => p.fullName == 'Fati Alhassan');
    final v = s.startVisit(p)
      ..systolic = Field.manual(138)
      ..diastolic = Field.manual(92)
      ..urineProtein = Field.manual(2)
      ..headache = Field.manual(TriState.yes);
    final o = s.assess(v);
    await s.issueReferral(v);
    final d = await decodeReferral(s.outcomes[v.id]!.referralQr!);
    expect(findingsFromCard(d.card).triggers, o.assessment.triggeredBy);
    expect(o.assessment.triggeredBy,
        ['Blood pressure 138/92', 'Severe headache: Yes', 'Urine protein 2+']);
  });

  test('phone numbers travel on both cards', () async {
    final s = _seeded();
    final p = s.patients.values.firstWhere((p) => p.fullName == 'Fati Alhassan');
    final v = s.startVisit(p)
      ..systolic = Field.manual(140)
      ..diastolic = Field.manual(95)
      ..headache = Field.manual(TriState.yes);
    s.assess(v);
    final r = await s.issueReferral(v);
    final card = (await decodeReferral(s.outcomes[v.id]!.referralQr!)).card;
    expect(card.officerPhone, '0244112233');

    // The hospital reads it, confirms arrival and issues the acknowledgement.
    final h = AppState(null, clock: () => DateTime(2026, 10, 17, 11, 1))
      ..saveOfficer(const Officer(
          name: 'Rahinatu Seidu', zone: 'Maternity ward', facility: 'Walewale Hospital',
          mode: AppMode.receive, phone: '0209981234'));
    final rec = ReceivedReferral(card: card, signatureValid: true, scannedAt: h.now);
    h.storeReceived(rec);
    h.confirmArrival(rec);
    final ack = (await decodeAck(await h.ackQr(rec))).card;

    s.applyAck(ack);
    expect(s.outcomes[r.visitId]!.receivedBy, 'Rahinatu Seidu');
    expect(s.outcomes[r.visitId]!.receiverPhone, '0209981234');
  });

  test('chase list ranks emergency first, then oldest', () {
    final s = _seeded();
    final open = s.openReferrals;
    expect(open.first.urgency, Urgency.emergency);
    final urgent = open.where((r) => r.urgency == Urgency.urgent).toList();
    expect(urgent.first.raisedAt.isBefore(urgent.last.raisedAt), isTrue);
  });
}
