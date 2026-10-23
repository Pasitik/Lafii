/// Transcript to candidate visit values. Grammar and regex only, no model.
///
/// Every value found is written with provenance `extracted` and does not
/// count until the officer confirms it (CLAUDE.md invariant 2).
///
/// Deliberately not handled, and the reason a small language model is the
/// next build: self-correction ("140, sorry, 150"), temporal phrases
/// ("since Sunday"), and paraphrase ("her feet are puffy").
library;

import 'package:visit_schema/visit_schema.dart';

import 'src/numbers.dart';

export 'src/numbers.dart' show normalise, numberWords;

class Extraction {
  final Map<Measure, num> measures;
  final Map<DangerSign, TriState> signs;

  /// Plain-language notes for things heard but not used: contradictions and
  /// values outside a plausible range. Shown to the officer, never applied.
  final List<String> notes;

  const Extraction(this.measures, this.signs, this.notes);

  bool get isEmpty => measures.isEmpty && signs.isEmpty;
}

/// Readings outside these ranges are almost certainly mishearings.
const plausible = <Measure, (num, num)>{
  Measure.systolic: (60, 260),
  Measure.diastolic: (30, 160),
  Measure.temperatureC: (30, 43),
  Measure.weightKg: (25, 200),
  Measure.pulse: (30, 220),
  Measure.fundalHeightCm: (5, 50),
  Measure.fetalHeartRate: (60, 220),
  Measure.urineProtein: (0, 4),
  Measure.haemoglobin: (2, 20),
};

// Words allowed between a keyword and its number: "temperature is 38",
// "weight was about 64", "pulse of 88".
const _filler = r'(?:\s+(?:is|was|of|at|about|around|reading|measured|today|now|she|her|has|a|the))*';
const _n = r'(\d{1,3}(?:\.\d+)?)';
const _i = r'(\d{1,3})';

final _measurePatterns = <Measure, List<RegExp>>{
  Measure.temperatureC: [RegExp('\\b(?:temperature|temp)$_filler\\s+$_n')],
  Measure.weightKg: [RegExp('\\b(?:weight|weighs|weighing)$_filler\\s+$_n')],
  Measure.pulse: [
    RegExp('(?<!fetal )(?<!foetal )(?<!baby s )\\b(?:pulse|pulse rate|maternal heart rate)$_filler\\s+$_i'),
  ],
  // "fundal" is not in the small speech model's dictionary, so it comes back as
  // "vaginal", "fungal" or "final". "<anything> height N" in an antenatal
  // summary is fundal height; "weight" is a different word and never matches.
  Measure.fundalHeightCm: [
    RegExp('\\b(?:(?:symphysis\\s+)?(?:fundal|fundus|vaginal|fungal|final|fondle)\\s+)?height'
        '$_filler\\s+$_i'),
    RegExp('\\b(?:fundal|fundus|sfh)$_filler\\s+$_i'),
  ],
  Measure.fetalHeartRate: [
    RegExp('\\b(?:fetal heart|foetal heart|fetal heart rate|foetal heart rate|fhr|baby s heart(?: rate)?)(?: rate)?$_filler\\s+$_i'),
  ],
  Measure.haemoglobin: [RegExp('\\b(?:haemoglobin|hemoglobin|hb|hgb|hemo|haemo)$_filler\\s+$_n')],
};

final _bpPair = [
  RegExp('\\b$_i\\s+(?:over|by)\\s+$_i\\b'),
];
final _systolic = RegExp('\\bsystolic$_filler\\s+$_i');
final _diastolic = RegExp('\\bdiastolic$_filler\\s+$_i');

final _protein = [
  RegExp(r'\b(?:urine\s+)?protein(?:uria)?' '$_filler' r'\s+(nil|negative|\d)(?:\s+plus)?'),
  RegExp(r'\b(\d)\s+plus\s+(?:of\s+)?(?:urine\s+)?protein'),
  RegExp(r'\bplus\s+(\d)\s+(?:urine\s+)?protein'),
];

