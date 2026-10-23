enum Provenance { extracted, confirmed, manual, missing }

enum Urgency { routine, urgent, emergency }

enum ReferralState { raised, arrived, closed }

enum TriState { notAsked, yes, no }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// A single clinical value with where it came from.
///
/// Only [Provenance.confirmed] and [Provenance.manual] values may reach the
/// rule engine. See [RuleInput], which is the only type the engine accepts.
class Field<T> {
  T? value;
  Provenance provenance;

  Field(this.value, this.provenance) {
    if (value == null) provenance = Provenance.missing;
  }

  Field.missing()
      : value = null,
        provenance = Provenance.missing;
  Field.manual(T this.value) : provenance = Provenance.manual;
  Field.extracted(T this.value) : provenance = Provenance.extracted;
  Field.confirmed(T this.value) : provenance = Provenance.confirmed;

  bool get usableByRules =>
      provenance == Provenance.confirmed || provenance == Provenance.manual;

  bool get isMissing => value == null || provenance == Provenance.missing;

  /// The value only if the rule engine is allowed to see it.
  T? get usableValue => usableByRules ? value : null;

  /// Typed by the officer. Clearing the value makes it missing.
  void setManual(T? v) {
    value = v;
    provenance = v == null ? Provenance.missing : Provenance.manual;
  }

  void confirm() {
    if (value != null) provenance = Provenance.confirmed;
  }

  /// Returns a confirmed or manual value to the unconfirmed state.
  void unconfirm() {
    if (value != null) provenance = Provenance.extracted;
  }

  Map<String, Object?> toJson(Object? Function(T v) enc) =>
      {'v': value == null ? null : enc(value as T), 'p': provenance.name};

  static Field<T> fromJson<T>(Object? json, T Function(Object v) dec) {
    if (json is! Map) return Field<T>.missing();
    final raw = json['v'];
    final p = _enumByName(Provenance.values, json['p'], Provenance.missing);
    if (raw == null) return Field<T>.missing();
    return Field<T>(dec(raw), p);
  }

  @override
  String toString() => 'Field($value, ${provenance.name})';
}

int _int(Object v) => (v as num).toInt();
double _dbl(Object v) => (v as num).toDouble();
TriState _tri(Object v) =>
    _enumByName(TriState.values, v, TriState.notAsked);

class Patient {
  String id;
  String givenName;
  String familyName;
  String community;
  int? birthYear;
  String? phone;

  Patient({
    required this.id,
    required this.givenName,
    required this.familyName,
    required this.community,
    this.birthYear,
    this.phone,
  });

  String get fullName => '$givenName $familyName';

  int? ageAt(DateTime when) => birthYear == null ? null : when.year - birthYear!;

  Map<String, Object?> toJson() => {
        'id': id,
        'givenName': givenName,
        'familyName': familyName,
        'community': community,
        'birthYear': birthYear,
        'phone': phone,
      };

  factory Patient.fromJson(Map<String, Object?> j) => Patient(
        id: j['id'] as String,
        givenName: j['givenName'] as String,
        familyName: j['familyName'] as String,
        community: j['community'] as String,
        birthYear: (j['birthYear'] as num?)?.toInt(),
        phone: j['phone'] as String?,
      );
}

class Pregnancy {
  String id;
  String patientId;
  int gravida;
  int para;
  int gestationalWeeks;

  Pregnancy({
    required this.id,
    required this.patientId,
    required this.gravida,
    required this.para,
    required this.gestationalWeeks,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'gravida': gravida,
        'para': para,
        'gestationalWeeks': gestationalWeeks,
      };

  factory Pregnancy.fromJson(Map<String, Object?> j) => Pregnancy(
        id: j['id'] as String,
        patientId: j['patientId'] as String,
        gravida: (j['gravida'] as num).toInt(),
        para: (j['para'] as num).toInt(),
        gestationalWeeks: (j['gestationalWeeks'] as num).toInt(),
      );
}

/// The nine danger signs, in the order they are asked.
enum DangerSign {
  convulsions('Fits or convulsions'),
  vaginalBleeding('Vaginal bleeding'),
  headache('Severe headache'),
  visualDisturbance('Blurred vision'),
  oedema('Swelling of face or hands'),
  severeAbdominalPain('Severe abdominal pain'),
  fever('Fever'),
  reducedFetalMovement('Reduced fetal movement'),
  severePallor('Severe pallor');

  const DangerSign(this.label);
  final String label;
}

/// Numeric observations on a visit, with their display label and unit.
enum Measure {
  systolic('Systolic blood pressure', 'mmHg'),
  diastolic('Diastolic blood pressure', 'mmHg'),
  temperatureC('Temperature', '°C'),
  weightKg('Weight', 'kg'),
  pulse('Pulse', 'per min'),
  fundalHeightCm('Fundal height', 'cm'),
  fetalHeartRate('Fetal heart rate', 'per min'),
  urineProtein('Urine protein', '+'),
  haemoglobin('Haemoglobin', 'g/dL');

  const Measure(this.label, this.unit);
  final String label;
  final String unit;

