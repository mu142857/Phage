# 后巷(晾衣巷尽头那扇小门进去):又窄又黑的死胡同,下水道帮在这儿堵人。
# 楼都是背面:没人住、窗户钉死、消防梯、墙上帮派画的红围巾结 + 粉笔记账的"正"字。
from pxlib import *
from pxlib import Canvas
import random

SOOT = (22, 20, 18)
GANG_RED = (168, 58, 66)
CHALK = (196, 190, 172)


def _tag_scarf(c, cx, cy, s=1.0, col=GANG_RED):
    """喷漆的红围巾结:两只耳朵 + 中间一个结 + 两条往下飘的尾巴,带往下流的漆。"""
    pts = []
    for dx, dy in [(-8, -3), (-7, -4), (-6, -4), (-5, -3), (-4, -2), (-3, -1), (-7, -2), (-6, -1), (-5, -1), (-4, 0),
                   (-8, -2), (-8, -1), (-7, 0), (-6, 1), (-5, 1), (-4, 1),
                   (8, -3), (7, -4), (6, -4), (5, -3), (4, -2), (3, -1), (7, -2), (6, -1), (5, -1), (4, 0),
                   (8, -2), (8, -1), (7, 0), (6, 1), (5, 1), (4, 1),
                   (-2, -1), (-1, -1), (0, -1), (1, -1), (2, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0),
                   (-1, 1), (0, 1), (1, 1),
                   (-1, 2), (-2, 3), (-2, 4), (-3, 5), (-3, 6), (-4, 7),
                   (1, 2), (2, 3), (2, 4), (3, 5), (4, 6), (4, 7), (5, 8)]:
        pts.append((int(cx + dx * s), int(cy + dy * s)))
    for (x, y) in pts:
        c.tint(x, y, col, 0.85)
    # 漆往下流
    for x in (cx - 6, cx - 1, cx + 5, cx + 3):
        ln = c.rng.randint(2, 6)
        for j in range(ln):
            c.tint(x, cy + 2 + j + (2 if x > cx else 0), col, 0.6 * (1 - j / ln))


ZHENG = ["#####", "..#..", "#.##.", "#.#..", "#####"]


def _tally(c, x, y, n, col=CHALK):
    """粉笔记账:一排"正"字,最后一个可以没写完。"""
    full, rest = divmod(n, 5)
    strokes = [[(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)], [(2, 1), (2, 2), (2, 3)], [(3, 2)], [(0, 2), (0, 3)],
               [(0, 4), (1, 4), (2, 4), (3, 4), (4, 4)]]
    k = 0
    for i in range(full + (1 if rest else 0)):
        m = 5 if i < full else rest
        for s in strokes[:m]:
            for (dx, dy) in s:
                c.tint(x + i * 7 + dx, y + dy, col, 0.55 + 0.2 * c.rng.random())
        k += 1


def entry_back(seed=401):
    """进来的那扇门所在的楼背面(就是晾衣巷尽头那栋)。门中心在 x=25。"""
    W, H = 72, 118
    c = Canvas(W, H, seed)
    c.wall(0, 0, W - 3, H - 1, CONCRETE, base=2.4, spread=2.4, scale=10)
    c.stains(0, 0, W - 3, H - 1, 26, SOOT, r=6, t=0.5)
    for y in (24, 52, 80):
        c.ledge(0, W - 3, y, light=CONCRETE[5], overhang=0)
        c.drips(0, W - 3, y + 3, 12, maxlen=12, color=SOOT)
    for (x, y) in [(10, 6), (34, 6), (54, 6), (10, 32), (54, 32), (34, 60), (54, 60), (10, 86)]:
        c.boarded(x, y, 7, 10)
    c.window(34, 32, 7, 10, lit=False, broken=True)
    c.drainpipe(64, 0, H - 2, c=(80, 66, 54))
    # 门 + 门上一个小灯泡
    c.door(22, 103, 7, 14, color=(56, 38, 32), step=False)
    c.hline(20, 30, 101, IRON_D)
    c.set(25, 98, IRON_D); c.set(25, 99, LIT[2]); c.set(26, 99, LIT[2]); c.set(25, 100, LIT[1]); c.set(26, 100, LIT[1])
    c.grime_bottom(0, W - 3, H - 1, 14, k=0.4)
    return c


