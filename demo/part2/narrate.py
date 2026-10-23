"""Adds the voice-over to the hospital-side phone recording.

python narrate.py -> demo/part2/lafii-part2.mp4
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from build_video import FFMPEG, FFPROBE  # noqa: E402

SRC = os.path.join(HERE, "..", "part1", "lafii part 2.mp4")
VOICE = "en-NG-AbeoNeural"

# Freeze the arrival screen so its narration fits: (source time, seconds held).
HOLD_AT, HOLD_FOR = 21.5, 8.5

# (planned start in the edited video, text)
LINES = [
    (0.5, "This is the hospital's phone, at Walewale Hospital. It runs the same Lafii app, "
          "set to receive mode. Nothing was synced from the health officer's phone in advance."),
    (12.0, "When the mother arrives, the clinician scans the QR code from her card."),
    (16.0, "The signature is valid, so the card has not been changed since it was issued. "
           "It shows exactly why she was referred: blood pressure one forty over ninety five, "
           "and a severe headache, with the officer's phone number to call back."),
    (31.0, "Confirming arrival takes one tap. The clinician can record an outcome: admitted, "
           "treated and sent home, or transferred. An acknowledgement QR code is created at once."),
    (50.6, "On the hospital's list, she is now marked as arrived, with the time."),
    (56.5, "She can be given a follow-up date back at her CHPS compound. The acknowledgement "
           "travels back on her card, or is scanned from this screen by the officer, so Amina "
           "learns that Fati arrived, with no network needed."),
]


def duration(p):
    out = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "json", p],
                         capture_output=True, text=True, check=True).stdout
    return float(json.loads(out)["format"]["duration"])


def main():
    with tempfile.TemporaryDirectory() as tmp:
        clips, starts, end = [], [], 0.0
        for i, (planned, text) in enumerate(LINES):
            mp3 = os.path.join(tmp, f"n{i}.mp3")
            subprocess.run([sys.executable, "-m", "edge_tts", "--voice", VOICE,
                            "--text", text.replace("CHPS", "chips"), "--write-media", mp3],
                           check=True, capture_output=True)
            start = max(planned, end + 0.4)
            d = duration(mp3)
            clips.append(mp3)
            starts.append(start)
            end = start + d
            print(f"line {i + 1}: {start:5.1f}s to {end:5.1f}s")

        src_len = duration(SRC)
        video_len = src_len + HOLD_FOR
        tail = max(0.0, end + 1.5 - video_len)  # hold the last frame if speech runs past

        vf = (f"[0:v]setpts=PTS-STARTPTS,fps=30,scale=1080:2400:flags=lanczos,setsar=1,split[a][b];"
              f"[a]trim=end={HOLD_AT},setpts=PTS-STARTPTS,"
              f"tpad=stop_mode=clone:stop_duration={HOLD_FOR}[v1];"
              f"[b]trim=start={HOLD_AT},setpts=PTS-STARTPTS,"
              f"tpad=stop_mode=clone:stop_duration={tail:.2f}[v2];"
              f"[v1][v2]concat=n=2:v=1:a=0,format=yuv420p[v]")
        inputs = ["-i", SRC]
        mix = []
        for i, (c, s) in enumerate(zip(clips, starts), 1):
            inputs += ["-i", c]
            mix.append(f"[{i}:a]aresample=48000,aformat=channel_layouts=stereo,"
                       f"adelay={int(s * 1000)}:all=1[n{i}]")
        total = video_len + tail
        af = ";".join(mix) + ";" + "".join(f"[n{i}]" for i in range(1, len(clips) + 1)) + \
            f"amix=inputs={len(clips)}:normalize=0,apad,atrim=duration={total:.2f}[aout]"
        out = os.path.join(HERE, "lafii-part2.mp4")
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", *inputs,
                        "-filter_complex", vf + ";" + af, "-map", "[v]", "-map", "[aout]",
                        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", "30",
                        "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out], check=True)
        print(f"Wrote {out} ({int(total // 60)}:{total % 60:04.1f})")


if __name__ == "__main__":
    main()
