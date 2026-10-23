import 'dart:math';

import 'package:card_codec/card_codec.dart';
import 'package:extract/extract.dart' as ex;
import 'package:flutter/widgets.dart';
import 'package:reports/reports.dart';
import 'package:resolver/resolver.dart';
import 'package:rules/rules.dart' as rules;
import 'package:visit_schema/visit_schema.dart';

import '../format.dart';
import 'store.dart';

/// Every referral from a CHPS zone goes here in the MVP.
const kReferralDestination = 'Walewale Hospital';

/// Spoken visit summary: Vosk on the phone, then the extract package.
/// Turn off to demo the tap-only loop.
const kSpeechEnabled = true;

enum AppMode { refer, receive }

class Officer {
  final String name;
  final String zone;
  final String facility;
  final AppMode mode;

  /// Put on every referral or acknowledgement this phone issues, so the
  /// other end can call. Null only for phones set up before it was asked.
  final String? phone;

  const Officer({
    required this.name,
    required this.zone,
    required this.facility,
    required this.mode,
    this.phone,
  });

  Map<String, Object?> toJson() =>
      {'name': name, 'zone': zone, 'facility': facility, 'mode': mode.name, 'phone': phone};
  factory Officer.fromJson(Map<String, Object?> j) => Officer(
        name: j['name'] as String,
        zone: j['zone'] as String,
        facility: j['facility'] as String,
        mode: j['mode'] == 'receive' ? AppMode.receive : AppMode.refer,
        phone: j['phone'] as String?,
      );
}

enum Decision { referred, notReferred, routine }

/// What came out of a visit: the assessment, the officer's decision, and
/// the next contact or the referral.
class VisitOutcome {
  final String visitId;
  final Assessment assessment;
  final List<String> notUsed;
  Decision decision;
  DateTime? nextContact;
  int? nextContactWeeks;
  String? referralId;
  String? referralQr;

  /// From the acknowledgement: who confirmed her arrival and their phone.
  String? receivedBy;
  String? receiverPhone;

  VisitOutcome({
    required this.visitId,
    required this.assessment,
    required this.notUsed,
    required this.decision,
    this.nextContact,
    this.nextContactWeeks,
    this.referralId,
    this.referralQr,
    this.receivedBy,
    this.receiverPhone,
  });

  Map<String, Object?> toJson() => {
        'visitId': visitId,
        'assessment': assessment.toJson(),
        'notUsed': notUsed,
        'decision': decision.name,
        'nextContact': nextContact?.toIso8601String(),
        'nextContactWeeks': nextContactWeeks,
        'referralId': referralId,
        'referralQr': referralQr,
        'receivedBy': receivedBy,
        'receiverPhone': receiverPhone,
      };

  factory VisitOutcome.fromJson(Map<String, Object?> j) => VisitOutcome(
        visitId: j['visitId'] as String,
        assessment: Assessment.fromJson((j['assessment'] as Map).cast()),
        notUsed: (j['notUsed'] as List).cast<String>(),
        decision: Decision.values.byName(j['decision'] as String),
        nextContact:
            j['nextContact'] == null ? null : DateTime.parse(j['nextContact'] as String),
        nextContactWeeks: j['nextContactWeeks'] as int?,
        referralId: j['referralId'] as String?,
        referralQr: j['referralQr'] as String?,
        receivedBy: j['receivedBy'] as String?,
        receiverPhone: j['receiverPhone'] as String?,
      );
}

/// A referral card read on a receive-mode phone.
class ReceivedReferral {
  final ReferralCard card;
  final bool signatureValid;
  final DateTime scannedAt;
  DateTime? arrivedAt;
  String? outcome;
  DateTime? followUp;

  ReceivedReferral({
    required this.card,
    required this.signatureValid,
    required this.scannedAt,
    this.arrivedAt,
    this.outcome,
    this.followUp,
  });

