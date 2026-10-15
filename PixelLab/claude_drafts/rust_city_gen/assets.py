# 晾衣巷全部素材。python3 assets.py → out/*.png
import math
from pxlib import *

CLOTH = [(140, 60, 50), (60, 106, 108), (176, 138, 62), (190, 180, 150), (82, 96, 130),
         (168, 108, 104), (150, 152, 140), (104, 120, 70), (120, 70, 110)]


# ============================================================
# 绿灰楼:窗户伸出晾衣竿、空调外机、底层半拉卷帘的小铺
# ============================================================
def house_green(seed=11):
    W, H = 54, 104
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 51, 10
    c.wall(L, TOP, R, H - 1, GREENGRAY, base=2.8, spread=2.8, scale=9)
    c.stains(L, TOP, R, H - 1, 18, (40, 34, 24), r=5, t=0.45)
    c.rust_band(L, R, TOP, 6, color=(52, 44, 30))
    # 屋顶:平顶 + 天线
    c.hline(L - 1, R + 1, TOP - 1, GREENGRAY[5]); c.hline(L - 1, R + 1, TOP, GREENGRAY[1])
    c.vline(40, 0, TOP - 2, IRON); c.hline(37, 43, 2, IRON); c.hline(38, 42, 5, IRON)
    c.rect(8, TOP - 5, 15, TOP - 2, CONCRETE[2]); c.hline(8, 15, TOP - 5, CONCRETE[4])
    floors = [30, 50, 70]
    for y in floors:
        c.ledge(L, R, y, light=GREENGRAY[5])
        c.rust_band(L, R, y + 2, 4, color=(52, 44, 30), t=0.5)
        c.drips(L, R, y + 3, 9, maxlen=10, color=(40, 34, 24))
    # 三排窗
    lit = {(0, 2), (1, 0), (2, 1)}
    for fi, ftop in enumerate([TOP + 2, 32, 52]):
        for wi, wx in enumerate([6, 21, 37]):
            c.window(wx, ftop + 5, 6, 8, lit=(fi, wi) in lit,
                     curtain=(150, 70, 60) if (fi, wi) == (1, 0) else None, sill=GREENGRAY[5])
    # 空调外机(挂在窗下)
    for (x, y) in [(36, 24), (5, 64)]:
        c.rect(x, y, x + 7, y + 4, (120, 122, 112)); c.hline(x, x + 7, y, (150, 150, 138))
        for xx in range(x + 1, x + 7, 2):
            c.vline(xx, y + 1, y + 3, (70, 72, 66))
        c.set(x + 1, y + 5, IRON_D); c.set(x + 6, y + 5, IRON_D)
        c.drips(x + 2, x + 5, y + 6, 2, maxlen=8, color=(40, 34, 24))
    # 小阳台(带两盆绿植)
    c.railing(18, 33, 50, h=4, top=GREENGRAY[5], post_a=GREENGRAY[4], post_b=GREENGRAY[2], base=GREENGRAY[1])
    for px_, col in [(20, (70, 120, 60)), (30, (96, 140, 70))]:
        c.rect(px_, 44, px_ + 2, 45, (120, 64, 44))
        c.set(px_, 42, col); c.set(px_ + 1, 41, col); c.set(px_ + 2, 42, col); c.set(px_ + 1, 43, col)
        c.set(px_ - 1, 43, shade(col, 0.7)); c.set(px_ + 3, 43, shade(col, 0.7))
    c.drainpipe(L + 1, TOP, H - 2, c=(70, 76, 66))
    # 底层:半拉卷帘的小铺 + 雨棚(雨棚是可站平台)
    SX0, SX1, SY = 14, 41, 84
    c.rect(SX0, SY, SX1, H - 1, (20, 18, 16))
    for y in range(SY + 7, H):  # 卷帘下面半截透出的暖光
        c.hline(SX0 + 1, SX1 - 1, y, mix(LIT[1], LIT[0], (y - SY - 7) / 13))
    for y in range(SY, SY + 7):  # 卷帘
        c.hline(SX0, SX1, y, (104, 106, 98) if y % 2 else (78, 80, 74))
    c.hline(SX0, SX1, SY + 7, (50, 50, 46))
    for x in range(SX0 + 3, SX1 - 2, 5):  # 店里的瓶瓶罐罐剪影
        h = 2 + (x * 7) % 3
        c.rect(x, H - 4 - h, x + 1, H - 5, (60, 40, 26))
    # 雨棚:红白条
    AY = 80
    for x in range(SX0 - 3, SX1 + 4):
        col = (140, 60, 50) if ((x - SX0) // 3) % 2 == 0 else (180, 170, 150)
        c.set(x, AY, shade(col, 1.1)); c.set(x, AY + 1, col); c.set(x, AY + 2, shade(col, 0.8))
        if x % 3 == 0:
            c.set(x, AY + 3, shade(col, 0.7))
    c.hline(SX0 - 3, SX1 + 3, AY - 1, IRON_D)
    c.door(44, H - 11, 5, 11, color=(64, 70, 58), step=False)
    c.grime_bottom(L, R, H - 1, 10, k=0.45)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8)
    return c


