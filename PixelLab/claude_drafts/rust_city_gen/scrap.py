# 修车废料巷素材
import math
from pxlib import *

TIN_RUST = [(70, 34, 16), (104, 52, 24), (138, 74, 36), (166, 100, 52)]
TIN_BLUE = [(38, 46, 54), (56, 70, 82), (78, 96, 108), (104, 120, 128)]
TIN_GRAY = [(44, 44, 42), (64, 64, 60), (88, 86, 80), (112, 108, 98)]
TIN_GREEN = [(36, 48, 40), (52, 70, 56), (72, 94, 74), (98, 118, 92)]
PAINT = {"teal": (60, 104, 100), "red": (130, 52, 40), "cream": (176, 160, 120), "blue": (64, 84, 120)}


def tin(c, x0, y0, x1, y1, ramp, rust=0.3):
    """瓦楞铁皮:竖棱一亮一暗,一张张板之间有搭缝和铆钉,随机锈斑。"""
    rng = c.rng
    pw = rng.randint(8, 12)
    for x in range(x0, x1 + 1):
        k = (x - x0) % 3
        col = mix(ramp[2], ramp[3], 0.6) if k == 0 else (ramp[2] if k == 1 else mix(ramp[1], ramp[2], 0.4))
        for y in range(y0, y1 + 1):
            c.set(x, y, col)
        if (x - x0) % pw == pw - 1:
            c.vline(x, y0, y1, ramp[0])
            for y in range(y0 + 2, y1, 5):
                c.set(x - 1, y, (30, 26, 22))
    for y in range(y0 + 1, y1, rng.randint(14, 18)):   # 横搭缝
        c.hline(x0, x1, y, ramp[0])
    c.mottle(x0, y0, x1, y1, amt=0.16, scale=5, accent=TIN_RUST[1], accent_amt=0.35 + rust * 0.4)
    c.stains(x0, y0, x1, y1, int((x1 - x0) * (y1 - y0) * rust / 60), TIN_RUST[1], r=4, t=0.55)
    c.drips(x0, x1, y0 + 1, int((x1 - x0) / 5), maxlen=10, color=TIN_RUST[0])


def tire(c, x, y, w=12):
    """侧看一个轮胎:黑胶圈,中间一道亮边。x,y=左上,高 4。"""
    c.hline(x + 1, x + w - 2, y, (52, 50, 48))
    c.hline(x, x + w - 1, y + 1, (34, 32, 30)); c.hline(x, x + w - 1, y + 2, (28, 26, 25))
    c.hline(x + 1, x + w - 2, y + 3, (18, 17, 16))
    for xx in range(x + 1, x + w - 1, 2):
        c.set(xx, y + 2, (44, 42, 40))


def tire_stack(n=3, w=12, seed=101):
    c = Canvas(w, n * 4, seed)
    for i in range(n):
        off = c.rng.choice([0, 0, 1, -1]) if i else 0
        tire(c, max(0, off), i * 4, w - abs(off))
    return c


# ------------------------------------------------------------
# 车库:单坡铁皮顶,大卷帘门半开里面亮着,门头挂扳手招牌,旁边一摞轮胎和油桶
# ------------------------------------------------------------
def garage(seed=102, ramp=TIN_RUST):
    W, H = 62, 52
    c = Canvas(W, H, seed)
    tin(c, 2, 12, W - 3, H - 1, ramp)
    # 单坡顶(左高右低)
    for x in range(0, W):
        y = 6 + int(x * 5 / W)
        c.hline(x, x, y, TIN_GRAY[3]); c.vline(x, y + 1, y + 4, TIN_GRAY[1] if x % 3 else TIN_GRAY[2])
        c.set(x, y + 5, (30, 28, 26))
    c.vline(10, 0, 6, IRON); c.set(9, 0, IRON); c.set(11, 0, IRON)   # 烟筒
    c.set(10, -1 + 1, TIN_GRAY[3])
    # 卷帘门(半开)+ 里面
    DX0, DX1, DY = 10, 46, 22
    for y in range(DY, H):
        for x in range(DX0, DX1 + 1):
            t = (y - DY) / (H - DY)
            c.set(x, y, mix((150, 104, 56), (60, 42, 26), t))
    # 里面:吊着的灯 + 一个车轮 + 工具墙
    c.vline(28, DY, DY + 9, IRON_D); c.hline(26, 30, DY + 10, IRON); c.set(28, DY + 11, LIT[2])
    for x in range(14, 24, 3):
        c.vline(x, DY + 13, DY + 16, IRON_L)
    c.hline(13, 24, DY + 12, WOOD_D)
    tire(c, 32, H - 6, 10)
    for y in range(DY, DY + 12):
        c.hline(DX0, DX1, y, (110, 112, 104) if y % 2 else (82, 84, 78))
    c.hline(DX0, DX1, DY + 12, (40, 40, 38))
    c.vline(DX0 - 1, DY, H - 1, IRON_D); c.vline(DX1 + 1, DY, H - 1, IRON_D)
    # 扳手招牌
    c.rect(18, 14, 38, 20, (34, 26, 22)); c.rect(19, 15, 37, 19, PAINT["cream"])
    ic = (60, 50, 44)
    c.hline(23, 31, 17, ic); c.set(22, 16, ic); c.set(22, 18, ic); c.set(32, 16, ic); c.set(32, 18, ic)
    # 小窗
    c.window(50, 26, 6, 6, lit=True, cross=True, sill=None)
    c.grime_bottom(2, W - 3, H - 1, 6, k=0.5)
    return c