/// Terms for each sign. Longer phrases first so they win over sub-phrases.
const signTerms = <DangerSign, List<String>>{
  DangerSign.convulsions: ['convulsions', 'convulsion', 'convulsing', 'seizures', 'seizure', 'fitting', 'fits'],
  // Not "fit" alone: "she is fit and well" must not read as a convulsion.
  DangerSign.vaginalBleeding: ['vaginal bleeding', 'bleeding per vagina', 'blood loss', 'bleeding'],
  DangerSign.headache: ['severe headache', 'headaches', 'headache', 'head ache'],
  DangerSign.visualDisturbance: [
    'blurred vision', 'blurry vision', 'blurring of vision', 'visual disturbance',
    'seeing spots', 'flashing lights', 'blurring',
  ],
  DangerSign.oedema: ['oedema', 'edema', 'swelling', 'swollen'],
  DangerSign.severeAbdominalPain: [
    'severe abdominal pain', 'abdominal pain', 'stomach pain', 'belly pain', 'tummy pain',
    'pain in the abdomen', 'pain in her abdomen',
  ],
  DangerSign.fever: ['fever', 'feverish', 'febrile'],
  DangerSign.reducedFetalMovement: [
    'reduced fetal movements', 'reduced fetal movement', 'reduced foetal movement',
    'decreased fetal movement', 'reduced movements', 'reduced movement',
    'baby not moving', 'baby is not moving', 'baby s not moving', 'less movement',
  ],
  DangerSign.severePallor: ['severe pallor', 'very pale', 'pallor', 'pale'],
};

/// Phrases that state a sign is absent without a separate negator.
const _negativePhrases = <DangerSign, List<String>>{
  DangerSign.reducedFetalMovement: [
    'baby is moving well', 'baby moving well', 'good fetal movements', 'good fetal movement',
    'normal fetal movements', 'normal movements', 'moving well',
  ],
};

const _negators = {'no', 'not', 'denies', 'denied', 'without', 'nil', 'never', 'none', 'neither', 'nor', 'negative'};
const _boundaries = {
  'but', 'however', 'although', 'though', 'except', 'yes', 'has', 'have', 'had', 'reports',
  'complains', 'with', 'and', '.', ',', 'over', 'is', 'was',
};

class _Span {
  final DangerSign sign;
  final int start;
  final int end; // exclusive
  final bool negativePhrase;
  _Span(this.sign, this.start, this.end, this.negativePhrase);
}

/// Extracts candidate values from one transcript.
Extraction extract(String transcript) {
  final tokens = normalise(transcript);
  final text = tokens.join(' ');
  final notes = <String>[];

  final found = <Measure, Set<num>>{};
  void add(Measure m, num v) => found.putIfAbsent(m, () => {}).add(v);

  // Blood pressure: "140 over 95", "systolic 140 diastolic 95".
  for (final re in _bpPair) {
    for (final m in re.allMatches(text)) {
      add(Measure.systolic, int.parse(m[1]!));
      add(Measure.diastolic, int.parse(m[2]!));
    }
  }
  for (final m in _systolic.allMatches(text)) {
    add(Measure.systolic, int.parse(m[1]!));
  }
  for (final m in _diastolic.allMatches(text)) {
    add(Measure.diastolic, int.parse(m[1]!));
  }

  _measurePatterns.forEach((measure, patterns) {
    for (final re in patterns) {
      for (final m in re.allMatches(text)) {
        add(measure, num.parse(m[1]!));
      }
    }
  });

  for (final re in _protein) {
    for (final m in re.allMatches(text)) {
      final raw = m[1]!;
      add(Measure.urineProtein, raw == 'nil' || raw == 'negative' ? 0 : int.parse(raw));
    }
  }

  final measures = <Measure, num>{};
  found.forEach((m, values) {
    if (values.length > 1) {
      notes.add('${m.label}: heard ${values.map(_fmt).join(' and ')}. Enter it by tap.');
      return;
    }
    final v = values.single;
    final (lo, hi) = plausible[m]!;
    if (v < lo || v > hi) {
      notes.add('${m.label}: heard ${_fmt(v)}, which is outside the usual range. Enter it by tap.');
      return;
    }
    measures[m] = m.isDecimal ? v.toDouble() : v.round();
  });

  final signs = _signs(tokens, notes);
  return Extraction(measures, signs, notes);
}

String _fmt(num v) =>
    v is double && v != v.roundToDouble() ? v.toStringAsFixed(1) : '${v.round()}';

