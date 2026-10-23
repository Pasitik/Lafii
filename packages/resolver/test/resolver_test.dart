import 'package:resolver/resolver.dart';
import 'package:test/test.dart';
import 'package:visit_schema/visit_schema.dart';

Patient _p(String id, String g, String f, String c, int? by) =>
    Patient(id: id, givenName: g, familyName: f, community: c, birthYear: by);

final _fati = _p('1', 'Fati', 'Alhassan', 'Kpasenkpe', 1998);
final _fati2 = _p('2', 'Fati', 'Alhasan', 'Kpasenkpe', 1999);
final _fatiFar = _p('3', 'Fati', 'Alhassan', 'Wulugu', 1990);
final _memunatu = _p('4', 'Memunatu', 'Iddrisu', 'Wulugu', 2000);

void main() {
  test('transliteration variants share a phonetic key', () {
    expect(phoneticKey('Alhassan'), phoneticKey('Alhasan'));
    expect(phoneticKey('Iddrisu'), phoneticKey('Idrisu'));
    expect(phoneticKey('Fuseini'), phoneticKey('Fusheini'));
  });

  test('search is spelling tolerant and ordered without a score', () {
    final all = [
      Candidate(_fatiFar, DateTime(2026, 6, 2)),
      Candidate(_fati2, DateTime(2026, 3, 11)),
      Candidate(_fati, DateTime(2026, 9, 19)),
      Candidate(_memunatu, null),
    ];
    final r = search('fati alhas', all);
    expect(r.map((c) => c.patient.id), ['2', '1', '3']);
    expect(search('idrisu', all).single.patient.id, '4');
    expect(search('  ', all), isEmpty);
  });

  test('possible duplicates need same community and close age', () {
    final d = possibleDuplicates(_fati, [_fati, _fati2, _fatiFar, _memunatu]);
    expect(d.map((p) => p.id), ['2']);
  });
}
