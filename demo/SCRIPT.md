# Lafii demo: voice-over script

15 lines, about 3 minutes in total. Record **one audio file per line**.

## Where the files go

Put them in `demo/voiceover/`, named by line number:

```
demo/voiceover/line01.m4a
demo/voiceover/line02.m4a
...
demo/voiceover/line15.m4a
```

Any of `.wav .mp3 .m4a .aac .ogg .flac .opus .webm` works. `01.m4a` or `line1.m4a` also work.

## How to record

- Same room, same distance from the mic, for all 15 lines.
- Leave about half a second of silence before and after each line. The build adds its own short gap, so you don't need to time anything.
- Speak at your normal pace. If a line runs long, the video holds on that screen until you finish; if the screen action is longer, the video speeds it up.
- If you stumble, re-record just that line and overwrite its file.

## The lines

| # | On screen | Say | ~Length |
|---|---|---|---|
| 01 | Setup: name, zone and facility are filled in | This is Lafii, an app for Community Health Officers in Northern Ghana. Setting up takes one screen: her name, her CHPS zone and her facility. No account, no login, and no internet, ever. | 13s |
| 02 | Home: referrals to chase, women due this week | Amina's day opens on two lists: the referrals she is still waiting to hear back on, and the women due for a visit this week. | 7s |
| 03 | Find a woman: "Fati Alhas" finds two records | Fati Alhassan has come in without her card, so Amina searches by name. Spellings vary, so the search is forgiving. Each record shows community, age and last visit. There is no match score. | 12s |
| 04 | "These may be the same woman": two cards side by side | Two records may be the same woman. The app shows them side by side, with equal weight, and never merges them on its own. Amina asks Fati, and chooses. | 10s |
| 05 | Antenatal visit 4, with the Speak instead button | This is Fati's fourth antenatal visit. Everything can be entered by tap, or Amina can speak the summary instead. | 7s |
| 06 | Blood pressure typed: 140 / 95 | Blood pressure: one forty over ninety five, typed on the phone's number pad. | 5s |
| 07 | Danger signs: Fits No, Bleeding No, Headache Yes | Every danger sign has three answers: yes, no, or not asked. A question nobody asked is never saved as a no. Fits: no. Bleeding: no. Severe headache: yes. | 12s |
| 08 | Consent in Dagbani, then the recording counter | To speak instead, the app first asks Fati's consent, in Dagbani. Speech is turned into text on the phone itself, and the audio is deleted as soon as the values are checked. | 11s |
| 09 | Back to the visit screen | Today Amina stays with tapping. Either way, the values arrive at the same check. | 5s |
| 10 | "Check what you recorded": a value unconfirmed and confirmed again | Every value is confirmed one at a time. There is no confirm-all button. A value that has not been confirmed is left out of the assessment, and anything not recorded says Missing. Nothing is guessed. | 13s |
| 11 | Urgent: Signs of pre-eclampsia | The assessment comes from a fixed protocol rule, not from AI. High blood pressure with a severe headache: signs of pre-eclampsia, refer today. It shows exactly which values triggered it, and Amina can disagree and record why. | 14s |
| 12 | Referral code, signed QR, "Tell Fati" | Amina issues the referral. She writes this short code on Fati's paper card. The hospital scans the signed QR code with no network, and the app tells Amina what to say to Fati. | 11s |
| 13 | Home, then "Not yet arrived" | Back home, Fati joins the list of women who have not yet arrived, most serious first. When the hospital's acknowledgement is scanned, she comes off the list. | 10s |
| 14 | October report: register line and DHIMS2 figures | And the visit pays Amina back. Her register line and her monthly DHIMS2 figures are filled in for her, ready to export. | 8s |
| 15 | Home | One visit, entered once: a clinical record, a register line, a monthly report, and a referral that comes back. All on the phone. All offline. | 10s |

Pronunciation: CHPS is "chips". DHIMS2 is "D-H-I-M-S two".

## Building the video

From `demo/tools/`:

```
python build_video.py --check     # shows which lines are present
python build_video.py             # writes demo/lafii-demo.mp4
```

Needs ffmpeg (`winget install Gyan.FFmpeg`). A missing line is left silent rather than failing, so you can build part-way to check timing.

`demo/lafii-demo-draft.mp4` is the same video narrated by a Windows test voice, for timing only. Don't publish it.

## Re-recording the screen

The screen footage in `demo/screen/` was driven automatically on the Android emulator. To redo it, start the emulator, install the demo build, and run:

```
flutter build apk --release --target-platform android-x64 --dart-define=LAFII_DEMO=true
adb install -r build/app/outputs/flutter-apk/app-release.apk
python demo/tools/walkthrough.py rehearse   # screenshots to demo/tools/shots/
python demo/tools/walkthrough.py record     # clips to demo/screen/
```

The `LAFII_DEMO` flag only exposes the accessibility tree so the script can find buttons by their text. Never ship that build.
