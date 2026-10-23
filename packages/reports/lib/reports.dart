/// Register line and monthly aggregate, generated from captured visits.
///
/// Only values the rule engine may use (confirmed or manual) are written.
/// Anything else is written as the word Missing, never imputed.
library;

import 'package:visit_schema/visit_schema.dart';

class RegisterEntry {
  final AncVisit visit;
  final Patient patient;
  final Pregnancy pregnancy;
  final Referral? referral;
  final String? referredTo;
  final DateTime? nextContact;

  const RegisterEntry({
    required this.visit,
    required this.patient,
    required this.pregnancy,
    this.referral,
    this.referredTo,
    this.nextContact,
  });
}

String _two(int n) => n.toString().padLeft(2, '0');
String _dm(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

String _bp(AncVisit v) {
  final s = v.systolic.usableValue;
  final d = v.diastolic.usableValue;
  if (s == null && d == null) return 'Missing';
  return '${s ?? 'Missing'}/${d ?? 'Missing'}';
}

String _num(Field<num>? f) {
  final v = f?.usableValue;
  if (v == null) return 'Missing';
  return v is double && v != v.roundToDouble() ? v.toStringAsFixed(1) : '${v.round()}';
}

/// Short destination for the register, e.g. "Walewale Hospital" to "Walewale".
String shortFacility(String f) =>
    f.replaceAll(RegExp(r'\s+(Hospital|Health Centre|CHPS)$'), '');

/// One line for the paper register, e.g.
/// `17/10 · Fati Alhassan · 28 · ANC4 · GA 32 · BP 140/95 · Ref: Walewale (K7M 4QP)`
String registerLine(RegisterEntry e) {
  final v = e.visit;
  final age = e.patient.ageAt(v.visitDate);
  final parts = <String>[
    _dm(v.visitDate),
    e.patient.fullName,
    age?.toString() ?? 'Age missing',
    'ANC${v.contactNumber}',
    'GA ${e.pregnancy.gestationalWeeks}',
    'BP ${_bp(v)}',
  ];
  final hb = v.haemoglobin?.usableValue;
  if (hb != null) parts.add('Hb ${_num(v.haemoglobin)}');
  final r = e.referral;
  if (r != null) {
    final code = '${r.id.substring(0, 3)} ${r.id.substring(3)}';
    parts.add('Ref: ${shortFacility(e.referredTo ?? '')} ($code)');
  } else if (e.nextContact != null) {
    parts.add('Next ${_dm(e.nextContact!)}');
  }
  return parts.join(' · ');
}

String _csv(Object? v) {
  final s = v?.toString() ?? '';
  return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _csvRows(List<List<Object?>> rows) =>
    '${rows.map((r) => r.map(_csv).join(',')).join('\r\n')}\r\n';

/// Register as CSV, one row per visit.
String registerCsv(List<RegisterEntry> entries) => _csvRows([
      [
        'Date', 'Name', 'Community', 'Age', 'ANC contact', 'Weeks pregnant',
        'Systolic', 'Diastolic', 'Weight (kg)', 'Fundal height (cm)',
        'Haemoglobin (g/dL)', 'Referral code', 'Referred to', 'Next contact',
      ],
      for (final e in entries)
        [
          '${_two(e.visit.visitDate.day)}/${_two(e.visit.visitDate.month)}/${e.visit.visitDate.year}',
          e.patient.fullName,
          e.patient.community,
          e.patient.ageAt(e.visit.visitDate) ?? 'Missing',
          e.visit.contactNumber,
          e.pregnancy.gestationalWeeks,
          _num(e.visit.systolic),
          _num(e.visit.diastolic),
          _num(e.visit.weightKg),
          _num(e.visit.fundalHeightCm),
          _num(e.visit.haemoglobin),
          e.referral?.id ?? '',
          e.referral == null ? '' : (e.referredTo ?? ''),
          e.nextContact == null
              ? ''
              : '${_two(e.nextContact!.day)}/${_two(e.nextContact!.month)}/${e.nextContact!.year}',
        ],
    ]);

class AggregateRow {
  /// Must be the exact DHIMS2 data element name. See [kDhimsLabelsVerified].
  final String element;
  final int value;
  const AggregateRow(this.element, this.value);
}

/// The element names below are placeholders until someone on the team copies
/// the exact DHIMS2 names from the monthly ANC form (story 8.3).
const bool kDhimsLabelsVerified = false;

bool _inMonth(DateTime d, int year, int month) =>
    d.year == year && d.month == month;

/// Monthly aggregate derived only from captured visits and referrals.
List<AggregateRow> monthlyAggregate({
  required int year,
  required int month,
  required List<AncVisit> visits,
  required List<Referral> referrals,
}) {
  final inMonth = visits.where((v) => _inMonth(v.visitDate, year, month)).toList();
  bool highBp(AncVisit v) {
    final s = v.systolic.usableValue;
    final d = v.diastolic.usableValue;
    return (s != null && s >= 140) || (d != null && d >= 90);
  }

  return [
    AggregateRow('ANC registrants', inMonth.where((v) => v.contactNumber == 1).length),
    AggregateRow('ANC attendances', inMonth.length),
    AggregateRow('ANC 4th visit', inMonth.where((v) => v.contactNumber == 4).length),
    AggregateRow('ANC 8th visit', inMonth.where((v) => v.contactNumber == 8).length),
    AggregateRow('BP 140/90 or higher', inMonth.where(highBp).length),
    AggregateRow('ANC referrals out',
        referrals.where((r) => _inMonth(r.raisedAt, year, month)).length),
    AggregateRow(
        'Referral feedback received',
        referrals
            .where((r) =>
                r.arrivedAt != null && _inMonth(r.arrivedAt!, year, month))
            .length),
  ];
}

String aggregateCsv(List<AggregateRow> rows, {required String period}) =>
    _csvRows([
      ['Period', 'Data element', 'Value'],
      for (final r in rows) [period, r.element, r.value],
    ]);
