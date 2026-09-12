#!/usr/bin/env python3
"""Generate original antialiased monochrome Roku assets, without dependencies.

Nine-patches include the real one-pixel black stretch/content markers. Corners
and strokes use subpixel distance coverage; no third-party artwork is bundled.
"""
from pathlib import Path
import math
import struct
import zlib

OUT = Path(__file__).resolve().parents[1] / 'images'
BASE = (16, 17, 18)


def png(name, width, height, pixel):
    def chunk(kind, data):
        value = kind + data
        return struct.pack('>I', len(data)) + value + struct.pack('>I', zlib.crc32(value) & 0xffffffff)
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(pixel(x, y))
    data = b'\x89PNG\r\n\x1a\n'
    data += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b'')
    (OUT / name).write_bytes(data)


def clamp(value):
    return max(0, min(1, value))


def round_alpha(x, y, w, h, radius):
    qx = abs(x + .5 - w / 2) - (w / 2 - radius)
    qy = abs(y + .5 - h / 2) - (h / 2 - radius)
    distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius
    return clamp(.5 - distance)


def rounded(name, w, h, radius, border=0, inverse=False):
    def pixel(x, y):
        alpha = round_alpha(x, y, w, h, radius)
        if border:
            alpha -= round_alpha(x-border, y-border, w-2*border, h-2*border, max(0, radius-border))
        if inverse:
            return (*BASE, round(255*(1-alpha)))
        return (255, 255, 255, round(255*clamp(alpha)))
    png(name, w, h, pixel)


def spinner():
    def pixel(x, y):
        dx, dy = x + .5 - 32, y + .5 - 32
        coverage = clamp(2.5 - abs(math.hypot(dx, dy) - 25))
        angle = (math.atan2(dy, dx) + math.pi / 2) % (2 * math.pi)
        alpha = coverage * (.10 + .90 * angle / (2 * math.pi))
        return (245, 245, 245, round(255 * alpha))
    png('ui-spinner.png', 64, 64, pixel)


def ninepatch(name, border=0):
    def pixel(x, y):
        if x in (0, 49) or y in (0, 49):
            stretch = (y == 0 and 20 <= x <= 29) or (x == 0 and 20 <= y <= 29)
            padding = (y == 49 and 10 <= x <= 39) or (x == 49 and 10 <= y <= 39)
            return (0, 0, 0, 255 if stretch or padding else 0)
        alpha = round_alpha(x-1, y-1, 48, 48, 8)
        if border:
            alpha -= round_alpha(x-1-border, y-1-border, 48-2*border, 48-2*border, 8-border)
        return (255, 255, 255, round(255*clamp(alpha)))
    png(name, 50, 50, pixel)


def progress_pill():
    # Six-pixel pill with fixed three-pixel end caps and a stretchable middle.
    def pixel(x, y):
        if x in (0, 9) or y in (0, 7):
            stretch = (y == 0 and 4 <= x <= 5) or (x == 0 and 3 <= y <= 4)
            return (0, 0, 0, 255 if stretch else 0)
        return (255, 255, 255, round(255 * round_alpha(x-1, y-1, 8, 6, 3)))
    png('ui-progress-pill.9.png', 10, 8, pixel)


def segment_distance(x, y, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]
    length = dx*dx + dy*dy
    t = clamp(((x-a[0])*dx+(y-a[1])*dy)/length) if length else 0
    return math.hypot(x-a[0]-t*dx, y-a[1]-t*dy)


def icon(name, paths=(), circles=()):
    segments = [(a,b) for path in paths for a,b in zip(path,path[1:])]
    def pixel(x, y):
        distances = [segment_distance(x+.5,y+.5,a,b) for a,b in segments]
        distances += [abs(math.hypot(x+.5-cx,y+.5-cy)-r) for cx,cy,r in circles]
        distance = min(distances) if distances else 64
        return (255,255,255,round(255*clamp(2.1-distance)))
    png('ui-nav-' + name + '.png',64,64,pixel)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    icon('home', [[(10,30),(32,11),(54,30)],[(17,27),(17,52),(28,52),(28,38),(37,38),(37,52),(47,52),(47,27)]])
    icon('discover', [[(24,41),(29,28),(42,22),(36,36),(24,41)]], [(32,32,23)])
    icon('tv', [[(14,15),(50,15),(55,20),(55,43),(50,48),(14,48),(9,43),(9,20),(14,15)],[(24,55),(40,55)],[(32,48),(32,55)]])
    icon('list', [[(18,10),(46,10),(46,54),(32,44),(18,54),(18,10)]])
    icon('search', [[(40,40),(54,54)]], [(27,27,17)])
    gear = []
    for i in range(32):
        angle = (i/32)*math.tau
        radius = 24 if i % 4 in (1,2) else 19
        gear.append((32+radius*math.cos(angle),32+radius*math.sin(angle)))
    gear.append(gear[0])
    icon('settings',[gear],[(32,32,8)])
    icon('chevron',[[(14,23),(32,41),(50,23)]])
    icon('player-rewind', [[(30,15),(12,32),(30,49),(30,15)],[(51,15),(33,32),(51,49),(51,15)]])
    icon('player-forward', [[(13,15),(31,32),(13,49),(13,15)],[(34,15),(52,32),(34,49),(34,15)]])
    icon('player-exit', [[(25,12),(12,12),(12,52),(25,52)],[(26,32),(54,32),(44,22)],[(54,32),(44,42)]])
    spinner()
    progress_pill()
    ninepatch('ui-round-fill.9.png')
    ninepatch('ui-round-outline.9.png',2)
    rounded('ui-card-corners.png',256,144,8,inverse=True)
    rounded('ui-card-focus.png',256,144,8,border=2)
    rounded('ui-profile-corners.png',160,160,12,inverse=True)
    rounded('ui-profile-focus.png',178,178,17,border=3)
    # Neutral shading retains the cinematic image instead of a flat text panel.
    png('ui-hero-left.png',1280,720,lambda x,y:(*BASE,round(218*(1-clamp((x-190)/800)))))
    png('ui-hero-bottom.png',1280,720,lambda x,y:(*BASE,round(255*clamp((y-450)/240))))
    print('Generated antialiased Roku icons, real nine-patches, masks, and gradients.')


if __name__ == '__main__':
    main()

# Video overlays need black alpha ramps even over a white video frame.
png('player-gradient-top.png', 2, 210, lambda x, y: (0, 0, 0, round(230 * (1-y/209)**1.2)))
png('player-gradient-bottom.png', 2, 338, lambda x, y: (0, 0, 0, round(250 * min(1, (y/337)*2.1)**0.65)))
