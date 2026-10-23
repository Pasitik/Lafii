import 'package:card_codec/card_codec.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'chase.dart';
import 'find.dart';
import 'receive.dart';
import 'visit.dart';

/// Camera QR reader. Uses the bundled ML Kit model, so it works on a phone
/// that has never been online. Returns the raw text of the first code seen.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      scroll: false,
      header: ScreenHeader(title: widget.title, sub: Text(widget.hint, style: T.ui(14, height: 1.4))),
      body: ClipRRect(
        borderRadius: BorderRadius.circular(Sp.radius),
        child: ColoredBox(
          color: C.strong,
          child: MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'The camera is not available. Allow camera access for this app in '
                'Android settings, then try again.',
                style: T.ui(15, color: C.surface, height: 1.5),
              ),
            ),
            onDetect: (capture) {
              if (_done) return;
              final raw = capture.barcodes
                  .map((b) => b.rawValue)
                  .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
              if (raw == null) return;
              _done = true;
              Navigator.pop(context, raw);
            },
          ),
        ),
      ),
      bottom: BottomBar(children: [
        SecondaryButton('Cancel', onPressed: () => Navigator.pop(context)),
      ]),
    );
  }
}

Future<String?> _scan(BuildContext context, String title, String hint) => Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => ScannerScreen(title: title, hint: hint)));

void _message(BuildContext context, String title, String body) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => MessageScreen(title: title, body: body)));

/// Home "Scan card": her referral card opens her record; an acknowledgement
/// closes the referral.
Future<void> scanCardFromHome(BuildContext context) async {
  final raw = await _scan(context, 'Scan her card',
      'Hold the QR on her card, or on the hospital phone, inside the frame.');
  if (raw == null || !context.mounted) return;
  switch (peekKind(raw)) {
    case 'A':
      return applyAcknowledgement(context, raw);
    case 'R':
      final s = AppScope.read(context);
      final d = await decodeReferral(raw);
      if (!context.mounted) return;
      final p = s.patients[d.card.patientId];
      if (p == null) {
        // Registered on another phone. Show what her card says, and offer to
        // find her or register her here with the card's details filled in.
        // Nothing is created until the officer chooses.
        final c = d.card;
        final read = ReceivedReferral(card: c, signatureValid: d.signatureValid, scannedAt: s.now);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (ctx) => ArrivalScreen(
                      received: read,
                      actions: BottomBar(
                        note: 'She is not registered on this phone.',
                        children: [
                          SecondaryButton('Find by name',
                              onPressed: () => Navigator.pushReplacement(
                                  ctx,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          FindScreen(initialQuery: '${c.givenName} ${c.familyName}')))),
                          PrimaryButton('Register her here',
                              onPressed: () => Navigator.pushReplacement(
                                  ctx,
                                  MaterialPageRoute(
                                      builder: (_) => RegisterScreen(
                                            initialName: '${c.givenName} ${c.familyName}',
                                            community: c.community,
                                            age: c.birthYear == null ? null : s.now.year - c.birthYear!,
                                            weeks: c.gestationalWeeks,
                                            gravida: c.gravida,
                                            para: c.para,
                                          )))),
                        ],
                      ),
                    )));
        return;
      }
      openVisitFor(context, p);
    default:
      _message(context, 'Not a referral card',
          'This QR code was not made by this app. Find her by name instead.');
  }
}

Future<void> scanAcknowledgement(BuildContext context) async {
  final raw = await _scan(context, 'Scan an acknowledgement',
      'From the hospital phone, or from her card when she returns.');
  if (raw == null || !context.mounted) return;
  await applyAcknowledgement(context, raw);
}

Future<void> applyAcknowledgement(BuildContext context, String raw) async {
  final s = AppScope.read(context);
  final Decoded<AckCard> d;
  try {
    d = await decodeAck(raw);
  } on CardFormatException {
    if (context.mounted) {
      _message(context, 'Not an acknowledgement',
          'This QR code is not an acknowledgement from a receiving facility.');
    }
    return;
  }
  if (!context.mounted) return;
  if (!d.signatureValid) {
    return _message(context, 'Signature not valid',
        'This acknowledgement may have been changed. The referral stays open. '
        'Ask the facility to show it again.');
  }
  final r = s.applyAck(d.card);
  if (r == null) {
    return _message(context, 'Not on this phone',
        'Referral ${groupCode(d.card.referralId)} was not issued on this phone.');
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => LoopClosedScreen(referral: r)));
}

/// Receive mode: read an arriving woman's card.
Future<void> scanArrivingCard(BuildContext context) async {
  final raw = await _scan(context, 'Scan arriving card',
      'Hold the QR on her card or on the referring phone inside the frame.');
  if (raw == null || !context.mounted) return;
  final s = AppScope.read(context);
  final Decoded<ReferralCard> d;
  try {
    d = await decodeReferral(raw);
  } on CardFormatException {
    if (context.mounted) {
      _message(context, 'Not a referral card',
          'This QR code is not a referral from a CHPS officer.');
    }
    return;
  }
  if (!context.mounted) return;
  final existing = s.received[d.card.referralId];
  final rec = existing ??
      ReceivedReferral(card: d.card, signatureValid: d.signatureValid, scannedAt: s.now);
  if (existing == null) s.storeReceived(rec);
  Navigator.push(context, MaterialPageRoute(builder: (_) => ArrivalScreen(received: rec)));
}
