# 各条巷子通用的道具:石砌挡土墙(带盖石/青苔/小草/台阶)、几种木箱、桶、
# 两头钉在墙上的晾衣绳/灯串(任意宽度)。
import math
import random
from pxlib import *

CLOTH = [(140, 60, 50), (60, 106, 108), (176, 138, 62), (190, 180, 150), (82, 96, 130),
         (168, 108, 104), (150, 152, 140), (104, 120, 70), (120, 70, 110)]
MOSS = [(52, 66, 38), (70, 88, 46), (96, 112, 58)]
FLOWERS = [(190, 70, 70), (210, 160, 70), (200, 120, 160), (230, 220, 200)]


# ============================================================
# 石砌挡土墙:顶面在图里 y=TOPPAD(上面留几行画草/盖石凸起),往下 rise 行可见,
# 再多画 4 行压到地面贴图下面。steps_l/steps_r = 两头台阶级数(0=直上直下)。
# ============================================================
TOPPAD = 3


def stone_wall(width, rise, seed=41, steps_l=4, steps_r=4, step_w=4, moss=0.25, ramp=STONE, step_rise=None):
    H = TOPPAD + rise + 4
    c = Canvas(width, H, seed)
    rng = c.rng
    y0 = TOPPAD
    # ---- 墙面:先画一整片斑驳石面(多色块),再用很淡、断续的缝暗示石块 ----
    c.wall(0, y0 + 2, width - 1, H - 1, ramp, base=2.6, spread=1.7, scale=7,
           accents=[((70, 82, 52), 0.35), ((96, 70, 48), 0.35), (shade(ramp[-1], 1.05), 0.2)])
    joints = []
    y = y0 + 3
    while y < H:
        bh = rng.choice([4, 5, 5, 6])
        x = -rng.randint(0, 8)
        while x < width:
            bw = rng.randint(6, 15)
            k = rng.uniform(0.88, 1.12)
            for yy in range(y, min(H, y + bh)):
                for xx in range(max(0, x), min(width, x + bw)):
                    c.darken(xx, yy, k)
            if rng.random() < 0.6:          # 有的石块上沿亮一点点
                for xx in range(max(0, x), min(width, x + bw - 1)):
                    c.tint(xx, y, ramp[-1], 0.28)
            for yy in range(y, min(H, y + bh)):      # 竖缝:淡、断续
                if 0 <= x + bw < width and rng.random() < 0.65:
                    c.darken(x + bw, yy, 0.8)
            joints.append((x + bw, y))
            x += bw + 1
        if y + bh < H:
            for xx in range(width):        # 横缝:淡、断续
                if rng.random() < 0.6:
                    c.darken(xx, y + bh, 0.82)
        y += bh + 1
    # ---- 石缝里长出来的小草/小花(用户喜欢这个) ----
    for _ in range(int(width / 9)):
        jx, jy = joints[rng.randrange(len(joints))]
        if not (1 <= jx < width - 1 and y0 + 4 <= jy < H - 3):
            continue
        n = rng.randint(1, 3)
        for k in range(n):
            gx = jx + rng.choice([-1, 0, 1])
            c.set(gx, jy - k, MOSS[2] if k == n - 1 else MOSS[1])
        c.set(jx + 1, jy, MOSS[0])
        if rng.random() < 0.25:
            c.set(jx, jy - n, FLOWERS[rng.randrange(len(FLOWERS))])
    # ---- 盖石:一块一块,长短不一,缺角,个别高出一格 ----
    x = 0
    while x < width:
        bw = rng.randint(5, 13)
        raised = rng.random() < 0.18
        top = y0 - (1 if raised else 0)
        for xx in range(x, min(width, x + bw)):
            c.set(xx, top, ramp[5] if rng.random() < 0.7 else ramp[4])
            for yy in range(top + 1, y0 + 2):
                c.set(xx, yy, ramp[3] if rng.random() < 0.7 else ramp[4 if rng.random() < 0.5 else 2])
        # 缺角
        if rng.random() < 0.5:
            c.set(x, top, T)
            c.set(x, top + 1, ramp[2])
        if rng.random() < 0.4 and x + bw - 1 < width:
            c.set(x + bw - 1, top, T)
        if x + bw < width:   # 盖石之间的缝(淡)
            for yy in range(top + 1, y0 + 2):
                c.darken(x + bw - 1, yy, 0.82)
        x += bw
    for xx in range(width):
        c.darken(xx, y0 + 2, 0.78)
    # ---- 青苔:从盖石边垂下来几缕 ----
    for _ in range(int(width * moss / 6)):
        mx = rng.randint(0, width - 1)
        ln = rng.randint(1, 4)
        for k in range(ln):
            c.tint(mx, y0 + 1 + k, MOSS[1], 0.75 - k * 0.15)
            if rng.random() < 0.5:
                c.tint(mx + 1, y0 + 1 + k, MOSS[0], 0.6 - k * 0.15)
    # ---- 小草:盖石上冒几根 ----
    for _ in range(int(width / 18)):
        gx = rng.randint(2, width - 3)
        if c.get(gx, y0)[3] == 0:
            continue
        for dx, h in [(-1, 1), (0, 2), (1, 1)]:
            for k in range(h):
                c.set(gx + dx, y0 - 1 - k, MOSS[2] if k == h - 1 else MOSS[1])
    # ---- 水渍、墙根 ----
    c.stains(0, y0 + 3, width - 1, H - 1, int(width / 12), (40, 46, 36), r=4, t=0.35)
    c.grime_bottom(0, width - 1, H - 1, 6, k=0.6)
    # ---- 两头切台阶 ----
    for side, steps in ((0, steps_l), (1, steps_r)):
        for s in range(steps):
            sr = step_rise if step_rise is not None else rise
            top = y0 + sr - int(round(sr * (s + 1) / steps))
            xs0 = s * step_w
            for x in range(xs0, xs0 + step_w):
                xx = x if side == 0 else width - 1 - x
                for yy in range(0, top):
                    c.set(xx, yy, T)
                c.set(xx, top, ramp[5] if (x - xs0) else ramp[4])
                c.set(xx, top + 1, ramp[3])
                c.set(xx, top + 2, ramp[1])
            # 踏步边磨圆:外沿一格暗一点
            edge = xs0 if side == 0 else width - 1 - xs0
            c.set(edge, top, ramp[3])
    return c