  bool get isDecimal =>
      this == temperatureC || this == weightKg || this == haemoglobin;
}

class AncVisit {
  String id;
  String patientId;
  String pregnancyId;
  DateTime visitDate;
  int contactNumber; // ANC contact 1..8

  Field<int> systolic;
  Field<int> diastolic;
  Field<double> temperatureC;
  Field<double> weightKg;
  Field<int> pulse;
  Field<int> fundalHeightCm;
  Field<int> fetalHeartRate;

  Field<TriState> headache;
  Field<TriState> visualDisturbance;
  Field<TriState> oedema;
  Field<TriState> vaginalBleeding;
  Field<TriState> fever;
  Field<TriState> reducedFetalMovement;
  Field<TriState> convulsions;
  Field<TriState> severeAbdominalPain;
  Field<TriState> severePallor;

  Field<int>? urineProtein; // dipstick 0..4
  Field<double>? haemoglobin;
  String? freeNote;

  AncVisit({
    required this.id,
    required this.patientId,
    required this.pregnancyId,
    required this.visitDate,
    required this.contactNumber,
    Field<int>? systolic,
    Field<int>? diastolic,
    Field<double>? temperatureC,
    Field<double>? weightKg,
    Field<int>? pulse,
    Field<int>? fundalHeightCm,
    Field<int>? fetalHeartRate,
    Field<TriState>? headache,
    Field<TriState>? visualDisturbance,
    Field<TriState>? oedema,
    Field<TriState>? vaginalBleeding,
    Field<TriState>? fever,
    Field<TriState>? reducedFetalMovement,
    Field<TriState>? convulsions,
    Field<TriState>? severeAbdominalPain,
    Field<TriState>? severePallor,
    this.urineProtein,
    this.haemoglobin,
    this.freeNote,
  })  : systolic = systolic ?? Field.missing(),
        diastolic = diastolic ?? Field.missing(),
        temperatureC = temperatureC ?? Field.missing(),
        weightKg = weightKg ?? Field.missing(),
        pulse = pulse ?? Field.missing(),
        fundalHeightCm = fundalHeightCm ?? Field.missing(),
        fetalHeartRate = fetalHeartRate ?? Field.missing(),
        headache = headache ?? Field.missing(),
        visualDisturbance = visualDisturbance ?? Field.missing(),
        oedema = oedema ?? Field.missing(),
        vaginalBleeding = vaginalBleeding ?? Field.missing(),
        fever = fever ?? Field.missing(),
        reducedFetalMovement = reducedFetalMovement ?? Field.missing(),
        convulsions = convulsions ?? Field.missing(),
        severeAbdominalPain = severeAbdominalPain ?? Field.missing(),
        severePallor = severePallor ?? Field.missing();

  Field<TriState> sign(DangerSign s) => switch (s) {
        DangerSign.convulsions => convulsions,
        DangerSign.vaginalBleeding => vaginalBleeding,
        DangerSign.headache => headache,
        DangerSign.visualDisturbance => visualDisturbance,
        DangerSign.oedema => oedema,
        DangerSign.severeAbdominalPain => severeAbdominalPain,
        DangerSign.fever => fever,
        DangerSign.reducedFetalMovement => reducedFetalMovement,
        DangerSign.severePallor => severePallor,
      };

  /// Every numeric observation as a `Field<num>` view. Optional fields that
  /// are absent are created as missing so the screen can offer Enter.
  Field<num> measure(Measure m) => switch (m) {
        Measure.systolic => systolic,
        Measure.diastolic => diastolic,
        Measure.temperatureC => temperatureC,
        Measure.weightKg => weightKg,
        Measure.pulse => pulse,
        Measure.fundalHeightCm => fundalHeightCm,
        Measure.fetalHeartRate => fetalHeartRate,
        Measure.urineProtein => urineProtein ??= Field.missing(),
        Measure.haemoglobin => haemoglobin ??= Field.missing(),
      };

  /// Sets a numeric observation typed by the officer.
  void setMeasure(Measure m, num? v) {
    switch (m) {
      case Measure.temperatureC:
        temperatureC.setManual(v?.toDouble());
      case Measure.weightKg:
        weightKg.setManual(v?.toDouble());
      case Measure.haemoglobin:
        (haemoglobin ??= Field.missing()).setManual(v?.toDouble());
      case Measure.systolic:
        systolic.setManual(v?.round());
      case Measure.diastolic:
        diastolic.setManual(v?.round());
      case Measure.pulse:
        pulse.setManual(v?.round());
      case Measure.fundalHeightCm:
        fundalHeightCm.setManual(v?.round());
      case Measure.fetalHeartRate:
        fetalHeartRate.setManual(v?.round());
      case Measure.urineProtein:
        (urineProtein ??= Field.missing()).setManual(v?.round());
    }
  }

