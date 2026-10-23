/// Name search and possible duplicate detection.
///
/// Never merges and never ranks by a score. Search results are ordered
/// alphabetically, then by most recent contact, so nothing is presented as
/// the recommended match. Duplicates are only proposed; a person decides.
library;

import 'package:visit_schema/visit_schema.dart';

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ɛ': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'ɔ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ŋ': 'n', 'ɣ': 'g', 'ʒ': 'z',
};

/// Lowercase, accents folded, letters only, no spaces.
String normalise(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final c = _accents[ch] ?? ch;
    if (RegExp('[a-z]').hasMatch(c)) b.write(c);
  }
  return b.toString();
}

/// A loose phonetic key for transliteration variants common in Dagbani and
/// Mampruli names written in English: Alhassan / Alhasan, Iddrisu / Idrisu,
/// Fuseini / Fusheini, Mohammed / Muhammad.
String phoneticKey(String s) {
  var n = normalise(s);
  if (n.isEmpty) return n;
  n = n
      .replaceAll('sh', 's')
      .replaceAll('ph', 'f')
      .replaceAll('kh', 'k')
      .replaceAll('dh', 'd')
      .replaceAll('th', 't')
      .replaceAll('ck', 'k')
      .replaceAll('q', 'k')
      .replaceAll('y', 'i');
  final first = n[0];
  final rest = n.substring(1).replaceAll(RegExp('[aeiouh]'), '');
  final collapsed = StringBuffer(first);
  for (final ch in rest.split('')) {
    final last = collapsed.toString();
    if (last[last.length - 1] != ch) collapsed.write(ch);
  }
  return collapsed.toString();
}

class Candidate {
  final Patient patient;
  final DateTime? lastContact;
  const Candidate(this.patient, this.lastContact);
}

bool _tokenMatches(String queryToken, String nameToken) {
  final q = normalise(queryToken);
  final t = normalise(nameToken);
  if (q.isEmpty) return true;
  if (t.startsWith(q)) return true;
  return q.length >= 3 && phoneticKey(t).startsWith(phoneticKey(q));
}

/// Patients whose name matches every word in [query], in any order.
List<Candidate> search(String query, List<Candidate> all) {
  final words = query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return const [];
  final out = all.where((c) {
    final tokens = [c.patient.givenName, c.patient.familyName];
    final joined = normalise(c.patient.fullName);
    return words.every((w) =>
        tokens.any((t) => _tokenMatches(w, t)) || joined.contains(normalise(w)));
  }).toList();
  out.sort((a, b) {
    final n = normalise(a.patient.fullName).compareTo(normalise(b.patient.fullName));
    if (n != 0) return n;
    final la = a.lastContact, lb = b.lastContact;
    if (la == null || lb == null) return la == null ? (lb == null ? 0 : 1) : -1;
    return lb.compareTo(la);
  });
  return out;
}

/// Other records that may be the same woman: same phonetic name, same
/// community, and birth years within two of each other.
List<Patient> possibleDuplicates(Patient p, List<Patient> all) => all.where((o) {
      if (o.id == p.id) return false;
      if (normalise(o.community) != normalise(p.community)) return false;
      if (phoneticKey(o.givenName) != phoneticKey(p.givenName)) return false;
      if (phoneticKey(o.familyName) != phoneticKey(p.familyName)) return false;
      final a = o.birthYear, b = p.birthYear;
      return a == null || b == null || (a - b).abs() <= 2;
    }).toList();
