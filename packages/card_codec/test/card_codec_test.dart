import 'dart:convert';

import 'package:card_codec/card_codec.dart';
import 'package:test/test.dart';

final _card = ReferralCard(
  patientId: 'p-0001-fati-alhassan',
  givenName: 'Fati',
  familyName: 'Alhassan',
  community: 'Kpasenkpe',
  birthYear: 1998,
  gestationalWeeks: 32,
  gravida: 3,
  para: 2,
  systolic: 140,
  diastolic: 95,
  signs: [2, 2, 1, 0, 0, 0, 2, 0, 0],
  referralId: 'K7M4QP',
  ruleId: 'R4',
  urgency: 1,
  issuedAt: DateTime(2026, 10, 17, 10, 14),
  officer: 'Amina Mahama',
  fromFacility: 'Kpasenkpe CHPS',
  toFacility: 'Walewale Hospital',
  contactNumber: 4,
  haemoglobin: 10.5,
  temperatureC: 38.4,
  urineProtein: 2,
  officerPhone: '0244174417',
);

void main() {
  test('referral round trip with a valid signature', () async {
    final qr = await encodeReferral(_card);
    final d = await decodeReferral(qr);
    expect(d.signatureValid, isTrue);
    final c = d.card;
    expect(c.givenName, 'Fati');
    expect(c.community, 'Kpasenkpe');
    expect(c.systolic, 140);
    expect(c.diastolic, 95);
    expect(c.signs, _card.signs);
    expect(c.ruleId, 'R4');
    expect(c.issuedAt, DateTime(2026, 10, 17, 10, 14));
    expect(c.toFacility, 'Walewale Hospital');
    expect(c.haemoglobin, 10.5);
    expect(c.temperatureC, 38.4);
    expect(c.urineProtein, 2);
    expect(c.officerPhone, '0244174417');
    expect(peekKind(qr), 'R');
  });

  test('referral payload stays under 400 bytes', () async {
    final qr = await encodeReferral(_card);
    expect(encodedSize(qr), lessThan(400));
  });

  test('cards without the optional values still decode', () async {
    final bare = ReferralCard(
      patientId: 'p2', givenName: 'Memunatu', familyName: 'Iddrisu', community: 'Wulugu',
      birthYear: null, gestationalWeeks: 18, gravida: 1, para: 0, systolic: null,
      diastolic: null, signs: List.filled(9, 0), referralId: 'H3W9TB', ruleId: 'R2',
      urgency: 2, issuedAt: DateTime(2026, 10, 22, 9), officer: 'Amina Mahama',
      fromFacility: 'Kpasenkpe CHPS', toFacility: 'Walewale Hospital', contactNumber: 2,
    );
    final c = (await decodeReferral(await encodeReferral(bare))).card;
    expect(c.temperatureC, isNull);
    expect(c.urineProtein, isNull);
    expect(c.systolic, isNull);
  });

  test('tampered payload fails the signature check but still decodes', () async {
    final qr = await encodeReferral(_card);
    final raw = base64Url.decode(qr + '=' * ((4 - qr.length % 4) % 4));
    // Flip the systolic value 140 (0x18 0x8c) to 120 (0x18 0x78).
    final i = _indexOf(raw, [0x18, 0x8c]);
    expect(i, greaterThanOrEqualTo(0));
    raw[i + 1] = 0x78;
    final tampered = base64Url.encode(raw).replaceAll('=', '');
    final d = await decodeReferral(tampered);
    expect(d.signatureValid, isFalse);
    expect(d.card.systolic, 120);
  });

  test('acknowledgement round trip', () async {
    final qr = await encodeAck(AckCard(
      referralId: 'K7M4QP',
      state: 1,
      facility: 'Walewale Hospital',
      arrivedAt: DateTime(2026, 10, 17, 11, 1),
      outcome: 'Admitted',
      followUp: DateTime(2026, 10, 24),
      receivedBy: 'Rahinatu Seidu',
      receiverPhone: '0209981234',
    ));
    final d = await decodeAck(qr);
    expect(d.signatureValid, isTrue);
    expect(d.card.referralId, 'K7M4QP');
    expect(d.card.receivedBy, 'Rahinatu Seidu');
    expect(d.card.receiverPhone, '0209981234');
    expect(d.card.outcome, 'Admitted');
    expect(d.card.followUp, DateTime(2026, 10, 24));
    expect(peekKind(qr), 'A');
  });

  test('garbage is rejected', () async {
    expect(() => decodeReferral('hello'), throwsA(isA<CardFormatException>()));
  });

  test('referral codes avoid ambiguous characters', () {
    for (var i = 0; i < 200; i++) {
      final c = newReferralCode();
      expect(c, hasLength(6));
      expect(c, isNot(matches(RegExp('[01ILOU]'))));
    }
    expect(groupCode('K7M4QP'), 'K7M 4QP');
  });
}

int _indexOf(List<int> h, List<int> n) {
  for (var i = 0; i <= h.length - n.length; i++) {
    var ok = true;
    for (var j = 0; j < n.length; j++) {
      if (h[i + j] != n[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}
