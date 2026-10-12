# 铁锈城建筑像素画小库:照用户 rust_city 建筑的画法(斑驳墙面/楼层亮线/锈迹下流/
# 深框十字窗/亮暗交替栏杆/顶光),全部逐像素画,无描边。
import random
from PIL import Image

T = (0, 0, 0, 0)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a) if len(c) == 3 else c


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c[:3])


# ---------- 材质色阶(暗→亮) ----------
OCHRE = [(58, 40, 20), (86, 60, 28), (122, 96, 48), (158, 128, 66), (184, 156, 92), (198, 178, 124)]
CONCRETE = [(30, 32, 32), (45, 46, 44), (58, 57, 52), (72, 73, 67), (88, 88, 80), (108, 104, 92)]
GREENGRAY = [(34, 42, 39), (47, 58, 52), (61, 74, 64), (78, 92, 78), (98, 110, 92), (124, 132, 110)]
BRICK = [(48, 25, 12), (77, 37, 27), (99, 52, 38), (117, 62, 44), (132, 82, 60), (150, 104, 78)]
PLASTER_PINK = [(60, 40, 36), (88, 58, 50), (118, 82, 68), (146, 108, 88), (168, 132, 106), (186, 158, 128)]
STONE = [(33, 32, 29), (48, 46, 40), (63, 60, 52), (80, 76, 66), (98, 92, 78), (118, 110, 92)]

RUST = [(62, 26, 10), (104, 46, 22), (132, 70, 40)]
FRAME = (46, 40, 33)
PANE = (26, 24, 23)
PANE_HI = (64, 60, 54)
WOOD_D = (49, 31, 25)
WOOD = (72, 44, 32)
WOOD_L = (99, 60, 44)
IRON_D = (40, 26, 22)
IRON = (70, 48, 38)
IRON_L = (123, 98, 87)
CREAM = (199, 172, 129)
LIT = [(176, 119, 58), (240, 178, 78), (255, 222, 150)]
BRASS = (199, 160, 80)


