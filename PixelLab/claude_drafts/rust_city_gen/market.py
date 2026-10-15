# 夜市摊位街素材
import math
from pxlib import *
from props import CLOTH, MOSS

RED_PAPER = [(110, 34, 26), (168, 56, 38), (214, 96, 52), (246, 170, 96)]
AWNINGS = {
    "red": ((150, 54, 44), (196, 184, 156)),
    "teal": ((52, 104, 104), (190, 182, 152)),
    "mustard": ((176, 132, 54), (96, 60, 40)),
    "plum": ((104, 58, 86), (190, 176, 146)),
}


def lantern(c, x, y, big=False):
    """纸灯笼:顶盖、红纸身(中间最亮)、底下流苏。x,y=顶盖左上。"""
    w = 4 if big else 3
    h = 5 if big else 4
    c.hline(x, x + w - 1, y, IRON_D)
    for yy in range(1, h + 1):
        for xx in range(w):
            edge = xx in (0, w - 1)
            mid = 1 <= yy <= h - 1
            col = RED_PAPER[2] if (mid and not edge) else RED_PAPER[1]
            if mid and not edge and yy == h // 2 + (1 if big else 0):
                col = RED_PAPER[3]
            c.set(x + xx, y + yy, col)
    c.hline(x, x + w - 1, y + h + 1, IRON_D)
    c.set(x + w // 2, y + h + 2, (196, 150, 60))
    return (x + w // 2, y + h // 2 + 1)


def lantern_line(w, sag=None, spacing=12, seed=1, rope=(110, 90, 70)):
    """灯笼串:两头钉墙。返回 (canvas, 灯笼中心列表)。"""
    sag = sag if sag is not None else max(2, min(8, w // 12))
    c = Canvas(w, sag + 14, seed)
    ys = []
    for x in range(w):
        t = x / max(1, w - 1)
        y = 2 + int(round(sag * 4 * t * (1 - t)))
        ys.append(y)
        c.set(x, y, rope)
    for x, d in ((0, 1), (w - 1, -1)):
        c.set(x, 1, IRON_D); c.set(x, 2, IRON); c.set(x, 3, IRON_D); c.set(x + d, 1, IRON_D)
    centers = []
    off = (w % spacing) // 2 + spacing // 2
    for i, x in enumerate(range(off, w - 4, spacing)):
        y = ys[x]
        c.set(x, y + 1, IRON_D)
        centers.append(lantern(c, x - 1, y + 2, big=(i % 3 == 1)))
    return c, centers


# ------------------------------------------------------------
# 摊位:招牌板 + 条纹雨棚 + 两根柱子 + 挂货 + 柜台和货品
# ------------------------------------------------------------
def goods(c, kind, x0, x1, ytop):
    rng = c.rng
    x = x0
    while x <= x1 - 2:
        if kind == "fish":
            col = (150, 160, 166) if rng.random() < 0.6 else (176, 120, 96)
            c.hline(x, x + 3, ytop, col); c.set(x + 4, ytop - 1, shade(col, 0.8)); c.set(x + 4, ytop + 0, shade(col, 0.8))
            c.set(x, ytop - 1, shade(col, 1.2))
            x += 6
        elif kind == "bowls":
            col = (200, 192, 170)
            c.hline(x, x + 3, ytop, col); c.hline(x + 1, x + 2, ytop + 1, shade(col, 0.75))
            c.set(x + 1, ytop - 1, (190, 130, 70)); c.set(x + 2, ytop - 1, (210, 160, 90))
            x += 5
        elif kind == "fruit":
            for i in range(3):
                col = [(196, 90, 44), (210, 150, 50), (150, 50, 40)][rng.randrange(3)]
                c.set(x + i, ytop, col)
                if i == 1:
                    c.set(x + i, ytop - 1, shade(col, 1.15))
            x += 4
        elif kind == "bottles":
            col = [(60, 100, 70), (110, 70, 40), (70, 90, 110)][rng.randrange(3)]
            h = rng.randint(2, 4)
            c.vline(x, ytop - h + 1, ytop, col); c.set(x, ytop - h, shade(col, 1.4))
            x += 2
        else:
            x += 3


def stall(w=44, h=44, awning="red", kind="fish", hang="lantern", seed=81):
    c = Canvas(w, h, seed)
    rng = c.rng
    A, B = AWNINGS[awning]
    SIGN_Y, AW_Y, COUNTER_Y = 0, 7, h - 13
    # 后墙(柜台后面那块暗暖色)
    for y in range(AW_Y + 5, COUNTER_Y):
        for x in range(3, w - 3):
            t = (y - AW_Y) / (COUNTER_Y - AW_Y)
            c.set(x, y, mix((36, 26, 20), (92, 60, 34), t))
    # 后墙货架两层
    for sy in (AW_Y + 12, AW_Y + 20):
        if sy < COUNTER_Y - 2:
            c.hline(4, w - 5, sy, WOOD_L)
            goods(c, ["bottles", "bowls", "fruit"][rng.randrange(3)], 5, w - 6, sy - 1)
    # 柱子
    for px in (2, w - 3):
        c.vline(px, AW_Y, h - 1, WOOD)
        c.vline(px + 1, AW_Y, h - 1, WOOD_D)
    # 雨棚:竖条纹,顶亮,下沿波浪
    for y in range(AW_Y, AW_Y + 5):
        for x in range(0, w):
            col = A if (x // 3) % 2 == 0 else B
            k = 1.15 if y == AW_Y else (0.85 if y == AW_Y + 4 else 1.0)
            c.set(x, y, shade(col, k))
    for x in range(0, w):
        if x % 3 == 1:
            col = A if (x // 3) % 2 == 0 else B
            c.set(x, AW_Y + 5, shade(col, 0.75))
    c.hline(0, w - 1, AW_Y - 1, IRON_D)
    # 招牌板(空,画个小图标)
    sx0, sx1 = w // 2 - 9, w // 2 + 8
    c.rect(sx0, SIGN_Y, sx1, SIGN_Y + 5, WOOD_D)
    c.rect(sx0 + 1, SIGN_Y + 1, sx1 - 1, SIGN_Y + 4, (128, 50, 40) if awning != "red" else (60, 50, 40))
    c.hline(sx0 + 1, sx1 - 1, SIGN_Y + 1, shade((128, 50, 40), 1.2) if awning != "red" else (80, 66, 52))
    ic = (214, 180, 110)
    mx = w // 2
    if kind == "fish":
        c.hline(mx - 3, mx + 1, SIGN_Y + 3, ic); c.set(mx + 2, SIGN_Y + 2, ic); c.set(mx + 2, SIGN_Y + 4, ic); c.set(mx - 2, SIGN_Y + 2, ic)
    elif kind == "bowls":
        c.hline(mx - 3, mx + 2, SIGN_Y + 2, ic); c.hline(mx - 2, mx + 1, SIGN_Y + 3, ic); c.set(mx, SIGN_Y + 1, ic); c.set(mx + 1, SIGN_Y + 1, ic)
    elif kind == "fruit":
        c.rect(mx - 1, SIGN_Y + 2, mx + 1, SIGN_Y + 4, ic); c.set(mx, SIGN_Y + 1, (120, 150, 70))
    else:
        c.vline(mx - 2, SIGN_Y + 2, SIGN_Y + 4, ic); c.vline(mx + 1, SIGN_Y + 1, SIGN_Y + 4, ic); c.set(mx + 1, SIGN_Y + 1, (230, 220, 200))
    c.vline(sx0 + 3, SIGN_Y + 6, AW_Y - 1, IRON_D); c.vline(sx1 - 3, SIGN_Y + 6, AW_Y - 1, IRON_D)
    # 雨棚下挂的东西
    hangers = []
    if hang == "lantern":
        hangers.append(lantern(c, 6, AW_Y + 6))
        hangers.append(lantern(c, w - 10, AW_Y + 6, big=True))
    else:
        for x in range(6, w - 6, 4):     # 一串串晾干的东西
            col = [(150, 110, 60), (190, 170, 120), (120, 60, 40)][rng.randrange(3)]
            ln = rng.randint(3, 6)
            c.vline(x, AW_Y + 6, AW_Y + 6 + ln, col)
            c.set(x, AW_Y + 6 + ln, shade(col, 0.7))
    # 柜台
    c.rect(1, COUNTER_Y, w - 2, h - 1, WOOD)
    for x in range(1, w - 1, 4):
        c.vline(x, COUNTER_Y + 2, h - 2, WOOD_D)
    c.hline(0, w - 1, COUNTER_Y, (138, 96, 66)); c.hline(0, w - 1, COUNTER_Y + 1, WOOD_D)
    c.hline(1, w - 2, h - 1, (30, 22, 18))
    goods(c, kind, 3, w - 4, COUNTER_Y - 1)
    # 柜台前面挂一块布帘(颜色同雨棚)
    for x in range(w // 2 - 6, w // 2 + 6):
        for y in range(COUNTER_Y + 3, COUNTER_Y + 8 + (x % 2)):
            c.set(x, y, shade(A, 0.9 if (x % 3) else 0.75))
    return c, hangers


# ------------------------------------------------------------
# 夜市的楼 A:粉灰墙三层,二楼通长木走廊(可站),底层敞开的铺面,侧挂竖招牌
# ------------------------------------------------------------
def market_house_a(seed=91):
    W, H = 64, 96
    c = Canvas(W, H, seed)
    L, R, TOP = 3, 60, 16
    c.wall(L, TOP, R, H - 1, PLASTER_PINK, base=2.8, spread=2.6, scale=9)
    c.stains(L, TOP, R, H - 1, 16, RUST[1], r=5, t=0.45)
    # 瓦檐:深灰瓦一排一排,两头微微翘
    for i in range(6):
        y = TOP - 6 + i
        for x in range(L - 3 + (5 - i) // 2, R + 4 - (5 - i) // 2):
            c.set(x, y, (46, 48, 50) if (x + i) % 3 else (66, 68, 70))
    c.hline(L - 3, R + 3, TOP - 1, (84, 86, 88))
    c.set(L - 4, TOP - 2, (84, 86, 88)); c.set(R + 4, TOP - 2, (84, 86, 88))
    c.rect(44, TOP - 13, 48, TOP - 6, BRICK[3]); c.hline(43, 49, TOP - 13, STONE[4])
    c.rust_band(L, R, TOP, 5)
    # 三楼窗
    for i, wx in enumerate([8, 26, 44]):
        c.window(wx, TOP + 5, 6, 8, lit=(i != 1), shutter=(120, 64, 50) if i == 1 else None)
    c.ledge(L, R, 36, light=CREAM)
    c.drips(L, R, 39, 8, maxlen=7)
    # 二楼:通长木走廊(地板在 y=58)
    for i, wx in enumerate([9, 27, 45]):
        if i == 1:
            c.door(wx, 44, 6, 14, color=(90, 50, 40), knob=False, step=False)
        else:
            c.window(wx, 43, 6, 9, lit=True, curtain=(150, 70, 60) if i == 0 else None)
    GY = 58
    c.rect(L - 2, GY, R + 2, GY + 1, WOOD)
    c.hline(L - 2, R + 2, GY, (138, 96, 66))
    c.hline(L - 2, R + 2, GY + 2, WOOD_D)
    for x in range(L - 2, R + 3):        # 木栏杆
        if (x - L) % 3 == 0:
            c.vline(x, GY - 5, GY - 1, WOOD_L)
    c.hline(L - 2, R + 2, GY - 6, (138, 96, 66))
    c.hline(L - 2, R + 2, GY - 5, WOOD)
    for bx in (L, R - 1):                  # 撑木
        for i in range(4):
            c.set(bx + (i if bx == L else -i) // 2, GY + 3 + i, WOOD_D)
    # 走廊下挂灯笼
    hangers = [lantern(c, 14, GY + 3), lantern(c, 40, GY + 3, big=True)]
    # 侧挂竖招牌(空板,铜边)
    c.rect(R + 1, 40, R + 3, 41, IRON_D)
    c.rect(R - 1, 42, R + 3, 56, (40, 28, 22))
    c.rect(R, 43, R + 2, 55, (140, 56, 44))
    for y in (45, 49, 53):
        c.set(R + 1, y, (214, 180, 110))
    # 底层敞开铺面
    SX0, SX1, SY = 8, 52, 70
    for y in range(SY, H):
        for x in range(SX0, SX1 + 1):
            t = (y - SY) / (H - SY)
            c.set(x, y, mix((120, 82, 42), (70, 46, 28), t))
    for sy in (75, 82):
        c.hline(SX0 + 2, SX1 - 2, sy, WOOD_L)
        goods(c, "bottles" if sy == 75 else "bowls", SX0 + 3, SX1 - 3, sy - 1)
    c.rect(SX0 + 4, 88, SX1 - 4, H - 1, WOOD)          # 柜台
    c.hline(SX0 + 4, SX1 - 4, 88, (138, 96, 66))
    goods(c, "fruit", SX0 + 6, SX1 - 6, 87)
    c.vline(SX0 - 1, SY, H - 1, WOOD_D); c.vline(SX1 + 1, SY, H - 1, WOOD_D)
    c.hline(SX0 - 1, SX1 + 1, SY - 1, WOOD_D)
    # 布帘:三片,颜色不一
    for i, col in enumerate([(150, 54, 44), (52, 104, 104), (176, 132, 54)]):
        x0 = SX0 + i * 15
        for x in range(x0, x0 + 14):
            for y in range(SY, SY + 4 + (1 if x % 4 == 1 else 0)):
                c.set(x, y, shade(col, 0.85 if x % 3 == 0 else 1.0))
    c.grime_bottom(L, R, H - 1, 6, k=0.55)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8); c.tint(L, y, PLASTER_PINK[5], 0.3)
    return c, hangers, GY


# ------------------------------------------------------------
# 夜市的楼 B:高瘦水泥楼,每层小阳台挂灯笼,正面竖排三块彩色空招牌
# ------------------------------------------------------------
def market_house_b(seed=92):
    W, H = 50, 112
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 47, 6
    c.wall(L, TOP, R, H - 1, CONCRETE, base=2.9, spread=2.6, scale=9)
    c.stains(L, TOP, R, H - 1, 18, (40, 34, 24), r=5, t=0.45)
    c.hline(L - 1, R + 1, TOP - 1, CONCRETE[5]); c.hline(L - 1, R + 1, TOP, CONCRETE[1])
    c.vline(12, 0, TOP - 2, IRON); c.hline(10, 14, 1, IRON)
    hangers = []
    floors = [26, 46, 66, 86]
    for y in floors:
        c.ledge(L, R, y, light=CONCRETE[5])
        c.drips(L, R, y + 3, 8, maxlen=9, color=(40, 34, 24))
    for fi, ftop in enumerate([TOP, 26, 46, 66]):
        c.window(6, ftop + 6, 6, 8, lit=(fi % 2 == 0))
        c.window(20, ftop + 6, 6, 8, lit=(fi == 1))
        # 每层右边一个小阳台挂灯笼
        c.railing(30, R + 1, ftop + 18, h=3)
        if fi in (1, 3):
            hangers.append(lantern(c, 36, ftop + 20))
        else:
            for x, col in [(33, (96, 140, 70)), (40, (120, 150, 80))]:   # 盆栽
                c.rect(x, ftop + 15, x + 2, ftop + 16, (120, 64, 44)); c.set(x + 1, ftop + 13, col); c.set(x, ftop + 14, col); c.set(x + 2, ftop + 14, col)
    # 竖招牌三块(空板)
    for (x, y, col) in [(L + 1, 30, (140, 56, 44)), (L + 1, 52, (52, 104, 104)), (L + 1, 72, (196, 176, 120))]:
        c.rect(x - 2, y, x + 1, y + 13, (34, 26, 22))
        c.rect(x - 1, y + 1, x, y + 12, col)
        c.set(x - 1, y + 1, shade(col, 1.3))
    # 底层:卷帘半开 + 门
    c.rect(6, 92, 30, H - 1, (20, 18, 16))
    for y in range(99, H):
        c.hline(7, 29, y, mix(LIT[1], LIT[0], (y - 99) / 13))
    for y in range(92, 99):
        c.hline(6, 30, y, (104, 106, 98) if y % 2 else (78, 80, 74))
    c.door(36, H - 12, 6, 12, color=(64, 70, 58), step=False)
    c.grime_bottom(L, R, H - 1, 10, k=0.45)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8)
    return c, hangers


# ------------------------------------------------------------
# 面摊车:两个轮子、锅(冒汽的地方)、小伞
# ------------------------------------------------------------
def noodle_cart(seed=93):
    W, H = 30, 30
    c = Canvas(W, H, seed)
    # 伞
    for i in range(4):
        c.hline(4 + i * 2 - 2, W - 5 - i * 2 + 2, 3 - i + 3, (150, 54, 44) if i % 2 == 0 else (196, 184, 156))
    c.hline(2, W - 3, 6, (150, 54, 44)); c.hline(2, W - 3, 7, (110, 40, 34))
    c.vline(W // 2, 7, 15, IRON_D)
    hang = lantern(c, 4, 8)
    # 车身
    c.rect(2, 16, W - 3, 24, WOOD)
    c.hline(2, W - 3, 16, (138, 96, 66)); c.hline(2, W - 3, 24, WOOD_D)
    for x in range(4, W - 3, 5):
        c.vline(x, 18, 23, WOOD_D)
    # 锅
    c.rect(16, 12, 24, 15, (60, 62, 64)); c.hline(15, 25, 12, (110, 112, 112)); c.hline(17, 23, 11, (180, 170, 150))
    c.rect(5, 13, 10, 15, (200, 192, 170)); c.hline(5, 10, 13, (230, 222, 200))   # 一摞碗
    # 轮子
    for wx in (7, W - 8):
        for (dx, dy) in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -2), (1, -2), (-1, 2), (1, 2), (-2, -1), (-2, 1), (2, -1), (2, 1)]:
            c.set(wx + dx, 26 + dy, (30, 28, 26))
        c.set(wx, 26, IRON_L)
    c.hline(0, 3, 18, WOOD_D)   # 推把
    return c, hang, (20, 10)


# ------------------------------------------------------------
# 夜市牌楼(主街入口 / 巷子这头的出口):两根铁柱 + 横梁 + 空招牌 + 灯笼,中间镂空
# ------------------------------------------------------------
def market_gate(seed=94):
    W, H = 50, 66
    c = Canvas(W, H, seed)
    # 柱子(铆钉铁柱)
    for px in (3, W - 7):
        c.rect(px, 14, px + 3, H - 1, IRON)
        c.vline(px, 14, H - 1, IRON_L); c.vline(px + 3, 14, H - 1, IRON_D)
        for y in range(18, H - 2, 6):
            c.set(px + 1, y, IRON_D); c.set(px + 2, y, IRON_L)
        c.rect(px - 1, H - 4, px + 4, H - 1, STONE[3]); c.hline(px - 1, px + 4, H - 4, STONE[5])
        c.rust_band(px, px + 3, 20, 6, t=0.5)
    # 横梁(两道)+ 斜撑格子
    for y in (12, 22):
        c.rect(0, y, W - 1, y + 2, IRON)
        c.hline(0, W - 1, y, IRON_L); c.hline(0, W - 1, y + 2, IRON_D)
    for x in range(7, W - 7, 6):
        for i in range(7):
            c.set(x + i // 2, 15 + i, IRON_D)
            c.set(x + 5 - i // 2, 15 + i, IRON_D)
    # 顶上弧形铁花 + 空招牌
    for x in range(W):
        y = 11 - int(round(5 * math.sin(math.pi * x / (W - 1))))
        c.set(x, y, IRON_L); c.set(x, y + 1, IRON_D)
    c.rect(13, 1, 36, 9, (40, 28, 22))
    c.rect(14, 2, 35, 8, (140, 52, 40))
    c.hline(14, 35, 2, (176, 80, 56))
    for x in (16, 33):
        c.set(x, 4, (214, 180, 110)); c.set(x, 6, (214, 180, 110))
    # 横梁下挂一排灯笼 + 一道彩旗
    hangers = []
    for i, x in enumerate(range(9, W - 9, 8)):
        c.vline(x + 1, 25, 26, IRON_D)
        hangers.append(lantern(c, x, 27, big=(i % 2 == 0)))
    for x in range(4, W - 4):
        y = 33 + int(round(2 * math.sin(math.pi * (x - 4) / (W - 9))))
        c.set(x, y, (120, 100, 80))
        if x % 4 == 0:
            col = [(150, 54, 44), (52, 104, 104), (176, 132, 54), (104, 58, 86)][(x // 4) % 4]
            c.set(x, y + 1, col); c.set(x + 1, y + 1, col); c.set(x, y + 2, col)
    return c, hangers


# ------------------------------------------------------------
# 夜市尽头的大市场楼:两层,三个拱门(两个关着、一个透亮),顶上大空招牌
# ------------------------------------------------------------
def market_hall(seed=95):
    W, H = 96, 90
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 93, 18
    c.wall(L, TOP, R, H - 1, OCHRE, base=2.7, spread=2.8, scale=10)
    c.stains(L, TOP, R, H - 1, 22, RUST[1], r=6, t=0.5)
    c.rust_band(L, R, TOP, 6)
    # 大招牌(空)
    c.rect(18, 2, 77, 14, (34, 26, 22))
    c.rect(20, 4, 75, 12, (120, 46, 36))
    c.hline(20, 75, 4, (160, 70, 50))
    for x in range(22, 75, 6):
        c.set(x, 8, (214, 180, 110))
    c.vline(24, 15, TOP - 1, IRON_D); c.vline(71, 15, TOP - 1, IRON_D)
    c.hline(L - 1, R + 1, TOP - 1, CREAM); c.hline(L - 1, R + 1, TOP, OCHRE[1])
    # 二楼一排长窗
    for i, wx in enumerate(range(8, 88, 14)):
        c.window(wx, TOP + 6, 6, 12, lit=(i % 2 == 0))
    c.ledge(L, R, 42)
    c.drips(L, R, 45, 14, maxlen=9)
    # 三个拱门
    for i, ax in enumerate([10, 38, 66]):
        aw, top = 20, 52
        cx = ax + aw / 2 - 0.5
        for y in range(top, H):
            for x in range(ax, ax + aw):
                inside = y >= top + 8 or (x - cx) ** 2 + ((y - (top + 8)) * 1.2) ** 2 <= (aw / 2 - 0.3) ** 2
                if not inside:
                    continue
                if i == 1:   # 中间这个开着,里面亮
                    t = (y - top) / (H - top)
                    c.set(x, y, mix((200, 140, 70), (110, 70, 36), t))
                else:        # 卷帘
                    c.set(x, y, (96, 98, 90) if y % 2 else (70, 72, 66))
        for a in range(0, 181, 4):
            rad = math.radians(a)
            x = int(round(cx + math.cos(rad) * (aw / 2 + 0.6)))
            y = int(round(top + 8 - math.sin(rad) * (aw / 2 + 0.6) / 1.2))
            c.set(x, y, CREAM if (a // 20) % 2 == 0 else STONE[4])
        for y in range(top + 8, H):
            c.set(ax - 1, y, STONE[4]); c.set(ax + aw, y, STONE[4])
    # 开着的门里:人影一样的货架、吊灯
    c.hline(41, 54, 68, WOOD_L); goods(c, "bottles", 42, 54, 67)
    c.hline(41, 54, 76, WOOD_L); goods(c, "fruit", 42, 54, 75)
    c.vline(47, 52, 56, IRON_D); c.set(47, 57, LIT[2])
    c.grime_bottom(L, R, H - 1, 8, k=0.5)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8)
    return c


# ------------------------------------------------------------
# 夜市远景(0.8x):一片亮窗的楼背 + 竖招牌剪影 + 一串串红灯笼点
# ------------------------------------------------------------
def market_back(W=320, H=90, seed=96):
    c = Canvas(W, H, seed)
    rng = c.rng
    x = 0
    ramps = [PLASTER_PINK, CONCRETE, OCHRE, BRICK]
    while x < W:
        bw = rng.randint(30, 56)
        top = rng.randint(-6, 26)
        ramp = ramps[rng.randrange(len(ramps))]
        x1 = min(W - 1, x + bw - 1)
        c.wall(x, max(0, top), x1, H - 1, ramp, base=2.0, spread=1.6, scale=8)
        if top > 0:
            c.hline(x, x1, top, ramp[4])
        for fy in range(max(top, 0) + 6, H - 8, 15):
            for wx in range(x + 4, x1 - 5, 10):
                c.window(wx, fy, 5, 7, lit=rng.random() < 0.35, sill=None)
        if rng.random() < 0.7:      # 竖招牌
            sx = x + rng.randint(2, max(3, bw - 5))
            sy = max(top, 0) + rng.randint(8, 30)
            col = [(140, 56, 44), (52, 104, 104), (176, 132, 54)][rng.randrange(3)]
            c.rect(sx, sy, sx + 2, sy + 12, col)
        for yy in range(max(0, top), H):
            c.darken(x1, yy, 0.5)
        x += bw
    for i in range(6):              # 红灯笼串(远处只是一排红点)
        x0 = rng.randint(0, W - 70); ln = rng.randint(40, 70); y0 = rng.randint(14, 56); sag = rng.randint(2, 5)
        for xx in range(ln):
            t = xx / (ln - 1)
            y = y0 + int(round(sag * 4 * t * (1 - t)))
            if c.get(x0 + xx, y)[3] == 0:
                continue
            c.set(x0 + xx, y, (80, 70, 60))
            if xx % 6 == 3:
                c.set(x0 + xx, y + 1, (230, 120, 60)); c.set(x0 + xx, y + 2, (200, 80, 46))
    for yy in range(H):
        for xx in range(W):
            p = c.get(xx, yy)
            if p[3] and max(p[:3]) <= 200 and not (p[0] > 180 and p[1] < 140):
                c.px[xx, yy] = rgba(mix(shade(p, 0.55), (34, 30, 34), 0.25))
    return c