Map<DangerSign, TriState> _signs(List<String> tokens, List<String> notes) {
  final spans = <_Span>[];
  final taken = List<bool>.filled(tokens.length, false);

  void scan(DangerSign sign, String phrase, bool negative) {
    final words = phrase.split(' ');
    for (var i = 0; i + words.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < words.length; j++) {
        if (taken[i + j] || tokens[i + j] != words[j]) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (var j = 0; j < words.length; j++) {
        taken[i + j] = true;
      }
      spans.add(_Span(sign, i, i + words.length, negative));
    }
  }

  // Negative phrases first, then terms longest first, so "baby is moving
  // well" is not read as a mention of movement and "severe headache" is one
  // span, not two.
  _negativePhrases.forEach((s, list) {
    for (final p in list) {
      scan(s, p, true);
    }
  });
  final all = <(DangerSign, String)>[
    for (final e in signTerms.entries)
      for (final t in e.value) (e.key, t),
  ]..sort((a, b) => b.$2.split(' ').length.compareTo(a.$2.split(' ').length));
  for (final (s, t) in all) {
    scan(s, t, false);
  }
  spans.sort((a, b) => a.start.compareTo(b.start));

  final answers = <DangerSign, Set<TriState>>{};
  for (final sp in spans) {
    final v = sp.negativePhrase || _negated(sp, spans, tokens) ? TriState.no : TriState.yes;
    answers.putIfAbsent(sp.sign, () => {}).add(v);
  }

  final out = <DangerSign, TriState>{};
  answers.forEach((s, vs) {
    if (vs.length > 1) {
      notes.add('${s.label}: heard both yes and no. Answer it by tap.');
    } else {
      out[s] = vs.single;
    }
  });
  return out;
}

/// A negator within four words before the term, in the same clause.
/// "no bleeding or fever": the negation carries across "or" / "nor".
/// "no bleeding but headache": "but" ends the clause, headache is yes.
bool _negated(_Span sp, List<_Span> spans, List<String> tokens) {
  var i = sp.start - 1;
  var steps = 0;
  var passedOr = false;
  while (i >= 0 && steps < 4) {
    final t = tokens[i];
    if (_negators.contains(t)) return true;
    if (t == 'or' || t == 'nor') {
      passedOr = true;
      i--;
      continue;
    }
    if (_boundaries.contains(t)) return false;
    final other = spans.where((o) => o != sp && o.start <= i && i < o.end).firstOrNull;
    if (other != null) {
      if (!passedOr) return false;
      passedOr = false;
      i = other.start - 1;
      continue;
    }
    if (isNumber(t)) return false;
    i--;
    steps++;
  }
  return false;
}

/// Every word the extractor understands. Given to the speech recogniser as
/// its grammar so it only hears words that can become a value; anything else
/// comes back as "[unk]" and is ignored.
List<String> get vocabulary {
  final words = <String>{
    ...numberWords,
    'point', 'and', 'a', 'over', 'by', 'plus', 'degrees', 'kilos', 'kilograms', 'kg',
    'centimetres', 'centimeters', 'weeks', 'beats', 'per', 'minute',
    'blood', 'pressure', 'b', 'p', 'systolic', 'diastolic',
    'temperature', 'temp', 'weight', 'weighs', 'pulse', 'rate', 'maternal',
    'fundal', 'height', 'fundus', 'fetal', 'foetal', 'heart', 'baby', 'baby\'s',
    'haemoglobin', 'hemoglobin', 'h', 'urine', 'protein', 'nil', 'negative', 'trace',
    'moving', 'well', 'good', 'normal', 'movements', 'movement', 'not', 'is',
    'she', 'her', 'has', 'have', 'had', 'with', 'reports', 'complains', 'of',
    'was', 'at', 'about', 'today', 'the', 'in', 'yes',
    ..._negators,
    ..._boundaries.where((b) => b != '.' && b != ','),
    'or', 'nor',
    for (final list in signTerms.values)
      for (final t in list) ...t.split(' '),
    for (final list in _negativePhrases.values)
      for (final t in list) ...t.split(' '),
  }..remove('s');
  return [...words.toList()..sort(), '[unk]'];
}

/// Writes an extraction onto a visit as `extracted` values.
///
/// Values the officer already typed or confirmed are never overwritten; the
/// labels of any that differ are returned so the screen can say so.
List<String> applyExtraction(Extraction e, AncVisit v) {
  final skipped = <String>[];
  e.measures.forEach((m, value) {
    final f = v.measure(m);
    if (f.usableByRules) {
      if (f.value != value) skipped.add(m.label);
      return;
    }
    v.setMeasure(m, value);
    v.measure(m).unconfirm();
  });
  e.signs.forEach((s, value) {
    final f = v.sign(s);
    if (f.usableByRules) {
      if (f.value != value) skipped.add(s.label);
      return;
    }
    f.value = value;
    f.provenance = Provenance.extracted;
  });
  return skipped;
}