# ============================================================
# 木箱:三种款
# ============================================================
def crate_slat(w=12, h=12, seed=51):
    """板条箱:2 格宽外框 + 四角铁包角 + 中间横板条透出黑缝 + 斜撑。"""
    c = Canvas(w, h, seed)
    rng = c.rng
    plank = [WOOD_D, WOOD, WOOD_L, (124, 82, 56)]
    c.rect(0, 0, w - 1, h - 1, (22, 16, 14))
    for y in range(2, h - 2, 3):          # 横板条
        col = plank[rng.choice([1, 2, 2])]
        c.hline(2, w - 3, y, col)
        c.hline(2, w - 3, y + 1, shade(col, 0.8))
    for i in range(h - 4):                # 斜撑
        x = 2 + int(i * (w - 5) / (h - 5))
        c.set(x, 2 + i, plank[3]); c.set(x + 1, 2 + i, plank[2])
    # 外框:上/左亮,下/右暗
    c.hline(0, w - 1, 0, plank[3]); c.hline(0, w - 1, 1, plank[2])
    c.vline(0, 0, h - 1, plank[2]); c.vline(1, 1, h - 2, plank[1])
    c.hline(0, w - 1, h - 1, (34, 22, 18)); c.hline(1, w - 2, h - 2, plank[0])
    c.vline(w - 1, 0, h - 1, (34, 22, 18)); c.vline(w - 2, 1, h - 2, plank[0])
    # 铁包角 + 钉子
    for (x, y) in [(0, 0), (w - 2, 0), (0, h - 2), (w - 2, h - 2)]:
        c.rect(x, y, x + 1, y + 1, IRON)
        c.set(x, y, IRON_L)
    for (x, y) in [(3, 1), (w - 4, 1), (3, h - 2), (w - 4, h - 2)]:
        c.set(x, y, (30, 24, 20))
    # 磕碰:边上几个缺口
    for _ in range(3):
        side = rng.randrange(4)
        k = rng.randint(3, (w if side < 2 else h) - 4)
        p = [(k, 0), (k, h - 1), (0, k), (w - 1, k)][side]
        c.set(p[0], p[1], T)
    return c


