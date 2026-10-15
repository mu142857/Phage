from PIL import Image
import math

def hexc(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)

def grid(rows, pal):
    """rows: list of strings, '.' = transparent; pal: char -> hex"""
    h = len(rows); w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h), (0,0,0,0))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in ('.', ' '): continue
            im.putpixel((x, y), hexc(pal[c]))
    return im

def put(im, x, y, col):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), hexc(col) if isinstance(col, str) else col)

def disc(im, cx, cy, r, ramp, light=(-0.45, -0.9), ring=None):
    """top-lit shaded disc; ramp = [highlight ... dark]; ring=(r_in) leaves hole"""
    lx, ly = light; ln = math.hypot(lx, ly); lx, ly = lx/ln, ly/ln
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r: continue
            if ring is not None and d < ring: continue
            nz = math.sqrt(max(0, 1 - (d / r) ** 2))
            nx, ny = dx / r, dy / r
            v = -(nx * lx + ny * ly) * 0.75 + nz * 0.35  # brightness
            t = (1 - (v + 0.6) / 1.4)
            i = min(len(ramp) - 1, max(0, int(t * len(ramp))))
            put(im, x, y, ramp[i])

def blank(w, h):
    return Image.new('RGBA', (w, h), (0,0,0,0))
