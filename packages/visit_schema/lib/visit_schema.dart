/// Shared contract between the pure packages and the app.
///
/// Section 6 of CLAUDE.md is frozen. Everything in `models.dart` mirrors it.
/// `rule_input.dart` and `events.dart` are additive and do not change any
/// frozen type.
library;

export 'src/models.dart';
export 'src/rule_input.dart';
export 'src/events.dart';
