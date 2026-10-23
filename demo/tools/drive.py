"""Drives the Lafii app on the emulator through adb, by on-screen text."""
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ADB = os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe")
PKG = "com.example.lafii"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def sh(*args, check=True):
    r = subprocess.run([ADB, *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def nodes():
    for _ in range(3):
        sh("shell", "uiautomator", "dump", "/sdcard/ui.xml", check=False)
        raw = sh("shell", "cat", "/sdcard/ui.xml", check=False)
        if raw.strip().startswith("<?xml"):
            break
        time.sleep(0.5)
    root = ET.fromstring(raw)
    out = []
    for n in root.iter("node"):
        label = (n.get("text") or "") + "|" + (n.get("content-desc") or "") + "|" + (n.get("hint") or "")
        b = [int(x) for x in re.findall(r"\d+", n.get("bounds"))]
        out.append({"label": label, "cls": n.get("class"), "b": b,
                    "click": n.get("clickable") == "true", "focused": n.get("focused") == "true"})
    return out


def find(text, exact=False, index=0, timeout=8.0):
    deadline = time.time() + timeout
    while True:
        hits = []
        for n in nodes():
            parts = n["label"].split("|")
            ok = any(p == text for p in parts) if exact else text in n["label"]
            if ok and n["b"][2] > n["b"][0]:
                hits.append(n)
        if len(hits) > index:
            return hits[index]
        if time.time() > deadline:
            raise LookupError(f"not on screen: {text!r}")
        time.sleep(0.4)


def center(n):
    x1, y1, x2, y2 = n["b"]
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap(text, exact=False, index=0, dx=0, dy=0, pause=0.6):
    x, y = center(find(text, exact, index))
    sh("shell", "input", "tap", str(x + dx), str(y + dy))
    time.sleep(pause)


def tap_xy(x, y, pause=0.6):
    sh("shell", "input", "tap", str(x), str(y))
    time.sleep(pause)


def type_text(s, pause=0.4):
    # Type in small chunks so it looks like typing on the recording.
    for word in s.split(" "):
        if word:
            sh("shell", "input", "text", word)
        if word is not s.split(" ")[-1]:
            sh("shell", "input", "keyevent", "62")  # space
    time.sleep(pause)


def field_after(label, index=0):
    """The input box below a field label."""
    lab = find(label, exact=True, index=index)
    x1, y1, x2, y2 = lab["b"]
    for n in nodes():
        if n["cls"] == "android.widget.EditText" and n["b"][1] >= y2 - 4 and n["b"][1] < y2 + 220 \
                and n["b"][0] <= x1 + 40:
            return n
    raise LookupError(f"no input under {label!r}")


def fill(label, value, index=0):
    x, y = center(field_after(label, index))
    sh("shell", "input", "tap", str(x), str(y))
    time.sleep(0.4)
    type_text(value)


def keyboard_shown():
    out = sh("shell", "dumpsys", "input_method", check=False)
    vis = re.findall(r"mImeWindowVis=(\d+)", out)
    return "mInputShown=true" in out or any(v != "0" for v in vis)


def hide_keyboard():
    if keyboard_shown():
        sh("shell", "input", "keyevent", "4")  # back closes the IME only
        time.sleep(0.6)


def back(pause=0.8):
    sh("shell", "input", "keyevent", "4")
    time.sleep(pause)


def swipe_up(dist=900, ms=600, pause=0.6):
    sh("shell", "input", "swipe", "540", "1700", "540", str(1700 - dist), str(ms))
    time.sleep(pause)


def scroll_to(text, exact=False, max_swipes=8):
    for _ in range(max_swipes):
        try:
            n = find(text, exact, timeout=0.5)
            if n["b"][3] < 2150 and n["b"][1] > 250:
                return n
        except LookupError:
            pass
        swipe_up(700)
    return find(text, exact, timeout=1)


def shot(name):
    sh("shell", "screencap", "-p", "/sdcard/shot.png")
    path = os.path.join(OUT, "tools", "shots", f"{name}.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sh("pull", "/sdcard/shot.png", path)
    return path


_rec = None


def rec_start(name):
    global _rec
    sh("shell", "rm", "-f", f"/sdcard/{name}.mp4", check=False)
    _rec = (name, subprocess.Popen([ADB, "shell", "screenrecord", "--bit-rate", "12000000",
                                    f"/sdcard/{name}.mp4"]))
    time.sleep(1.2)


def rec_stop(hold=1.0):
    global _rec
    time.sleep(hold)
    name, p = _rec
    sh("shell", "pkill", "-INT", "screenrecord", check=False)
    p.wait(timeout=15)
    time.sleep(1.0)
    dest = os.path.join(OUT, "screen", f"{name}.mp4")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    sh("pull", f"/sdcard/{name}.mp4", dest)
    _rec = None
    return dest


def fresh_start():
    sh("shell", "am", "force-stop", PKG)
    sh("shell", "pm", "clear", PKG)
    sh("shell", "pm", "grant", PKG, "android.permission.RECORD_AUDIO")
    sh("shell", "pm", "grant", PKG, "android.permission.CAMERA")
    sh("shell", "am", "start", "-W", "-n", f"{PKG}/.MainActivity")
    time.sleep(2.5)
    find("Your name", exact=True, timeout=30)
    time.sleep(2.0)


def demo_status_bar():
    sh("shell", "settings", "put", "global", "sysui_demo_allowed", "1")
    b = ["shell", "am", "broadcast", "-a", "com.android.systemui.demo", "-e", "command"]
    sh(*b, "enter")
    sh(*b, "clock", "-e", "hhmm", "0941")
    sh(*b, "battery", "-e", "level", "100", "-e", "plugged", "false")
    sh(*b, "network", "-e", "wifi", "hide", "-e", "mobile", "hide", "-e", "airplane", "show")
    sh(*b, "notifications", "-e", "visible", "false")


if __name__ == "__main__":
    for n in nodes():
        if n["label"].strip("|"):
            print(n["cls"].split(".")[-1], n["b"], repr(n["label"]))

