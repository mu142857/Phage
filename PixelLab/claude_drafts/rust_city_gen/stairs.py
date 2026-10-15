# 楼梯坡巷素材
import math
from pxlib import *
from props import MOSS, CLOTH

PLASTER = [(70, 62, 50), (100, 90, 72), (132, 120, 96), (160, 148, 120), (184, 172, 142), (204, 194, 164)]
TILE = [(70, 34, 24), (100, 48, 32), (130, 66, 42), (156, 90, 60)]
SHUTTER_BLUE = (70, 96, 120)
SHUTTER_GREEN = (76, 110, 80)
FLOWERS = [(190, 70, 70), (210, 160, 70), (200, 120, 160), (230, 220, 200)]


def tile_roof(c, x0, x1, y_eave, rise, ramp=TILE, chimney=None):
    """两坡瓦顶(侧看是三角):一排排瓦,檐口一道亮边。"""
    cx = (x0 + x1) / 2
    half = (x1 - x0) / 2
    for y in range(y_eave - rise, y_eave + 1):
        t = (y - (y_eave - rise)) / rise
        hw = half * t
        for x in range(int(math.floor(cx - hw)), int(math.ceil(cx + hw)) + 1):
            row = (y - (y_eave - rise)) % 3
            col = ramp[2] if row == 0 else (ramp[1] if row == 1 else ramp[0])
            if (x + (y // 3)) % 4 == 0:
                col = shade(col, 0.8)
            c.set(x, y, col)
    for x in range(x0 - 1, x1 + 2):
        c.set(x, y_eave + 1, ramp[3])
        c.set(x, y_eave + 2, ramp[0])
    if chimney:
        chx, chh = chimney
        top = y_eave - int(rise * (1 - abs(chx - cx) / half)) - chh
        c.rect(chx, top, chx + 3, y_eave - 2, BRICK[3]); c.hline(chx - 1, chx + 4, top, STONE[4])


def flower_box(c, x, y, w=6):
    rng = c.rng
    c.rect(x, y, x + w - 1, y + 1, WOOD); c.hline(x, x + w - 1, y, WOOD_L)
    for xx in range(x, x + w):
        if rng.random() < 0.8:
            c.set(xx, y - 1, MOSS[rng.randrange(1, 3)])
        if rng.random() < 0.5:
            c.set(xx, y - 2, FLOWERS[rng.randrange(len(FLOWERS))])
    for xx in range(x, x + w, 2):     # 垂下来的藤
        if rng.random() < 0.5:
            c.set(xx, y + 2, MOSS[1]); c.set(xx, y + 3, MOSS[0])


def hill_house_a(seed=301, ramp=PLASTER, shutter=SHUTTER_BLUE):
    """奶油色两层小楼:红瓦两坡顶,蓝百叶窗+花箱,门前三级台阶,门边壁灯。"""
    W, H = 46, 62
    c = Canvas(W, H, seed)
    L, R, TOP = 3, 42, 20
    c.wall(L, TOP, R, H - 1, ramp, base=3.3, spread=2.0, scale=8)
    c.stains(L, TOP, R, H - 1, 10, (70, 60, 44), r=4, t=0.35)
    tile_roof(c, L - 2, R + 2, TOP - 1, 16, chimney=(32, 6))
    c.ledge(L, R, 40, light=ramp[5])
    c.drips(L, R, 43, 6, maxlen=6, color=(90, 76, 56))
    for wx, lit in ((8, True), (28, False)):
        c.window(wx, 26, 6, 8, lit=lit, shutter=shutter)
        flower_box(c, wx - 1, 34, 8)
    c.window(30, 47, 6, 8, lit=True, shutter=shutter)
    c.door(10, 48, 7, 14, color=shade(shutter, 0.8), knob=True, step=False)
    c.hline(8, 19, H - 1, STONE[4])
    # 壁灯
    c.set(20, 48, IRON_D); c.set(21, 48, IRON_D); c.set(21, 49, LIT[2]); c.set(21, 50, LIT[1])
    c.grime_bottom(L, R, H - 1, 6, k=0.6)
    for y in range(TOP, H):
        c.darken(R, y, 0.65); c.tint(L, y, ramp[5], 0.3)
    return c, (21, 50)


def hill_house_b(seed=302, ramp=OCHRE):
    """瘦高三层:二楼小阳台挂满盆栽,顶层圆窗,单坡顶。阳台可站。"""
    W, H = 40, 74
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 37, 12
    c.wall(L, TOP, R, H - 1, ramp, base=3.0, spread=2.6, scale=8)
    c.stains(L, TOP, R, H - 1, 12, RUST[1], r=4, t=0.45)
    for x in range(L - 2, R + 3):      # 单坡瓦顶
        y = TOP - 1 - int((x - L + 2) * 8 / (R - L + 4))
        for yy in range(y, TOP):
            c.set(x, yy, TILE[1] if (yy - y) % 3 else TILE[2])
        c.set(x, y, TILE[3])
    # 圆窗
    cx, cy = 19, TOP + 8
    for a in range(0, 360, 15):
        c.set(int(round(cx + math.cos(math.radians(a)) * 3.5)), int(round(cy + math.sin(math.radians(a)) * 3.5)), WOOD)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                c.set(cx + dx, cy + dy, LIT[1] if dy > -1 else LIT[2])
    c.hline(cx - 2, cx + 2, cy, WOOD); c.vline(cx, cy - 2, cy + 2, WOOD)
    c.ledge(L, R, 28)
    c.drips(L, R, 31, 6, maxlen=6)
    # 二楼阳台(地板 y=48)
    c.door(15, 34, 7, 14, color=(90, 60, 44), knob=False, step=False)
    c.window(5, 36, 5, 7); c.window(28, 36, 5, 7, lit=True)
    c.railing(0, W - 1, 48, h=4)
    for x in (2, 8, 27, 33):
        col = MOSS[2] if x % 3 else MOSS[1]
        c.rect(x, 46, x + 2, 47, (130, 70, 46))
        c.set(x + 1, 44, col); c.set(x, 45, col); c.set(x + 2, 45, col); c.set(x + 1, 43, FLOWERS[x % 4])
    for x in range(1, W - 1, 3):    # 栏杆外垂下来的藤
        ln = (x * 7) % 5
        for k in range(ln):
            c.set(x, 50 + k, MOSS[1] if k % 2 else MOSS[0])
    c.window(6, 56, 5, 7); c.door(22, 60, 7, 14, color=(70, 54, 40), step=False)
    c.grime_bottom(L, R, H - 1, 6, k=0.5)
    for y in range(TOP, H):
        c.darken(R, y, 0.65)
    return c, 48


def hill_house_c(seed=303):
    """石头小屋:粗石墙,木门,烟囱(冒烟的地方),门口一盏挂灯,屋顶长草。"""
    W, H = 50, 56
    c = Canvas(W, H, seed)
    L, R, TOP = 3, 46, 22
    # 石墙:斑驳石面 + 淡淡的、断续的石缝,缝里冒点草
    rng = c.rng
    c.wall(L, TOP, R, H - 1, STONE, base=2.8, spread=1.7, scale=6,
           accents=[((70, 82, 52), 0.35), ((96, 70, 48), 0.35), (shade(STONE[-1], 1.05), 0.2)])
    y = TOP
    while y < H:
        bh = rng.choice([4, 5])
        x = L - rng.randint(0, 5)
        while x <= R:
            bw = rng.randint(5, 10)
            k = rng.uniform(0.88, 1.12)
            for yy in range(y, min(H, y + bh)):
                for xx in range(max(L, x), min(R + 1, x + bw)):
                    c.darken(xx, yy, k)
            for xx in range(max(L, x), min(R + 1, x + bw - 1)):
                if rng.random() < 0.6:
                    c.tint(xx, y, STONE[-1], 0.28)
            for yy in range(y, min(H, y + bh)):
                if L <= x + bw <= R and rng.random() < 0.65:
                    c.darken(x + bw, yy, 0.8)
            if rng.random() < 0.12 and L < x + bw < R:
                c.set(x + bw, y + bh - 1, MOSS[1]); c.set(x + bw, y + bh - 2, MOSS[2])
            x += bw + 1
        y += bh + 1
    tile_roof(c, L - 3, R + 3, TOP - 1, 18, ramp=[(52, 50, 46), (72, 70, 64), (92, 88, 80), (118, 112, 100)], chimney=(12, 8))
    for _ in range(10):   # 屋顶长草
        gx = rng.randint(10, 40)
        for yy in range(TOP - 18, TOP):
            if c.get(gx, yy)[3]:
                c.set(gx, yy, MOSS[1]); c.set(gx, yy - 1, MOSS[2]); break
    c.window(8, 30, 6, 7, lit=True, shutter=SHUTTER_GREEN)
    c.window(36, 30, 6, 7, lit=False, shutter=SHUTTER_GREEN)
    c.door(20, H - 16, 9, 16, color=WOOD, double=False, knob=True, step=False)
    c.hline(19, 29, H - 17, WOOD_D)
    c.vline(33, TOP + 4, TOP + 6, IRON_D); c.hline(31, 33, TOP + 4, IRON_D)
    c.set(31, TOP + 5, IRON_D); c.set(31, TOP + 6, LIT[2]); c.set(31, TOP + 7, LIT[1])
    flower_box(c, 7, 38, 8)
    c.grime_bottom(L, R, H - 1, 6, k=0.55)
    for y in range(TOP, H):
        c.darken(R, y, 0.65)
    return c, (31, TOP + 7), (13, TOP - 16)


def stair_rail(run, rise, steps, seed=304):
    """台阶扶手:一根随台阶斜上去的铁管 + 几根立杆。左低右高。"""
    W, H = run + 2, rise + 8
    c = Canvas(W, H, seed)
    for x in range(W):
        y = int(round(H - 2 - (x / (W - 1)) * rise)) - 5
        c.set(x, y, IRON_L); c.set(x, y + 1, IRON_D)
    for x in range(0, W, max(4, run // steps)):
        y = int(round(H - 2 - (x / (W - 1)) * rise))
        c.vline(x, y - 4, y, IRON)
    return c


def bench(seed=305):
    c = Canvas(16, 7, seed)
    c.hline(0, 15, 0, WOOD_L); c.hline(0, 15, 1, WOOD)
    c.hline(0, 15, 3, WOOD_L); c.hline(0, 15, 4, WOOD_D)
    for x in (1, 14):
        c.vline(x, 0, 6, IRON)
    c.vline(1, 5, 6, IRON_D); c.vline(14, 5, 6, IRON_D)
    return c


def telescope(seed=306):
    """投币望远镜:铁柱 + 斜着的镜筒(用阶梯像素画,不旋转)。"""
    c = Canvas(12, 16, seed)
    c.vline(5, 7, 15, IRON); c.vline(6, 7, 15, IRON_D)
    c.hline(3, 8, 15, IRON_D)
    c.rect(4, 6, 7, 8, IRONP if False else (60, 72, 70))
    for i in range(6):
        c.set(3 + i, 5 - i // 2, (80, 100, 96)); c.set(3 + i, 6 - i // 2, (56, 70, 68))
    c.set(9, 2, (200, 220, 210)); c.set(9, 3, (120, 140, 130))
    c.set(5, 9, (190, 160, 80))   # 投币口
    return c


def lookout_rail(W=48, seed=307):
    c = Canvas(W, 8, seed)
    c.railing(0, W - 1, 7, h=5)
    return c


def potted(seed=308, big=False):
    c = Canvas(7, 9 if big else 6, seed)
    rng = c.rng
    h = c.h
    c.rect(1, h - 3, 5, h - 1, (130, 70, 46)); c.hline(0, 6, h - 3, (156, 90, 60)); c.hline(1, 5, h - 1, (90, 46, 30))
    for _ in range(10 if big else 6):
        x, y = rng.randint(1, 5), rng.randint(0, h - 4)
        c.set(x, y, MOSS[rng.randrange(3)])
    c.set(rng.randint(1, 5), rng.randint(0, 1), FLOWERS[rng.randrange(4)])
    return c


# ------------------------------------------------------------
# 主街上的入口:两栋楼的墙角夹着一道往上走的石阶,阶顶一盏灯,阶边盆栽
# ------------------------------------------------------------
def stair_mouth(seed=309):
    W, H = 56, 80
    c = Canvas(W, H, seed)
    rng = c.rng
    # 远处:阶顶的小楼(暖光窗)和夜空留空
    for y in range(18, 52):
        for x in range(16, 40):
            c.set(x, y, shade(PLASTER[2], 0.55))
    c.window(20, 26, 5, 6, lit=True, sill=None); c.window(31, 30, 5, 6, lit=False, sill=None)
    tile_roof(c, 14, 41, 17, 8)
    # 台阶:从下往上越来越窄越来越暗(透视)
    n = 9
    for i in range(n):
        y1 = H - 1 - i * 3
        y0 = y1 - 2
        inset = int(i * 1.2)
        x0, x1 = 12 + inset, W - 13 - inset
        k = 1 - i * 0.06
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                v = STONE[4] if y == y0 else (STONE[2] if y == y0 + 1 else STONE[1])
                c.set(x, y, shade(v, k))
        if rng.random() < 0.5:
            c.set(rng.randint(x0, x1), y0, MOSS[1])
    # 扶手
    for i in range(n * 3):
        y = H - 6 - i
        x = 13 + int(i * 1.2 / 3)
        c.set(x, y, IRON_L)
    for i in range(0, n * 3, 6):
        y = H - 6 - i; x = 13 + int(i * 1.2 / 3)
        c.vline(x, y, y + 4, IRON)
    # 阶顶的灯
    c.vline(37, 38, 52, IRON); c.hline(35, 38, 38, IRON)
    c.set(35, 39, IRON_D); c.set(35, 40, LIT[2]); c.set(35, 41, LIT[1])
    # 两边的楼角(带窗、楼层线、管子)
    for side in (0, 1):
        x0, x1 = (0, 11) if side == 0 else (W - 12, W - 1)
        ramp = OCHRE if side == 0 else PLASTER_PINK
        c.wall(x0, 4 if side == 0 else 10, x1, H - 1, ramp, base=2.7, spread=2.2, scale=6)
        c.stains(x0, 4, x1, H - 1, 6, RUST[1], r=3, t=0.45)
        for ly in (30, 56):
            c.hline(x0, x1, ly, CREAM); c.hline(x0, x1, ly + 1, shade(CREAM, 0.6))
            c.drips(x0, x1, ly + 2, 3, maxlen=6)
        wx = x0 + 3 if side == 0 else x0 + 3
        c.window(wx, 16 if side == 0 else 20, 5, 7, lit=(side == 1))
        c.window(wx, 40, 5, 7, lit=(side == 0))
        edge = x1 if side == 0 else x0
        for y in range(H):
            if c.get(edge, y)[3]:
                c.darken(edge, y, 0.55)
        c.grime_bottom(x0, x1, H - 1, 6, k=0.55)
    c.vline(10, 4, H - 1, IRON)   # 落水管
    for x, big in ((14, True), (38, False)):
        p = potted(310 + x, big)
        c.im.alpha_composite(p.im, (x, H - p.h))
    return c, (35, 41)


# ------------------------------------------------------------
# 远景:山下的屋顶(瓦顶、烟囱、天线),站高了就是在看它们
# ------------------------------------------------------------
def stair_back(W=320, H=90, seed=311):
    c = Canvas(W, H, seed)
    rng = c.rng
    x = -10
    while x < W:
        bw = rng.randint(22, 40)
        eave = rng.randint(24, 48)
        rise = rng.randint(6, 12)
        x1 = x + bw
        ramp = [PLASTER, OCHRE, PLASTER_PINK, CONCRETE][rng.randrange(4)]
        c.wall(max(0, x), eave, min(W - 1, x1), H - 1, ramp, base=2.2, spread=1.6, scale=6)
        tile_roof(c, x, x1, eave - 1, rise, ramp=TILE if rng.random() < 0.7 else [(52, 50, 46), (72, 70, 64), (92, 88, 80), (118, 112, 100)],
                  chimney=(x + rng.randint(4, bw - 6), 4) if rng.random() < 0.6 else None)
        for wy in range(eave + 4, H - 6, 10):
            for wx in range(x + 3, x1 - 4, 8):
                if 0 <= wx < W - 4:
                    c.window(wx, wy, 3, 4, lit=rng.random() < 0.3, cross=False, sill=None)
        if rng.random() < 0.3:     # 天线
            ax = x + bw // 2
            c.vline(ax, eave - rise - 8, eave - rise, IRON); c.hline(ax - 2, ax + 2, eave - rise - 6, IRON)
        x = x1 + rng.randint(-4, 2)
    for yy in range(H):
        for xx in range(W):
            p = c.get(xx, yy)
            if p[3] and max(p[:3]) <= 200:
                c.px[xx, yy] = rgba(mix(shade(p, 0.55), (34, 34, 40), 0.3))
    return c


def front_vines(W=40, H=36, seed=312):
    """前景剪影:从上面垂下来的藤蔓和一个吊盆。"""
    c = Canvas(W, H, seed)
    rng = c.rng
    for _ in range(9):
        x = rng.randint(1, W - 2)
        ln = rng.randint(H // 3, H - 2)
        for y in range(ln):
            xx = x + (1 if (y // 4) % 2 else 0)
            c.set(xx, y, MOSS[1])
            if rng.random() < 0.35:
                c.set(xx + rng.choice([-1, 1]), y, MOSS[2])
    c.hline(0, W - 1, 0, MOSS[0])
    return c


# ------------------------------------------------------------
# 台地挡土墙上的点缀
# ------------------------------------------------------------
def cellar_door(seed=370):
    """嵌在石墙里的拱形地窖门。"""
    W, H = 12, 15
    c = Canvas(W, H, seed)
    cx = (W - 1) / 2
    for y in range(H):
        for x in range(W):
            r = (x - cx) ** 2 + ((y - 5) * 1.1) ** 2
            if y >= 5 or r <= 30:
                c.set(x, y, STONE[4] if (y < 5 and r > 16) or x in (0, W - 1) else WOOD)
    for x in range(2, W - 2):
        for y in range(3, H):
            if (x - cx) ** 2 + ((y - 5) * 1.1) ** 2 <= 14 or y >= 5:
                c.set(x, y, WOOD if (x % 3) else WOOD_D)
    c.hline(2, W - 3, 8, IRON_D); c.hline(2, W - 3, 12, IRON_D)
    c.set(W - 4, 10, BRASS)
    return c


def barred_window(seed=371):
    c = Canvas(8, 7, seed)
    c.rect(0, 0, 7, 6, STONE[4])
    c.rect(1, 1, 6, 5, (24, 22, 20))
    c.set(2, 4, LIT[0]); c.set(3, 4, LIT[0])
    for x in (2, 4, 6):
        c.vline(x, 1, 5, IRON)
    return c


def moss_curtain(W=14, H=12, seed=372):
    c = Canvas(W, H, seed)
    rng = c.rng
    c.hline(0, W - 1, 0, MOSS[1])
    for x in range(W):
        ln = rng.randint(1, H - 1) if rng.random() < 0.7 else 0
        for y in range(1, ln):
            c.set(x, y, MOSS[0] if y % 3 else MOSS[1])
        if ln > 3 and rng.random() < 0.3:
            c.set(x, ln, FLOWERS[rng.randrange(4)])
    return c


def spout(seed=373, H=24):
    """石墙上的出水口:石兽头一样的水嘴,一道水往下流进小水槽。"""
    W = 12
    c = Canvas(W, H, seed)
    c.rect(3, 0, 8, 4, STONE[3]); c.hline(3, 8, 0, STONE[5]); c.rect(5, 3, 6, 5, STONE[1])
    c.set(4, 1, (20, 20, 20)); c.set(7, 1, (20, 20, 20))
    for y in range(6, H - 4):
        c.set(5, y, (120, 150, 160) if y % 3 else (170, 196, 200)); c.set(6, y, (90, 120, 130))
    c.rect(0, H - 4, W - 1, H - 1, STONE[3]); c.hline(0, W - 1, H - 4, STONE[5])
    c.hline(1, W - 2, H - 3, (80, 110, 120))
    return c


def hill_tree(seed=374):
    """观景台上的小树:细干 + 几团深绿树冠(配 swing 着色器晃)。"""
    W, H = 32, 42
    c = Canvas(W, H, seed)
    rng = c.rng
    for y in range(18, H):
        c.set(15, y, WOOD); c.set(16, y, WOOD_D)
    c.set(14, 26, WOOD); c.set(13, 25, WOOD); c.set(17, 22, WOOD); c.set(18, 21, WOOD)
    for (bx, by, r) in [(16, 12, 9), (9, 17, 6), (23, 16, 7), (15, 4, 5)]:
        for y in range(by - r, by + r):
            for x in range(bx - r - 1, bx + r + 1):
                d = ((x - bx) / (r + 1)) ** 2 + ((y - by) / r) ** 2
                if d <= 1 and rng.random() < 0.93:
                    t = (y - (by - r)) / (2 * r)
                    col = MOSS[2] if t < 0.3 else (MOSS[1] if t < 0.7 else MOSS[0])
                    if rng.random() < 0.15:
                        col = shade(col, 0.8)
                    c.set(x, y, col)
    return c
