import 'package:extract/extract.dart';
import 'package:test/test.dart';
import 'package:visit_schema/visit_schema.dart';

void main() {
  group('numbers', () {
    test('spoken numbers become digits', () {
      expect(normalise('one forty over ninety five').join(' '), '140 over 95');
      expect(normalise('one hundred and twelve').join(' '), '112');
      expect(normalise('a hundred and ten').join(' '), '110');
      expect(normalise('thirty eight point four').join(' '), '38.4');
      expect(normalise('one twelve over seventy').join(' '), '112 over 70');
      expect(normalise('one forty five').join(' '), '145');
      expect(normalise('BP 140/95.').join(' '), 'bp 140 over 95 .');
    });
  });

  group('blood pressure', () {
    void bp(String said) {
      final e = extract(said);
      expect(e.measures[Measure.systolic], 140, reason: said);
      expect(e.measures[Measure.diastolic], 95, reason: said);
    }

    test('parses the three required forms', () {
      bp('one forty over ninety five');
      bp('140 over 95');
      bp('systolic 140 diastolic 95');
    });

    test('also parses common variants', () {
      bp('blood pressure is one hundred and forty over ninety five');
      bp('BP 140/95');
    });
  });

  group('danger signs', () {
    test('negation window: no bleeding, no fever, but headache', () {
      final e = extract('no bleeding, no fever, but headache');
      expect(e.signs[DangerSign.vaginalBleeding], TriState.no);
      expect(e.signs[DangerSign.fever], TriState.no);
      expect(e.signs[DangerSign.headache], TriState.yes);
    });

    test('negation works without punctuation, as speech arrives', () {
      final e = extract('no bleeding no fever but headache');
      expect(e.signs[DangerSign.vaginalBleeding], TriState.no);
      expect(e.signs[DangerSign.fever], TriState.no);
      expect(e.signs[DangerSign.headache], TriState.yes);
    });

    test('negation carries across "or"', () {
      final e = extract('she denies bleeding or fits');
      expect(e.signs[DangerSign.vaginalBleeding], TriState.no);
      expect(e.signs[DangerSign.convulsions], TriState.no);
    });

    test('signs not mentioned stay absent, never No', () {
      final e = extract('headache');
      expect(e.signs.keys, [DangerSign.headache]);
      expect(e.signs.containsKey(DangerSign.convulsions), isFalse);
    });

    test('phrases that carry their own negation', () {
      expect(extract('the baby is not moving').signs[DangerSign.reducedFetalMovement], TriState.yes);
      expect(extract('baby is moving well').signs[DangerSign.reducedFetalMovement], TriState.no);
    });

    test('"fit and well" is not a convulsion', () {
      expect(extract('she is fit and well').signs, isEmpty);
    });

    test('contradiction is left for the officer', () {
      final e = extract('headache, no headache');
      expect(e.signs.containsKey(DangerSign.headache), isFalse);
      expect(e.notes.single, contains('Severe headache'));
    });
  });

  group('measurements', () {
    test('a full summary', () {
      final e = extract('Blood pressure one forty over ninety five. Temperature thirty seven point two. '
          'Weight sixty four kilos. Pulse eighty eight. Fundal height thirty. '
          'Fetal heart rate one forty four. Haemoglobin ten point five. Protein two plus. '
          'She has a severe headache, no bleeding, no fits.');
      expect(e.measures, {
        Measure.systolic: 140,
        Measure.diastolic: 95,
        Measure.temperatureC: 37.2,
        Measure.weightKg: 64.0,
        Measure.pulse: 88,
        Measure.fundalHeightCm: 30,
        Measure.fetalHeartRate: 144,
        Measure.haemoglobin: 10.5,
        Measure.urineProtein: 2,
      });
      expect(e.signs, {
        DangerSign.headache: TriState.yes,
        DangerSign.vaginalBleeding: TriState.no,
        DangerSign.convulsions: TriState.no,
      });
      expect(e.notes, isEmpty);
    });

    test('fundal height survives the recogniser mishearing "fundal"', () {
      // Exactly what Vosk returned for "fundal height thirty" on the desktop test.
      final e = extract('b p one twelve over seventy weight sixty four kilos vaginal height thirty');
      expect(e.measures[Measure.fundalHeightCm], 30);
      expect(e.measures[Measure.weightKg], 64.0);
      expect(e.measures[Measure.systolic], 112);
      expect(e.signs.containsKey(DangerSign.vaginalBleeding), isFalse);
      expect(extract('fundal height 28').measures[Measure.fundalHeightCm], 28);
    });

    test('fetal heart rate is not read as pulse', () {
      final e = extract('fetal heart rate 140');
      expect(e.measures[Measure.fetalHeartRate], 140);
      expect(e.measures.containsKey(Measure.pulse), isFalse);
    });

    test('implausible values are not used', () {
      final e = extract('temperature 83');
      expect(e.measures, isEmpty);
      expect(e.notes.single, contains('outside the usual range'));
    });

    test('two different readings are not used', () {
      final e = extract('140 over 95 ... 150 over 95');
      expect(e.measures.containsKey(Measure.systolic), isFalse);
      expect(e.measures[Measure.diastolic], 95);
    });

    test('nothing is invented from silence', () {
      final e = extract('');
      expect(e.isEmpty, isTrue);
    });
  });

  test('vocabulary covers every word of a typical summary', () {
    const said = 'blood pressure one hundred and forty over ninety five she has a severe '
        'headache no bleeding no fits temperature thirty seven point two haemoglobin '
        'ten point five the baby is moving well';
    final vocab = vocabulary.toSet();
    expect(said.split(' ').where((w) => !vocab.contains(w)), isEmpty);
    expect(vocabulary.last, '[unk]');
  });

  group('applyExtraction', () {
    AncVisit visit() => AncVisit(
        id: 'v', patientId: 'p', pregnancyId: 'g', visitDate: DateTime(2026, 10, 21), contactNumber: 1);

    test('writes values with provenance extracted', () {
      final v = visit();
      applyExtraction(extract('140 over 95, headache'), v);
      expect(v.systolic.value, 140);
      expect(v.systolic.provenance, Provenance.extracted);
      expect(v.headache.value, TriState.yes);
      expect(v.headache.provenance, Provenance.extracted);
      expect(v.systolic.usableByRules, isFalse);
    });

    test('never overwrites a value the officer typed', () {
      final v = visit()..systolic = Field.manual(130);
      final skipped = applyExtraction(extract('140 over 95'), v);
      expect(v.systolic.value, 130);
      expect(v.systolic.provenance, Provenance.manual);
      expect(skipped, ['Systolic blood pressure']);
      expect(v.diastolic.provenance, Provenance.extracted);
    });
  });
}