  Map<String, Object?> toJson() {
    Object? e(Object v) => v;
    Object? t(TriState v) => v.name;
    return {
      'id': id,
      'patientId': patientId,
      'pregnancyId': pregnancyId,
      'visitDate': visitDate.toIso8601String(),
      'contactNumber': contactNumber,
      'systolic': systolic.toJson(e),
      'diastolic': diastolic.toJson(e),
      'temperatureC': temperatureC.toJson(e),
      'weightKg': weightKg.toJson(e),
      'pulse': pulse.toJson(e),
      'fundalHeightCm': fundalHeightCm.toJson(e),
      'fetalHeartRate': fetalHeartRate.toJson(e),
      for (final s in DangerSign.values) s.name: sign(s).toJson(t),
      'urineProtein': urineProtein?.toJson(e),
      'haemoglobin': haemoglobin?.toJson(e),
      'freeNote': freeNote,
    };
  }

  factory AncVisit.fromJson(Map<String, Object?> j) {
    Field<TriState> tri(String k) => Field.fromJson(j[k], _tri);
    return AncVisit(
      id: j['id'] as String,
      patientId: j['patientId'] as String,
      pregnancyId: j['pregnancyId'] as String,
      visitDate: DateTime.parse(j['visitDate'] as String),
      contactNumber: (j['contactNumber'] as num).toInt(),
      systolic: Field.fromJson(j['systolic'], _int),
      diastolic: Field.fromJson(j['diastolic'], _int),
      temperatureC: Field.fromJson(j['temperatureC'], _dbl),
      weightKg: Field.fromJson(j['weightKg'], _dbl),
      pulse: Field.fromJson(j['pulse'], _int),
      fundalHeightCm: Field.fromJson(j['fundalHeightCm'], _int),
      fetalHeartRate: Field.fromJson(j['fetalHeartRate'], _int),
      headache: tri('headache'),
      visualDisturbance: tri('visualDisturbance'),
      oedema: tri('oedema'),
      vaginalBleeding: tri('vaginalBleeding'),
      fever: tri('fever'),
      reducedFetalMovement: tri('reducedFetalMovement'),
      convulsions: tri('convulsions'),
      severeAbdominalPain: tri('severeAbdominalPain'),
      severePallor: tri('severePallor'),
      urineProtein:
          j['urineProtein'] == null ? null : Field.fromJson(j['urineProtein'], _int),
      haemoglobin:
          j['haemoglobin'] == null ? null : Field.fromJson(j['haemoglobin'], _dbl),
      freeNote: j['freeNote'] as String?,
    );
  }
}

class Assessment {
  String ruleId;
  String ruleTitle;
  Urgency urgency;
  List<String> triggeredBy; // human readable, e.g. "Blood pressure 140/95"
  String recommendation;

  Assessment({
    required this.ruleId,
    required this.ruleTitle,
    required this.urgency,
    required this.triggeredBy,
    required this.recommendation,
  });

  Map<String, Object?> toJson() => {
        'ruleId': ruleId,
        'ruleTitle': ruleTitle,
        'urgency': urgency.name,
        'triggeredBy': triggeredBy,
        'recommendation': recommendation,
      };

  factory Assessment.fromJson(Map<String, Object?> j) => Assessment(
        ruleId: j['ruleId'] as String,
        ruleTitle: j['ruleTitle'] as String,
        urgency: _enumByName(Urgency.values, j['urgency'], Urgency.routine),
        triggeredBy: (j['triggeredBy'] as List).cast<String>(),
        recommendation: j['recommendation'] as String,
      );
}

class Referral {
  String id; // six char human readable, e.g. K7M4QP
  String patientId;
  String visitId;
  String ruleId;
  Urgency urgency;
  DateTime raisedAt;
  String raisedBy;
  ReferralState state;
  DateTime? arrivedAt;
  String? arrivedFacility;
  String? outcomeNote;
  DateTime? followUpDate;

  Referral({
    required this.id,
    required this.patientId,
    required this.visitId,
    required this.ruleId,
    required this.urgency,
    required this.raisedAt,
    required this.raisedBy,
    this.state = ReferralState.raised,
    this.arrivedAt,
    this.arrivedFacility,
    this.outcomeNote,
    this.followUpDate,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'visitId': visitId,
        'ruleId': ruleId,
        'urgency': urgency.name,
        'raisedAt': raisedAt.toIso8601String(),
        'raisedBy': raisedBy,
        'state': state.name,
        'arrivedAt': arrivedAt?.toIso8601String(),
        'arrivedFacility': arrivedFacility,
        'outcomeNote': outcomeNote,
        'followUpDate': followUpDate?.toIso8601String(),
      };

  factory Referral.fromJson(Map<String, Object?> j) {
    DateTime? d(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    return Referral(
      id: j['id'] as String,
      patientId: j['patientId'] as String,
      visitId: j['visitId'] as String,
      ruleId: j['ruleId'] as String,
      urgency: _enumByName(Urgency.values, j['urgency'], Urgency.routine),
      raisedAt: DateTime.parse(j['raisedAt'] as String),
      raisedBy: j['raisedBy'] as String,
      state: _enumByName(ReferralState.values, j['state'], ReferralState.raised),
      arrivedAt: d('arrivedAt'),
      arrivedFacility: j['arrivedFacility'] as String?,
      outcomeNote: j['outcomeNote'] as String?,
      followUpDate: d('followUpDate'),
    );
  }
}
