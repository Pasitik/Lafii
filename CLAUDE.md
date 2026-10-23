# CLAUDE.md

Context for any agent working in this repository. Read this fully before writing code.

## 1. What this is

An offline-first Android app that lets a Community Health Officer in rural Northern Ghana record an antenatal visit once, and get back three things: a clinical record, the line for her paper register, and her monthly aggregate report. When the visit triggers a danger sign, it issues a referral the mother carries as a QR card, which a district hospital can read with no network, and which produces an acknowledgement that eventually reaches the officer.

Built for the UNICEF StartUp Lab AI for Nurturing Care Hackathon. Three-day build window. Two developers.

## 2. Why it exists, and why that shapes the code

A Community Health Officer refers a woman to a district hospital on a paper slip and then never learns whether she arrived, what was done, or whether she survived. Referral completion is not measured anywhere in the Ghanaian health system. That is the problem.

Ghana already tried the obvious fix. In June 2023 the Ghana Health Service rolled out the MCH e-Tracker across 241 facilities in Savannah Region, 80 percent of them CHPS compounds. Facility use fell from 58 percent to 23 percent within seven months. Only 17 percent used it across all seven months. The reasons the staff gave:

- They had to fill in both the app and the paper register, because paper reporting is a government directive. The app was additional work, never a replacement.
- The reporting modules were not configured, so the system could not return the aggregate figures they needed to compile their own mandatory monthly report.
- Synchronisation failed so often that staff walked away from their facilities to find mobile coverage.

Usage fell every month except October, the month a supervisory visit took place. Usage tracked supervision, not usefulness.

**The engineering consequence.** The officer bears all the data entry cost and receives none of the benefit. Every design decision in this repository exists to invert that. If a change you are about to make adds effort for the officer without returning something in the same session, it is the wrong change. Say so rather than implementing it.

## 3. Hard invariants

These are not preferences. Breaking any of them breaks the product's core claim. If a task appears to require breaking one, stop and raise it.

1. **No accept-all.** There is no confirm-all, select-all or approve-all control anywhere in the app. Every numeric clinical value is confirmed individually by tap. Do not add one for convenience, and do not add one because a screen feels tedious.
2. **Unconfirmed means missing.** The rule engine accepts only fields with provenance `confirmed` or `manual`. A field with provenance `extracted` is treated as `missing`. Enforce this at the package boundary in Dart, not in the UI. There must be a unit test proving it.
3. **No model makes a clinical decision.** Danger sign detection is a deterministic rule engine. AI converts speech to candidate field values and nothing else.
4. **No network.** The MVP makes no outbound request of any kind and does not declare the `INTERNET` permission in the manifest. If a task seems to need the network, it is out of scope.
5. **No loading states.** No spinners, skeletons, progress bars or percentages. Saving is local and instant. An app that implies a network call in a place with no network loses trust immediately.
6. **Danger signs are tri-state.** Not asked, Yes, No. Never a boolean and never a toggle switch, because a toggle defaults to off and silently records a negative answer to a question nobody asked.
7. **Never auto-merge records.** Identity matching proposes a confidence-scored link that a human confirms and can reverse. Two records are never combined by code.
8. **Never show a confidence score in the UI.** Show evidence instead: community, age, last contact date. A number invites over-trust.
9. **Missing values are never imputed.** Not from a previous visit, not from a population average, not as zero. Render the word `Missing`.
10. **Audio is discarded.** The recording is deleted as soon as fields are extracted. No transcript is persisted. Nothing audio-related is written to durable storage.
11. **Clinical events are append-only.** They are never merge-deleted or overwritten during sync. Scalar corrections may use last-writer-wins; observations may not.
12. **Tap entry is always a complete path.** Every field reachable by voice must be reachable by tap. Tap entry is never styled or described as a fallback.

## 4. Scope

**In scope for the three-day build**

Antenatal visits only. Capture by tap and by voice. Confirm screen with provenance. Rule engine with roughly ten danger signs. Referral issue with a signed QR. Receive mode with offline card decode and arrival confirmation. Acknowledgement QR and loop closure. Chase list. Register line and monthly aggregate generation. Settings.

**Explicitly out of scope. Do not build these, do not scaffold for them.**