# ------------------------------------------------------------
# 两层铁皮工棚:外挂铁梯上平顶(平顶可站),二楼一扇亮窗
# ------------------------------------------------------------
def shed_tall(seed=103, ramp=TIN_BLUE):
    W, H = 56, 72
    c = Canvas(W, H, seed)
    tin(c, 2, 8, W - 3, H - 1, ramp)
    c.hline(0, W - 1, 6, TIN_GRAY[3]); c.hline(0, W - 1, 7, TIN_GRAY[1]); c.hline(0, W - 1, 8, (30, 28, 26))
    c.railing(2, 22, 6, h=4)
    # 楼层分隔(焊缝)
    c.hline(2, W - 3, 38, (30, 28, 26)); c.hline(2, W - 3, 39, ramp[3])
    c.window(10, 16, 8, 10, lit=True)
    c.window(30, 16, 8, 10, lit=False, broken=True)
    c.door(10, H - 16, 8, 16, color=TIN_GRAY[1], knob=True, step=False)
    c.window(30, 46, 8, 8, lit=False)
    # 外挂铁梯(右侧)
    for y in range(8, H):
        c.set(W - 6, y, IRON_L); c.set(W - 3, y, IRON)
        if y % 4 == 0:
            c.hline(W - 6, W - 3, y, IRON_L)
    # 雨棚
    for x in range(6, 22):
        c.set(x, 56, TIN_RUST[2]); c.set(x, 57, TIN_RUST[1])
    c.grime_bottom(2, W - 3, H - 1, 8, k=0.5)
    return c


