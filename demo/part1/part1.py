"""Records Part 1 of the submission video on the emulator: Amina's side,
from switching on airplane mode to the issued referral QR.

python part1.py rehearse | record
Needs the LAFII_DEMO build installed and the emulator microphone fed from the
laptop (Extended controls > Microphone > Virtual microphone uses host audio input).
"""
import os
import sys
import time
import winsound

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

import drive  # noqa: E402
from drive import fill, find, nodes, scroll_to, sh, tap, tap_xy, type_text  # noqa: E402

drive.OUT = HERE  # clips -> part1/screen, shots -> part1/tools/shots
PKG = drive.PKG
VITALS = os.path.join(HERE, "voice", "vitals16k.wav")


def enter_key(pause=0.8):
    sh("shell", "input", "keyevent", "66")
    time.sleep(pause)


def prepare():
    sh("shell", "cmd", "connectivity", "airplane-mode", "disable", check=False)
    sh("shell", "settings", "put", "global", "sysui_demo_allowed", "0", check=False)
    sh("shell", "am", "force-stop", PKG)
    sh("shell", "pm", "clear", PKG)
    sh("shell", "pm", "grant", PKG, "android.permission.RECORD_AUDIO")
    sh("shell", "pm", "grant", PKG, "android.permission.CAMERA")
    sh("shell", "input", "keyevent", "3")  # home
    time.sleep(3)


def p1_01_airplane():
    sh("shell", "am", "start", "-a", "android.settings.AIRPLANE_MODE_SETTINGS")
    time.sleep(2.5)
    n = find("Airplane mode", timeout=10)
    # The row's switch sits at the right edge of the "Airplane mode" row.
    y = (n["b"][1] + n["b"][3]) // 2
    tap_xy(960, y, pause=3.0)
    sh("shell", "input", "keyevent", "3")  # home, airplane icon now in the status bar
    time.sleep(2.0)


def p1_02_setup():
    sh("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    find("Your name", exact=True, timeout=40)
    time.sleep(1.5)
    fill("Your name", "Amina Mahama")
    enter_key(0.8)
    fill("CHPS zone", "Kpasenkpe")
    enter_key(0.8)
    fill("Your phone number", "0244112233")
    enter_key(1.0)
    tap("Choose your facility", pause=1.2)
    tap("Kpasenkpe CHPS", exact=True, pause=1.5)


def p1_03_home():
    tap("Start using the app", pause=3.0)


def p1_04_find():
    tap("Find by name", pause=1.2)
    type_text("fati alhas", pause=0.8)
    enter_key(2.0)


def p1_05_duplicate():
    tap("Fati Alhassan", index=0, pause=3.0)


def p1_06_visit_bp():
    card = find("Fati Alhassan", exact=True)
    cx = (card["b"][0] + card["b"][2]) // 2
    for n in nodes():
        if "This is her" in n["label"] and n["b"][0] <= cx <= n["b"][2]:
            tap_xy((n["b"][0] + n["b"][2]) // 2, (n["b"][1] + n["b"][3]) // 2, pause=3.0)
            break
    else:
        raise LookupError("This is her")
    boxes = sorted([n for n in nodes() if n["cls"] == "android.widget.EditText"],
                   key=lambda n: (n["b"][1], n["b"][0]))
    for box, value in ((boxes[0], "140"), (boxes[1], "95")):
        tap_xy((box["b"][0] + box["b"][2]) // 2, (box["b"][1] + box["b"][3]) // 2, pause=0.6)
        type_text(value, pause=0.8)
    enter_key(1.5)


def _sign(label, answer):
    n = scroll_to(f"{label} {answer}\n")
    tap_xy((n["b"][0] + n["b"][2]) // 2, (n["b"][1] + n["b"][3]) // 2, pause=1.2)


def p1_07_signs():
    sh("shell", "input", "swipe", "540", "1500", "540", "1250", "500")
    time.sleep(0.8)
    _sign("Fits or convulsions", "No")
    _sign("Vaginal bleeding", "No")
    _sign("Severe headache", "Yes")
    time.sleep(1.5)


def p1_08_confirm():
    scroll_to("Save and continue")
    tap("Save and continue", pause=3.0)
    # A value can be returned to unconfirmed, and must be confirmed again.
    tap("Confirmed", index=0, pause=2.0)
    tap("Confirm", exact=True, index=0, pause=2.0)


def p1_09_assess():
    tap("Continue to assessment", pause=4.0)


def p1_10_referral():
    tap("Issue referral", pause=4.0)
    time.sleep(2.0)


SEGMENTS = [p1_01_airplane, p1_02_setup, p1_03_home, p1_04_find, p1_05_duplicate,
            p1_06_visit_bp, p1_07_signs, p1_08_confirm, p1_09_assess, p1_10_referral]


def main(mode):
    prepare()
    for i, seg in enumerate(SEGMENTS, 1):
        name = f"p1_{i:02d}"
        if mode == "record":
            drive.rec_start(name)
        try:
            seg()
        except Exception as e:
            print(name, "FAILED:", e, drive.shot(f"{name}_FAILED"))
            if mode == "record":
                drive.rec_stop(0)
            raise
        if mode == "record":
            print(name, drive.rec_stop(1.5))
        print(name, drive.shot(name))
    # Full-resolution still of the referral QR, for the real phone to scan.
    sh("shell", "screencap", "-p", "/sdcard/qr.png")
    sh("pull", "/sdcard/qr.png", os.path.join(HERE, "referral_qr_screen.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "rehearse")