On-device language model for extraction. Any server or district node. Bluetooth, Wi-Fi Direct or Nearby Connections. SMS. Vision model for paper registers. DHIS2 or DHIMS2 transmission. Postnatal, newborn and sick child visit types. Authentication, accounts, multi-user. Caregiver-facing audio. Dagbani speech recognition.

Several of these are real roadmap items and appear in the pitch as such. They are not in the code.

## 5. Architecture

No server. Everything is Dart. The backend developer writes pure packages with no Flutter dependency; the mobile developer imports them.

```
packages/
  visit_schema/   models, JSON, provenance enforcement   (pure Dart)
  rules/          danger sign engine, returns Assessment  (pure Dart)
  extract/        transcript string to partial AncVisit   (pure Dart)
  card_codec/     CBOR pack/unpack, Ed25519 sign/verify   (pure Dart)
  reports/        register line, monthly aggregate        (pure Dart)
  resolver/       phonetic name matching, scoring         (pure Dart)
lafii/            Flutter app, screens, sqflite, QR, speech
design_handoff_referral_app/   HTML design reference (do not ship)
```

The app lives in `lafii/` rather than `app/`. `visit_schema` is the only package the others share. Nothing depends on `lafii`. Do not put Flutter imports in `packages/`.

**Stack**

Flutter (Dart), Android only, minSdk 23. `sqflite_sqlcipher` for encrypted local storage, keyed from the Android Keystore through `flutter_secure_storage`. `mobile_scanner` for QR read, `qr_flutter` for QR render. `cbor` and `cryptography` for the card payload. `share_plus` and `path_provider` for CSV export through the share sheet. Vosk for speech through `vosk_flutter_service` (the original `vosk_flutter` is Dart 2 only; this fork wraps the same official `com.alphacephei:vosk-android`), with the small English model bundled at `lafii/assets/models` and the extract vocabulary as its grammar. Never call `ModelLoader.loadFromNetwork`. Microphone capture is done by the `record` package (plain mic source, automatic gain, capped software boost, PCM streamed in memory only) and fed to the recogniser directly; the plugin's own `SpeechService` capture uses the voice-recognition source, which arrived as near silence in testing. `speech_to_text` on Android's recogniser remains the agreed fallback. compileSdk is 37 because `permission_handler_android` requires it. Kotlin platform channels only where a native SDK requires it.

**Critical build detail.** `mobile_scanner` must use the bundled ML Kit variant, not the Play Services one. The default downloads its model on first use, which means the first scan fails on a phone that has never been online. Since mobile_scanner 5 the bundled model is the default; never set `dev.steenbakker.mobile_scanner.useUnbundled=true`. This must be verified in airplane mode on a fresh install.

## 6. Data model

This is the shared contract. Do not change it without flagging it explicitly, because both developers build against it.

```dart
enum Provenance { extracted, confirmed, manual, missing }
enum Urgency { routine, urgent, emergency }
enum ReferralState { raised, arrived, closed }
enum TriState { notAsked, yes, no }

class Field<T> {
  T? value;
  Provenance provenance;
  bool get usableByRules =>
      provenance == Provenance.confirmed || provenance == Provenance.manual;
}

class Patient {
  String id; String givenName; String familyName;
  String community; int? birthYear; String? phone;
}

class Pregnancy {
  String id; String patientId; int gravida; int para; int gestationalWeeks;
}

class AncVisit {
  String id; String patientId; String pregnancyId;
  DateTime visitDate; int contactNumber;          // ANC contact 1..8

  Field<int> systolic; Field<int> diastolic;
  Field<double> temperatureC; Field<double> weightKg; Field<int> pulse;
  Field<int> fundalHeightCm; Field<int> fetalHeartRate;

  Field<TriState> headache, visualDisturbance, oedema, vaginalBleeding,
      fever, reducedFetalMovement, convulsions, severeAbdominalPain,
      severePallor;

  Field<int>? urineProtein;      // dipstick 0..4
  Field<double>? haemoglobin;
  String? freeNote;
}

class Assessment {
  String ruleId; String ruleTitle; Urgency urgency;
  List<String> triggeredBy;      // human readable, e.g. "Blood pressure 140/95"
  String recommendation;
}

class Referral {
  String id;                     // six char human readable, e.g. K7M4QP
  String patientId; String visitId; String ruleId;
  Urgency urgency; DateTime raisedAt; String raisedBy;
  ReferralState state;
  DateTime? arrivedAt; String? arrivedFacility;
  String? outcomeNote; DateTime? followUpDate;
}
```

