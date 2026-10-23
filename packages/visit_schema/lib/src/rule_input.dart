import 'models.dart';

/// Why a value did not reach the rule engine.
enum NotUsedReason { missing, notConfirmed }

class NotUsed {
  final String label;
  final NotUsedReason reason;
  const NotUsed(this.label, this.reason);

  /// Plain text for the "Not used" section, e.g. "Haemoglobin: missing".
  String get text =>
      '$label: ${reason == NotUsedReason.missing ? 'missing' : 'not confirmed'}';
}

/// The only view of a visit the rule engine can read.
///
/// Built exclusively by [RuleInput.from], which drops every field whose
/// provenance is not `confirmed` or `manual`. An `extracted` value arrives
/// here as `null`, exactly like a missing one. This is the package boundary
/// that enforces invariant 2; no screen can bypass it.
class RuleInput {
  final int? systolic;
  final int? diastolic;
  final double? temperatureC;
  final int? urineProtein;
  final double? haemoglobin;

  /// From the pregnancy record, which is always entered by the officer.
  final int gestationalWeeks;

  final Map<DangerSign, TriState> _signs;

  /// Fields that were left out, in display order.
  final List<NotUsed> notUsed;

  const RuleInput._({
    required this.systolic,
    required this.diastolic,
    required this.temperatureC,
    required this.urineProtein,
    required this.haemoglobin,
    required this.gestationalWeeks,
    required Map<DangerSign, TriState> signs,
    required this.notUsed,
  }) : _signs = signs;

  factory RuleInput.from(AncVisit visit, Pregnancy pregnancy) {
    final notUsed = <NotUsed>[];

    T? take<T>(Field<T>? f, String label) {
      if (f == null || f.value == null) {
        notUsed.add(NotUsed(label, NotUsedReason.missing));
        return null;
      }
      if (!f.usableByRules) {
        notUsed.add(NotUsed(label, NotUsedReason.notConfirmed));
        return null;
      }
      return f.value;
    }

    final systolic = take(visit.systolic, Measure.systolic.label);
    final diastolic = take(visit.diastolic, Measure.diastolic.label);
    final temp = take(visit.temperatureC, Measure.temperatureC.label);
    final protein = take(visit.urineProtein, Measure.urineProtein.label);
    final hb = take(visit.haemoglobin, Measure.haemoglobin.label);

    final signs = <DangerSign, TriState>{};
    for (final s in DangerSign.values) {
      final f = visit.sign(s);
      if (f.value == null || f.value == TriState.notAsked) {
        signs[s] = TriState.notAsked;
        notUsed.add(NotUsed(s.label, NotUsedReason.missing));
      } else if (!f.usableByRules) {
        signs[s] = TriState.notAsked;
        notUsed.add(NotUsed(s.label, NotUsedReason.notConfirmed));
      } else {
        signs[s] = f.value!;
      }
    }

    return RuleInput._(
      systolic: systolic,
      diastolic: diastolic,
      temperatureC: temp,
      urineProtein: protein,
      haemoglobin: hb,
      gestationalWeeks: pregnancy.gestationalWeeks,
      signs: Map.unmodifiable(signs),
      notUsed: List.unmodifiable(notUsed),
    );
  }

  TriState sign(DangerSign s) => _signs[s] ?? TriState.notAsked;

  bool has(DangerSign s) => sign(s) == TriState.yes;
}
