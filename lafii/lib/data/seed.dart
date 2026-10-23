import 'package:rules/rules.dart' as rules;
import 'package:visit_schema/visit_schema.dart';

import '../format.dart';
import 'app_state.dart';

/// Demo records for the judging run. Real Northern Ghanaian names and West
/// Mamprusi settlements (CLAUDE.md section 11), including one deliberate
/// near-duplicate pair for the resolver: Fati Alhassan and Fati Alhasan.
void seedDemo(AppState s) {
  final today = dateOnly(s.now);
  DateTime ago(int days) => today.subtract(Duration(days: days)).add(const Duration(hours: 10));
  DateTime ahead(int days) => today.add(Duration(days: days));

  Patient patient(String g, String f, String c, int by, [String? phone]) {
    final p = Patient(
        id: s.newId(), givenName: g, familyName: f, community: c, birthYear: by, phone: phone);
    s.putPatient(p);
    return p;
  }

  Pregnancy pregnancy(Patient p, int weeks, int gravida, int para) {
    final g = Pregnancy(
        id: s.newId(), patientId: p.id, gravida: gravida, para: para, gestationalWeeks: weeks);
    s.putPregnancy(g);
    return g;
  }

  /// Earlier routine contacts, the last of which sets the next due date.
  AncVisit history(Patient p, Pregnancy g, int count, {DateTime? nextDue, int lastDaysAgo = 28}) {
    late AncVisit last;
    for (var i = 0; i < count; i++) {
      final when = ago(lastDaysAgo + (count - 1 - i) * 42);
      final v = AncVisit(
        id: s.newId(),
        patientId: p.id,
        pregnancyId: g.id,
        visitDate: when,
        contactNumber: i + 1,
        systolic: Field.manual(108 + i * 2),
        diastolic: Field.manual(68 + i),
        weightKg: Field.manual(58.0 + i),
        headache: Field.manual(TriState.no),
        vaginalBleeding: Field.manual(TriState.no),
        convulsions: Field.manual(TriState.no),
      );
      s.saveVisit(v);
      final a = rules.assess(RuleInput.from(v, g));
      s.putOutcome(VisitOutcome(
        visitId: v.id,
        assessment: a,
        notUsed: const [],
        decision: Decision.routine,
        nextContact: i == count - 1 ? nextDue : when.add(const Duration(days: 42)),
      ));
      last = v;
    }
    return last;
  }

  void openReferral(Patient p, Pregnancy g, int contacts, int daysAgo,
      void Function(AncVisit v) findings) {
    final v = history(p, g, contacts, lastDaysAgo: daysAgo);
    findings(v);
    s.saveVisit(v);
    final a = rules.assess(RuleInput.from(v, g));
    final r = Referral(
      id: _codes[s.referrals.length % _codes.length],
      patientId: p.id,
      visitId: v.id,
      ruleId: a.ruleId,
      urgency: a.urgency,
      raisedAt: ago(daysAgo),
      raisedBy: s.officer!.name,
    );
    s.putReferral(r);
    s.putOutcome(VisitOutcome(
      visitId: v.id,
      assessment: a,
      notUsed: const [],
      decision: Decision.referred,
      referralId: r.id,
    ));
  }

  // Due this week.
  final fati = patient('Fati', 'Alhassan', 'Kpasenkpe', 1998, '0244174417');
  history(fati, pregnancy(fati, 32, 3, 2), 3, nextDue: ahead(0));

  final memunatu = patient('Memunatu', 'Iddrisu', 'Wulugu', 2000, '0209921356');
  history(memunatu, pregnancy(memunatu, 18, 1, 0), 1, nextDue: ahead(0));

  final ayishetu = patient('Ayishetu', 'Sulemana', 'Kpasenkpe', 2002);
  history(ayishetu, pregnancy(ayishetu, 36, 2, 1), 5, nextDue: ahead(1));

  final zulaiha = patient('Zulaiha', 'Mohammed', 'Kpasenkpe', 2003);
  history(zulaiha, pregnancy(zulaiha, 24, 1, 0), 2, nextDue: ahead(3));

  final rukaya = patient('Rukaya', 'Alhassan', 'Wulugu', 1996, '0551407783');
  history(rukaya, pregnancy(rukaya, 30, 4, 3), 4, nextDue: ahead(4));

  final salamatu = patient('Salamatu', 'Baba', 'Janga', 1999);
  history(salamatu, pregnancy(salamatu, 26, 2, 1), 3, nextDue: ahead(6));

  // Near duplicate of Fati Alhassan, older record, one visit.
  final fati2 = patient('Fati', 'Alhasan', 'Kpasenkpe', 1999);
  history(fati2, pregnancy(fati2, 14, 3, 2), 1, nextDue: ahead(30), lastDaysAgo: 220);

  // Referrals not yet confirmed.
  final abibata = patient('Abibata', 'Fuseini', 'Janga', 1995);
  openReferral(abibata, pregnancy(abibata, 34, 5, 4), 4, 4,
      (v) => v.vaginalBleeding = Field.manual(TriState.yes));

  final damata = patient('Damata', 'Yakubu', 'Loagri', 1997);
  openReferral(damata, pregnancy(damata, 29, 3, 2), 3, 6, (v) {
    v.haemoglobin = Field.manual(6.4);
    v.severePallor = Field.manual(TriState.yes);
  });

  final sanatu = patient('Sanatu', 'Abdulai', 'Nasia', 1993);
  openReferral(sanatu, pregnancy(sanatu, 31, 2, 1), 4, 1, (v) {
    v.systolic = Field.manual(146);
    v.diastolic = Field.manual(92);
  });

  final hawabu = patient('Hawabu', 'Fuseini', 'Yagaba', 2001);
  history(hawabu, pregnancy(hawabu, 20, 1, 0), 2, nextDue: ahead(12));
}

const _codes = ['H3W9TB', 'M6RX2D', 'Q4KP8N', 'T7CJ5V'];
