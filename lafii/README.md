# Lafii app (Flutter)

The Android app for Lafii. For what the project is, why it exists and how the pieces fit, see the [main README](../README.md). The rules every change must follow are in [CLAUDE.md](../CLAUDE.md).

## Run

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter analyze
flutter test
```

The pure Dart logic (rules, card format, speech extraction, reports, name search) lives in `../packages/` and has its own tests: `cd ../packages/<name> && dart test`.

## Build

```bash
flutter build apk --release --split-per-abi
```

Most phones need `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Building needs **NDK 28.2.13676358** and the **Android 37** platform from Android Studio's SDK Manager.

## Layout

```
lib/
  main.dart              start-up, picks Setup, Refer home or Receive home
  theme.dart             colours, type and spacing tokens
  format.dart            dates, phone numbers, plain-text numbers
  data/
    app_state.dart       all app state; every change is written to the phone at once
    store.dart           encrypted SQLCipher database, append-only events table
    seed.dart            demo women and referrals (Kpasenkpe and nearby)
    card_findings.dart   rebuilds "referred because" on the receiving phone
  speech/
    recogniser.dart      microphone to Vosk, in memory only
  screens/
    setup.dart           first launch and Settings (refer or receive, phone number)
    home.dart            due this week, referrals to chase
    find.dart            search, possible duplicates, register a new woman
    visit.dart           tap entry, tri-state danger signs
    speech.dart          consent, then recording
    confirm.dart         confirm each value; no confirm-all
    outcome.dart         assessment, disagreement, routine outcome, referral QR
    receive.dart         receive home, arrival, acknowledgement QR
    chase.dart           not yet arrived, loop closed
    report.dart          register lines, monthly figures, CSV export
    scan_flows.dart      QR scanning and routing
  ui/widgets.dart        shared components
assets/
  fonts/                 bundled fonts (never downloaded)
  models/                Vosk small English speech model
```

## Things to know

- **No network.** Release builds must not declare `INTERNET`. ML Kit pulls it in, so `android/app/src/main/AndroidManifest.xml` removes it. Check with `aapt dump permissions` after adding any plugin.
- **R8 and Vosk.** `android/app/proguard-rules.pro` keeps JNA and Vosk classes. Without it, release builds crash at launch.
- **Speech switch.** `kSpeechEnabled` in `lib/data/app_state.dart` turns voice entry on or off.
- **Demo builds.** `--dart-define=LAFII_DEMO=true` exposes the accessibility tree so the demo scripts in `../demo/tools` can drive the app. Never ship that build.
- **Emulator microphone.** Voice entry needs Extended controls > Microphone > *Virtual microphone uses host audio input* switched on after every emulator start, and even then may hear silence. A real phone is more reliable.
