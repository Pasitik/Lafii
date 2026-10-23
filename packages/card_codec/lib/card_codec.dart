/// Referral and acknowledgement QR payloads.
///
/// Wire format: base64url( CBOR [ bstr payload, bstr signature ] ), where the
/// payload is a CBOR map with one or two character keys and the signature is
/// Ed25519 over the payload bytes. Repeated strings are replaced with the
/// lookup codes in `lookups.dart`.
library;

export 'src/codec.dart';
export 'src/lookups.dart';
