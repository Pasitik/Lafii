"""Two-phone field test guide for Lafii.

python test_guide_pdf.py -> release/Lafii-two-phone-test-guide.pdf
"""
import os

from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (CondPageBreak, KeepTogether, PageBreak, Paragraph,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

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
A_COL = HexColor("#08283B")   # Phone A, Amina
B_COL = HexColor("#046C4E")   # Phone B, hospital
WARN = HexColor("#FDF6B2")

W = A4[0] - 36 * mm


def st(name, font, size, color, leading=None, **kw):
    return ParagraphStyle(name, fontName=font, fontSize=size, textColor=color,
                          leading=leading or size * 1.4, **kw)


TITLE = st("t", "Poppins-Bold", 24, NAVY, 30)
SUB = st("s", "Inter", 11, BODY, 16)
H1 = st("h1", "Poppins-Bold", 16, NAVY, 21, spaceBefore=6, spaceAfter=2)
H1SUB = st("h1s", "Inter", 10, MUTED, 14, spaceAfter=8)
H2 = st("h2", "Inter-SemiBold", 11.5, NAVY, 16, spaceBefore=8, spaceAfter=4)
TEXT = st("x", "Inter", 10, BODY, 14.5)
CELL = st("c", "Inter", 9.5, STRONG, 13.5)
EXPECT = st("e", "Inter", 9.5, BODY, 13.5)
HEAD = st("hd", "Inter-SemiBold", 8.5, MUTED, 11)
WHO = st("w", "Inter-SemiBold", 8.5, white, 10, alignment=1)
NUM = st("n", "Inter-SemiBold", 9.5, MUTED, 13)


def mono(s):
    return f"<font face='Mono'>{s}</font>"


def b(s):
    return f"<font face='Inter-SemiBold'>{s}</font>"


def box(paragraphs, bg=TINT):
    t = Table([[paragraphs]], colWidths=[W])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg), ("BOX", (0, 0), (-1, -1), 0.6, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 12), ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 10), ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
    ]))
    return t


def who(code):
    return Paragraph("A" if code == "A" else "B", WHO)


def steps(rows):
    """rows: (who, do, expect). who is 'A' or 'B'."""
    data = [[Paragraph("#", HEAD), Paragraph("Phone", HEAD), Paragraph("Do this", HEAD),
             Paragraph("You should see", HEAD), Paragraph("OK", HEAD)]]
    styles = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]
    for i, (w, do, exp) in enumerate(rows, 1):
        tick = Table([[""]], colWidths=[5 * mm], rowHeights=[5 * mm])
        tick.setStyle(TableStyle([("BOX", (0, 0), (-1, -1), 0.9, MUTED)]))
        data.append([Paragraph(str(i), NUM), who(w), Paragraph(do, CELL),
                     Paragraph(exp, EXPECT), tick])
        r = i
        styles += [
            ("BACKGROUND", (1, r), (1, r), A_COL if w == "A" else B_COL),
            ("VALIGN", (1, r), (1, r), "MIDDLE"),
            ("LINEBELOW", (0, r), (-1, r), 0.5, DIVIDER),
        ]
    t = Table(data, colWidths=[7 * mm, 13 * mm, 70 * mm, W - 7 * mm - 13 * mm - 70 * mm - 11 * mm,
                               11 * mm], repeatRows=1)
    styles.append(("LEFTPADDING", (4, 0), (4, -1), 2))
    t.setStyle(TableStyle(styles))
    return t


def test(title, sub, rows, note=None):
    out = [CondPageBreak(60 * mm), Paragraph(title, H1), Paragraph(sub, H1SUB), steps(rows)]
    if note:
        out += [Spacer(1, 6), box(Paragraph(note, TEXT), WARN)]
    out.append(Spacer(1, 10))
    return out


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Inter", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, "Lafii · two-phone test guide")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def roles_table():
    t = Table([
        [Paragraph("A", WHO), Paragraph(
            f"{b('Phone A: the Community Health Officer')}<br/>Plays Amina Mahama at "
            "Kpasenkpe CHPS. Records visits and issues referrals.", CELL)],
        [Paragraph("B", WHO), Paragraph(
            f"{b('Phone B: the receiving hospital')}<br/>Plays the maternity ward at Walewale "
            "Hospital. Reads the referral card and sends back an acknowledgement.", CELL)],
    ], colWidths=[13 * mm, W - 13 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, 0), A_COL), ("BACKGROUND", (0, 1), (0, 1), B_COL),
        ("VALIGN", (0, 0), (0, -1), "MIDDLE"), ("VALIGN", (1, 0), (1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, 0), 4, white),
        ("LEFTPADDING", (1, 0), (1, -1), 10), ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("BOX", (1, 0), (1, 0), 0.6, BORDER), ("BOX", (1, 1), (1, 1), 0.6, BORDER),
    ]))
    return t


