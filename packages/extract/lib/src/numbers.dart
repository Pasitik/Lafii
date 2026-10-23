/// Turns spoken numbers into digits, so the patterns only ever see digits.
///
/// "one forty over ninety five"   -> "140 over 95"
/// "one hundred and twelve"       -> "112"
/// "thirty eight point four"      -> "38.4"
/// "a hundred and ten"            -> "110"
library;

const _units = {
  'zero': 0, 'oh': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
};
const _teens = {
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
  'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
};
const _tens = {
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fourty': 40, 'fifty': 50,
  'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
};

/// Spoken number words, for the recogniser's grammar.
Iterable<String> get numberWords =>
    [..._units.keys.where((k) => k != 'oh'), ..._teens.keys, ..._tens.keys.where((k) => k != 'fourty'), 'hundred'];

bool _isDigits(String t) => RegExp(r'^\d+(\.\d+)?$').hasMatch(t);

bool _isNumberWord(String t) =>
    _units.containsKey(t) || _teens.containsKey(t) || _tens.containsKey(t) || t == 'hundred';

enum _K { none, unit, teen, tens, tensUnit, hundred, colloquial }

/// Lowercases, splits punctuation, rewrites "140/95" as "140 over 95", and
/// replaces every run of number words with digits.
List<String> normalise(String text) {
  var s = text.toLowerCase();
  s = s.replaceAllMapped(RegExp(r'(\d)\s*/\s*(\d)'), (m) => '${m[1]} over ${m[2]}');
  s = s.replaceAll('°', ' degrees ');
  s = s.replaceAllMapped(RegExp(r'(\d)\s*\+'), (m) => '${m[1]} plus');
  // Keep decimal points inside numbers; every other punctuation mark becomes
  // its own token so it can act as a clause boundary.
  s = s.replaceAllMapped(RegExp(r'(?<!\d)\.|\.(?!\d)'), (_) => ' . ');
  s = s.replaceAll(RegExp(r'[,;:!?]'), ' , ');
  s = s.replaceAll(RegExp(r"[^a-z0-9.,' ]"), ' ');
  s = s.replaceAll("'s", ' s');
  s = s.replaceAll("'", '');
  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  final out = <String>[];
  var i = 0;
  while (i < words.length) {
    final w = words[i];
    final startsNumber = _isNumberWord(w) ||
        (w == 'a' && i + 1 < words.length && words[i + 1] == 'hundred');
    if (!startsNumber) {
      out.add(w);
      i++;
      continue;
    }
    i = _readNumbers(words, i, out);
  }
  return out;
}

/// Reads one run of number words starting at [i], appends the digits, and
/// returns the index after the run.
int _readNumbers(List<String> words, int i, List<String> out) {
  var current = 0;
  var kind = _K.none;

  void flush() {
    if (kind != _K.none) out.add('$current');
    current = 0;
    kind = _K.none;
  }

  while (i < words.length) {
    final w = words[i];
    if (w == 'a' && i + 1 < words.length && words[i + 1] == 'hundred') {
      flush();
      current = 1;
      kind = _K.unit;
      i++;
      continue;
    }
    if (w == 'and' && kind == _K.hundred && i + 1 < words.length && _isNumberWord(words[i + 1])) {
      i++;
      continue;
    }
    if (w == 'point' && kind != _K.none && i + 1 < words.length && _units.containsKey(words[i + 1])) {
      final digits = StringBuffer();
      i++;
      while (i < words.length && _units.containsKey(words[i])) {
        digits.write(_units[words[i]]);
        i++;
      }
      out.add('$current.$digits');
      current = 0;
      kind = _K.none;
      continue;
    }
    if (w == 'hundred') {
      current = (kind == _K.none ? 1 : current) * 100;
      kind = _K.hundred;
      i++;
      continue;
    }
    final u = _units[w];
    final teen = _teens[w];
    final ten = _tens[w];
    if (u == null && teen == null && ten == null) break;

    if (u != null) {
      if (kind == _K.tens || kind == _K.hundred || (kind == _K.colloquial && current % 10 == 0)) {
        current += u;
        kind = kind == _K.hundred ? _K.unit : _K.tensUnit;
      } else {
        flush();
        current = u;
        kind = _K.unit;
      }
    } else {
      final v = (teen ?? ten)!;
      if (kind == _K.unit && current < 10) {
        // "one forty" -> 140, "one twelve" -> 112
        current = current * 100 + v;
        kind = teen != null ? _K.teen : _K.colloquial;
      } else if (kind == _K.hundred || (kind == _K.unit && current >= 100)) {
        current += v;
        kind = teen != null ? _K.teen : _K.tens;
      } else {
        flush();
        current = v;
        kind = teen != null ? _K.teen : _K.tens;
      }
    }
    i++;
  }
  flush();
  return i;
}

/// True for a token produced by [normalise] that is a number.
bool isNumber(String t) => _isDigits(t);