def crate_panel(w=12, h=11, seed=55, paint=(70, 92, 74)):
    """刷过漆的平板箱:漆掉了一块露木头,一个模板喷的记号。"""
    c = Canvas(w, h, seed)
    rng = c.rng
    c.wall(0, 0, w - 1, h - 1, [shade(paint, 0.55), shade(paint, 0.75), paint, shade(paint, 1.2)], base=2.0, spread=0.8, scale=3)
    for _ in range(6):   # 掉漆露木
        x, y = rng.randint(1, w - 3), rng.randint(1, h - 3)
        c.set(x, y, WOOD); c.set(x + 1, y, WOOD_L)
    c.hline(0, w - 1, 0, shade(paint, 1.35)); c.vline(0, 0, h - 1, shade(paint, 1.15))
    c.hline(0, w - 1, h - 1, (24, 22, 20)); c.vline(w - 1, 0, h - 1, shade(paint, 0.5))
    c.hline(1, w - 2, h // 2, shade(paint, 0.6))  # 中缝
    mx, my = w // 2 - 1, h // 2 - 4               # 喷的记号:一个 X
    for (dx, dy) in [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]:
        c.set(mx + dx, my + dy, (190, 176, 140))
    for (x, y) in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]:
        c.set(x, y, IRON_L)
    c.set(w - 1, 2, T); c.set(0, h - 3, T)
    return c


