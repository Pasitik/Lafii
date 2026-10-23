"""One-phone demo recording guide for Lafii.

python demo_guide_pdf.py -> release/Lafii-one-phone-demo-guide.pdf
"""
import os

from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (CondPageBreak, Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FONTS = os.path.join(ROOT, "lafii", "assets", "fonts")
for name, file in [("Inter", "Inter-400.ttf"), ("Inter-Medium", "Inter-500.ttf"),
                   ("Inter-SemiBold", "Inter-600.ttf"), ("Inter-Bold", "Inter-700.ttf"),
                   ("Poppins-Bold", "Poppins-700.ttf"), ("Mono", "JetBrainsMono-600.ttf")]:
    pdfmetrics.registerFont(TTFont(name, os.path.join(FONTS, file)))
pdfmetrics.registerFontFamily("Inter", normal="Inter", bold="Inter-Bold",
                              italic="Inter", boldItalic="Inter-Bold")

NAVY = HexColor("#08283B")
BODY = HexColor("#3E3D3A")
MUTED = HexColor("#656461")
STRONG = HexColor("#1A1A18")
BORDER = HexColor("#E5E7EB")
DIVIDER = HexColor("#F0F1F3")
TINT = HexColor("#EFF7FE")
WARN = HexColor("#FDF6B2")
ROLE = {"R": ("Refer", HexColor("#08283B")),       # phone in Refer mode (Amina)
        "H": ("Receive", HexColor("#046C4E")),     # phone in Receive mode (hospital)
        "L": ("Laptop", HexColor("#656461")),      # laptop or phone settings
        "P": ("Phone", HexColor("#7E7D7B"))}       # Android itself, not the app
W = A4[0] - 36 * mm


def st(name, font, size, color, leading=None, **kw):
    return ParagraphStyle(name, fontName=font, fontSize=size, textColor=color,
                          leading=leading or size * 1.4, **kw)


TITLE = st("t", "Poppins-Bold", 24, NAVY, 30)
SUB = st("s", "Inter", 11, BODY, 16)
H1 = st("h1", "Poppins-Bold", 15, NAVY, 20, spaceBefore=4, spaceAfter=2)
H1SUB = st("h1s", "Inter", 10, MUTED, 14, spaceAfter=8)
H2 = st("h2", "Inter-SemiBold", 11.5, NAVY, 16, spaceBefore=8, spaceAfter=4)
TEXT = st("x", "Inter", 10, BODY, 14.5)
CELL = st("c", "Inter", 9.5, STRONG, 13.5)
EXPECT = st("e", "Inter", 9.5, BODY, 13.5)
HEAD = st("hd", "Inter-SemiBold", 8.5, MUTED, 11)
WHO = st("w", "Inter-SemiBold", 7.5, white, 9, alignment=1)
NUM = st("n", "Inter-SemiBold", 9.5, MUTED, 13)


def mono(s):
    return f"<font face='Mono'>{s}</font>"


def b(s):
    return f"<font face='Inter-SemiBold'>{s}</font>"


def box(p, bg=TINT):
    t = Table([[p]], colWidths=[W])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg), ("BOX", (0, 0), (-1, -1), 0.6, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 12), ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 10), ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
    ]))
    return t


_counter = [0]


def steps(rows):
    data = [[Paragraph("#", HEAD), Paragraph("Where", HEAD), Paragraph("Do this", HEAD),
             Paragraph("You should see", HEAD), Paragraph("OK", HEAD)]]
    styles = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (4, 0), (4, -1), 2),
    ]
    for r, (who, do, exp) in enumerate(rows, 1):
        _counter[0] += 1
        label, colour = ROLE[who]
        tick = Table([[""]], colWidths=[5 * mm], rowHeights=[5 * mm])
        tick.setStyle(TableStyle([("BOX", (0, 0), (-1, -1), 0.9, MUTED)]))
        data.append([Paragraph(str(_counter[0]), NUM), Paragraph(label, WHO),
                     Paragraph(do, CELL), Paragraph(exp, EXPECT), tick])
        styles += [("BACKGROUND", (1, r), (1, r), colour), ("VALIGN", (1, r), (1, r), "MIDDLE"),
                   ("LINEBELOW", (0, r), (-1, r), 0.5, DIVIDER)]
    t = Table(data, colWidths=[8 * mm, 15 * mm, 70 * mm, W - 8 * mm - 15 * mm - 70 * mm - 10 * mm,
                               10 * mm], repeatRows=1)
    t.setStyle(TableStyle(styles))
    return t


