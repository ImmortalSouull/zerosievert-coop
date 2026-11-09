"""ZERO Sievert CO-OP 2.0.0 showcase (1920x1080, English captions) from the takes in zerosievert-coop-work/caps/v2.

Takes are desktop recordings (ffmpeg ddagrab, re-encoded to mp4 with -g 15 so seeking works) of test windows: show.ts (scenario show, 2 windows), octo2.ts
(8 windows, 4x2 grid of 640x360), trade/event/extract/arena.ts (2 windows). Two-window takes: window A at x 0..1180,
y 8..672, window B at x 1200..2380. Text uses the game's own pixel font (silver.ttf from the user's install).
"""
import os
import shutil
import subprocess
from pathlib import Path

CAPS = Path(__file__).resolve().parent.parent.parent / "zerosievert-coop-work" / "caps" / "v2"
OUT = CAPS / "out"
FF = next((Path(os.environ["LOCALAPPDATA"]) / "Microsoft" / "WinGet" / "Packages").glob("Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe"))
FONT_SRC = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert\ZS_vanilla\languages\english\silver.ttf")
if not FONT_SRC.exists():
    FONT_SRC = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert\ZS_vanilla\languages\russian\silver.ttf")
ACCENT = "0xB6FF3B"
GREY = "0x9aa38f"
BG = "0x0c0e0a"
WA = "crop=1180:664:0:8"
WB = "crop=1180:664:1200:8"

OUT.mkdir(exist_ok=True)
shutil.copy(FONT_SRC, OUT / "silver.ttf")
_n = 0


def dt(text, size, color, y, x="(w-tw)/2"):
    global _n
    _n += 1
    (OUT / f"t{_n}.txt").write_text(text, encoding="utf-8")
    return f"drawtext=fontfile=silver.ttf:textfile=t{_n}.txt:fontsize={size}:fontcolor={color}:x={x}:y={y}"


def caption(title, sub):
    return ",".join([dt(title, 96, ACCENT, 40), dt(sub, 52, "white", 150)])


def fades(dur):
    return f"fade=t=in:st=0:d=0.25,fade=t=out:st={dur - 0.25:.2f}:d=0.25"


def run(args):
    subprocess.run([str(FF), "-v", "error", "-y"] + args, cwd=OUT, check=True)


def enc(name, inputs, fc, dur):
    run(inputs + ["-filter_complex", fc, "-map", "[v]", "-t", str(dur), "-an", "-r", "30",
                  "-c:v", "libx264", "-crf", "18", "-preset", "medium", "-pix_fmt", "yuv420p", name])


def seg_single(name, src, t, dur, title, sub, win=WA):
    fc = (f"[0:v]{win},scale=1440:810:flags=lanczos,setsar=1[m];color=c={BG}:s=1920x1080:d={dur}:r=30[bg];"
          f"[bg][m]overlay=240:250:shortest=1,{caption(title, sub)},{fades(dur)}[v]")
    enc(name, ["-ss", str(t), "-t", str(dur), "-i", str(CAPS / src)], fc, dur)


def seg_dual(name, src, t, dur, title, sub):
    fc = (f"[0:v]split[a][b];[a]{WA},scale=930:523:flags=lanczos,setsar=1[l];[b]{WB},scale=930:523:flags=lanczos,setsar=1[r];"
          f"color=c={BG}:s=1920x1080:d={dur}:r=30[bg];[bg][l]overlay=20:330:shortest=1[b1];[b1][r]overlay=970:330:shortest=1,"
          f"{caption(title, sub)},{dt('PLAYER 1', 40, GREY, 280, '20')},{dt('PLAYER 2', 40, GREY, 280, '970')},{fades(dur)}[v]")
    enc(name, ["-ss", str(t), "-t", str(dur), "-i", str(CAPS / src)], fc, dur)