Additive types in `visit_schema` that do not change the above: `RuleInput` (the only input the rule engine accepts; built by `RuleInput.from`, which drops non-usable fields), `NotUsed`, `DangerSign` and `Measure` (labels and ordering), `ClinicalEvent` and `mergeEventLogs`.

## 7. The rule set

First match wins. Every rule returns the inputs that triggered it, for display.

| ID | Condition | Urgency |
|:---|:---|:---|
| R1 | Convulsions | Emergency |
| R2 | Vaginal bleeding | Emergency |
| R3 | Systolic >= 160 or diastolic >= 110 | Emergency |
| R4 | Systolic >= 140 or diastolic >= 90, with any of headache, visual disturbance, oedema, severe abdominal pain, urine protein >= 2 | Urgent, suspected pre-eclampsia |
| R5 | Systolic >= 140 or diastolic >= 90, no other sign | Urgent |
| R6 | Temperature >= 38.0 | Urgent |
| R7 | Reduced fetal movement at gestation >= 28 weeks | Urgent |
| R8 | Severe pallor, or haemoglobin < 7 where measured | Urgent |
| R9 | Severe abdominal pain alone | Urgent |
| R10 | Nothing triggered | Routine, schedule next contact |

**These thresholds require sign-off from the team midwife before shipping.** If you are asked to add, remove or change a rule, note in your response that clinical sign-off is required. Do not invent clinical logic. Until sign-off, `kMidwifeSignedOff` in `packages/rules` stays false and the assessment screen says "Awaiting sign-off by the team midwife."

## 8. The card payload

CBOR encoded, Ed25519 signed, encoded as a base64url string inside the QR.

Referral QR carries: version, patient id, given name, family name, community code, birth year, gestational weeks, gravida, para, systolic, diastolic, danger sign bitfield, referral id, rule id, urgency, issued timestamp, officer id, signature. It also carries origin and destination facility codes, the ANC contact number, and haemoglobin, temperature and urine protein where confirmed. Together these are every input a rule can fire on, so the receiving phone re-runs the same rule engine on the card and shows the exact "referred because" findings the officer saw; if its result does not match the rule ID on the card, it says so rather than showing a list.

Acknowledgement QR carries: version, referral id, state, facility code, arrived timestamp, outcome code, follow-up date, signature. It also carries the name and phone number of the clinician who confirmed arrival.

Each officer's phone number is collected once at setup (both modes) and carried on every card that phone issues: the referring officer's on the referral (`op`), the receiving clinician's on the acknowledgement (`rp`, with name `rb`), so either end can call the other. These are staff numbers, not the woman's.

Use single or two character CBOR map keys. Replace repeated strings with lookup codes bundled in the app. Target under 400 bytes so the QR stays readable from a phone screen at arm's length. Error correction level M.

The keypair is a hardcoded shared demo key for the bootcamp. Real key distribution is roadmap and should not be scaffolded.

## 9. Extraction

Grammar and regex only. No model.

Numbers are extracted deterministically and are never produced by anything probabilistic. Blood pressure must parse "one forty over ninety five", "140 over 95" and "systolic 140 diastolic 95". Boolean symptoms are detected by term list with a negation window, so "no bleeding, no fever, but headache" yields bleeding no, fever no, headache yes.

Does not attempt self-correction, temporal grounding of phrases like "since Sunday", or paraphrase resolution. Those are the stated reason a small language model is the next build.

Everything extracted is written with provenance `extracted` and must be confirmed before it counts.

## 10. UI rules

The screens follow the design handoff in `design_handoff_referral_app/` (AmaliTech tokens), with the bans below applied on top. Where the handoff and this section disagree, this section wins.

**Tokens.** Primary navy `#08283B`, pressed `#051823`. Surface `#FDFDFD`, card `#FFFFFF`. Text `#1A1A18` strong, `#3E3D3A` body, `#656461` muted, never lighter. Borders `#E5E7EB`, inputs `#D1D5DB`, dividers `#F0F1F3`. Unconfirmed or unset is a dashed `#7E7D7B` outline. Emergency `#C81E1E`, Urgent `#B48700`, Routine `#046C4E`. All tokens live in `lafii/lib/theme.dart`.

