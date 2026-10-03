"""Vertical (1080x1920) TikTok showcase from the recorded takes.

Takes (zerosievert-coop-work/caps): host.mkv + guest.mkv (same moment, two windows), menu.mkv (one window).
Text is drawn with the game's own Cyrillic pixel font (silver.ttf from the user's install, render-only).
"""
import shutil
import subprocess
from pathlib import Path

CAPS = Path(r"C:\Users\pasha\zerosievert-coop-work\caps")
OUT = CAPS / "showcase"
FF = next(Path(r"C:\Users\pasha\AppData\Local\Microsoft\WinGet\Packages").glob("Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe"))
FONT_SRC = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ZERO Sievert\ZS_vanilla\languages\russian\silver.ttf")
ACCENT = "0xB6FF3B"
GREY = "0x9aa38f"
BG = "0x0c0e0a"
CROP = "crop=840:472:262:124,scale=1000:562:flags=neighbor,setsar=1"

OUT.mkdir(exist_ok=True)
shutil.copy(FONT_SRC, OUT / "silver.ttf")
_n = 0


def dt(text, size, color, y):
    global _n
    _n += 1
    (OUT / f"t{_n}.txt").write_text(text, encoding="utf-8")
    return f"drawtext=fontfile=silver.ttf:textfile=t{_n}.txt:fontsize={size}:fontcolor={color}:x=(w-tw)/2:y={y}"


def block(text_lines, size, color, y0, gap=1.3):
    return ",".join(dt(t, size, color, int(y0 + i * size * gap)) for i, t in enumerate(text_lines))


def run(args):
    subprocess.run([str(FF), "-v", "error", "-y"] + args, cwd=OUT, check=True)


def fades(dur):
    return f"fade=t=in:st=0:d=0.2,fade=t=out:st={dur - 0.2:.2f}:d=0.2"


def seg_dual(name, t, dur, title, caption):
    """Host on top, guest below."""
    texts = ",".join([
        block(title, 100, ACCENT, 150),
        block(caption, 62, "white", 150 + len(title) * 130 + 10, gap=1.25),
        dt("ИГРОК 1 · ХОСТ", 46, GREY, 640),
        dt("ИГРОК 2 · ГОСТЬ", 46, GREY, 1258),
    ])
    fc = (f"[0:v]{CROP}[h];[1:v]{CROP}[g];color=c={BG}:s=1080x1920:d={dur}:r=30[bg];"
          f"[bg][h]overlay=40:690:shortest=1[b1];[b1][g]overlay=40:1308:shortest=1,{texts},"
          f"{fades(dur)},fps=30,format=yuv420p[v]")
    run(["-ss", str(t), "-t", str(dur), "-i", str(CAPS / "host.mkv"),
         "-ss", str(t), "-t", str(dur), "-i", str(CAPS / "guest.mkv"),
         "-filter_complex", fc, "-map", "[v]", "-an", "-c:v", "libx264", "-crf", "18", name])


def seg_single(name, src, t, dur, title, caption, crop="scale=1080:607:flags=lanczos"):
    texts = ",".join([block(title, 100, ACCENT, 150), block(caption, 62, "white", 150 + len(title) * 130 + 10, gap=1.25)])
    fc = (f"[0:v]{crop},setsar=1[m];color=c={BG}:s=1080x1920:d={dur}:r=30[bg];"
          f"[bg][m]overlay=0:760:shortest=1,{texts},{fades(dur)},fps=30,format=yuv420p[v]")
    run(["-ss", str(t), "-t", str(dur), "-i", str(CAPS / src), "-filter_complex", fc,
         "-map", "[v]", "-an", "-c:v", "libx264", "-crf", "18", name])


def seg_card(name, dur, rows):
    parts = []
    y = 300
    for text, size, color in rows:
        parts.append(dt(text, size, color, y))
        y += int(size * 1.3) + (60 if size > 90 else (24 if color == GREY else 6))
    fc = (f"color=c={BG}:s=1080x1920:d={dur}:r=30," + ",".join(parts) +
          f",fade=t=in:st=0:d=0.3,fade=t=out:st={dur - 0.6:.2f}:d=0.6,format=yuv420p[v]")
    run(["-filter_complex", fc, "-map", "[v]", "-t", str(dur), "-an", "-c:v", "libx264", "-crf", "18", name])


segs = [
    ("dual", "s01.mp4", 10.6, 3.0, ["ZERO SIEVERT", "В КООПЕРАТИВЕ"], ["мод на совместные рейды"]),
    ("single", "s02.mp4", "menu.mkv", 0.2, 2.4, ["F7 - ПАНЕЛЬ КООПА"], ["приглашение через Steam", "или подключение по IP"], "crop=760:428:260:110,scale=1080:608:flags=lanczos"),
    ("dual", "s03.mp4", 13.0, 3.0, ["ОДНА КАРТА", "НА ДВОИХ"], ["общие враги и общий лут", "видно и слышно друг друга"]),
    ("dual", "s04.mp4", 16.2, 2.8, ["СМЕРТЕЛЬНЫЙ", "УРОН?"], ["ты не умираешь, а падаешь", "можно ползти и стрелять", "из пистолета"]),
    ("dual", "s05.mp4", 18.0, 3.4, ["ДРУГ ПОДНИМАЕТ"], ["без предметов, бинтом", "или аптечкой - от этого", "зависит HP после подъёма"]),
    ("dual", "s06.mp4", 21.4, 5.6, ["АПТЕЧКА - 5 СЕКУНД"], ["2-е ранение - таймер вдвое", "короче, 3-е - смерть"]),
    ("single", "s07.mp4", "menu.mkv", 16.8, 3.6, ["СВОИ ПРАВИЛА"], ["таймер, время подъёма,", "огонь по союзнику"], "crop=1180:664:50:24,scale=1080:608:flags=lanczos"),
    ("single", "s08.mp4", "menu.mkv", 22.6, 2.6, ["СВОЯ СЛОЖНОСТЬ"], ["количество врагов", "и аномалий, лут, потеря вещей"], "crop=1180:664:50:24,scale=1080:608:flags=lanczos"),
]
names = []
for s in segs:
    if s[0] == "dual":
        seg_dual(*s[1:])
    else:
        seg_single(*s[1:])
    names.append(s[1])
seg_card("s09.mp4", 5.5, [
    ("ZERO SIEVERT CO-OP", 112, ACCENT),
    ("ГОТОВО", 60, GREY),
    ("совместные рейды", 72, "white"),
    ("общий лут", 72, "white"),
    ("ранения и поднятие", 72, "white"),
    ("настраиваемая сложность", 72, "white"),
    ("ДАЛЬШЕ", 60, GREY),
    ("тест с другом через Steam", 72, "white"),
    ("вход в идущий рейд", 72, "white"),
    ("полировка", 72, "white"),
])
names.append("s09.mp4")
(OUT / "list.txt").write_text("".join(f"file '{n}'\n" for n in names), encoding="utf-8")
run(["-f", "concat", "-safe", "0", "-i", "list.txt", "-c", "copy", "zs_coop_tiktok.mp4"])
print(OUT / "zs_coop_tiktok.mp4")
