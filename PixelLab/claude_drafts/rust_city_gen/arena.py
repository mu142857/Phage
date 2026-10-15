# 竞技场街素材
import math
from pxlib import *

SLIME_BLUE = (70, 110, 150)


def poster(kind=0, seed=401, torn=False):
    """拳赛海报:纸色底,一个史莱姆剪影 + 拳头,上下两道色条(没有字)。"""
    W, H = 12, 16
    c = Canvas(W, H, seed)
    paper = [(186, 170, 130), (170, 120, 90), (150, 150, 140)][kind % 3]
    band = [(150, 50, 40), (50, 80, 110), (176, 132, 54)][kind % 3]
    c.rect(0, 0, W - 1, H - 1, paper)
    c.rect(0, 0, W - 1, 2, band); c.rect(0, H - 3, W - 1, H - 1, band)
    # 史莱姆剪影(圆顶)
    for y in range(5, 12):
        for x in range(2, 10):
            if (x - 5.5) ** 2 + ((y - 11) * 1.2) ** 2 <= 16:
                c.set(x, y, shade(SLIME_BLUE, 0.6) if kind != 2 else (60, 50, 44))
    c.set(4, 8, paper); c.set(7, 8, paper)
    # 拳头
    c.rect(8, 6, 10, 8, (200, 160, 120)); c.set(9, 5, (200, 160, 120))
    # 旧:四角发黄、一道折痕
    for (x, y) in [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)]:
        c.set(x, y, shade(paper, 0.7))
    c.vline(W // 2, 3, H - 4, shade(paper, 0.88))
    if torn:
        rng = c.rng
        for y in range(H // 2, H):
            for x in range(W - 1 - (y - H // 2) // 2 - rng.randint(0, 1), W):
                c.set(x, y, T)
    return c


def banner(seed=402, col=(110, 40, 36)):
    """竖条旗:铁杆横挑,布上一个圈里的拳头。"""
    W, H = 9, 24
    c = Canvas(W, H, seed)
    c.hline(0, W - 1, 0, IRON_L)
    for y in range(1, H):
        w_off = 0 if y < H - 3 else (y - (H - 3))
        for x in range(0 + w_off // 2, W - w_off // 2):
            if y >= H - 3 and x == W // 2:
                continue
            c.set(x, y, shade(col, 1.1 if x == 1 else (0.8 if x == W - 2 else 1.0)))
    for a in range(0, 360, 30):
        c.set(int(round(4 + math.cos(math.radians(a)) * 2.5)), int(round(9 + math.sin(math.radians(a)) * 2.5)), (200, 170, 90))
    c.set(4, 9, (200, 170, 90)); c.set(3, 9, (200, 170, 90))
    return c


def ticket_booth(seed=403):
    """售票亭:小铁皮亭子,圆顶,窗口拉着铁栅,一块空牌子。"""
    W, H = 26, 36
    c = Canvas(W, H, seed)
    body = [(52, 40, 34), (76, 56, 44), (102, 74, 54), (128, 96, 70)]
    c.wall(2, 10, W - 3, H - 1, body, base=2.0, spread=1.2, scale=4)
    for x in range(0, W):
        y = 9 - int(round(5 * math.sin(math.pi * x / (W - 1))))
        c.vline(x, y, 9, (70, 80, 76) if x % 3 else (90, 100, 94))
        c.set(x, y, (120, 130, 120))
    c.vline(W // 2, 0, 4, IRON); c.set(W // 2, 0, (200, 170, 90))
    c.rect(5, 14, W - 6, 24, (20, 18, 16))
    for x in range(5, W - 5, 2):
        c.vline(x, 14, 24, IRON_L)
    c.hline(4, W - 5, 25, (138, 96, 66))
    c.rect(6, 27, W - 7, 31, (150, 52, 40)); c.hline(6, W - 7, 27, (186, 80, 56))
    c.stains(2, 10, W - 3, H - 1, 6, RUST[1], r=3, t=0.6)
    c.grime_bottom(2, W - 3, H - 1, 5, k=0.5)
    return c


def rubble(W=20, seed=404):
    c = Canvas(W, 6, seed)
    rng = c.rng
    for x in range(W):
        h = int(round(5 * max(0, 1 - abs(x - W / 2) / (W / 2)))) + rng.randint(0, 1)
        for y in range(6 - h, 6):
            c.set(x, y, [BRICK[2], STONE[2], BRICK[1], STONE[3]][rng.randrange(4)])
    return c
