#!/usr/bin/env python3
"""Generate PlayerOverlay gradient and focus-pill PNGs — pure Python, no Pillow."""
import struct
import zlib
import os
import sys

def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    c = chunk_type + data
    crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    return struct.pack(">I", len(data)) + c + crc

def write_png(path: str, width: int, height: int, pixels: bytes) -> None:
    """pixels: raw RGBA bytes, row-major, no filter byte."""
    assert len(pixels) == width * height * 4
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw = b''
    stride = width * 4
    for y in range(height):
        raw += b'\x00'  # filter: none
        raw += pixels[y * stride : (y + 1) * stride]
    compressed = zlib.compress(raw)
    png = sig + png_chunk(b'IHDR', ihdr) + png_chunk(b'IDAT', compressed) + png_chunk(b'IEND', b'')
    with open(path, "wb") as f:
        f.write(png)

def top_gradient(out_dir: str) -> None:
    """1280x120, #101112 with alpha 0xCC at top → 0x00 at bottom."""
    w, h = 1280, 120
    pixels = bytearray(w * h * 4)
    for y in range(h):
        alpha = int(204 * (1.0 - y / (h - 1)))  # 0xCC → 0x00
        for x in range(w):
            i = (y * w + x) * 4
            pixels[i] = 16; pixels[i+1] = 17; pixels[i+2] = 18; pixels[i+3] = alpha
    write_png(os.path.join(out_dir, "player-gradient-top.png"), w, h, bytes(pixels))

def bottom_gradient(out_dir: str) -> None:
    """1280x192, #101112 with alpha 0x00 at top → 0xCC at bottom."""
    w, h = 1280, 192
    pixels = bytearray(w * h * 4)
    for y in range(h):
        alpha = int(204 * (y / (h - 1)))
        for x in range(w):
            i = (y * w + x) * 4
            pixels[i] = 16; pixels[i+1] = 17; pixels[i+2] = 18; pixels[i+3] = alpha
    write_png(os.path.join(out_dir, "player-gradient-bottom.png"), w, h, bytes(pixels))

def focus_pill(out_dir: str) -> None:
    """240x48 rounded pill, #202224 fill, 12px corner radius."""
    w, h, r = 240, 48, 12
    pixels = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            inside = True
            # top-left
            if x < r and y < r:
                dx, dy = r - x - 1, r - y - 1
                inside = dx*dx + dy*dy <= r*r
            # top-right
            elif x >= w - r and y < r:
                dx, dy = x - (w - r), r - y - 1
                inside = dx*dx + dy*dy <= r*r
            # bottom-left
            elif x < r and y >= h - r:
                dx, dy = r - x - 1, y - (h - r)
                inside = dx*dx + dy*dy <= r*r
            # bottom-right
            elif x >= w - r and y >= h - r:
                dx, dy = x - (w - r), y - (h - r)
                inside = dx*dx + dy*dy <= r*r
            if inside:
                i = (y * w + x) * 4
                pixels[i] = 245; pixels[i+1] = 245; pixels[i+2] = 245; pixels[i+3] = 255
    write_png(os.path.join(out_dir, "player-focus-pill.png"), w, h, bytes(pixels))

def main() -> None:
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "images")
    os.makedirs(out, exist_ok=True)
    top_gradient(out)
    bottom_gradient(out)
    focus_pill(out)
    print(f"Wrote player-gradient-top.png, player-gradient-bottom.png, player-focus-pill.png → {out}")

if __name__ == "__main__":
    main()