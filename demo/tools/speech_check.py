"""Live check of voice capture on the emulator.

Plays a WAV through the laptop speakers while the app records, with the
emulator's microphone fed from the laptop microphone (-allow-host-audio).

python speech_check.py path/to/sentence.wav
"""
import sys
import time
import winsound

from drive import find, fresh_start, demo_status_bar, sh, shot, tap
import walkthrough as w


def main(wav):
    demo_status_bar()
    fresh_start()
    w.s01_setup()
    w.s02_home()
    tap("Fati Alhassan", index=0, pause=2.0)       # due list -> visit
    tap("Speak instead", pause=2.0)
    tap("She agreed", pause=1.0)
    find("Speak now", timeout=90)                 # wait until actually listening
    print("listening")
    time.sleep(1.0)
    winsound.PlaySound(wav, winsound.SND_FILENAME)  # blocks until played
    time.sleep(2.0)
    tap("Stop and review fields", pause=4.0)
    print(shot("speech_check"))


if __name__ == "__main__":
    main(sys.argv[1])
