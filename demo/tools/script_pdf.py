"""Renders the voice-over script as a PDF for reading while recording.

python script_pdf.py  -> demo/Lafii-voiceover-script.pdf
Lines come from script.txt so the PDF never drifts from the build.
"""
import os

from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (KeepTogether, Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.dirname(HERE)
FONTS = os.path.join(DEMO, "..", "lafii", "assets", "fonts")

for name, file in [("Inter", "Inter-400.ttf"), ("Inter-Medium", "Inter-500.ttf"),
                   ("Inter-SemiBold", "Inter-600.ttf"), ("Poppins-Bold", "Poppins-700.ttf"),
                   ("Mono", "JetBrainsMono-600.ttf")]:
    pdfmetrics.registerFont(TTFont(name, os.path.join(FONTS, file)))

NAVY = HexColor("#08283B")
BODY = HexColor("#3E3D3A")
MUTED = HexColor("#656461")
STRONG = HexColor("#1A1A18")
BORDER = HexColor("#E5E7EB")
TINT = HexColor("#EFF7FE")

CUES = [
    "Setup: name, zone and facility filled in",
    "Home: referrals to chase, women due this week",
    "Find a woman: “Fati Alhas” finds two records",
    "“These may be the same woman”: two cards side by side",
    "Antenatal visit 4, with the Speak instead button",
    "Blood pressure typed: 140 / 95",
    "Danger signs: Fits No, Bleeding No, Headache Yes",
    "Consent in Dagbani, then the recording counter",
    "Back to the visit screen",
    "“Check what you recorded”: a value unconfirmed, then confirmed",
    "Urgent: Signs of pre-eclampsia",
    "Referral code, signed QR, “Tell Fati”",
    "Home, then “Not yet arrived”",
    "October report: register line and DHIMS2 figures",
    "Home",
]
LENGTHS = [13, 7, 12, 10, 7, 5, 12, 11, 5, 13, 14, 11, 10, 8, 10]


def style(name, font, size, color, leading=None, **kw):
    return ParagraphStyle(name, fontName=font, fontSize=size, textColor=color,
                          leading=leading or size * 1.35, **kw)


TITLE = style("t", "Poppins-Bold", 24, NAVY, 30)
SUB = style("s", "Inter", 11, BODY, 16)
H2 = style("h", "Inter-SemiBold", 12, NAVY, 16, spaceBefore=4, spaceAfter=4)
TEXT = style("x", "Inter", 10, BODY, 14.5)
CODE = style("c", "Mono", 9.5, STRONG, 14)
NUM = style("n", "Poppins-Bold", 20, NAVY, 22)
CUE = style("q", "Inter-Medium", 9, MUTED, 12)
SAY = style("y", "Inter", 13.5, STRONG, 20)
LEN = style("l", "Inter", 9, MUTED, 12, alignment=2)


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Inter", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, "Lafii demo · voice-over script")
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def line_block(n, cue, say, secs, width):
    t = Table(
        [[Paragraph(f"{n:02d}", NUM), Paragraph(cue, CUE), Paragraph(f"~{secs}s", LEN)],
         ["", Paragraph(say, SAY), ""]],
        colWidths=[16 * mm, width - 16 * mm - 16 * mm, 16 * mm],
    )
    t.setStyle(TableStyle([
        ("SPAN", (0, 0), (0, 1)),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 1), (-1, 1), 0.6, BORDER),
        ("TOPPADDING", (0, 0), (-1, 0), 10),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 2),
        ("BOTTOMPADDING", (0, 1), (-1, 1), 12),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]))
    return KeepTogether(t)


def main():
    with open(os.path.join(HERE, "script.txt"), encoding="utf-8") as f:
        lines = [l.strip() for l in f if l.strip()]
    assert len(lines) == len(CUES) == len(LENGTHS) == 15

    out = os.path.join(DEMO, "Lafii-voiceover-script.pdf")
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=18 * mm, bottomMargin=18 * mm,
                            title="Lafii demo voice-over script", author="Lafii team")
    width = A4[0] - 36 * mm

    howto = Table([[Paragraph(
        "<b>Save each line as its own file</b> in <font face='Mono'>demo/voiceover/</font>, "
        "named by number: <font face='Mono'>line01.m4a</font> to "
        "<font face='Mono'>line15.m4a</font>. Any common audio format works (wav, mp3, m4a, "
        "aac, ogg, flac).<br/><br/>"
        "Record every line in the same room, at the same distance from the mic. Leave about "
        "half a second of silence before and after each line. Speak at your normal pace: the "
        "video holds or speeds up each screen to fit your clip. If you stumble, re-record "
        "just that line and overwrite its file.<br/><br/>"
        "<b>Say</b> CHPS as “chips”, and DHIMS2 as “D-H-I-M-S two”.",
        TEXT)]], colWidths=[width])
    howto.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), TINT),
        ("BOX", (0, 0), (-1, -1), 0.6, BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 12), ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("TOPPADDING", (0, 0), (-1, -1), 10), ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
    ]))

    story = [
        Paragraph("Lafii demo: voice-over script", TITLE),
        Spacer(1, 4),
        Paragraph("15 lines, about two and a half minutes of speaking (the finished video "
                  "runs about three). One audio file per line.", SUB),
        Spacer(1, 12),
        howto,
        Spacer(1, 8),
    ]
    for i, (cue, say, secs) in enumerate(zip(CUES, lines, LENGTHS), 1):
        story.append(line_block(i, cue, say, secs, width))

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(out)


if __name__ == "__main__":
    main()