# ============================================================
# 红砖窄楼:拱窗、中间一个小阳台、挂空招牌
# ============================================================
def house_brick(seed=21):
    W, H = 44, 86
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 41, 12
    c.wall(L, TOP, R, H - 1, BRICK, base=2.8, spread=1.6, scale=8)
    c.bricks(L, TOP, R, H - 1, BRICK)
    c.stains(L, TOP, R, H - 1, 12, (40, 30, 26), r=5, t=0.4)
    # 坡屋顶
    for i in range(10):
        y = TOP - 1 - i
        x0, x1 = L - 1 + i * 2, R + 1 - i * 2
        if x0 > x1:
            break
        for x in range(x0, x1 + 1):
            c.set(x, y, (40, 42, 44) if (x + i) % 3 else (58, 60, 62))
        c.set(x0, y, (90, 92, 94))
    c.hline(L - 2, R + 2, TOP - 1, (70, 72, 74))
    c.rect(30, TOP - 12, 33, TOP - 4, BRICK[3]); c.hline(29, 34, TOP - 12, STONE[3])
    floors = [36, 60]
    for y in floors:
        c.ledge(L, R, y, light=STONE[5])
        c.drips(L, R, y + 3, 6, maxlen=7, color=(40, 30, 26))
    # 拱窗
    def arch(x, y, lit=False):
        c.window(x, y + 1, 6, 9, lit=lit, sill=STONE[5])
        c.hline(x + 1, x + 4, y, WOOD); c.set(x, y + 1, STONE[4]); c.set(x + 5, y + 1, STONE[4])
        c.hline(x + 1, x + 4, y - 1, STONE[4])
    arch(8, 19); arch(28, 19, lit=True)
    arch(8, 43, lit=True); arch(28, 43)
    # 中层小阳台(可站)
    c.railing(4, 39, 60, h=4)
    c.bracket(5, 62, 3); c.bracket(37, 62, 3, dx=-1)
    # 空招牌(挂杆 + 木牌)
    c.hline(R - 1, W - 1, 65, IRON)
    c.rect(36, 66, 43, 71, WOOD); c.hline(36, 43, 66, WOOD_L); c.set(37, 66, IRON); c.set(42, 66, IRON)
    # 底层门 + 台阶
    c.door(17, 74, 8, 12, color=(92, 48, 36), double=True, step=False)
    c.hline(15, 26, 85, STONE[3])
    c.window(32, 74, 5, 7, sill=STONE[5])
    c.window(5, 74, 5, 7, sill=STONE[5])
    c.grime_bottom(L, R, H - 1, 8, k=0.5)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8)
    return c


