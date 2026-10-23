import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:cryptography/cryptography.dart';

import 'lookups.dart';

const int cardVersion = 1;

/// Shared demo key for the bootcamp. Real key distribution is roadmap.
/// Every install signs and verifies with this one key.
final Uint8List _demoSeed = Uint8List.fromList(
    List<int>.generate(32, (i) => (i * 73 + 41) & 0xff));

final _ed = Ed25519();
Future<SimpleKeyPair>? _keyPair;
Future<SimpleKeyPair> _key() => _keyPair ??= _ed.newKeyPairFromSeed(_demoSeed);

/// Danger sign answers on the card. Order is fixed by the wire format and
/// matches `DangerSign` in visit_schema: convulsions, vaginal bleeding,
/// headache, visual disturbance, oedema, severe abdominal pain, fever,
/// reduced fetal movement, severe pallor.
/// Each entry: 0 not asked, 1 yes, 2 no.
int packSigns(List<int> signs) {
  var bits = 0;
  for (var i = 0; i < signs.length; i++) {
    bits |= (signs[i] & 3) << (2 * i);
  }
  return bits;
}

List<int> unpackSigns(int bits, int count) =>
    [for (var i = 0; i < count; i++) (bits >> (2 * i)) & 3];

class ReferralCard {
  final String patientId;
  final String givenName;
  final String familyName;
  final String community;
  final int? birthYear;
  final int gestationalWeeks;
  final int gravida;
  final int para;
  final int? systolic;
  final int? diastolic;

  /// See [packSigns]. Nine entries.
  final List<int> signs;
  final String referralId;
  final String ruleId;

  /// 0 routine, 1 urgent, 2 emergency. Same order as `Urgency`.
  final int urgency;
  final DateTime issuedAt;
  final String officer;
  final String fromFacility;
  final String toFacility;

  /// ANC contact number of the visit that raised the referral.
  final int contactNumber;
  final double? haemoglobin;

  /// Carried so the receiving facility can see every value that can trigger
  /// a rule (R6 fever, R4 urine protein), not only blood pressure.
  final double? temperatureC;
  final int? urineProtein;

  /// The referring officer's phone, so the facility can call her back.
  final String? officerPhone;

  const ReferralCard({
    required this.patientId,
    required this.givenName,
    required this.familyName,
    required this.community,
    required this.birthYear,
    required this.gestationalWeeks,
    required this.gravida,
    required this.para,
    required this.systolic,
    required this.diastolic,
    required this.signs,
    required this.referralId,
    required this.ruleId,
    required this.urgency,
    required this.issuedAt,
    required this.officer,
    required this.fromFacility,
    required this.toFacility,
    required this.contactNumber,
    this.haemoglobin,
    this.temperatureC,
    this.urineProtein,
    this.officerPhone,
  });
}

class AckCard {
  final String referralId;

  /// 1 arrived, 2 closed. Same order as `ReferralState`.
  final int state;
  final String facility;
  final DateTime arrivedAt;
  final String? outcome;
  final DateTime? followUp;

  /// Who confirmed her arrival, and how to reach them.
  final String? receivedBy;
  final String? receiverPhone;

  const AckCard({
    required this.referralId,
    required this.state,
    required this.facility,
    required this.arrivedAt,
    this.outcome,
    this.followUp,
    this.receivedBy,
    this.receiverPhone,
  });
}

/// A decoded card. The values are always returned so a clinician can still
/// read them when [signatureValid] is false.
class Decoded<T> {
  final T card;
  final bool signatureValid;
  final int payloadBytes;
  const Decoded(this.card, this.signatureValid, this.payloadBytes);
}

class CardFormatException extends FormatException {
  const CardFormatException(super.message);
}

Object _place(Map<int, String> table, String value) =>
    codeFor(table, value) ?? value;

String _unplace(Map<int, String> table, Object? v) =>
    v is int ? (table[v] ?? 'Unknown') : (v as String? ?? 'Unknown');

int _secs(DateTime d) => d.toUtc().millisecondsSinceEpoch ~/ 1000;
DateTime _fromSecs(Object? v) =>
    DateTime.fromMillisecondsSinceEpoch((v as int) * 1000, isUtc: true).toLocal();
