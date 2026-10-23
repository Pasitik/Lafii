/// Lookup codes bundled with the app. Codes are part of the wire format:
/// never renumber an entry, only append.
library;

const communityCodes = <int, String>{
  1: 'Kpasenkpe',
  2: 'Wulugu',
  3: 'Janga',
  4: 'Loagri',
  5: 'Nasia',
  6: 'Yagaba',
  7: 'Walewale',
};

const facilityCodes = <int, String>{
  1: 'Walewale Hospital',
  2: 'Kpasenkpe CHPS',
  3: 'Wulugu Health Centre',
  4: 'Janga CHPS',
  5: 'Loagri CHPS',
  6: 'Nasia CHPS',
  7: 'Yagaba CHPS',
};

const outcomeCodes = <int, String>{
  1: 'Admitted',
  2: 'Treated, sent home',
  3: 'Transferred',
};

int? codeFor(Map<int, String> table, String? value) {
  if (value == null) return null;
  for (final e in table.entries) {
    if (e.value == value) return e.key;
  }
  return null;
}
