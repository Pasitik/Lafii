"""Joins Part 1 screen clips with their narration.

python assemble.py -> demo/part1/lafii-part1.mp4
Each clip is sped up (max 3x) or held on its last frame to fit its line.
The final referral QR is held longer so it can be scanned from the video.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from build_video import FFMPEG, FFPROBE  # noqa: E402

LEAD, TAIL, MAX_SPEEDUP, FINAL_HOLD = 0.4, 0.5, 3.0, 8.0


def duration(p):
    out = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "json", p],
                         capture_output=True, text=True, check=True).stdout
    return float(json.loads(out)["format"]["duration"])


def tighten(video, tmp):
    """Drops frames where nothing on screen changes (the automation waiting
    between taps), keeping every real movement at normal speed."""
    out = os.path.join(tmp, "tight_" + os.path.basename(video))
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", video, "-vf",
                    "fps=30,mpdecimate=hi=64:lo=16:frac=0.02:max=12,setpts=N/30/TB",
                    "-an", "-c:v", "libx264", "-crf", "16", "-r", "30", out], check=True)
    return out


def segment(video, voice, out, extra_hold=0.0):
    v, a = duration(video), duration(voice)
    target = a + LEAD + TAIL
    if v > target * 2.5:
        video = tighten(video, os.path.dirname(out))
        v = duration(video)
    speed = min(MAX_SPEEDUP, v / target) if v > target else 1.0
    played = v / speed
    total = max(target, played) + extra_hold
    hold = total - played
    vf = (f"setpts=PTS-STARTPTS,fps=30,setpts=PTS/{speed:.4f},scale=1080:2400:flags=lanczos,setsar=1,"
          f"tpad=stop_mode=clone:stop_duration={hold:.3f},trim=duration={total:.3f},format=yuv420p")
    af = (f"aresample=48000,aformat=channel_layouts=stereo,adelay={int(LEAD * 1000)}:all=1,"
          f"apad,atrim=duration={total:.3f}")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", video, "-i", voice,
                    "-filter_complex", f"[0:v]{vf}[v];[1:a]{af}[a]", "-map", "[v]", "-map", "[a]",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", "30",
                    "-c:a", "aac", "-b:a", "160k", "-ar", "48000", out], check=True)
    print(f"{os.path.basename(video)}: video {v:5.1f}s voice {a:5.1f}s -> {total:5.1f}s"
          f" ({'x%.2f' % speed if speed > 1 else 'held %.1fs' % hold})")
    return total


def main():
    ids = [l.split("|")[0] for l in open(os.path.join(HERE, "narration.txt"), encoding="utf-8-sig")
           if l.strip()]
    with tempfile.TemporaryDirectory() as tmp:
        parts, total = [], 0.0
        for i, sid in enumerate(ids):
            part = os.path.join(tmp, f"{sid}.mp4")
            total += segment(os.path.join(HERE, "screen", f"{sid}.mp4"),
                             os.path.join(HERE, "voice", f"{sid}.mp3"), part,
                             FINAL_HOLD if i == len(ids) - 1 else 0.0)
            parts.append(part)
        # Re-encode while joining: segments from different recorders differ in
        # encoder settings, and a stream copy silently drops some of them.
        out = os.path.join(HERE, "lafii-part1.mp4")
        inputs = [x for p in parts for x in ("-i", p)]
        streams = "".join(f"[{i}:v][{i}:a]" for i in range(len(parts)))
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", *inputs, "-filter_complex",
                        f"{streams}concat=n={len(parts)}:v=1:a=1[v][a]", "-map", "[v]", "-map", "[a]",
                        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", "30",
                        "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out], check=True)
    print(f"Wrote {out} ({int(total // 60)}:{total % 60:04.1f})")


if __name__ == "__main__":
    main()