Fonts are Inter (UI), Poppins (titles) and JetBrains Mono (numbers, codes, register lines), bundled as assets under `lafii/assets/fonts`. Never use the `google_fonts` package: it downloads at runtime.

Corner radius 8. Touch targets never below 48. Screen padding 22. Rows at least 60 where they are tappable list rows.

**Never produce.** Shadows of any kind. Gradients. Badge pills, chips or tags (single-select choices are a segmented control). Icons beyond a chevron on a tappable row. Emoji. Floating action buttons. Progress rings or statistic tiles. Placeholder names like John Doe. Centred text, except a button label, the referral code box and the recording counter.

**Status is never a coloured capsule.** It is a 3px left edge rule plus a plain text word: Routine, Urgent, Emergency. A full-width banner is allowed for the finding on the assessment screen.

**Copy.** Plain and factual. "Awaiting confirmation" not "Pending follow-ups". "Record a visit" not "Start new session". No exclamation marks, no greeting, no user's first name, no em dashes anywhere in interface text. Never "the system recommends" or "AI suggests".

## 11. Sample data

Always use real Northern Ghanaian names and real settlements in West Mamprusi, North East Region. Never Akan names, never Southern Ghanaian places. A judging panel in Tamale will notice. The design handoff uses Akan placeholder names; do not copy them.

Names: Fati Alhassan, Memunatu Iddrisu, Abibata Fuseini, Ayishetu Sulemana, Damata Yakubu, Sanatu Abdulai, Hawabu Fuseini, Rukaya Alhassan, Zulaiha Mohammed, Salamatu Baba.

Communities: Kpasenkpe, Wulugu, Janga, Loagri, Nasia, Yagaba. Referral destination: Walewale Hospital. Officer: Amina Mahama. Language for consent prompts: Dagbani.

Seed one deliberate near-duplicate pair with a transliteration variant, for example Fati Alhassan and Fati Alhasan, to exercise the resolver. Seed data lives in `lafii/lib/data/seed.dart` and loads on first setup in refer mode.

## 12. Testing

Minimum bar before anything is considered done:

- One unit test per rule, asserting urgency and triggered inputs.
- A test proving an `extracted` field does not trigger a rule.
- A `card_codec` round-trip test, plus a tampered-payload test asserting signature failure.
- A negation test in `extract`.
- A merge test asserting clinical events are not deleted.

Pure packages must be testable with `dart test` and no Flutter dependency.

## 13. Domain glossary

**CHPS** Community-based Health Planning and Services. The community level tier of Ghana's health system. Pronounced "chips".
**CHO** Community Health Officer. Staffs a CHPS zone. The primary user.
**ANC** Antenatal care. A pregnancy is followed across numbered contacts, typically 1 to 8.
**DHIMS2** Ghana's national aggregate health reporting system, built on DHIS2. Monthly submission is mandatory.
**e-Tracker** The DHIS2 tracker Android app for patient-level maternal and child health data. The system described in section 2.
**IMCI** Integrated Management of Childhood Illness. A WHO clinical protocol.
**Gravida / para** Number of pregnancies and number of births.
**Fundal height** Uterus measurement in cm, roughly tracks gestational weeks.
**Pre-eclampsia** High blood pressure with organ involvement in pregnancy. A leading cause of maternal death and the primary case this MVP demonstrates.
**Back referral** Information returned from the receiving facility to the referring officer after treatment.

## 14. Working agreements

- The schema in section 6 is frozen. Flag any needed change rather than making it.
- Do not add a dependency without saying why and what it replaces.
- Prefer cutting scope to extending time. The build window is fixed and cannot move.
- If a request conflicts with an invariant in section 3, say so and propose an alternative.
- When something clinical is uncertain, say it needs the midwife rather than guessing.
- Build order is tap entry first, then rules, then referral and card, then receive mode, then speech last. A complete working loop with no AI at all should exist before any speech code is written. Speech is behind `kSpeechEnabled` in `lafii/lib/data/app_state.dart`; turn it off to demo the tap-only loop.