def results_table():
    rows = [["Test", "Result", "What went wrong, or what felt slow or confusing"]]
    for name in ["1  Setup", "2  Referral, end to end", "3  Routine visit",
                 "4  Disagree with the app", "5  Voice entry", "6  Find, duplicate, register",
                 "7  Monthly report"]:
        rows.append([name, "Pass  /  Fail", ""])
    t = Table([[Paragraph(c, HEAD if i == 0 else CELL) for c in r] for i, r in enumerate(rows)],
              colWidths=[48 * mm, 26 * mm, W - 74 * mm], rowHeights=[None] + [17 * mm] * 7)
    t.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.6, BORDER), ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("BACKGROUND", (0, 0), (-1, 0), DIVIDER),
        ("TOPPADDING", (0, 0), (-1, -1), 6), ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ]))
    return t


def main():
    out = os.path.join(ROOT, "release", "Lafii-two-phone-test-guide.pdf")
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=16 * mm, bottomMargin=18 * mm,
                            title="Lafii two-phone test guide", author="Lafii team")
    s = []

    s += [
        Paragraph("Lafii: two-phone test guide", TITLE), Spacer(1, 4),
        Paragraph("Two people, two Android phones, no internet. About 45 minutes. "
                  "Work through the tests in order and tick each step as you go.", SUB),
        Spacer(1, 12), roles_table(), Spacer(1, 12),
        Paragraph("Before you start", H2),
        box(Paragraph(
            f"1. On {b('both phones')}, turn on {b('airplane mode')} and check that Wi-Fi and "
            "mobile data are off. Every test must work with no network. If anything asks for "
            "the internet, write it down: that is a failure.<br/>"
            "2. Charge both phones to at least 50%.<br/>"
            "3. Sit side by side. Phone B will scan Phone A's screen, and the other way round.<br/>"
            "4. Turn screen brightness up on both phones. QR codes scan best from a bright, "
            "flat screen with no glare.<br/>"
            "5. Keep a pen handy for the results sheet on the last page.", TEXT)),
        Spacer(1, 8),
        Paragraph("What this test is checking", H2),
        Paragraph(
            "A woman with dangerous blood pressure is referred from a CHPS compound to the "
            "district hospital. The hospital reads her referral from a QR code with no network "
            "and nothing synced in advance, confirms she arrived, and sends an acknowledgement "
            "back. The officer learns she arrived. Along the way the officer's register line "
            "and monthly report fill themselves in.", TEXT),
        Spacer(1, 6),
        Paragraph("Scanning tips", H2),
        Paragraph(
            "Hold the scanning phone 20 to 30 cm from the QR, square on, and keep both phones "
            "still for a second. If it does not read, tilt slightly to remove glare or move a "
            "little closer. Note in the results how easy or hard each scan was.", TEXT),
    ]

    s += test("Test 1. Set up both phones",
              "Each phone is set up once. No account or password.",
              [
                  ("A", f"Open Lafii. Under {b('This phone is used to')}, choose {b('Refer patients')}.",
                   f"The {b('Set up this phone')} screen."),
                  ("A", f"Your name: {mono('Amina Mahama')}. CHPS zone: {mono('Kpasenkpe')}. "
                        "Your phone number: the tester's real number. "
                        f"Facility: tap the box and choose {b('Kpasenkpe CHPS')}.",
                   f"{b('Start using the app')} turns dark blue once all four are filled."),
                  ("A", f"Tap {b('Start using the app')}.",
                   f"Home, headed {b('Kpasenkpe CHPS · Amina Mahama')} and today's date. Two "
                   f"lists: {b('Referrals not yet confirmed')} (Abibata Fuseini, Damata Yakubu) "
                   f"and {b('Due this week')} (Fati Alhassan first)."),
                  ("B", f"Open Lafii. Choose {b('Receive patients')}.",
                   f"The second field changes to {b('Ward or unit')}."),
                  ("B", f"Your name: your own name. Ward or unit: {mono('Maternity ward')}. "
                        "Your phone number: your real number. "
                        f"Facility: {b('Walewale Hospital')}. Tap {b('Start using the app')}.",
                   f"A dark blue screen headed {b('Walewale Hospital')}, the text "
                   f"{b('Cards read on this phone')}, and a {b('Scan arriving card')} button."),
              ],
              note=f"{b('If Phone A shows no women')} on Home, it was first set up in Receive "
                   "mode, so the demo records were not loaded. Clear the app's data (Android "
                   "Settings › Apps › Lafii › Storage › Clear data) and set it up again as "
                   "Refer patients.")

    s += test("Test 2. A referral, end to end",
              "The main story: pre-eclampsia signs, a referral, arrival at the hospital, and "
              "the loop closing back on the officer's phone.",
              [
                  ("A", f"On Home, under {b('Due this week')}, tap {b('Fati Alhassan')}.",
                   f"{b('Antenatal visit 4')}, with Fati Alhassan · 28 · Kpasenkpe above it."),
                  ("A", f"Blood pressure: type {mono('140')} in the first box and {mono('95')} in "
                        "the second. Leave Weeks pregnant at 32.",
                   "The phone's number pad opens for each box."),
                  ("A", f"Under {b('Danger signs')}: Fits or convulsions {b('No')}, Vaginal bleeding "
                        f"{b('No')}, Severe headache {b('Yes')}. Leave the rest untouched.",
                   f"Chosen answers turn dark blue. The untouched ones keep dashed outlines and "
                   f"say {b('Not asked')}. They are not recorded as No."),
                  ("A", f"Scroll down and tap {b('Save and continue')}.",
                   f"{b('Check what you recorded')}. Blood pressure and weeks show "
                   f"{b('Confirmed')}. Unentered values say {b('Missing')} in red. There is no "
                   "confirm-all button anywhere."),
                  ("A", f"Tap the green {b('Confirmed')} next to Systolic blood pressure.",
                   f"It turns dashed and grey, with a {b('Confirm')} button. Tap {b('Confirm')} "
                   "to restore it."),
                  ("A", f"Tap {b('Continue to assessment')}.",
                   f"A yellow banner: {b('URGENT · REFER TODAY')}, {b('Signs of pre-eclampsia')}. "
                   f"Under {b('Because you recorded')}: Blood pressure 140/95 and Severe headache: "
                   "Yes. Below that, the protocol rule (R4) and a list of what was not used."),
                  ("A", f"Tap {b('Issue referral')}.",
                   f"{b('Write this code on her card')}: a six-character code, a large QR code, "
                   f"and a blue box {b('Tell Fati')} explaining why she must go to Walewale "
                   "Hospital today. Write the code down here: ________"),
                  ("B", f"Tap {b('Scan arriving card')}. Allow the camera if asked. Point it at "
                        "Phone A's QR code.",
                   "The camera opens and closes by itself once it reads the code."),
                  ("B", "Look at the arrival screen.",
                   f"{b('Fati Alhassan, 28')}, the same referral code, from Amina Mahama, "
                   f"Kpasenkpe CHPS, and {b('Officer’s phone')} with Phone A's number. A green strip: {b('Signature valid')} with today's date. "
                   f"Urgent, Signs of pre-eclampsia. {b('Referred because the officer recorded')}: "
                   "Blood pressure 140/95 and Severe headache: Yes, the same list Phone A showed. "
                   f"Below it, {b('Everything on her card')}, with Haemoglobin {b('Missing')}. "
                   "All of this came from the QR code, with no network."),
                  ("B", f"Tap {b('Confirm arrival')}. This is one tap.",
                   f"{b('Arrival confirmed')} with the time, then {b('Add an outcome')}. An "
                   "acknowledgement QR code is already on screen."),
                  ("B", f"Under Outcome, tap {b('Admitted')}. Under Follow-up at CHPS, tap the box and "
                        "pick a date three days from today.",
                   "The QR code redraws after each change."),
                  ("A", f"Tap {b('Code written on the card')}.",
                   f"Back on Home. {b('Referrals not yet confirmed')} now says See all 4."),
                  ("A", f"Tap {b('See all 4')}.",
                   f"{b('Not yet arrived')}: Abibata Fuseini (Emergency) first, then the Urgent "
                   "ones oldest first, with Fati Alhassan last, marked Today."),
                  ("A", f"Tap {b('Scan an acknowledgement')}. Point it at Phone B's QR code.",
                   f"{b('Acknowledgement scanned')}, {b('Fati Alhassan arrived')}. Arrived "
                   "time, Outcome Admitted, the follow-up date, Received at Walewale Hospital, "
                   f"{b('Confirmed by')} Phone B's tester and {b('Their phone')} with Phone B's number."),
                  ("A", f"Tap {b('Back to home')}.",
                   f"Fati is no longer under {b('Referrals not yet confirmed')}. (Her follow-up "
                   "date joins Due this week from tomorrow, since she was seen today.)"),
                  ("B", f"Tap {b('Done')}.",
                   f"Fati appears under {b('Cards read on this phone')}, marked Arrived with the time."),
              ],
              note="If any scan fails after a minute of trying, write down which one (B reading "
                   "A, or A reading B), the distance, and the lighting. Do not skip ahead: the "
                   "later steps depend on each scan.")

    s += test("Test 3. A routine visit",
              "No danger signs: the visit should end with a next contact date and a register line.",
              [
                  ("A", f"On Home, tap {b('Memunatu Iddrisu')}. Blood pressure {mono('112')} / "
                        f"{mono('70')}. Fits {b('No')}, Bleeding {b('No')}, Severe headache {b('No')}.",
                   "Antenatal visit 2."),
                  ("A", f"{b('Save and continue')}, then {b('Continue to assessment')}.",
                   f"A green banner: {b('ROUTINE')}, {b('No danger signs recorded')}. A "
                   f"{b('Next contact')} date with the reason (by protocol for her weeks), and a "
                   f"{b('Register line')} in typewriter text."),
                  ("A", f"Tap {b('Finish visit')}.",
                   "Back on Home. Memunatu is no longer due this week."),
              ])

    s += test("Test 4. Disagree with the app",
              "The officer always has the last word. Her reason is recorded alongside the rule.",
              [
                  ("A", f"On Home, tap {b('Ayishetu Sulemana')} (36 weeks). Set "
                        f"{b('Reduced fetal movement')} to {b('Yes')}.",
                   ""),
                  ("A", f"{b('Save and continue')}, then {b('Continue to assessment')}.",
                   f"{b('URGENT')}, {b('Reduced fetal movement')}, triggered by Reduced fetal "
                   "movement: Yes and 36 weeks pregnant."),
                  ("A", f"Tap {b('I disagree')}. Choose {b('Value was recorded wrongly')}. In Note, "
                        f"type {mono('Baby moving well on recheck')}.",
                   f"{b('Refer anyway')} and {b('Do not refer')} only work once a reason is chosen."),
                  ("A", f"Tap {b('Do not refer')}.",
                   f"A blue banner: {b('NOT REFERRED · YOUR DECISION')}, a line saying her reason "
                   f"is recorded alongside rule R7, a next contact date, and a register line. "
                   f"Tap {b('Finish visit')}."),
              ])

    s += test("Test 5. Voice entry",
              "Speak the visit instead of typing. Speech is turned into text on the phone, in "
              "airplane mode. Every value it hears must still be confirmed by hand.",
              [
                  ("A", f"On Home, tap {b('Rukaya Alhassan')}. Tap {b('Speak instead')} (top right).",
                   f"{b('Ask before recording')}, with her language (Dagbani or English) and the "
                   "consent text she would hear."),
                  ("A", f"Tap {b('She agreed')}. Allow the microphone if asked.",
                   f"{b('Recording')} with a seconds counter. There is no waveform or microphone "
                   "animation. That is on purpose."),
                  ("A", "Say, clearly and at normal speed: "
                        f"{b('Temperature thirty eight point four. No bleeding. No fits. No headache.')}",
                   "The counter keeps going while you speak."),
                  ("A", f"Tap {b('Stop and review fields')}.",
                   f"{b('Check what you said')}. Temperature 38.4, Vaginal bleeding No, Fits No and "
                   f"Severe headache No appear in {b('dashed grey')} boxes, each with its own "
                   f"{b('Confirm')} button. The top line counts how many still need you."),
                  ("A", f"Tap {b('Confirm')} on each one, one at a time.",
                   "Each turns solid with a green Confirmed. The count goes down."),
                  ("A", f"Tap {b('Continue to assessment')}.",
                   f"{b('URGENT')}, {b('Fever')}, triggered by Temperature 38.4 °C."),
              ],
              note=f"{b('Write down exactly what it heard')} if any value is wrong or missing, "
                   "and how you said it. The recogniser is still being tuned for Ghanaian English. "
                   f"If it heard nothing, the screen says so in a box at the top: {b('Heard but not used')}.")

    s += test("Test 6. Find a woman, possible duplicate, register",
              "When she has no card. The app never guesses which record is hers.",
              [
                  ("A", f"On Home, tap {b('Find by name')}. Type {mono('fati alhas')}.",
                   f"{b('2 records match')}: Fati Alhasan, age 27, and Fati Alhassan, age 28, both "
                   "Kpasenkpe, each with a last-seen date. No score or percentage anywhere."),
                  ("A", f"Tap {b('Fati Alhassan')} (age 28).",
                   f"{b('These may be the same woman')}: two cards side by side, neither "
                   f"highlighted, each with its own {b('This is her')} button. Nothing is merged."),
                  ("A", "Press the phone's back button once to return to the search. Clear the box "
                        f"and type {mono('Hawa Issahaku')}.",
                   f"{b('No records match')}. {b('Register a new woman')} is in the same place at "
                   "the bottom as before."),
                  ("A", f"Tap {b('Register a new woman')}. Her name is already filled in from the "
                        f"search. Community {b('Loagri')}, Age {mono('22')}, "
                        f"Weeks pregnant {mono('16')}, Gravida {mono('1')}, Para {mono('0')}. Leave "
                        f"Phone blank. Tap {b('Register and start visit')}.",
                   f"{b('Antenatal visit 1')} for Hawa Issahaku · 22 · Loagri. Press back to leave "
                   "without recording a visit."),
              ])

    s += test("Test 7. The officer's monthly report",
              "The payback for the officer: her register and report are filled in for her.",
              [
                  ("A", f"On Home, scroll down and tap {b('October report')} (the current month).",
                   f"{b('Today’s register lines')}: one typewriter line for each visit finished "
                   f"today (Fati, Memunatu, Ayishetu, Rukaya). Below, {b('DHIMS2 data elements')} "
                   "with counts, and a note that the element names are still to be checked."),
                  ("A", "Check the numbers against what you did today.",
                   "ANC attendances includes today's four visits. ANC referrals out includes Fati."),
                  ("A", f"Tap {b('Export register and report')}.",
                   "The Android share sheet opens with two CSV files. Cancel: in airplane mode "
                   "there is nowhere to send them, and that is fine."),
              ])

    s += [PageBreak(),
          Paragraph("Results", H1),
          Paragraph("Fill this in together at the end. Be specific: the screen, what you "
                    "tapped, what you expected, what happened.", H1SUB),
          results_table(), Spacer(1, 12),
          Paragraph("Three questions", H2),
          Paragraph(
              "1. Did anything ask for, or seem to wait for, the internet?<br/><br/>"
              "2. Which step would a busy officer find slow or confusing?<br/><br/>"
              "3. Was any wording on screen unclear, or wrong for a CHPS compound or a "
              "district hospital?<br/><br/>", TEXT),
          Spacer(1, 4),
          Paragraph(f"Tester A: ______________________ &nbsp;&nbsp;&nbsp; Tester B: "
                    f"______________________ &nbsp;&nbsp;&nbsp; Date: ____________", TEXT)]

    doc.build(s, onFirstPage=footer, onLaterPages=footer)
    print(out)


if __name__ == "__main__":
    main()
