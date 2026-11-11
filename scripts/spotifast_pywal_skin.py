#!/usr/bin/env python3
"""Generate a pywal-coloured copy of the default Winamp skin (base-2.91) for Spotifast.

The skin keeps the default layout and shading. Only the colours change:
  - neutral / slate-blue chrome -> pywal background hue, original brightness kept
  - coloured pixels             -> pywal colours chosen by hue
                                   (red -> color1, gold -> color3, green -> color2, blue -> color4)
VISCOLOR.TXT and PLEDIT.TXT go through the same mapping, so everything matches.

Usage: spotifast_pywal_skin.py [--colors FILE] [--base FILE] [--out FILE] [--preview FILE]
"""
import argparse
import colorsys
import io
import json
import os
import re
import struct
import sys
import tempfile
import zipfile

from PIL import Image

HOME = os.path.expanduser("~")
DEFAULT_BASE = os.path.join(HOME, ".dotfiles/spotifast/.config/spotifast/skin-base/base-2.91.wsz")
DEFAULT_COLORS = os.path.join(HOME, ".cache/wal/colors.json")
DEFAULT_OUT = os.path.join(HOME, ".config/spotifast/skins/Pywal.wsz")

# Tuning
CHROME_SAT_SCALE = 1.0  # how strongly the chrome takes on the pywal background tint
CHROME_LIGHTNESS = 0.9  # <1 darkens the chrome a little toward pywal's darker look
LED_MIN_LIGHTNESS = 0.55  # keeps green LED text/numbers readable on the black display


# ---------------------------------------------------------------- colours

def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


class Mapper:
    def __init__(self, wal):
        c = wal["colors"]
        bg = hex_rgb(wal["special"]["background"])
        self.bg_h, _, self.bg_s = colorsys.rgb_to_hls(*bg)
        # Hue anchors on the original colour wheel -> pywal colour.
        self.anchors = [
            (0, hex_rgb(c["color1"])),    # red
            (45, hex_rgb(c["color3"])),   # gold / orange (titlebars, eq top)
            (120, hex_rgb(c["color2"])),  # green (LEDs, sliders)
            (180, hex_rgb(c["color6"])),  # cyan
            (235, hex_rgb(c["color4"])),  # blue (playlist selection)
            (300, hex_rgb(c["color5"])),  # magenta
            (360, hex_rgb(c["color1"])),
        ]
        self.cache = {}

    def target(self, hue_deg):
        for (h0, c0), (h1, c1) in zip(self.anchors, self.anchors[1:]):
            if h0 <= hue_deg <= h1:
                return lerp(c0, c1, (hue_deg - h0) / (h1 - h0))
        return self.anchors[0][1]

    def map(self, rgb):
        """rgb: 0-255 tuple -> 0-255 tuple"""
        if rgb in self.cache:
            return self.cache[rgb]
        r, g, b = (x / 255 for x in rgb)
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        chroma = max(r, g, b) - min(r, g, b)
        hue = h * 360

        # The default chrome is a slate blue, so blue hues need much more chroma
        # before they count as "coloured".
        if 190 <= hue <= 260:
            w = smoothstep(0.40, 0.65, chroma)
        else:
            w = smoothstep(0.06, 0.18, chroma)

        # neutral mapping: background hue, original brightness
        ns = min(1.0, min(s, 0.45) / 0.25 * self.bg_s * CHROME_SAT_SCALE)
        ns *= 1 - 0.65 * smoothstep(0.35, 0.8, l)  # light buttons stay a pale grey
        neutral = colorsys.hls_to_rgb(self.bg_h, l * CHROME_LIGHTNESS if l < 0.95 else l, ns)

        # coloured mapping: pywal colour hue/sat, original brightness
        th, tl, ts = colorsys.rgb_to_hls(*self.target(hue))
        cl = l
        if 80 <= hue <= 160 and l >= 0.45:  # bright greens = LED text
            cl = max(l, LED_MIN_LIGHTNESS, tl)
        cs = min(1.0, ts * min(1.0, s / 0.6 + 0.3))
        coloured = colorsys.hls_to_rgb(th, cl, cs)

        out = tuple(round(255 * min(1, max(0, v))) for v in lerp(neutral, coloured, w))
        self.cache[rgb] = out
        return out