# ============================================================
# 巷子尽头的大墙:钉死的窗、横穿的大管子(可站)、一扇亮灯的门
# ============================================================
def dead_end(seed=31):
    W, H = 80, 112
    c = Canvas(W, H, seed)
    L, R, TOP = 0, 77, 0
    c.wall(L, TOP, R, H - 1, CONCRETE, base=2.6, spread=2.4, scale=10)
    c.stains(L, TOP, R, H - 1, 24, (30, 22, 16), r=6, t=0.5)
    for y in (26, 52, 78):
        c.ledge(L, R, y, light=CONCRETE[5], overhang=0)
        c.drips(L, R, y + 3, 12, maxlen=12, color=(30, 22, 16))
    for (x, y) in [(8, 8), (30, 8), (54, 8), (8, 34), (54, 34), (30, 60), (54, 60)]:
        c.boarded(x, y, 7, 9)
    c.window(30, 34, 7, 9, lit=True, curtain=(120, 60, 90))
    # 大管子横穿(上表面世界 y 可站),带法兰和锈
    def pipe(y, x0, x1, r=3, col=(84, 70, 58)):
        for yy in range(y, y + r * 2):
            t = (yy - y) / (r * 2 - 1)
            k = 1.35 - t * 0.9
            c.hline(x0, x1, yy, shade(col, k))
        for x in range(x0 + 6, x1, 16):
            c.rect(x, y - 1, x + 1, y + r * 2, shade(col, 0.7)); c.vline(x, y - 1, y + r * 2, shade(col, 1.2))
        c.drips(x0, x1, y + r * 2, 10, maxlen=8, color=RUST[1])
    pipe(66, 0, 79)
    pipe(44, 0, 30, r=2, col=(70, 82, 80))
    c.rect(30, 44, 33, 47, IRON_D)  # 管子拐进墙里
    # 竖管
    c.drainpipe(70, 0, H - 2, c=(84, 70, 58))
    # 门 + 门上的灯泡
    c.door(36, 98, 7, 14, color=(60, 40, 34), step=False)
    c.hline(34, 44, 96, IRON_D)
    c.set(39, 93, IRON_D); c.set(39, 94, LIT[2]); c.set(40, 94, LIT[2]); c.set(39, 95, LIT[1]); c.set(40, 95, LIT[1])
    c.hline(37, 42, 92, IRON_D)
    # 涂鸦:一个歪歪扭扭的箭头(指向门)
    g = (150, 70, 60)
    for i in range(8):
        c.tint(20 + i, 104 - i // 3, g, 0.6)
    c.tint(27, 101, g, 0.6); c.tint(26, 100, g, 0.6); c.tint(26, 103, g, 0.6)
    c.grime_bottom(L, R, H - 1, 12, k=0.45)
    return c


# ============================================================
# 高台挡土墙(两头台阶),顶面世界 y=66
# ============================================================
TER_STEP = 16  # 台阶段宽
def terrace(width=232, rise=14, seed=41):
    H = rise + 4  # 多画 4 行压到地面贴图下面
    c = Canvas(width, H, seed)
    c.wall(0, 0, width - 1, H - 1, STONE, base=2.4, spread=1.8, scale=6)
    # 石块缝
    for y in range(H):
        row = y // 5
        for x in range(width):
            if y % 5 == 4 or (x + row * 4) % 9 == 8:
                c.darken(x, y, 0.65)
    c.hline(0, width - 1, 0, STONE[5]); c.hline(0, width - 1, 1, STONE[3])
    # 排水口 + 水渍
    for dx in (60, 150):
        c.rect(dx, 5, dx + 3, 7, (14, 15, 16)); c.hline(dx - 1, dx + 4, 4, STONE[4])
        for j in range(8, H):
            c.tint(dx + 1, j, (40, 60, 56), 0.6); c.tint(dx + 2, j, (40, 60, 56), 0.4)
    c.stains(0, 2, width - 1, H - 1, 20, (40, 46, 36), r=4, t=0.4)
    # 两头切成台阶:左边 4 级往右升高,右边对称
    steps = 4
    for side in (0, 1):
        for s in range(steps):
            top = rise - int(round(rise * (s + 1) / steps))   # 第 s 级上表面
            xs0 = s * (TER_STEP // steps)
            xs1 = xs0 + TER_STEP // steps - 1
            for x in range(xs0, xs1 + 1):
                xx = x if side == 0 else width - 1 - x
                for y in range(0, top):
                    c.set(xx, y, T)
                c.set(xx, top, STONE[5]); c.set(xx, top + 1, STONE[3])
    c.grime_bottom(0, width - 1, H - 1, 6, k=0.6)
    return c


# ============================================================
# 木箱 / 桶
# ============================================================
def crate(w=12, h=12, seed=51):
    c = Canvas(w, h, seed)
    c.wall(0, 0, w - 1, h - 1, [WOOD_D, WOOD, WOOD_L, (120, 80, 56)], base=1.6, spread=0.8, scale=3)
    for y in range(2, h, 3):
        c.hline(1, w - 2, y, WOOD_D)
    c.rect(0, 0, w - 1, 0, (138, 96, 66)); c.vline(0, 0, h - 1, (120, 80, 56))
    c.vline(w - 1, 0, h - 1, WOOD_D); c.hline(0, w - 1, h - 1, (34, 22, 18))
    for i in range(min(w, h) - 2):  # 斜撑
        c.set(1 + i * (w - 2) // (h - 2), 1 + i, (120, 80, 56))
    return c


def barrel(seed=52):
    w, h = 8, 11
    c = Canvas(w, h, seed)
    col = (70, 82, 80)
    for x in range(w):
        k = 0.7 + 0.6 * math.sin(math.pi * (x + 0.5) / w)
        c.vline(x, 1, h - 1, shade(col, k))
    for y in (2, 8):
        c.hline(0, w - 1, y, IRON_D)
    c.hline(1, w - 2, 0, shade(col, 1.4))
    c.drips(0, w - 1, 3, 3, maxlen=5, color=RUST[1])
    return c


# ============================================================
# 晾衣绳(下垂的绳 + 一串衣服)
# ============================================================
def laundry_line(w, sag, items, seed, rope=(150, 140, 120), pad=18):
    H = sag + pad
    c = Canvas(w, H, seed)
    ys = []
    for x in range(w):
        t = x / (w - 1)
        y = int(round(sag * 4 * t * (1 - t)))
        ys.append(y)
        c.set(x, y, rope)
    def shirt(x, col):
        y = ys[x] + 1
        c.rect(x, y, x + 6, y + 1, col)         # 肩袖
        c.rect(x + 1, y + 2, x + 5, y + 7, col)  # 身
        c.hline(x, x + 6, y, shade(col, 1.2))
        c.vline(x + 5, y + 2, y + 7, shade(col, 0.75))
        c.set(x + 3, y, shade(col, 0.6))         # 领口
        c.set(x + 2, y - 1, (30, 26, 22)); c.set(x + 4, y - 1, (30, 26, 22))  # 夹子
        return 8
    def pants(x, col):
        y = ys[x] + 1
        c.rect(x, y, x + 4, y + 2, col)
        c.rect(x, y + 3, x + 1, y + 9, col); c.rect(x + 3, y + 3, x + 4, y + 9, col)
        c.hline(x, x + 4, y, shade(col, 1.2)); c.vline(x + 4, y + 3, y + 9, shade(col, 0.75))
        return 6
    def sheet(x, col, ww=11, hh=12):
        for xx in range(x, x + ww):
            y0 = ys[min(xx, w - 1)] + 1
            ln = hh - (1 if (xx - x) % 4 == 3 else 0)
            for y in range(y0, y0 + ln):
                k = 1.08 if (xx - x) % 4 == 0 else (0.86 if (xx - x) % 4 == 2 else 1.0)
                c.set(xx, y, shade(col, k))
        return ww + 1
    def sock(x, col):
        y = ys[x] + 1
        c.vline(x, y, y + 3, col); c.set(x + 1, y + 3, col)
        return 3
    def dress(x, col):
        y = ys[x] + 1
        c.rect(x + 1, y, x + 3, y + 3, col)
        for i in range(5):
            c.hline(x + 1 - i // 2, x + 3 + i // 2, y + 4 + i, col)
        c.hline(x + 1, x + 3, y, shade(col, 1.2))
        return 6
    def bulb(x, col):
        y = ys[x]
        c.set(x, y + 1, IRON_D); c.set(x, y + 2, LIT[2]); c.set(x, y + 3, LIT[1])
        return 1
    kinds = dict(shirt=shirt, pants=pants, sheet=sheet, sock=sock, dress=dress, bulb=bulb)
    for (x, kind, ci) in items:
        kinds[kind](x, CLOTH[ci] if isinstance(ci, int) else ci)
    return c


LINES = {
    "line_a": (72, 6, [(6, "shirt", 0), (16, "sock", 6), (20, "sock", 1), (26, "sheet", 3), (40, "pants", 4), (49, "shirt", 2), (60, "dress", 5)]),
    "line_b": (52, 4, [(5, "sheet", 6), (20, "shirt", 1), (30, "sock", 0), (34, "pants", 7), (42, "shirt", 8)]),
    "line_c": (96, 8, [(8, "dress", 2), (16, "shirt", 4), (28, "sheet", 0), (42, "sock", 3), (46, "sock", 3), (52, "shirt", 5), (64, "pants", 1), (72, "sheet", 7), (86, "shirt", 3)]),
    "line_d": (40, 3, [(4, "shirt", 3), (14, "pants", 2), (22, "sock", 4), (27, "dress", 0)]),
    "bulbs": (88, 7, [(x, "bulb", 0) for x in range(8, 88, 16)]),
}


# ============================================================
# 主街上的巷口:两侧墙角 + 黑黢黢的窄巷,深处一点暖光,头顶横着晾衣绳
# ============================================================
def alley_mouth(seed=61):
    W, H = 36, 72
    c = Canvas(W, H, seed)
    # 巷子深处:由上到下从暗到更暗,底部一点暖光
    for y in range(H):
        for x in range(8, 28):
            t = y / H
            base = mix((24, 22, 22), (14, 13, 13), t)
            if y > H - 22:
                d = abs(x - 18) / 10
                glow = max(0, 1 - d) * (y - (H - 22)) / 22
                base = mix(base, (120, 80, 40), glow * 0.55)
            c.set(x, y, base)
    # 深处的楼:小窗剪影
    for (x, y, lit) in [(11, 14, False), (20, 10, True), (12, 30, True), (21, 34, False)]:
        c.rect(x, y, x + 2, y + 3, LIT[1] if lit else (30, 28, 26))
    # 两侧墙(侧面,带砖)
    for side in (0, 1):
        x0, x1 = (0, 8) if side == 0 else (27, 35)
        c.wall(x0, 0, x1, H - 1, BRICK, base=2.2, spread=1.4, scale=5)
        c.bricks(x0, 0, x1, H - 1, BRICK)
        edge = x1 if side == 0 else x0
        for y in range(H):
            c.darken(edge, y, 0.55)
        c.grime_bottom(x0, x1, H - 1, 8, k=0.5)
    # 头顶的晾衣绳和衣服(小)
    for (y, xs) in [(18, [(10, 0), (15, 2), (21, 5)]), (38, [(12, 3), (19, 1)])]:
        c.hline(8, 27, y, (110, 104, 92))
        for (x, ci) in xs:
            col = shade(CLOTH[ci], 0.55)
            c.rect(x, y + 1, x + 3, y + 4, col)
    # 积水反光
    c.hline(13, 22, H - 2, (60, 60, 64)); c.hline(15, 19, H - 1, (80, 78, 76))
    return c


# ============================================================
# 远景(0.9x):巷子两侧更远的楼背面,压得很暗,零星亮窗、管子、晾衣绳
# ============================================================
def alley_back(W=320, H=90, seed=71):
    c = Canvas(W, H, seed)
    rng = c.rng
    x = 0
    ramps = [CONCRETE, GREENGRAY, BRICK, OCHRE, PLASTER_PINK]
    while x < W:
        bw = rng.randint(34, 62)
        top = rng.randint(-10, 22)
        ramp = ramps[rng.randrange(len(ramps))]
        x1 = min(W - 1, x + bw - 1)
        c.wall(x, max(0, top), x1, H - 1, ramp, base=2.0, spread=1.8, scale=8)
        if top > 0:
            c.hline(x, x1, top, ramp[4])
        for fy in range(max(top, 0) + 6, H - 8, 16):
            c.ledge(x + 1, x1 - 1, fy + 12, light=ramp[3], overhang=0)
            for wx in range(x + 4, x1 - 6, 11):
                lit = rng.random() < 0.12
                c.window(wx, fy, 5, 7, lit=lit, sill=None)
        if rng.random() < 0.6:
            c.drainpipe(x1 - 3, max(0, top), H - 1, c=(60, 52, 44))
        for yy in range(max(0, top), H):
            c.darken(x1, yy, 0.5)
        x += bw
    # 楼之间的晾衣绳
    for i in range(7):
        x0 = rng.randint(0, W - 60)
        ln = rng.randint(30, 60)
        y0 = rng.randint(10, 50)
        sag = rng.randint(2, 5)
        for xx in range(ln):
            t = xx / (ln - 1)
            y = y0 + int(round(sag * 4 * t * (1 - t)))
            if c.get(x0 + xx, y)[3] == 0:
                continue
            c.set(x0 + xx, y, (90, 84, 74))
            if xx % 7 in (2, 3, 4) and rng.random() < 0.8:
                col = shade(CLOTH[rng.randrange(len(CLOTH))], 0.8)
                for k in range(1, 4 + (xx % 3)):
                    if c.get(x0 + xx, y + k)[3]:
                        c.set(x0 + xx, y + k, col)
    # 整体压暗、偏冷,让它退到后面
    for yy in range(H):
        for xx in range(W):
            p = c.get(xx, yy)
            if p[3]:
                lum = max(p[:3])
                if lum > 200:   # 亮窗保留
                    continue
                c.px[xx, yy] = rgba(mix(shade(p, 0.55), (30, 34, 40), 0.25))
    return c


def enter_hint():
    # 和 NPC 的"…"气泡同款外形,里面是向上的箭头
    c = Canvas(7, 6)
    hi, lo, ink = (236, 230, 218), (181, 173, 156), (58, 42, 32)
    rows = [".#####.", "#######", "#######", "#######", ".#####.", ".#....."]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "#":
                c.set(x, y, hi if y < 4 else lo)
    c.set(3, 1, ink); c.set(2, 2, ink); c.set(3, 2, ink); c.set(4, 2, ink); c.set(3, 3, ink)
    return c


if __name__ == "__main__":
    enter_hint().save("out/enter_hint.png")
    import os
    os.makedirs("out", exist_ok=True)
    house_green().save("out/house_green.png")
    house_brick().save("out/house_brick.png")
    dead_end().save("out/dead_end.png")
    terrace().save("out/terrace.png")
    crate().save("out/crate.png")
    crate(9, 8, 53).save("out/crate_small.png")
    barrel().save("out/barrel.png")
    for name, (w, sag, items) in LINES.items():
        laundry_line(w, sag, items, seed=sum(map(ord, name))).save(f"out/{name}.png")
    alley_mouth().save("out/alley_mouth.png")
    alley_back().save("out/alley_back.png")
    print("done")