def tenement(seed, W=100, H=124, ramp=CONCRETE, escapes=(), lit_window=None, ac=2, tally=0, tag=None):
    """楼背面。escapes=[(x0,x1,y)] 消防梯平台(图里坐标,y=平台地板行),相邻两层之间画斜梯。"""
    c = Canvas(W, H, seed)
    r = random.Random(seed)
    c.wall(0, 0, W - 1, H - 1, ramp, base=2.5, spread=2.5, scale=9)
    if ramp is BRICK:
        c.bricks(0, 0, W - 1, H - 1, ramp)
    c.stains(0, 0, W - 1, H - 1, 30, SOOT, r=6, t=0.45)
    for y in range(18, H - 10, 26):
        c.ledge(0, W - 1, y, light=shade(ramp[5], 1.05), overhang=0)
        c.rust_band(0, W - 1, y + 2, depth=4, color=RUST[1], t=0.35)
        c.drips(0, W - 1, y + 3, 10, maxlen=10, color=SOOT)
    # 窗:大多钉死/黑着
    for row, y in enumerate(range(4, H - 22, 26)):
        for x in range(8, W - 10, 22):
            k = r.random()
            if lit_window == (row, x):
                c.window(x, y, 7, 10, lit=True, curtain=(110, 60, 70))
            elif k < 0.45:
                c.boarded(x, y, 7, 10)
            else:
                c.window(x, y, 7, 10, broken=k > 0.8)
    # 空调外机
    for _ in range(ac):
        x, y = r.randint(4, W - 16), r.choice(list(range(12, H - 30, 26)))
        c.rect(x, y, x + 9, y + 6, (84, 86, 82))
        c.hline(x, x + 9, y, (120, 120, 112))
        for xx in range(x + 1, x + 9, 2):
            c.vline(xx, y + 2, y + 5, (52, 54, 52))
        c.drips(x, x + 9, y + 7, 3, maxlen=10, color=SOOT)
    # 消防梯
    for (x0, x1, y) in escapes:
        c.railing(x0, x1, y, h=5)
        for xx in range(x0, x1 + 1, 6):
            c.bracket(xx, y + 2, n=3, dx=1)
    escs = sorted(escapes, key=lambda e: e[2])
    for a, b in zip(escs, escs[1:]):
        # 从上一层的左头斜着往左下接到下一层
        c.stair(a[0] + 4, a[2], a[0] + 4 - (b[2] - a[2]), b[2])
    if tally:
        _tally(c, 10, H - 30, tally)
    if tag:
        _tag_scarf(c, tag[0], tag[1], tag[2] if len(tag) > 2 else 1.0)
    c.drainpipe(W - 6, 0, H - 2, c=(76, 64, 52))
    c.grime_bottom(0, W - 1, H - 1, 16, k=0.4)
    return c


def gang_wall(seed=431):
    """巷子尽头:一堵砖墙,墙上一个巨大的红围巾结,底下一排粉笔"正"字,墙根一个下水道铁栅。"""
    W, H = 80, 124
    c = Canvas(W, H, seed)
    c.wall(0, 0, W - 1, H - 1, BRICK, base=2.3, spread=2.4, scale=8)
    c.bricks(0, 0, W - 1, H - 1, BRICK)
    c.stains(0, 0, W - 1, H - 1, 30, SOOT, r=6, t=0.5)
    for y in (30, 62):
        c.ledge(0, W - 1, y, light=shade(BRICK[5], 1.1), overhang=0)
        c.drips(0, W - 1, y + 3, 10, maxlen=12, color=SOOT)
    for (x, y) in [(10, 8), (60, 8), (10, 40), (60, 40)]:
        c.boarded(x, y, 7, 10)
    _tag_scarf(c, 40, 82, 1.6)
    _tally(c, 12, 100, 17)
    _tally(c, 12, 107, 9)
    # 墙根下水道铁栅(半截埋在地下)
    gx, gy = 30, H - 9
    c.rect(gx, gy, gx + 18, H - 1, (20, 20, 22))
    for x in range(gx, gx + 19, 3):
        c.vline(x, gy, H - 1, (70, 64, 58))
    c.hline(gx, gx + 18, gy, (96, 88, 78))
    c.drips(gx, gx + 18, gy - 6, 6, maxlen=6, color=(44, 60, 50))
    c.grime_bottom(0, W - 1, H - 1, 18, k=0.35)
    return c