def seg_grid(name, src, t, dur, title, sub):
    xs = [2, 652, 1302, 1952]
    tiles = [f"crop=620:348:{x}:{y}" for y in (10, 422) for x in xs]
    parts = [f"[0:v]split=8" + "".join(f"[s{i}]" for i in range(8))]
    for i, c in enumerate(tiles):
        parts.append(f"[s{i}]{c},scale=462:259:flags=lanczos,setsar=1[g{i}]")
    parts.append(f"color=c={BG}:s=1920x1080:d={dur}:r=30[bg0]")
    prev = "bg0"
    for i in range(8):
        x = 24 + (i % 4) * 470
        y = 300 + (i // 4) * 270
        parts.append(f"[{prev}][g{i}]overlay={x}:{y}:shortest=1[bg{i + 1}]")
        prev = f"bg{i + 1}"
    parts.append(f"[{prev}]{caption(title, sub)},{dt('8 GAME WINDOWS - ONE SESSION', 40, GREY, 860)},{fades(dur)}[v]")
    enc(name, ["-ss", str(t), "-t", str(dur), "-i", str(CAPS / src)], ";".join(parts), dur)


def seg_card(name, dur, rows):
    parts = []
    y = 150
    for text, size, color in rows:
        parts.append(dt(text, size, color, y))
        y += int(size * 1.25) + (30 if size >= 90 else 8)
    fc = (f"color=c={BG}:s=1920x1080:d={dur}:r=30," + ",".join(parts) +
          f",fade=t=in:st=0:d=0.4,fade=t=out:st={dur - 0.5:.2f}:d=0.5[v]")
    enc(name, [], fc, dur)


def probe(src):
    fp = str(FF).replace("ffmpeg.exe", "ffprobe.exe")
    return float(subprocess.run([fp, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(CAPS / src)],
                                capture_output=True, text=True).stdout)


names = []


def add(fn, name, *a):
    fn(name, *a)
    names.append(name)


add(seg_card, "c01.mp4", 4.0, [
    ("ZERO SIEVERT", 150, ACCENT),
    ("CO-OP 2.0", 150, ACCENT),
    ("raid together with your friends", 64, "white"),
    ("free mod - up to 8 players", 56, GREY),
])
add(seg_grid, "c02.mp4", "octo2.mp4", probe("octo2.mp4") - 16, 6.0, "UP TO 8 PLAYERS", "one raid - one map - shared enemies and loot")
add(seg_dual, "c03.mp4", "show.mp4", 21.0, 5.5, "COMMAND WHEEL, PINGS & CHAT", "hold Z for quick commands - Enter to type")
add(seg_dual, "c04.mp4", "show.mp4", 27.0, 5.0, "VOICE CHAT", "hold C to talk - quieter with distance")
add(seg_dual, "c05.mp4", "show.mp4", 32.5, 8.5, "GO DOWN, GET REVIVED", "your teammate picks a bandage or a medkit")
add(seg_single, "c06.mp4", "show.mp4", 45.5, 5.0, "RADIO", "talk to your team on a channel at any distance")
add(seg_single, "c07.mp4", "trade.mp4", 29.0, 4.5, "TRADING", "both players offer items, both confirm")
add(seg_single, "c08.mp4", "event.mp4", 26.5, 7.0, "RAID EVENTS", "answer a call for help - hold out against the waves")
add(seg_single, "c09.mp4", "extract.mp4", 24.0, 5.0, "GROUP EXTRACTION", "the countdown waits for your team")
add(seg_single, "c10.mp4", "extract.mp4", 32.0, 3.5, "RAID SUMMARY", "kills, damage, revives and loot of every player")
add(seg_single, "c11.mp4", "arena.mp4", 17.0, 7.0, "ARENA IN THE BUNKER", "PvP in the shooting range - nothing is lost")
add(seg_card, "c12.mp4", 7.0, [
    ("ZERO SIEVERT CO-OP 2.0", 110, ACCENT),
    ("host migration  -  crawl and drag  -  spectating", 50, "white"),
    ("shared quests  -  group tasks  -  personal loot", 50, "white"),
    ("visit your friends' bunkers  -  save backups", 50, "white"),
    ("every language of the game", 50, "white"),
    ("", 30, GREY),
    ("github.com/ImmortalSouull/zerosievert-coop", 58, ACCENT),
    ("Steam invite or direct IP - every player needs the mod", 44, GREY),
])
(OUT / "list.txt").write_text("".join(f"file '{n}'\n" for n in names), encoding="utf-8")
run(["-f", "concat", "-safe", "0", "-i", "list.txt", "-c", "copy", "zs_coop_2.0_showcase.mp4"])
print(OUT / "zs_coop_2.0_showcase.mp4")