# ---------------------------------------------------------------- BMP

def read_bmp(data):
    """Lenient reader: base-2.91 has RLE8 files that Pillow rejects."""
    off = struct.unpack_from("<I", data, 10)[0]
    _, w, h, _, bpp, comp = struct.unpack_from("<IiiHHI", data, 14)
    if not (bpp == 8 and comp == 1):
        return Image.open(io.BytesIO(data)).convert("RGB")
    ncol = struct.unpack_from("<I", data, 46)[0] or 256
    pal = [(data[54 + 4 * i + 2], data[54 + 4 * i + 1], data[54 + 4 * i]) for i in range(ncol)]
    flip = h > 0
    h = abs(h)
    px = [[0] * w for _ in range(h)]
    x = y = 0
    i = off
    while i + 1 < len(data) and y < h:
        a, b = data[i], data[i + 1]
        i += 2
        if a:
            for _ in range(a):
                if x < w:
                    px[y][x] = b
                x += 1
        elif b == 0:
            x, y = 0, y + 1
        elif b == 1:
            break
        elif b == 2:
            x, y, i = x + data[i], y + data[i + 1], i + 2
        else:
            for k in range(b):
                if x < w and i + k < len(data):
                    px[y][x] = data[i + k]
                x += 1
            i += b + (b & 1)
    im = Image.new("RGB", (w, h))
    rows = reversed(px) if flip else px
    im.putdata([pal[c] if c < len(pal) else (0, 0, 0) for row in rows for c in row])
    return im


def recolor_image(im, m):
    im = im.convert("RGB")
    pixels = im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()
    im.putdata([m.map(p) for p in pixels])
    return im


# ---------------------------------------------------------------- text files

def recolor_viscolor(text, m):
    out = []
    for line in text.splitlines():
        mt = re.match(r"\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,?(.*)", line)
        if mt:
            r, g, b = m.map(tuple(int(mt.group(i)) for i in (1, 2, 3)))
            out.append(f"{r},{g},{b},{mt.group(4)}")
        else:
            out.append(line)
    return "\r\n".join(out) + "\r\n"


def recolor_pledit(text, m):
    def sub(mt):
        h = mt.group(1)
        r, g, b = m.map(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)))
        return f"#{r:02X}{g:02X}{b:02X}"
    return re.sub(r"#([0-9A-Fa-f]{6})", sub, text)


# ---------------------------------------------------------------- main

def build(base, wal):
    m = Mapper(wal)
    files = {}
    with zipfile.ZipFile(base) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            name = os.path.basename(info.filename)
            data = z.read(info)
            up = name.upper()
            if up.endswith(".BMP"):
                buf = io.BytesIO()
                recolor_image(read_bmp(data), m).save(buf, "BMP")
                data = buf.getvalue()
            elif up == "VISCOLOR.TXT":
                data = recolor_viscolor(data.decode("latin-1"), m).encode("latin-1")
            elif up == "PLEDIT.TXT":
                data = recolor_pledit(data.decode("latin-1"), m).encode("latin-1")
            files[name] = data
    return files


def write_preview(files, path):
    names = ["MAIN.BMP", "TITLEBAR.BMP", "CBUTTONS.BMP", "EQMAIN.BMP", "PLEDIT.BMP", "VOLUME.BMP", "TEXT.BMP"]
    ims = [Image.open(io.BytesIO(files[n])) for n in names if n in files]
    sheet = Image.new("RGB", (sum(i.width for i in ims) + 4 * len(ims), max(i.height for i in ims)), (48, 48, 48))
    x = 0
    for i in ims:
        sheet.paste(i, (x, 0))
        x += i.width + 4
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--colors", default=DEFAULT_COLORS)
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--preview", help="also write a PNG contact sheet here")
    a = ap.parse_args()

    with open(a.colors) as f:
        wal = json.load(f)
    files = build(a.base, wal)

    out_dir = os.path.dirname(os.path.abspath(a.out))
    os.makedirs(out_dir, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=out_dir, prefix=".pywal-skin.", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as fh, zipfile.ZipFile(fh, "w", zipfile.ZIP_DEFLATED) as z:
            for name, data in files.items():
                z.writestr(name, data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, a.out)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    if a.preview:
        write_preview(files, a.preview)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    sys.exit(main())
