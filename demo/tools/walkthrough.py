"""The demo walkthrough, one function per voice-over line.

python walkthrough.py rehearse   -> runs it, screenshot after each segment
python walkthrough.py record     -> runs it, one screen recording per segment
"""
import sys
import time

from drive import (back, demo_status_bar, fill, find, fresh_start, hide_keyboard, nodes,
                   rec_start, rec_stop, scroll_to, sh, shot, swipe_up, tap, tap_xy)


def s01_setup():
    fill("Your name", "Amina Mahama")
    fill("CHPS zone", "Kpasenkpe")
    sh("shell", "input", "keyevent", "66")  # Done closes the keyboard
    time.sleep(1.0)
    tap("Choose your facility", pause=1.0)
    tap("Kpasenkpe CHPS", exact=True, pause=1.0)


def s02_home():
    tap("Start using the app", pause=2.5)


def s03_find():
    tap("Find by name", pause=1.2)
    from drive import type_text
    type_text("fati alhas", pause=1.5)
    hide_keyboard()
    time.sleep(1.5)


def s04_duplicate():
    tap("Fati Alhassan", index=0, pause=2.0)


def _this_is_her(name):
    card_name = find(name, exact=True)
    cx = (card_name["b"][0] + card_name["b"][2]) // 2
    for n in nodes():
        if "This is her" in n["label"] and n["b"][0] <= cx <= n["b"][2]:
            x = (n["b"][0] + n["b"][2]) // 2
            y = (n["b"][1] + n["b"][3]) // 2
            tap_xy(x, y, pause=2.0)
            return
    raise LookupError("This is her button")


def s05_visit():
    _this_is_her("Fati Alhassan")


def s06_bp():
    # Systolic and diastolic are the two boxes under "Blood pressure".
    from drive import type_text
    boxes = sorted([n for n in nodes() if n["cls"] == "android.widget.EditText"],
                   key=lambda n: (n["b"][1], n["b"][0]))
    sys_box, dia_box = boxes[0], boxes[1]
    for box, value in ((sys_box, "140"), (dia_box, "95")):
        x = (box["b"][0] + box["b"][2]) // 2
        y = (box["b"][1] + box["b"][3]) // 2
        tap_xy(x, y, pause=0.5)
        type_text(value, pause=0.6)
    hide_keyboard()
    time.sleep(1.0)


def _sign(label, answer):
    n = scroll_to(f"{label} {answer}\n")
    tap_xy((n["b"][0] + n["b"][2]) // 2, (n["b"][1] + n["b"][3]) // 2, pause=0.8)


def s07_signs():
    swipe_up(250)
    _sign("Fits or convulsions", "No")
    _sign("Vaginal bleeding", "No")
    _sign("Severe headache", "Yes")
    time.sleep(1.0)


def s08_speech():
    swipe_up(-500) if False else sh("shell", "input", "swipe", "540", "900", "540", "1700", "500")
    time.sleep(0.6)
    tap("Speak instead", pause=1.5)
    time.sleep(1.5)
    tap("She agreed", pause=1.0)
    time.sleep(4.0)


def s09_back_to_tap():
    tap("Switch to tapping", pause=1.5)
    time.sleep(1.0)


def s10_confirm():
    scroll_to("Save and continue")
    tap("Save and continue", pause=2.0)
    time.sleep(1.0)
    # Show that a value can be returned to unconfirmed, then confirm it.
    tap("Confirmed", index=0, pause=1.5)
    time.sleep(1.2)
    tap("Confirm", exact=True, index=0, pause=1.5)


def s11_assessment():
    tap("Continue to assessment", pause=2.5)
    time.sleep(2.0)


def s12_issue():
    tap("Issue referral", pause=3.0)
    time.sleep(3.0)


def s14_chase():
    tap("Code written on the card", pause=2.5)
    time.sleep(1.0)
    tap("See all", pause=2.0)
    time.sleep(1.5)


def s15_report():
    back(pause=1.5)
    scroll_to("report", max_swipes=3)
    tap("report", index=0, pause=2.5)
    time.sleep(1.5)


def s16_close():
    swipe_up(700)
    time.sleep(1.5)
    back(pause=2.0)
    sh("shell", "input", "swipe", "540", "800", "540", "1800", "500")
    time.sleep(1.5)


SEGMENTS = [s01_setup, s02_home, s03_find, s04_duplicate, s05_visit, s06_bp, s07_signs,
            s08_speech, s09_back_to_tap, s10_confirm, s11_assessment, s12_issue,
            s14_chase, s15_report, s16_close]


def main(mode, only=None):
    demo_status_bar()
    fresh_start()
    for i, seg in enumerate(SEGMENTS, 1):
        name = f"line{i:02d}"
        if mode == "record":
            rec_start(name)
        try:
            seg()
        except Exception as e:
            shot(f"{name}_FAILED")
            print(f"{name} {seg.__name__} FAILED: {e}")
            if mode == "record":
                rec_stop(0)
            raise
        if mode == "record":
            print(name, rec_stop(1.0))
        else:
            print(name, seg.__name__, shot(name))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "rehearse")