# ------------------------------------------------------------
# 废车:侧看小轿车,没轮子垫在砖上,漆掉得厉害
# ------------------------------------------------------------
def car_wreck(paint="teal", seed=104, W=46, H=20):
    c = Canvas(W, H, seed)
    col = PAINT[paint]
    ramp = [shade(col, 0.45), shade(col, 0.7), col, shade(col, 1.25)]
    BODY_Y = 8
    # 车身
    for x in range(1, W - 1):
        top = BODY_Y + (1 if x < 4 or x > W - 5 else 0)
        for y in range(top, H - 4):
            v = 2 if y < BODY_Y + 3 else 1
            c.set(x, y, ramp[v])
        c.set(x, top, ramp[3])
    # 驾驶室(梯形)
    for i in range(7):
        y = BODY_Y - 1 - i
        x0, x1 = 12 + i, W - 14 - i // 2
        c.hline(x0, x1, y, ramp[2] if i else ramp[1])
        c.set(x0, y, ramp[3])
    c.hline(18, W - 18, BODY_Y - 7, ramp[3])
    # 车窗(黑,一块碎)
    for y in range(BODY_Y - 5, BODY_Y - 1):
        c.hline(14 + (BODY_Y - 1 - y), 24, y, (22, 22, 24))
        c.hline(27, W - 17 - (BODY_Y - 1 - y) // 2, y, (22, 22, 24))
    c.vline(25, BODY_Y - 6, BODY_Y - 1, ramp[2]); c.vline(26, BODY_Y - 6, BODY_Y - 1, ramp[1])
    c.set(16, BODY_Y - 3, (90, 96, 100)); c.set(30, BODY_Y - 4, (90, 96, 100))
    # 门缝、把手、灯
    c.vline(25, BODY_Y, H - 6, ramp[0]); c.vline(36, BODY_Y + 1, H - 6, ramp[0])
    c.set(22, BODY_Y + 2, IRON_L); c.set(33, BODY_Y + 2, IRON_L)
    c.set(W - 2, BODY_Y + 2, (200, 180, 120)); c.set(1, BODY_Y + 2, (140, 40, 30))
    c.mottle(0, 0, W - 1, H - 5, amt=0.14, scale=4, accent=TIN_RUST[1], accent_amt=0.4)
    # 锈:下半截大片
    c.stains(1, BODY_Y + 2, W - 2, H - 5, 10, TIN_RUST[1], r=4, t=0.7)
    c.drips(1, W - 2, BODY_Y, 8, maxlen=6, color=TIN_RUST[0])
    # 轮拱(空的)+ 垫砖
    for wx in (9, W - 10):
        for x in range(wx - 4, wx + 5):
            for y in range(H - 7, H - 4):
                if (x - wx) ** 2 + ((y - (H - 4)) * 1.4) ** 2 <= 20:
                    c.set(x, y, (16, 15, 14))
        c.rect(wx - 3, H - 4, wx + 2, H - 1, BRICK[3]); c.hline(wx - 3, wx + 2, H - 4, BRICK[4]); c.vline(wx, H - 4, H - 1, BRICK[1])
    return c


def car_stack(n=3, seed=105):
    """压扁的车摞起来:每层 9 格高,颜色各异,略错位。"""
    W = 46
    H = n * 9 + 1
    c = Canvas(W, H, seed)
    rng = c.rng
    for i in range(n):
        col = list(PAINT.values())[rng.randrange(len(PAINT))]
        ramp = [shade(col, 0.4), shade(col, 0.65), col, shade(col, 1.2)]
        y0 = H - 9 * (i + 1) - 1
        off = rng.randint(-2, 2) if i else 0
        x0, x1 = max(0, 1 + off), min(W - 1, W - 2 + off)
        for y in range(y0, y0 + 9):
            for x in range(x0, x1 + 1):
                v = 3 if y == y0 else (2 if y < y0 + 3 else (1 if y < y0 + 7 else 0))
                c.set(x, y, ramp[v])
        c.hline(x0 + 4, x1 - 4, y0 + 3, (22, 22, 24))         # 压扁的车窗缝
        for wx in (x0 + 7, x1 - 7):                          # 压扁的轮拱
            c.hline(wx - 3, wx + 3, y0 + 7, (16, 15, 14)); c.hline(wx - 2, wx + 2, y0 + 6, (16, 15, 14))
        c.mottle(x0, y0, x1, y0 + 8, amt=0.14, scale=3, accent=TIN_RUST[1], accent_amt=0.4)
        c.stains(x0, y0, x1, y0 + 8, 6, TIN_RUST[1], r=3, t=0.6)
        c.drips(x0, x1, y0 + 2, 5, maxlen=6, color=TIN_RUST[0])
    return c


# ------------------------------------------------------------
# 废料山:锅炉片、齿轮、管子、铁板堆成的坡(碰撞是三角坡)
# ------------------------------------------------------------
def scrap_heap(W=64, H=28, seed=106):
    c = Canvas(W, H, seed)
    rng = c.rng
    peak = W // 2 + rng.randint(-6, 6)

    def top_at(x):
        return int(round(H - 1 - (H - 3) * max(0, 1 - abs(x - peak) / (W / 2))))
    for x in range(W):
        for y in range(top_at(x), H):
            v = rng.random()
            col = TIN_RUST[1] if v < 0.4 else (TIN_GRAY[1] if v < 0.7 else (TIN_RUST[0] if v < 0.9 else TIN_GRAY[2]))
            c.set(x, y, col)
    # 往里塞东西:板子、管子、齿轮、轮胎
    for _ in range(14):
        x = rng.randint(W // 5, W - W // 5 - 10)
        lo = top_at(x) + 1
        if lo >= H - 3:
            continue
        y = rng.randint(lo, H - 3)
        kind = rng.randrange(4)
        if kind == 0:
            ln = rng.randint(6, 12)
            col = rng.choice([TIN_BLUE[2], TIN_RUST[2], TIN_GRAY[3], TIN_GREEN[2]])
            for i in range(ln):
                yy = y + (i * rng.choice([0, 0, 1])) // 3
                if c.get(x + i, yy)[3]:
                    c.set(x + i, yy, col); c.set(x + i, yy + 1, shade(col, 0.6))
        elif kind == 1:
            ln = rng.randint(5, 10)
            for i in range(ln):
                if c.get(x + i, y)[3]:
                    c.set(x + i, y, IRON_L); c.set(x + i, y + 1, IRON)
        elif kind == 2:
            for a in range(0, 360, 30):
                xx = int(round(x + 3 + math.cos(math.radians(a)) * 2.6)); yy = int(round(y + math.sin(math.radians(a)) * 2.6))
                if c.get(xx, yy)[3]:
                    c.set(xx, yy, (150, 120, 70))
            c.set(x + 3, y, (40, 30, 20))
        else:
            if c.get(x, y)[3] and c.get(x + 9, y)[3]:
                tire(c, x, y, 10)
    # 坡顶描一道亮边
    for x in range(W):
        y = top_at(x)
        if c.get(x, y)[3]:
            c.tint(x, y, (200, 170, 120), 0.35)
    return c, peak


# ------------------------------------------------------------
# 吊车:格构铁塔 + 吊臂 + 钢缆 + 吊钩
# ------------------------------------------------------------
def crane(H=104, seed=107):
    W = 64
    c = Canvas(W, H, seed)
    TX0, TX1 = 6, 13
    col_a, col_b = (150, 110, 40), (110, 76, 30)
    for y in range(14, H):
        c.set(TX0, y, col_a); c.set(TX1, y, col_b)
        k = (y - 14) % 8
        c.set(TX0 + k * (TX1 - TX0) // 8, y, col_b)
        c.set(TX1 - k * (TX1 - TX0) // 8, y, col_b)
        if k == 0:
            c.hline(TX0, TX1, y, col_a)
    c.rect(TX0 - 2, 8, TX1 + 4, 14, (120, 90, 36)); c.hline(TX0 - 2, TX1 + 4, 8, col_a)
    c.window(TX0, 9, 5, 4, lit=True, cross=False, sill=None)
    # 吊臂
    for x in range(0, W):
        c.set(x, 6, col_a); c.set(x, 9 if x > TX1 + 4 else 6, col_b)
        if x > TX1 + 4 and (x - TX1) % 6 == 0:
            c.vline(x, 6, 9, col_b)
    c.hline(TX1 + 5, W - 1, 9, col_b)
    c.vline(TX0 + 3, 0, 6, col_a)
    for x in range(TX0 + 3, W - 1, 2):   # 拉索
        y = int((x - TX0 - 3) * 5 / (W - TX0 - 4))
        c.set(x, y + 1, (90, 80, 60))
    # 钢缆 + 吊钩
    HX = W - 8
    c.vline(HX, 10, 54, (70, 66, 60))
    c.rect(HX - 2, 55, HX + 2, 58, IRON); c.hline(HX - 2, HX + 2, 55, IRON_L)
    c.vline(HX, 59, 62, IRON_L); c.set(HX - 1, 63, IRON_L); c.set(HX - 2, 62, IRON_L); c.set(HX + 1, 63, IRON)
    c.drips(TX0, TX1, 20, 6, maxlen=10, color=TIN_RUST[0])
    return c


# ------------------------------------------------------------
# 铁丝网围栏
# ------------------------------------------------------------
def fence(W=48, H=26, seed=108):
    c = Canvas(W, H, seed)
    wire = (96, 96, 90)
    for x in range(W):
        for y in range(2, H - 1):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c.set(x, y, wire)
    for px in range(0, W, 16):
        c.vline(px, 0, H - 1, IRON); c.vline(px + 1, 0, H - 1, IRON_D)
    c.hline(0, W - 1, 2, IRON_L)
    for x in range(0, W, 3):   # 顶上的刺绳
        c.set(x, 0, (120, 116, 108)); c.set(x + 1, 1, (120, 116, 108))
    for _ in range(5):          # 破洞
        hx, hy = c.rng.randint(4, W - 6), c.rng.randint(6, H - 6)
        for dx in range(-1, 3):
            for dy in range(-1, 2):
                c.set(hx + dx, hy + dy, T)
    return c


# ------------------------------------------------------------
# 尽头的废料场大仓库:整面铁皮墙,大推拉门,门上大空招牌,探照灯
# ------------------------------------------------------------
def warehouse(seed=109):
    W, H = 96, 100
    c = Canvas(W, H, seed)
    tin(c, 0, 14, W - 1, H - 1, TIN_GREEN, rust=0.5)
    # 弧顶
    for x in range(W):
        y = 14 - int(round(10 * math.sin(math.pi * x / (W - 1))))
        c.vline(x, y, 14, TIN_GRAY[1] if x % 3 else TIN_GRAY[2])
        c.set(x, y, TIN_GRAY[3])
    c.rect(20, 18, 75, 28, (34, 26, 22)); c.rect(22, 20, 73, 26, (150, 120, 60))
    c.hline(22, 73, 20, (186, 156, 90))
    for x in range(26, 72, 8):
        c.set(x, 23, (90, 60, 30))
    # 高窗一排
    for wx in range(8, 88, 12):
        c.window(wx, 34, 7, 6, lit=(wx // 12) % 3 == 0, sill=None)
    c.hline(0, W - 1, 46, (30, 28, 26)); c.hline(0, W - 1, 47, TIN_GREEN[3])
    # 大推拉门:两扇,一扇拉开一条缝透光
    c.rect(18, 54, 77, H - 1, (30, 28, 26))
    tin(c, 19, 55, 46, H - 1, TIN_GRAY)
    tin(c, 52, 55, 76, H - 1, TIN_GRAY)
    for y in range(55, H):
        c.hline(47, 51, y, mix(LIT[1], LIT[0], (y - 55) / 45))
    c.hline(16, 79, 53, IRON_L)
    for x in range(22, 76, 6):
        c.set(x, 52, IRON_D)
    # 探照灯(左上)
    c.rect(4, 48, 9, 51, IRON); c.hline(4, 9, 51, (230, 220, 190)); c.vline(6, 52, 54, IRON_D)
    c.grime_bottom(0, W - 1, H - 1, 10, k=0.45)
    return c


# ------------------------------------------------------------
# 远景:废车堆、吊车、铁皮棚剪影,零星工作灯
# ------------------------------------------------------------
def scrap_back(W=320, H=90, seed=110):
    c = Canvas(W, H, seed)
    rng = c.rng
    x = 0
    while x < W:
        kind = rng.randrange(3)
        bw = rng.randint(30, 60)
        x1 = min(W - 1, x + bw)
        if kind == 0:      # 铁皮棚
            top = rng.randint(30, 50)
            tin(c, x, top, x1, H - 1, [TIN_GRAY, TIN_RUST, TIN_BLUE][rng.randrange(3)], rust=0.2)
            if rng.random() < 0.5:
                c.window(x + 6, top + 8, 6, 5, lit=True, sill=None)
        elif kind == 1:    # 一座车山
            peak = rng.randint(34, 56)
            for xx in range(x, x1):
                t = abs(xx - (x + x1) / 2) / (bw / 2)
                top = int(peak + (H - peak) * t * t)
                for yy in range(top, H):
                    col = [TIN_RUST[1], TIN_GRAY[1], TIN_BLUE[1], TIN_RUST[0]][(xx // 4 + yy // 3) % 4]
                    c.set(xx, yy, col)
        else:              # 吊车塔
            tx = x + bw // 2
            top = rng.randint(4, 20)
            for yy in range(top, H):
                c.set(tx, yy, (100, 76, 30)); c.set(tx + 3, yy, (80, 60, 26))
                if (yy - top) % 5 == 0:
                    c.hline(tx, tx + 3, yy, (100, 76, 30))
            c.hline(tx - 14, tx + 24, top, (100, 76, 30))
            c.vline(tx + 20, top, top + rng.randint(10, 30), (70, 66, 60))
            c.set(tx + 1, top + 2, LIT[1])
        x = x1 + rng.randint(0, 8)
    for yy in range(H):
        for xx in range(W):
            p = c.get(xx, yy)
            if p[3] and max(p[:3]) <= 200:
                c.px[xx, yy] = rgba(mix(shade(p, 0.5), (30, 32, 36), 0.3))
    return c


def chain(length=40, seed=141, hook=True):
    """吊链:一节横一节竖,底下一个钩子(前景剪影用)。"""
    c = Canvas(5, length + 6, seed)
    for y in range(length):
        if (y // 2) % 2 == 0:
            c.set(1, y, IRON); c.set(3, y, IRON)
        else:
            c.set(2, y, IRON_L)
    if hook:
        c.vline(2, length, length + 3, IRON_L); c.set(1, length + 4, IRON_L); c.set(0, length + 3, IRON_L); c.set(3, length + 5, IRON)
    return c