def box_small(w=9, h=8, seed=53):
    """小纸箱:胶带一道,角塌了一点。"""
    c = Canvas(w, h, seed)
    card = [(92, 70, 46), (120, 92, 60), (146, 114, 76)]
    c.wall(0, 0, w - 1, h - 1, card, base=1.3, spread=0.5, scale=3)
    c.hline(0, w - 1, 0, card[2]); c.hline(0, w - 1, h - 1, (40, 30, 22)); c.vline(w - 1, 0, h - 1, card[0])
    c.vline(w // 2, 0, 2, (170, 160, 130))          # 胶带
    c.hline(1, w - 2, 2, card[0])                     # 盖子折线
    c.set(0, 0, T); c.set(w - 1, 0, T); c.set(1, 0, card[1])
    return c


def barrel(seed=52, col=(70, 82, 80)):
    w, h = 8, 11
    c = Canvas(w, h, seed)
    for x in range(w):
        k = 0.7 + 0.6 * math.sin(math.pi * (x + 0.5) / w)
        c.vline(x, 1, h - 1, shade(col, k))
    for y in (2, 8):
        for x in range(w):
            c.set(x, y, shade(IRON_D, 0.8 + 0.5 * math.sin(math.pi * (x + 0.5) / w)))
    c.hline(1, w - 2, 0, shade(col, 1.4))
    c.set(0, 1, T); c.set(w - 1, 1, T)
    c.drips(0, w - 1, 3, 3, maxlen=5, color=RUST[1])
    c.set(2, 5, shade(col, 0.6)); c.set(5, 9, shade(col, 0.6))   # 凹痕
    return c


# ============================================================
# 晾衣绳 / 灯串:任意宽度,两头带钉在墙上的小铁钩
# ============================================================
def _rope(c, w, sag, rope):
    ys = []
    for x in range(w):
        t = x / max(1, w - 1)
        y = 2 + int(round(sag * 4 * t * (1 - t)))
        ys.append(y)
        c.set(x, y, rope)
    # 墙钉:两头各一个 L 形小铁钩
    for x, d in ((0, 1), (w - 1, -1)):
        c.set(x, 1, IRON_D); c.set(x, 2, IRON); c.set(x, 3, IRON_D)
        c.set(x + d, 1, IRON_D)
    return ys


def laundry_line(w, sag=None, seed=1, density=0.75, rope=(150, 140, 120)):
    sag = sag if sag is not None else max(2, min(9, w // 11))
    H = sag + 20
    c = Canvas(w, H, seed)
    rng = c.rng
    ys = _rope(c, w, sag, rope)

    def clip(x, y):
        c.set(x, y - 1, (30, 26, 22))

    def shirt(x, col):
        y = ys[x] + 1
        c.rect(x, y, x + 6, y + 1, col); c.rect(x + 1, y + 2, x + 5, y + 7, col)
        c.hline(x, x + 6, y, shade(col, 1.2)); c.vline(x + 5, y + 2, y + 7, shade(col, 0.75))
        c.set(x + 3, y, shade(col, 0.6)); clip(x + 2, y); clip(x + 4, y)
        return 8

    def pants(x, col):
        y = ys[x] + 1
        c.rect(x, y, x + 4, y + 2, col)
        c.rect(x, y + 3, x + 1, y + 9, col); c.rect(x + 3, y + 3, x + 4, y + 9, col)
        c.hline(x, x + 4, y, shade(col, 1.2)); c.vline(x + 4, y + 3, y + 9, shade(col, 0.75))
        clip(x, y); clip(x + 4, y)
        return 6

    def sheet(x, col):
        ww, hh = rng.randint(8, 12), rng.randint(9, 13)
        for xx in range(x, min(w - 2, x + ww)):
            y0 = ys[xx] + 1
            ln = hh - (1 if (xx - x) % 4 == 3 else 0)
            for y in range(y0, y0 + ln):
                k = 1.08 if (xx - x) % 4 == 0 else (0.86 if (xx - x) % 4 == 2 else 1.0)
                c.set(xx, y, shade(col, k))
        return ww + 1

    def sock(x, col):
        y = ys[x] + 1
        c.vline(x, y, y + 3, col); c.set(x + 1, y + 3, col); clip(x, y)
        return 3

    def dress(x, col):
        y = ys[x] + 1
        c.rect(x + 1, y, x + 3, y + 3, col)
        for i in range(5):
            c.hline(x + 1 - i // 2, x + 3 + i // 2, y + 4 + i, col)
        c.hline(x + 1, x + 3, y, shade(col, 1.2)); clip(x + 2, y)
        return 6

    def towel(x, col):
        y = ys[x] + 1
        c.rect(x, y, x + 3, y + 5, col)
        c.hline(x, x + 3, y + 4, shade(col, 0.7))
        return 5

    kinds = [shirt, shirt, pants, sheet, sock, dress, towel]
    x = rng.randint(3, 6)
    while x < w - 10:
        if rng.random() < density:
            x += kinds[rng.randrange(len(kinds))](x, CLOTH[rng.randrange(len(CLOTH))]) + rng.randint(0, 2)
        else:
            x += rng.randint(4, 9)
    return c


def bulb_line(w, sag=None, spacing=16, seed=1, rope=(130, 120, 104)):
    """返回 (canvas, [灯泡在图里的 (x,y)])。"""
    sag = sag if sag is not None else max(2, min(8, w // 12))
    c = Canvas(w, sag + 8, seed)
    ys = _rope(c, w, sag, rope)
    bulbs = []
    off = (w % spacing) // 2 + spacing // 2
    for x in range(off, w - 3, spacing):
        y = ys[x]
        c.set(x, y + 1, IRON_D); c.set(x, y + 2, LIT[2]); c.set(x, y + 3, LIT[1])
        bulbs.append((x, y + 2))
    return c, bulbs
