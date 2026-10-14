"""Render an 8x8 font (256 characters, 8 bytes each) to PNG without third-party libraries.

Usage:
    python show_font.py [font_file] [output.png] [scale]
Defaults: pr_fnt.bin -> font.png next to this script, scale 4.
"""
import os
import struct
import sys
import zlib

here = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "pr_fnt.bin")
dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "font.png")
scale = int(sys.argv[3]) if len(sys.argv) > 3 else 4

font = open(src, "rb").read()
count = len(font) // 8
cols, cell = 16, 10  # 16 characters per row, 10x10 cell (8x8 glyph + grid)
rows = (count + cols - 1) // cols
w, h = cols * cell * scale, rows * cell * scale

# 0 - background, 1 - glyph pixel, 2 - grid
img = [[0] * (cols * cell) for _ in range(rows * cell)]
for y in range(rows * cell):
    for x in range(cols * cell):
        if x % cell == 0 or y % cell == 0:
            img[y][x] = 2
for ch in range(count):
    ox, oy = (ch % cols) * cell + 1, (ch // cols) * cell + 1
    for r in range(8):
        bits = font[ch * 8 + r]
        for c in range(8):
            if bits & (0x80 >> c):
                img[oy + r][ox + c] = 1

palette = {0: b"\xff\xff\xff", 1: b"\x00\x00\x00", 2: b"\xd0\xd0\xd0"}
raw = bytearray()
for row in img:
    line = b"".join(palette[p] * scale for p in row)
    for _ in range(scale):
        raw += b"\x00" + line


def chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))


with open(dst, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
    f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
    f.write(chunk(b"IEND", b""))
print(f"{count} characters -> {dst} ({w}x{h})")