  Map<String, Object?> toJson() => {
        'card': referralToMap(card),
        'signatureValid': signatureValid,
        'scannedAt': scannedAt.toIso8601String(),
        'arrivedAt': arrivedAt?.toIso8601String(),
        'outcome': outcome,
        'followUp': followUp?.toIso8601String(),
      };

  factory ReceivedReferral.fromJson(Map<String, Object?> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return ReceivedReferral(
      card: referralFromMap(j['card'] as Map),
      signatureValid: j['signatureValid'] as bool,
      scannedAt: DateTime.parse(j['scannedAt'] as String),
      arrivedAt: d('arrivedAt'),
      outcome: j['outcome'] as String?,
      followUp: d('followUp'),
    );
  }
}

class DueItem {
  final Patient patient;
  final Pregnancy pregnancy;
  final DateTime due;
  final int nextContactNumber;
  const DueItem(this.patient, this.pregnancy, this.due, this.nextContactNumber);
}

/// All app state. Held in memory; every change is written to the encrypted
/// store without awaiting, so the screen never waits (invariants 4 and 5).
class AppState extends ChangeNotifier {
  AppState(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Store? _store;
  final DateTime Function() _clock;
  final _rng = Random.secure();

  DateTime get now => _clock();

  Officer? officer;
  final patients = <String, Patient>{};
  final pregnancies = <String, Pregnancy>{}; // by pregnancy id
  final visits = <String, AncVisit>{};
  final referrals = <String, Referral>{};
  final outcomes = <String, VisitOutcome>{}; // by visit id
  final received = <String, ReceivedReferral>{}; // by referral id

  bool get isSetUp => officer != null;
  bool get isReceiveMode => officer?.mode == AppMode.receive;

  /// Records created on this phone. Nothing syncs in the MVP, so this is the
  /// number that would go when a sync path exists (story 9.5).
  int get pendingSyncCount =>
      patients.length + visits.length + referrals.length + received.length;

  // ---------------------------------------------------------------- loading

  Future<void> load() async {
    final s = _store;
    if (s == null) return;
    final all = await s.loadAll();
    for (final j in all['officer'] ?? const []) {
      officer = Officer.fromJson(j);
    }
    for (final j in all['patient'] ?? const []) {
      final x = Patient.fromJson(j);
      patients[x.id] = x;
    }
    for (final j in all['pregnancy'] ?? const []) {
      final x = Pregnancy.fromJson(j);
      pregnancies[x.id] = x;
    }
    for (final j in all['visit'] ?? const []) {
      final x = AncVisit.fromJson(j);
      visits[x.id] = x;
    }
    for (final j in all['referral'] ?? const []) {
      final x = Referral.fromJson(j);
      referrals[x.id] = x;
    }
    for (final j in all['outcome'] ?? const []) {
      final x = VisitOutcome.fromJson(j);
      outcomes[x.visitId] = x;
    }
    for (final j in all['received'] ?? const []) {
      final x = ReceivedReferral.fromJson(j);
      received[x.card.referralId] = x;
    }
  }

  String newId() {
    final t = now.microsecondsSinceEpoch.toRadixString(36);
    final r = List.generate(6, (_) => _rng.nextInt(36).toRadixString(36)).join();
    return '$t$r';
  }

  void _put(String kind, String id, Map<String, Object?> json) {
    _store?.put(kind, id, json);
  }

  void _event(String kind, String entityId, [Map<String, Object?> data = const {}]) {
    _store?.append(ClinicalEvent(
        id: newId(), at: now, kind: kind, entityId: entityId, data: data));
  }

  // ------------------------------------------------------------------ setup

  void saveOfficer(Officer o) {
    officer = o;
    _put('officer', 'me', o.toJson());
    notifyListeners();
  }

  // --------------------------------------------------------------- patients

  Patient registerPatient({
    required String givenName,
    required String familyName,
    required String community,
    int? birthYear,
    String? phone,
    required int gestationalWeeks,
    required int gravida,
    required int para,
  }) {
    final p = Patient(
      id: newId(),
      givenName: givenName,
      familyName: familyName,
      community: community,
      birthYear: birthYear,
      phone: phone,
    );
    final g = Pregnancy(
        id: newId(),
        patientId: p.id,
        gravida: gravida,
        para: para,
        gestationalWeeks: gestationalWeeks);
    putPatient(p);
    putPregnancy(g);
    _event('patient_registered', p.id);
    notifyListeners();
    return p;
  }

  void putPatient(Patient p) {
    patients[p.id] = p;
    _put('patient', p.id, p.toJson());
  }

  void putPregnancy(Pregnancy g) {
    pregnancies[g.id] = g;
    _put('pregnancy', g.id, g.toJson());
  }

  Pregnancy? pregnancyFor(String patientId) {
    Pregnancy? out;
    for (final g in pregnancies.values) {
      if (g.patientId == patientId) out = g;
    }
    return out;
  }

  List<AncVisit> visitsFor(String patientId) =>
      visits.values.where((v) => v.patientId == patientId).toList()
        ..sort((a, b) => a.visitDate.compareTo(b.visitDate));

  DateTime? lastContact(String patientId) {
    final v = visitsFor(patientId);
    return v.isEmpty ? null : v.last.visitDate;
  }

  List<Candidate> get candidates => [
        for (final p in patients.values) Candidate(p, lastContact(p.id)),
      ];

  List<Patient> duplicatesOf(Patient p) =>
      possibleDuplicates(p, patients.values.toList());

  // ----------------------------------------------------------------- visits

  /// Starts today's visit, or returns the one already started today.
  AncVisit startVisit(Patient p) {
    final g = pregnancyFor(p.id)!;
    final today = dateOnly(now);
    for (final v in visitsFor(p.id)) {
      if (dateOnly(v.visitDate) == today && outcomes[v.id] == null) return v;
    }
    final previous = visits.values.where((v) => v.pregnancyId == g.id).length;
    final v = AncVisit(
      id: newId(),
      patientId: p.id,
      pregnancyId: g.id,
      visitDate: now,
      contactNumber: previous + 1,
    );
    saveVisit(v);
    _event('visit_started', v.id);
    return v;
  }

  /// Called on every change. Scalar snapshot, last writer wins.
  void saveVisit(AncVisit v) {
    visits[v.id] = v;
    _put('visit', v.id, v.toJson());
    notifyListeners();
  }

  void putOutcome(VisitOutcome o) {
    outcomes[o.visitId] = o;
    _put('outcome', o.visitId, o.toJson());
  }

  void putReferral(Referral r) {
    referrals[r.id] = r;
    _put('referral', r.id, r.toJson());
  }

  /// Writes what was heard onto the visit as `extracted` values and returns
  /// notes for the officer. The transcript itself is not stored anywhere;
  /// the event records only counts (invariant 10).
  List<String> applySpeech(AncVisit v, String transcript) {
    final e = ex.extract(transcript);
    final skipped = ex.applyExtraction(e, v);
    saveVisit(v);
    _event('speech_extracted', v.id, {
      'values': e.measures.length + e.signs.length,
      'notes': e.notes.length,
      'skipped': skipped.length,
    });
    return [
      if (transcript.trim().isEmpty || e.isEmpty)
        'Nothing usable was heard. Enter the values by tap.',
      ...e.notes,
      for (final s in skipped) '$s: you already entered a different value, so it was kept.',
    ];
  }

  void recordConsent(String visitId, {required bool given, required String language}) {
    _event('consent', visitId, {'given': given, 'language': language});
  }

  /// Runs the rule engine on confirmed and manual values only.
  VisitOutcome assess(AncVisit v) {
    final g = pregnancies[v.pregnancyId]!;
    final input = RuleInput.from(v, g);
    final a = rules.assess(input);
    final o = VisitOutcome(
      visitId: v.id,
      assessment: a,
      notUsed: [for (final n in input.notUsed) n.text],
      decision: a.urgency == Urgency.routine ? Decision.routine : Decision.referred,
    );
    if (a.urgency == Urgency.routine) _setNextContact(o, v, g);
    outcomes[v.id] = o;
    _put('outcome', v.id, o.toJson());
    _event('assessment', v.id, {'rule': a.ruleId, 'urgency': a.urgency.name});
    notifyListeners();
    return o;
  }

  void _setNextContact(VisitOutcome o, AncVisit v, Pregnancy g) {
    final n = rules.nextContact(v.visitDate, g.gestationalWeeks);
    o.nextContact = n.date;
    o.nextContactWeeks = n.atWeeks;
  }

  void recordDisagreement(AncVisit v,
      {required String reason, required String note, required bool refer}) {
    final o = outcomes[v.id]!;
    _event('disagreement', v.id, {
      'rule': o.assessment.ruleId,
      'reason': reason,
      'note': note,
      'decision': refer ? 'refer' : 'do_not_refer',
    });
    if (!refer) {
      o.decision = Decision.notReferred;
      _setNextContact(o, v, pregnancies[v.pregnancyId]!);
      _put('outcome', v.id, o.toJson());
      notifyListeners();
    }
  }

  ReferralCard cardFor(Referral r) {
    final v = visits[r.visitId]!;
    final p = patients[r.patientId]!;
    final g = pregnancies[v.pregnancyId]!;
    int code(Field<TriState> f) => switch (f.usableValue) {
          TriState.yes => 1,
          TriState.no => 2,
          _ => 0,
        };
    return ReferralCard(
      patientId: p.id,
      givenName: p.givenName,
      familyName: p.familyName,
      community: p.community,
      birthYear: p.birthYear,
      gestationalWeeks: g.gestationalWeeks,
      gravida: g.gravida,
      para: g.para,
      systolic: v.systolic.usableValue,
      diastolic: v.diastolic.usableValue,
      signs: [for (final s in DangerSign.values) code(v.sign(s))],
      referralId: r.id,
      ruleId: r.ruleId,
      urgency: r.urgency.index,
      issuedAt: r.raisedAt,
      officer: r.raisedBy,
      fromFacility: officer!.facility,
      toFacility: kReferralDestination,
      contactNumber: v.contactNumber,
      haemoglobin: v.haemoglobin?.usableValue,
      temperatureC: v.temperatureC.usableValue,
      urineProtein: v.urineProtein?.usableValue,
      officerPhone: officer!.phone,
    );
  }

  Future<Referral> issueReferral(AncVisit v) async {
    final o = outcomes[v.id]!;
    if (o.referralId != null) return referrals[o.referralId]!;
    var code = newReferralCode();
    while (referrals.containsKey(code)) {
      code = newReferralCode();
    }
    final r = Referral(
      id: code,
      patientId: v.patientId,
      visitId: v.id,
      ruleId: o.assessment.ruleId,
      urgency: o.assessment.urgency,
      raisedAt: now,
      raisedBy: officer!.name,
    );
    referrals[r.id] = r;
    o.decision = Decision.referred;
    o.referralId = r.id;
    o.referralQr = await encodeReferral(cardFor(r));
    _put('referral', r.id, r.toJson());
    _put('outcome', v.id, o.toJson());
    _event('referral_issued', r.id, {'visit': v.id, 'rule': r.ruleId});
    notifyListeners();
    return r;
  }

  // ------------------------------------------------------- chase and close

  /// Not yet arrived: Emergency before Urgent, then oldest first (7.5).
  List<Referral> get openReferrals {
    final list = referrals.values.where((r) => r.state == ReferralState.raised).toList();
    list.sort((a, b) {
      final u = b.urgency.index.compareTo(a.urgency.index);
      return u != 0 ? u : a.raisedAt.compareTo(b.raisedAt);
    });
    return list;
  }

  /// Applies a scanned acknowledgement. Returns null when the referral is
  /// not on this phone.
  Referral? applyAck(AckCard a) {
    final r = referrals[a.referralId];
    if (r == null) return null;
    r.state = ReferralState.closed;
    r.arrivedAt = a.arrivedAt;
    r.arrivedFacility = a.facility;
    r.outcomeNote = a.outcome;
    r.followUpDate = a.followUp;
    _put('referral', r.id, r.toJson());
    final o = outcomes[r.visitId];
    if (o != null) {
      o.receivedBy = a.receivedBy;
      o.receiverPhone = a.receiverPhone;
      _put('outcome', o.visitId, o.toJson());
    }
    _event('referral_closed', r.id, {
      'arrivedAt': a.arrivedAt.toIso8601String(),
      'facility': a.facility,
      'outcome': a.outcome,
      'followUp': a.followUp?.toIso8601String(),
    });
    notifyListeners();
    return r;
  }

  // ------------------------------------------------------------- due list

  /// Women due within the next seven days, including anyone overdue.
  List<DueItem> get dueThisWeek {
    final horizon = dateOnly(now).add(const Duration(days: 7));
    final out = <DueItem>[];
    for (final g in pregnancies.values) {
      final p = patients[g.patientId];
      if (p == null) continue;
      final vs = visits.values.where((v) => v.pregnancyId == g.id).toList()
        ..sort((a, b) => a.visitDate.compareTo(b.visitDate));
      if (vs.isEmpty) continue;
      final last = vs.last;
      DateTime? due = outcomes[last.id]?.nextContact;
      final ref = outcomes[last.id]?.referralId;
      if (ref != null) due = referrals[ref]?.followUpDate;
      if (due == null || due.isAfter(horizon)) continue;
      if (dateOnly(last.visitDate) == dateOnly(now)) continue;
      out.add(DueItem(p, g, due, last.contactNumber + 1));
    }
    out.sort((a, b) {
      final d = a.due.compareTo(b.due);
      return d != 0 ? d : a.patient.fullName.compareTo(b.patient.fullName);
    });
    return out;
  }

  // ---------------------------------------------------------------- reports

  RegisterEntry registerEntry(AncVisit v) {
    final o = outcomes[v.id];
    final r = o?.referralId == null ? null : referrals[o!.referralId];
    return RegisterEntry(
      visit: v,
      patient: patients[v.patientId]!,
      pregnancy: pregnancies[v.pregnancyId]!,
      referral: r,
      referredTo: r == null ? null : kReferralDestination,
      nextContact: o?.nextContact,
    );
  }

  /// Visits that reached an outcome, so half-entered visits are not counted.
  List<AncVisit> get completedVisits =>
      visits.values.where((v) => outcomes.containsKey(v.id)).toList()
        ..sort((a, b) => a.visitDate.compareTo(b.visitDate));

  // ------------------------------------------------------------ receive mode

  void storeReceived(ReceivedReferral r) {
    received[r.card.referralId] = r;
    _put('received', r.card.referralId, r.toJson());
    _event('card_read', r.card.referralId, {'signatureValid': r.signatureValid});
    notifyListeners();
  }

  void confirmArrival(ReceivedReferral r) {
    r.arrivedAt ??= now;
    _put('received', r.card.referralId, r.toJson());
    _event('arrival_confirmed', r.card.referralId);
    notifyListeners();
  }

  void setReceivedOutcome(ReceivedReferral r, {String? outcome, DateTime? followUp}) {
    r.outcome = outcome;
    r.followUp = followUp;
    _put('received', r.card.referralId, r.toJson());
    _event('outcome_recorded', r.card.referralId,
        {'outcome': outcome, 'followUp': followUp?.toIso8601String()});
    notifyListeners();
  }

  Future<String> ackQr(ReceivedReferral r) => encodeAck(AckCard(
        referralId: r.card.referralId,
        state: ReferralState.arrived.index,
        facility: officer!.facility,
        arrivedAt: r.arrivedAt!,
        outcome: r.outcome,
        followUp: r.followUp,
        receivedBy: officer!.name,
        receiverPhone: officer!.phone,
      ));

  List<ReceivedReferral> get receivedList => received.values.toList()
    ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks, where rebuilding on change is not wanted.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
