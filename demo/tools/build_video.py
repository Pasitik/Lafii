"""Assembles the demo video from screen clips and voice-over clips.

    python build_video.py                  -> demo/lafii-demo.mp4 from demo/voiceover/
    python build_video.py --check          -> lists which voice clips are present
    python build_video.py --voice DIR --out FILE

For each line NN, demo/screen/lineNN.mp4 is fitted to the voice clip
lineNN.(wav|mp3|m4a|aac|ogg|flac|opus|webm). Video longer than the voice is sped
up (at most 3.5x); video shorter is held on its last frame. Each line gets a
short lead-in and tail so lines never run into each other.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO = os.path.dirname(HERE)
LINES = 15
LEAD, TAIL = 0.35, 0.45
MAX_SPEEDUP = 3.5
AUDIO_EXT = ("wav", "mp3", "m4a", "aac", "ogg", "flac", "opus", "webm")


def tool(name):
    found = shutil.which(name)
    if found:
        return found
    for p in glob.glob(os.path.expandvars(
            rf"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\{name}.exe")):
        return p
    sys.exit(f"{name} not found. Install with: winget install Gyan.FFmpeg")


FFMPEG, FFPROBE = tool("ffmpeg"), tool("ffprobe")


def duration(path):
    out = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration",
                          "-of", "json", path], capture_output=True, text=True, check=True).stdout
    return float(json.loads(out)["format"]["duration"])


def voice_for(voice_dir, n):
    for f in os.listdir(voice_dir) if os.path.isdir(voice_dir) else []:
        stem, ext = os.path.splitext(f)
        if stem.lower() in (f"line{n:02d}", f"line{n}", f"{n:02d}", f"{n}") \
                and ext.lower().lstrip(".") in AUDIO_EXT:
            return os.path.join(voice_dir, f)
    return None


def build_segment(n, voice, out):
    video = os.path.join(DEMO, "screen", f"line{n:02d}.mp4")
    v = duration(video)
    a = duration(voice) if voice else None
    target = (a + LEAD + TAIL) if a is not None else v
    speed = min(MAX_SPEEDUP, v / target) if v > target else 1.0
    played = v / speed
    hold = max(0.0, target - played)
    total = max(target, played)

    vf = (f"fps=30,setpts=PTS/{speed:.4f},scale=1080:2400:flags=lanczos,setsar=1,"
          f"tpad=stop_mode=clone:stop_duration={hold:.3f},trim=duration={total:.3f},format=yuv420p")
    cmd = [FFMPEG, "-y", "-loglevel", "error", "-i", video]
    if voice:
        cmd += ["-i", voice]
        af = (f"aresample=48000,aformat=channel_layouts=stereo,"
              f"adelay={int(LEAD * 1000)}:all=1,apad,atrim=duration={total:.3f}")
        cmd += ["-filter_complex", f"[0:v]{vf}[v];[1:a]{af}[a]", "-map", "[v]", "-map", "[a]"]
    else:
        cmd += ["-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=r=48000:cl=stereo",
                "-vf", vf, "-map", "0:v", "-map", "1:a"]
    cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-r", "30",
            "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-shortest", out]
    subprocess.run(cmd, check=True)
    note = "no voice clip, silent" if not voice else (
        f"sped up {speed:.2f}x" if speed > 1 else f"held {hold:.1f}s")
    print(f"line{n:02d}: video {v:5.1f}s, voice {a or 0:5.1f}s -> {total:5.1f}s ({note})")
    return total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", default=os.path.join(DEMO, "voiceover"))
    ap.add_argument("--out", default=os.path.join(DEMO, "lafii-demo.mp4"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    voices = {n: voice_for(args.voice, n) for n in range(1, LINES + 1)}
    if args.check:
        for n, f in voices.items():
            print(f"line{n:02d}: {os.path.basename(f) if f else 'MISSING'}")
        return

    missing = [n for n, f in voices.items() if not f]
    if missing:
        print("Missing voice clips for lines:", ", ".join(f"{n:02d}" for n in missing),
              "- those segments will be silent.")

    with tempfile.TemporaryDirectory() as tmp:
        parts, total = [], 0.0
        for n in range(1, LINES + 1):
            part = os.path.join(tmp, f"part{n:02d}.mp4")
            total += build_segment(n, voices[n], part)
            parts.append(part)
        listing = os.path.join(tmp, "list.txt")
        with open(listing, "w", encoding="utf-8") as f:
            f.writelines(f"file '{p}'\n" for p in parts)
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0",
                        "-i", listing, "-c", "copy", "-movflags", "+faststart", args.out],
                       check=True)
    print(f"Wrote {args.out} ({total / 60:.0f}:{total % 60:04.1f})")


if __name__ == "__main__":
    main()