class Canvas:
    def __init__(self, w, h, seed=1):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), T)
        self.px = self.im.load()
        self.rng = random.Random(seed)

    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x, y, c, a=255):
        if self.inb(x, y):
            self.px[x, y] = rgba(c, a)

    def get(self, x, y):
        return self.px[x, y] if self.inb(x, y) else T

    def rect(self, x0, y0, x1, y1, c):  # 含端点
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.set(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.set(x, y, c)

    def darken(self, x, y, k):
        p = self.get(x, y)
        if p[3]:
            self.px[x, y] = rgba(shade(p, k), p[3])

    def tint(self, x, y, c, t):
        p = self.get(x, y)
        if p[3]:
            self.px[x, y] = rgba(mix(p, c, t), p[3])

    # ---------- 墙面:斑驳的值噪声 → 量化到色阶 ----------
    def noise_field(self, w, h, scale=6, octaves=3):
        r = self.rng
        field = [[0.0] * w for _ in range(h)]
        amp, tot = 1.0, 0.0
        s = scale
        for _ in range(octaves):
            gw, gh = w // s + 2, h // s + 2
            g = [[r.random() for _ in range(gw)] for _ in range(gh)]
            for y in range(h):
                for x in range(w):
                    fx, fy = x / s, y / s
                    ix, iy = int(fx), int(fy)
                    tx, ty = fx - ix, fy - iy
                    a = g[iy][ix] * (1 - tx) + g[iy][ix + 1] * tx
                    b = g[iy + 1][ix] * (1 - tx) + g[iy + 1][ix + 1] * tx
                    field[y][x] += (a * (1 - ty) + b * ty) * amp
            tot += amp
            amp *= 0.5
            s = max(1, s // 2)
        return [[v / tot for v in row] for row in field]

    def wall(self, x0, y0, x1, y1, ramp, base=3.2, spread=2.6, scale=6, dither=0.06):
        """斑驳墙面。base=平均色阶位置,spread=起伏。"""
        w, h = x1 - x0 + 1, y1 - y0 + 1
        f = self.noise_field(w, h, scale)
        for y in range(h):
            for x in range(w):
                v = base + (f[y][x] - 0.5) * spread * 2 + (self.rng.random() - 0.5) * dither * 4
                i = max(0, min(len(ramp) - 1, int(round(v))))
                self.set(x0 + x, y0 + y, ramp[i])

    def bricks(self, x0, y0, x1, y1, ramp, bw=4, bh=2):
        """砖纹:在已有墙面上压灰缝(暗一档),每块砖随机明暗。"""
        for y in range(y0, y1 + 1):
            row = (y - y0) // (bh + 1)
            in_mortar_row = (y - y0) % (bh + 1) == bh
            off = (bw // 2 + 1) * (row % 2)
            for x in range(x0, x1 + 1):
                if in_mortar_row or (x - x0 + off) % (bw + 1) == bw:
                    self.darken(x, y, 0.72)
                else:
                    bi = ((x - x0 + off) // (bw + 1)) * 31 + row * 17
                    k = 0.9 + ((bi * 2654435761) % 100) / 100 * 0.22
                    self.darken(x, y, k)

    def grime_bottom(self, x0, x1, y_bottom, height, k=0.55):
        """墙根发黑(地面湿气),越往下越暗。"""
        for i in range(height):
            t = (i + 1) / height
            for x in range(x0, x1 + 1):
                if self.rng.random() < 0.85:
                    self.darken(x, y_bottom - height + 1 + i, 1 - (1 - k) * t)

    def drips(self, x0, x1, y, n, maxlen=8, color=None):
        """从横线往下流的锈迹/水渍。"""
        color = color or RUST[1]
        for _ in range(n):
            x = self.rng.randint(x0, x1)
            ln = self.rng.randint(2, maxlen)
            wide = self.rng.random() < 0.4
            for j in range(ln):
                t = 0.75 * (1 - j / ln)
                self.tint(x, y + j, color, t)
                if wide and j < ln * 0.6:
                    self.tint(x + 1, y + j, color, t * 0.7)

    def stains(self, x0, y0, x1, y1, n, color, r=3, t=0.35):
        for _ in range(n):
            cx, cy = self.rng.randint(x0, x1), self.rng.randint(y0, y1)
            rr = self.rng.randint(1, r)
            for y in range(cy - rr, cy + rr * 2 + 1):
                for x in range(cx - rr, cx + rr + 1):
                    if x0 <= x <= x1 and y0 <= y <= y1:
                        d = ((x - cx) ** 2 + ((y - cy) * 0.6) ** 2) ** 0.5
                        if d <= rr and self.rng.random() < 0.8:
                            self.tint(x, y, color, t * (1 - d / (rr + 1)))

    # ---------- 楼层横线:顶亮一线 + 下面一线影 ----------
    def ledge(self, x0, x1, y, light=CREAM, overhang=1):
        self.hline(x0 - overhang, x1 + overhang, y, light)
        self.hline(x0 - overhang, x1 + overhang, y + 1, shade(light, 0.62))
        for x in range(x0, x1 + 1):
            self.darken(x, y + 2, 0.7)

    # ---------- 窗 ----------
    def window(self, x, y, w=5, h=7, lit=False, cross=True, shutter=None, sill=CREAM, broken=False, curtain=None):
        """x,y=左上角(含框)。"""
        self.rect(x, y, x + w - 1, y + h - 1, WOOD)
        self.hline(x, x + w - 1, y, WOOD_D)
        ix0, iy0, ix1, iy1 = x + 1, y + 1, x + w - 2, y + h - 2
        if lit:
            for yy in range(iy0, iy1 + 1):
                t = (yy - iy0) / max(1, iy1 - iy0)
                self.hline(ix0, ix1, yy, mix(LIT[2], LIT[1], t))
        else:
            self.rect(ix0, iy0, ix1, iy1, PANE)
            self.set(ix0, iy0, PANE_HI)
            if iy1 - iy0 > 2:
                self.set(ix0 + 1 if ix1 > ix0 else ix0, iy0 + 1, PANE_HI)
        if curtain:
            self.vline(ix0, iy0, iy1, curtain)
            self.set(ix0 + 1, iy0, curtain)
        if cross:
            mx = x + w // 2
            my = y + h // 2
            if w >= 5:
                self.vline(mx, iy0, iy1, WOOD)
            self.hline(ix0, ix1, my, WOOD)
        if broken and not lit:
            self.set(ix1, iy0, (14, 15, 16))
            self.set(ix1 - 1, iy0 + 1, (14, 15, 16))
        if sill:
            self.hline(x - 1, x + w, y + h, sill)
            self.hline(x - 1, x + w, y + h + 1, shade(sill, 0.55))
        if shutter:
            for yy in range(y, y + h):
                self.set(x - 2, yy, shutter if yy % 2 else shade(shutter, 0.75))
                self.set(x + w + 1, yy, shutter if yy % 2 else shade(shutter, 0.75))
                self.set(x - 1, yy, shade(shutter, 0.6))
                self.set(x + w, yy, shade(shutter, 0.6))

    def boarded(self, x, y, w=5, h=7):
        self.rect(x, y, x + w - 1, y + h - 1, PANE)
        for i, yy in enumerate(range(y + 1, y + h - 1, 2)):
            c = WOOD if i % 2 == 0 else WOOD_D
            self.hline(x - 1, x + w, yy, c)
            self.set(x + (i * 2) % w, yy, IRON_D)

    def door(self, x, y, w=5, h=9, color=WOOD, double=False, knob=True, step=True):
        self.rect(x - 1, y - 1, x + w, y + h - 1, FRAME)
        self.rect(x, y, x + w - 1, y + h - 1, color)
        self.hline(x, x + w - 1, y, shade(color, 1.25))
        for yy in range(y + 1, y + h):
            self.set(x, yy, shade(color, 0.8))
        if double:
            self.vline(x + w // 2, y + 1, y + h - 1, shade(color, 0.6))
            if knob:
                self.set(x + w // 2 - 1, y + h // 2 + 1, BRASS)
                self.set(x + w // 2 + 1, y + h // 2 + 1, BRASS)
        elif knob:
            self.set(x + w - 2, y + h // 2 + 1, BRASS)
        if step:
            self.hline(x - 2, x + w + 1, y + h, STONE[3])

    # ---------- 栏杆/阳台/消防梯 ----------
    def railing(self, x0, x1, y_floor, h=4, top=IRON_L, post_a=IRON_L, post_b=IRON, base=IRON_D):
        """y_floor=阳台地板那一行;栏杆在它上面 h 行。"""
        self.hline(x0, x1, y_floor - h, top)
        for x in range(x0, x1 + 1):
            c = post_a if (x - x0) % 2 == 0 else post_b
            for yy in range(y_floor - h + 1, y_floor):
                if (x - x0) % 2 == 0:
                    self.set(x, yy, c)
                else:
                    self.darken(x, yy, 0.55)
        self.hline(x0, x1, y_floor, base)
        self.hline(x0, x1, y_floor + 1, shade(base, 0.7))

    def bracket(self, x, y, n=3, dx=1, c=IRON_D):
        for i in range(n):
            self.set(x + i * dx, y + i, c)

    def stair(self, xa, ya, xb, yb, c=IRON_L, c2=IRON):
        """消防梯斜梯:从 (xa,ya) 到 (xb,yb) 的阶梯像素带,两格粗。"""
        n = abs(yb - ya)
        for i in range(n + 1):
            t = i / max(1, n)
            x = int(round(xa + (xb - xa) * t))
            y = int(round(ya + (yb - ya) * t))
            d = 1 if xb > xa else -1
            self.set(x, y, c2)
            self.set(x + d, y, c if i % 2 == 0 else c2)
            self.set(x + 2 * d, y, c2)
            self.set(x + d, y + 1, IRON_D)

    def rust_band(self, x0, x1, y, depth=5, color=None, t=0.6):
        """檐下锈带:横线下面一条不规则的锈色带,往下渐淡、参差。"""
        color = color or RUST[1]
        for x in range(x0, x1 + 1):
            d = max(1, int(depth * (0.4 + 0.8 * self.rng.random())))
            for j in range(d):
                self.tint(x, y + j, color, t * (1 - j / (d + 1)))

    def drainpipe(self, x, y0, y1, c=IRON):
        for y in range(y0, y1 + 1):
            self.set(x, y, shade(c, 1.3)); self.set(x + 1, y, c); self.set(x + 2, y, shade(c, 0.6))
            if (y - y0) % 11 == 0:
                self.hline(x - 1, x + 3, y, IRON_D)

    def save(self, path, scale=None):
        self.im.save(path)
        if scale:
            self.im.resize((self.w * scale, self.h * scale), Image.NEAREST).save(path.replace(".png", f"_x{scale}.png"))