def gate(seed=441):
    """卷下来的铁栅门:竖铁条 + 两道横梁 + 底下一排尖。12×74。"""
    W, H = 12, 74
    c = Canvas(W, H, seed)
    for x in range(0, W, 3):
        for y in range(0, H - 3):
            c.set(x, y, IRON_L if (y // 3) % 5 else IRON)
            c.set(x + 1, y, IRON)
        c.set(x, H - 3, IRON_L); c.set(x, H - 2, IRON); c.set(x, H - 1, IRON_D)
    for y in (6, 30, 54):
        c.hline(0, W - 1, y, IRON_L)
        c.hline(0, W - 1, y + 1, IRON_D)
    c.drips(0, W - 1, 8, 6, maxlen=10, color=RUST[1])
    c.drips(0, W - 1, 32, 6, maxlen=10, color=RUST[1])
    c.mottle(0, 0, W - 1, H - 1, amt=0.18, accent=RUST[1], accent_amt=0.5)
    return c


def dumpster(seed=451):
    """绿铁皮大垃圾箱(顶上能站)。26×15。"""
    W, H = 26, 15
    c = Canvas(W, H, seed)
    body = [(30, 42, 37), (40, 54, 47), (52, 66, 57)]
    c.rect(1, 3, W - 2, H - 2, body[1])
    for x in range(1, W - 1):
        c.set(x, 3, body[2])
    for x in range(3, W - 3, 4):
        c.vline(x, 4, H - 3, body[0])
    c.rect(0, 1, W - 1, 2, (34, 40, 36))           # 盖子
    c.hline(0, W - 1, 1, (64, 74, 66))
    c.rect(2, H - 1, 4, H - 1, IRON_D); c.rect(W - 5, H - 1, W - 3, H - 1, IRON_D)   # 轮子
    c.mottle(0, 0, W - 1, H - 1, amt=0.2, accent=RUST[1], accent_amt=0.45)
    c.drips(1, W - 2, 4, 5, maxlen=8, color=RUST[1])
    # 箱子上也被喷了个小记号
    for (x, y) in ((11, 7), (12, 6), (13, 7), (12, 8), (14, 8), (10, 8)):
        c.tint(x, y, GANG_RED, 0.75)
    return c


BAG = [(26, 28, 26), (42, 44, 42), (58, 62, 58), (90, 94, 88)]


def trash_bag(seed=461, w=11, h=10):
    """和放哨的伪装成的垃圾袋一个画法(真假混在一起)。"""
    import math
    c = Canvas(w + 4, h + 3, seed)
    r = random.Random(seed)
    cx = (w + 4) // 2
    hh = h + r.randint(-1, 1)
    for y in range(hh):
        t = y / max(1, hh - 1)
        half = int(round(1.5 + (w / 2 - 1) * math.sin(min(1.0, t * 1.15) * math.pi * 0.62)))
        yy = (h + 2) - (hh - 1) + y
        for x in range(-half, half + 1):
            col = BAG[1]
            if x < -half + 2 or y > hh - 3:
                col = BAG[0]
            elif x > half - 2 and y < hh - 3:
                col = BAG[2]
            if y in (3, 4) and x == half - 2:
                col = BAG[3]
            c.set(cx + x, yy, col)
    top = (h + 2) - hh
    c.set(cx, top, BAG[0]); c.set(cx - 1, top - 1, BAG[1]); c.set(cx + 1, top - 1, BAG[2])
    return c


def pallets(seed=471):
    W, H = 18, 9
    c = Canvas(W, H, seed)
    for i, y in enumerate((0, 3, 6)):
        c.hline(0, W - 1, y, WOOD_L)
        c.hline(0, W - 1, y + 1, WOOD)
        for x in (1, 8, 15):
            c.rect(x, y + 2, x + 1, y + 2, WOOD_D)
    c.mottle(0, 0, W - 1, H - 1, amt=0.2)
    return c


def scarf_flag(seed=481):
    """绑在管子上的一条红围巾(帮派地盘标记),挂着飘。7×12。"""
    W, H = 7, 12
    c = Canvas(W, H, seed)
    c.hline(0, 6, 0, (120, 110, 100))
    rows = ["RRRR...", ".RRr...", ".RRr...", "..Rr...", "..RRr..", "...Rr..", "...Rr..", "....Rr.", "....R..",
            "....Rr.", ".....R.", "......"]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == 'R':
                c.set(x, y + 1, GANG_RED)
            elif ch == 'r':
                c.set(x, y + 1, shade(GANG_RED, 0.7))
    return c


def back_far(W=320, H=90, seed=491):
    """0.8x 层:更远处的楼背面剪影,几乎全黑,零星一两扇亮窗。"""
    c = Canvas(W, H, seed)
    r = random.Random(seed)
    x = 0
    while x < W:
        w = r.randint(26, 48)
        top = r.randint(4, 30)
        col = (30 + r.randint(0, 8), 31 + r.randint(0, 8), 30 + r.randint(0, 6))
        c.rect(x, top, min(W - 1, x + w - 1), H - 1, col)
        c.hline(x, min(W - 1, x + w - 1), top, shade(col, 1.4))
        for yy in range(top + 6, H - 10, 9):
            for xx in range(x + 3, x + w - 4, 7):
                k = r.random()
                if k < 0.06:
                    c.rect(xx, yy, xx + 2, yy + 3, LIT[0])
                elif k < 0.5:
                    c.rect(xx, yy, xx + 2, yy + 3, shade(col, 0.7))
        x += w + r.randint(0, 3)
    return c