def scene(title, sub, rows, note=None):
    out = [CondPageBreak(55 * mm), Paragraph(title, H1), Paragraph(sub, H1SUB), steps(rows)]
    if note:
        out += [Spacer(1, 6), box(Paragraph(note, TEXT), WARN)]
    out.append(Spacer(1, 10))
    return out


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Inter", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, "Lafii · one-phone demo recording guide")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def legend():
    cells = [[Paragraph(ROLE[k][0], WHO), Paragraph(t, CELL)] for k, t in [
        ("R", "The app in Refer mode: you are Amina Mahama, the Community Health Officer."),
        ("H", "The app in Receive mode: you are the maternity ward at Walewale Hospital."),
        ("P", "Android itself: screenshots, settings, screen recorder."),
        ("L", "The laptop: shows a QR screenshot so the phone camera can scan it."),
    ]]
    t = Table(cells, colWidths=[17 * mm, W - 17 * mm])
    styles = [("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (1, 0), (1, -1), 8),
              ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
              ("LINEBELOW", (0, 0), (-1, -2), 3, white)]
    for i, k in enumerate("RHPL"):
        styles.append(("BACKGROUND", (0, i), (0, i), ROLE[k][1]))
    t.setStyle(TableStyle(styles))
    return t


def main():
    out = os.path.join(ROOT, "release", "Lafii-one-phone-demo-guide.pdf")
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=16 * mm, bottomMargin=18 * mm,
                            title="Lafii one-phone demo recording guide", author="Lafii team")
    s = [
        Paragraph("Lafii: recording the demo on one phone", TITLE), Spacer(1, 4),
        Paragraph("One person, one Android phone, one laptop. You play both the Community "
                  "Health Officer and the hospital by switching the app between Refer and "
                  "Receive mode. About 30 minutes to set up and record; the finished video runs "
                  "about 6 minutes.", SUB),
        Spacer(1, 12), legend(), Spacer(1, 10),
        Paragraph("How one phone scans its own QR codes", H2),
        Paragraph(
            "The app scans with the camera, and a phone cannot point its camera at its own "
            "screen. So each time a QR code appears you will: take a " + b("screenshot") +
            ", copy it to the laptop, open it full screen there, switch the app to the other "
            "mode, and scan the laptop screen with the phone. This happens twice: once for "
            "the referral, once for the acknowledgement.", TEXT),
        Spacer(1, 6),
        Paragraph("Before you press record", H2),
        box(Paragraph(
            f"1. {b('Install the latest app')} (Lafii-arm64.apk). If it was installed before, clear "
            "its data so the demo patients load fresh: Android Settings › Apps › Lafii › Storage "
            "› Clear storage.<br/>"
            f"2. {b('Turn on airplane mode.')} The app must work with no network, and the video "
            "should show the airplane icon. Bluetooth and Wi-Fi off too.<br/>"
            f"3. {b('Connect the phone to the laptop with a USB cable')} and choose "
            "File transfer when the phone asks. This is how screenshots reach the laptop with "
            "no network. Leave the cable plugged in.<br/>"
            f"4. {b('Turn on Show taps')} so viewers see each tap: Settings › System › Developer "
            "options › Show taps. (If Developer options is hidden: Settings › About phone, tap "
            "Build number seven times.)<br/>"
            f"5. {b('Turn on Do not disturb')}, brightness to maximum, and close other apps.<br/>"
            f"6. {b('Laptop')}: open the phone's DCIM › Screenshots folder in File Explorer, and "
            "turn the laptop's screen brightness up.<br/>"
            f"7. Keep this guide beside you and do every step in order. A skipped step usually "
            "means starting again from Scene 1.", TEXT)),
    ]

    s += scene("Scene 1. Start recording and set up as Amina",
               "The officer sets the phone up once: no account, no login.", [
        ("P", "Swipe down twice from the top, tap " + b("Screen record") + ". Choose "
              + b("no audio") + " (the voice-over is added later) and start.",
         "A countdown, then a small recording indicator."),
        ("R", "Open " + b("Lafii") + ". Under This phone is used to, keep " + b("Refer patients") + ".",
         b("Set up this phone") + "."),
        ("R", "Your name: " + mono("Amina Mahama") + ". CHPS zone: " + mono("Kpasenkpe") +
              ". Your phone number: " + mono("0244112233") + ". Facility: tap the box, choose "
              + b("Kpasenkpe CHPS") + ".",
         b("Start using the app") + " turns dark blue."),
        ("R", "Tap " + b("Start using the app") + ". Pause for 3 seconds on Home.",
         "Home: " + b("Referrals not yet confirmed") + " (Abibata Fuseini, Damata Yakubu) and "
         + b("Due this week") + " (Fati Alhassan first)."),
    ])

    s += scene("Scene 2. Find Fati, without her card",
               "Spellings vary, and the app never guesses which record is hers.", [
        ("R", "Tap " + b("Find by name") + ". Type " + mono("fati alhas") + ".",
         b("2 records match") + ": Fati Alhasan (27) and Fati Alhassan (28), both Kpasenkpe. "
         "No score anywhere."),
        ("R", "Tap " + b("Fati Alhassan") + " (age 28).",
         b("These may be the same woman") + ": two cards side by side. Pause 3 seconds."),
        ("R", "On the card showing " + b("Visits 3") + " and a phone number, tap "
              + b("This is her") + ".",
         b("Antenatal visit 4") + ", Fati Alhassan · 28 · Kpasenkpe."),
    ])

    s += scene("Scene 3. Speak the visit",
               "Speech is turned into text on the phone, in airplane mode. Every value must "
               "still be confirmed by hand.", [
        ("R", "Tap " + b("Speak instead") + " (top right).",
         b("Ask before recording") + ", with Dagbani selected and the consent text."),
        ("R", "Tap " + b("She agreed") + ". Allow the microphone if asked.",
         "First “Not listening yet”, then " + b("Recording. Speak now.") +
         " with a seconds counter."),
        ("R", "When the counter appears, hold the phone about 20 cm away and say clearly: "
              + b("“Blood pressure one forty over ninety five. She has a severe headache. "
                  "No bleeding. No fits.”"),
         "The counter keeps counting."),
        ("R", "Tap " + b("Stop and review fields") + ".",
         b("Check what you said") + ". " + b("What the phone heard") + " shows your sentence. "
         "Systolic 140, Diastolic 95, Severe headache Yes, Vaginal bleeding No, Fits No appear "
         "in dashed grey boxes."),
        ("R", "Tap " + b("Confirm") + " on each dashed value, one at a time, slowly.",
         "Each turns solid with a green " + b("Confirmed") + ". There is no confirm-all."),
    ], note=b("If a value was misheard or missing") + ": tap the value to correct it, or tap "
            + b("Enter") + " next to it and type it. Typed values count as confirmed. Do not "
            "re-record; carry on with the scene.")

    s += scene("Scene 4. The assessment and the referral",
               "A fixed protocol rule, not AI, decides. The referral is a code plus a signed QR.", [
        ("R", "Tap " + b("Continue to assessment") + " at the bottom. Pause 4 seconds.",
         "Yellow banner: " + b("URGENT · REFER TODAY") + ", " + b("Signs of pre-eclampsia") +
         ". Because you recorded: Blood pressure 140/95, Severe headache: Yes."),
        ("R", "Tap " + b("Issue referral") + ".",
         b("Write this code on her card") + ": a six-character code, a large QR code, and "
         + b("Tell Fati") + ". Write the code here: ____________"),
        ("P", b("Take a screenshot now") + " (power + volume down together). Do not leave this "
              "screen before the screenshot is taken: it cannot be reopened.",
         "A screenshot preview flashes in the corner."),
        ("R", "Tap " + b("Code written on the card") + ".",
         "Home. Referrals not yet confirmed now says " + b("See all 4") + "."),
    ])

    s += scene("Scene 5. Become the hospital",
               "The same phone now plays Walewale Hospital.", [
        ("L", "On the laptop, open the newest file in DCIM › Screenshots (the referral QR). "
              "Press F11 or double-click for full screen.",
         "The QR fills the laptop screen."),
        ("R", "On Home, scroll down and tap " + b("Settings") + ".", b("Settings") + "."),
        ("R", "Tap " + b("Receive patients") + ". Your name: " + mono("Rahinatu Seidu") +
              ". Ward or unit: " + mono("Maternity ward") + ". Your phone number: "
              + mono("0209981234") + ". Facility: " + b("Walewale Hospital") + ". Tap "
              + b("Save settings") + ".",
         "A dark blue screen: " + b("Walewale Hospital · Rahinatu Seidu") + ", and "
         + b("Scan arriving card") + ". The status strip reads Receive mode · Walewale Hospital."),
    ])

    s += scene("Scene 6. Fati arrives at the hospital",
               "The hospital reads everything from the QR: no network, nothing synced in advance.", [
        ("H", "Tap " + b("Scan arriving card") + ". Allow the camera if asked. Point the phone "
              "at the laptop screen, 20 to 30 cm away, square on.",
         "The camera closes by itself once it reads the code."),
        ("H", "Pause 5 seconds. Scroll slowly to the bottom and back.",
         b("Fati Alhassan, 28") + ", the referral code, from Amina Mahama, Kpasenkpe CHPS, "
         + b("Officer’s phone 024 411 2233") + ". Green " + b("Signature valid") +
         ". " + b("Referred because the officer recorded") + ": Blood pressure 140/95, Severe "
         "headache: Yes. Then " + b("Everything on her card") + "."),
        ("H", "Tap " + b("Confirm arrival") + ".",
         b("Arrival confirmed") + " with the time, " + b("Add an outcome") +
         ", and an acknowledgement QR."),
        ("H", "Tap " + b("Admitted") + ". Tap the Follow-up at CHPS box and pick a date 3 days "
              "from today.",
         "The QR redraws after each change."),
        ("P", b("Take a screenshot now") + " of the acknowledgement QR.",
         "A screenshot preview flashes."),
        ("H", "Tap " + b("Done") + ".",
         "Receive home lists Fati Alhassan, Urgent, with " + b("Arrived") + " and the time."),
    ], note="If the scan does not read: make the laptop QR bigger, lower the phone's angle to "
            "remove glare, and hold still for two seconds.")

    s += scene("Scene 7. Back to Amina: the loop closes",
               "The officer learns Fati arrived, with no network.", [
        ("L", "On the laptop, open the newest screenshot (the acknowledgement QR), full screen.",
         "The smaller acknowledgement QR fills the screen."),
        ("H", "Scroll down on the hospital home and tap " + b("Settings") + ".", b("Settings") + "."),
        ("H", "Tap " + b("Refer patients") + ". Your name: " + mono("Amina Mahama") +
              ". CHPS zone: change it to " + mono("Kpasenkpe") + ". Your phone number: "
              + mono("0244112233") + ". Facility: " + b("Kpasenkpe CHPS") + ". Tap "
              + b("Save settings") + ".",
         "Amina's Home again. Referrals not yet confirmed says " + b("See all 4") + "."),
        ("R", "Tap " + b("See all 4") + ".",
         b("Not yet arrived") + ": Abibata Fuseini (Emergency) first, Fati Alhassan last, Today."),
        ("R", "Tap " + b("Scan an acknowledgement") + " and point the phone at the laptop.",
         b("Acknowledgement scanned") + ", " + b("Fati Alhassan arrived") + ": arrival time, "
         "Admitted, the follow-up date, Received at Walewale Hospital, " + b("Confirmed by") +
         " Rahinatu Seidu, " + b("Their phone") + " 020 998 1234. Pause 4 seconds."),
        ("R", "Tap " + b("Back to home") + ".",
         "Home. Referrals not yet confirmed now says " + b("See all 3") + ": Fati is off the list."),
    ])

    s += scene("Scene 8. What the officer gets back",
               "The visit fills in her register and monthly report for her.", [
        ("R", "On Home, scroll down and tap " + b("October report") + " (the current month).",
         b("Today’s register lines") + " with Fati's line ending in Ref: Walewale and the "
         "code. Below, " + b("DHIMS2 data elements") + " with counts."),
        ("R", "Tap " + b("Export register and report") + ". Pause 2 seconds, then press back.",
         "The Android share sheet with two CSV files. Nothing is sent."),
        ("R", "Press back to Home. Pause 3 seconds.", "Home."),
        ("P", "Swipe down and tap the recording indicator to " + b("stop recording") + ".",
         "The video is saved in Photos or Gallery, under Movies or Screen recordings."),
    ])

    s += [
        CondPageBreak(70 * mm),
        Paragraph("After recording", H1),
        box(Paragraph(
            f"1. {b('Watch it through once.')} Check that every QR scan, the dashed values turning "
            "Confirmed, the urgent banner and the arrived screen are all visible.<br/>"
            f"2. {b('Trim')} the dead time while you moved to the laptop. The phone's built-in "
            "video editor or any laptop editor is fine.<br/>"
            f"3. {b('Keep airplane mode visible')} at least at the start and during both scans: it "
            "is the evidence that nothing used the network.<br/>"
            f"4. {b('Voice-over')}: record it separately against the trimmed video, or narrate "
            "from the separate voice-over script.<br/>"
            f"5. {b('If you must redo it')}: clear the app's storage (Before you start, step 1) so "
            "the demo patients reload, and start again from Scene 1.", TEXT)),
        Spacer(1, 10),
        Paragraph("If something goes wrong", H2),
        Paragraph(
            f"{b('No women on Home')}: the app was first set up in Receive mode. Clear its storage "
            f"and set up again as Refer.<br/>"
            f"{b('Start using the app stays grey')}: one of name, zone, phone number or facility "
            "is empty, or the phone number has fewer than 9 digits.<br/>"
            f"{b('What the phone heard says Silence')}: another app is holding the microphone, "
            "or the app has no microphone permission. Fix it, then type the values instead.<br/>"
            f"{b('Scan does not read')}: QR too small or glare on the laptop. Enlarge it and tilt "
            "the phone.<br/>"
            f"{b('Not on this phone')} after scanning the acknowledgement: the referral was issued "
            "before the app's storage was last cleared. Start again from Scene 1.", TEXT),
    ]

    doc.build(s, onFirstPage=footer, onLaterPages=footer)
    print(out)


if __name__ == "__main__":
    main()