int _days(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
DateTime _fromDays(int v) {
  final u = DateTime.fromMillisecondsSinceEpoch(v * 86400000, isUtc: true);
  return DateTime(u.year, u.month, u.day);
}

Map<String, Object?> referralToMap(ReferralCard c) => {
      'v': cardVersion,
      't': 'R',
      'pi': c.patientId,
      'gn': c.givenName,
      'fn': c.familyName,
      'c': _place(communityCodes, c.community),
      if (c.birthYear != null) 'by': c.birthYear,
      'ga': c.gestationalWeeks,
      'g': c.gravida,
      'p': c.para,
      if (c.systolic != null) 's': c.systolic,
      if (c.diastolic != null) 'd': c.diastolic,
      'ds': packSigns(c.signs),
      'id': c.referralId,
      'r': int.parse(c.ruleId.substring(1)),
      'u': c.urgency,
      'ts': _secs(c.issuedAt),
      'o': c.officer,
      'f': _place(facilityCodes, c.fromFacility),
      'to': _place(facilityCodes, c.toFacility),
      'n': c.contactNumber,
      if (c.haemoglobin != null) 'hb': (c.haemoglobin! * 10).round(),
      if (c.temperatureC != null) 'tc': (c.temperatureC! * 10).round(),
      if (c.urineProtein != null) 'up': c.urineProtein,
      if (c.officerPhone != null) 'op': c.officerPhone,
    };

ReferralCard referralFromMap(Map m) => ReferralCard(
      patientId: m['pi'] as String,
      givenName: m['gn'] as String,
      familyName: m['fn'] as String,
      community: _unplace(communityCodes, m['c']),
      birthYear: m['by'] as int?,
      gestationalWeeks: m['ga'] as int,
      gravida: m['g'] as int,
      para: m['p'] as int,
      systolic: m['s'] as int?,
      diastolic: m['d'] as int?,
      signs: unpackSigns(m['ds'] as int, 9),
      referralId: m['id'] as String,
      ruleId: 'R${m['r']}',
      urgency: m['u'] as int,
      issuedAt: _fromSecs(m['ts']),
      officer: m['o'] as String,
      fromFacility: _unplace(facilityCodes, m['f']),
      toFacility: _unplace(facilityCodes, m['to']),
      contactNumber: m['n'] as int,
      haemoglobin: m['hb'] == null ? null : (m['hb'] as int) / 10,
      temperatureC: m['tc'] == null ? null : (m['tc'] as int) / 10,
      urineProtein: m['up'] as int?,
      officerPhone: m['op'] as String?,
    );

Map<String, Object?> ackToMap(AckCard a) => {
      'v': cardVersion,
      't': 'A',
      'id': a.referralId,
      'st': a.state,
      'f': _place(facilityCodes, a.facility),
      'at': _secs(a.arrivedAt),
      if (a.outcome != null) 'oc': _place(outcomeCodes, a.outcome!),
      if (a.followUp != null) 'fu': _days(a.followUp!),
      if (a.receivedBy != null) 'rb': a.receivedBy,
      if (a.receiverPhone != null) 'rp': a.receiverPhone,
    };

AckCard ackFromMap(Map m) => AckCard(
      referralId: m['id'] as String,
      state: m['st'] as int,
      facility: _unplace(facilityCodes, m['f']),
      arrivedAt: _fromSecs(m['at']),
      outcome: m['oc'] == null ? null : _unplace(outcomeCodes, m['oc']),
      followUp: m['fu'] == null ? null : _fromDays(m['fu'] as int),
      receivedBy: m['rb'] as String?,
      receiverPhone: m['rp'] as String?,
    );

Future<String> _sign(Map<String, Object?> map) async {
  final payload = cborEncode(CborValue(map));
  final sig = await _ed.sign(payload, keyPair: await _key());
  final outer = cborEncode(CborList([
    CborBytes(payload),
    CborBytes(sig.bytes),
  ]));
  return base64Url.encode(outer).replaceAll('=', '');
}

/// Payload bytes before base64, for the size budget (target under 400).
int encodedSize(String qr) => _b64(qr).length;

Uint8List _b64(String s) {
  final pad = (4 - s.length % 4) % 4;
  return base64Url.decode(s + '=' * pad);
}

Future<(Map, bool, int)> _open(String qr) async {
  final List<int> payload;
  final List<int> sig;
  try {
    final outer = cborDecode(_b64(qr.trim()));
    if (outer is! CborList || outer.length != 2) {
      throw const CardFormatException('Not a card');
    }
    payload = (outer[0] as CborBytes).bytes;
    sig = (outer[1] as CborBytes).bytes;
  } on CardFormatException {
    rethrow;
  } catch (_) {
    throw const CardFormatException('Not a card');
  }
  final map = cborDecode(payload).toObject();
  if (map is! Map || map['v'] != cardVersion) {
    throw const CardFormatException('Unknown card version');
  }
  final kp = await _key();
  final ok = await _ed.verify(payload,
      signature: Signature(sig, publicKey: await kp.extractPublicKey()));
  return (map, ok, payload.length + sig.length);
}

/// Card kind without verifying, so a scanner can route: 'R' or 'A'.
String? peekKind(String qr) {
  try {
    final outer = cborDecode(_b64(qr.trim())) as CborList;
    final map = cborDecode((outer[0] as CborBytes).bytes).toObject() as Map;
    return map['t'] as String?;
  } catch (_) {
    return null;
  }
}

Future<String> encodeReferral(ReferralCard c) => _sign(referralToMap(c));

Future<Decoded<ReferralCard>> decodeReferral(String qr) async {
  final (m, ok, n) = await _open(qr);
  if (m['t'] != 'R') throw const CardFormatException('Not a referral card');
  try {
    return Decoded(referralFromMap(m), ok, n);
  } catch (_) {
    throw const CardFormatException('Referral card is incomplete');
  }
}

Future<String> encodeAck(AckCard a) => _sign(ackToMap(a));

Future<Decoded<AckCard>> decodeAck(String qr) async {
  final (m, ok, n) = await _open(qr);
  if (m['t'] != 'A') throw const CardFormatException('Not an acknowledgement');
  try {
    return Decoded(ackFromMap(m), ok, n);
  } catch (_) {
    throw const CardFormatException('Acknowledgement is incomplete');
  }
}

/// Crockford base32 without 0, 1, I, L, O, U. Six characters, e.g. K7M4QP.
const _codeAlphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

String newReferralCode([Random? rng]) {
  final r = rng ?? Random.secure();
  return List.generate(6, (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)])
      .join();
}

/// "K7M4QP" to "K7M 4QP".
String groupCode(String code) =>
    code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
