# 主街上的巷口:一栋底层开拱门洞的"过街楼",照用户主街楼的画法。
import math
from pxlib import *
from assets import CLOTH

WARMGRAY = [(34, 32, 30), (50, 47, 42), (64, 60, 53), (80, 76, 67), (100, 94, 82), (122, 114, 98)]


def arch_house(seed=7):
    W, H = 60, 82
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 57, 12
    c.wall(L, TOP, R, H - 1, WARMGRAY, base=2.8, spread=2.8, scale=9)
    c.stains(L, TOP, R, H - 1, 18, RUST[1], r=5, t=0.5)
    c.rust_band(L, R, TOP, 6)

    # ---- 屋顶:檐口 + 女儿墙栏杆 + 烟囱 + 晾衣架 ----
    c.hline(L - 1, R + 1, TOP - 1, WARMGRAY[5]); c.hline(L - 1, R + 1, TOP, WARMGRAY[1])
    for x in range(L, R + 1, 3):
        c.set(x, TOP + 1, WARMGRAY[1])
    c.railing(L + 2, 30, TOP - 2, h=4, top=IRON_L, post_a=IRON_L, post_b=IRON, base=IRON_D)
    c.wall(44, 1, 49, TOP - 2, BRICK, base=3, spread=1.4, scale=2)
    c.hline(43, 50, 1, STONE[4]); c.hline(43, 50, 2, STONE[2])
    c.set(46, 0, STONE[1]); c.set(47, 0, STONE[1])

    # ---- 楼层线 ----
    floors = [29, 46]
    for y in floors:
        c.ledge(L, R, y, light=CREAM)
        c.rust_band(L, R, y + 2, 5)
        c.drips(L, R, y + 3, 11, maxlen=9)

    # ---- 三楼:三扇窗,一扇亮 ----
    for i, wx in enumerate([7, 26, 45]):
        c.window(wx, TOP + 6, 6, 9, lit=(i == 2), shutter=(70, 82, 76) if i == 0 else None)
    # ---- 二楼:中间一个小阳台(晾着毯子),两边窗 ----
    c.window(7, 33, 6, 9)
    c.window(45, 33, 6, 9, lit=True, curtain=(120, 56, 48))
    c.door(26, 34, 6, 12, color=(70, 52, 40), knob=False, step=False)
    c.railing(20, 37, 45, h=4)
    c.bracket(20, 47, 2); c.bracket(37, 47, 2, dx=-1)
    rug = (112, 50, 42)
    for x in range(22, 28):
        for y in range(41, 47):
            c.set(x, y, rug if y % 3 else (168, 120, 60))
    c.drainpipe(R - 3, TOP, H - 2)

    # ---- 底层:拱门洞 ----
    AX0, AX1 = 19, 40           # 洞口内宽 22
    cx = (AX0 + AX1) / 2
    r = (AX1 - AX0 + 1) / 2
    spring = 66                 # 拱脚
    floor_y = H - 1

    def inside(x, y):
        if x < AX0 or x > AX1 or y > floor_y:
            return False
        if y >= spring:
            return True
        return (x - cx) ** 2 + ((y - spring) * 1.05) ** 2 <= (r - 0.3) ** 2

    # 洞里:近处黑,远处有个亮着的小院
    for y in range(40, H):
        for x in range(AX0, AX1 + 1):
            if not inside(x, y):
                continue
            c.set(x, y, (20, 18, 17))
    # 远处的院子(洞里中间缩小的一块):暖光墙面 + 小窗 + 晾衣绳
    FX0, FX1, FY0 = 23, 36, 60
    for y in range(FY0, floor_y - 3):
        for x in range(FX0, FX1 + 1):
            if inside(x, y):
                t = (y - FY0) / (floor_y - 3 - FY0)
                c.set(x, y, mix((86, 62, 38), (132, 92, 50), t))
    c.wall(FX0, FY0, FX1, floor_y - 4, OCHRE, base=2.0, spread=1.0, scale=3)
    for y in range(FY0, floor_y - 3):
        for x in range(FX0, FX1 + 1):
            c.tint(x, y, (150, 100, 50), 0.35)
    c.rect(25, 63, 27, 66, LIT[1]); c.hline(25, 27, 64, WOOD)     # 远处亮窗
    c.rect(32, 63, 34, 66, (40, 32, 26))
    # 远处晾衣绳 + 小衣服
    c.hline(FX0, FX1, 68, (110, 100, 84))
    for x, ci in [(24, 0), (28, 3), (33, 1)]:
        col = shade(CLOTH[ci], 0.8)
        c.rect(x, 69, x + 2, 72, col)
    # 远处地面:亮一条,往洞口方向变暗(透视)
    for y in range(floor_y - 3, floor_y + 1):
        t = (y - (floor_y - 3)) / 3
        for x in range(AX0, AX1 + 1):
            d = abs(x - cx) / r
            base = mix((120, 86, 48), (24, 20, 18), min(1, t * 0.6 + d * 0.8))
            c.set(x, y, base)
    # 洞内两侧墙(进深):暗砖
    for side in (0, 1):
        for i in range(4):
            x = AX0 + i if side == 0 else AX1 - i
            for y in range(40, floor_y + 1):
                if inside(x, y) and not (FX0 <= x <= FX1 and FY0 <= y):
                    k = 0.18 + i * 0.05
                    col = shade(BRICK[3], k + (0.06 if (y + i * 2) % 3 == 0 else 0))
                    c.set(x, y, col)
    # 洞顶挂一个灯泡,照亮拱顶
    c.vline(int(cx), spring - 9, spring - 6, IRON_D)
    c.set(int(cx), spring - 5, LIT[2]); c.set(int(cx), spring - 4, LIT[1])
    for y in range(spring - 9, spring + 4):
        for x in range(AX0, AX1 + 1):
            if inside(x, y) and not (FX0 <= x <= FX1 and FY0 <= y):
                dd = math.hypot(x - cx, (y - (spring - 5)) * 1.3)
                if dd < 7:
                    c.tint(x, y, (150, 100, 50), 0.45 * (1 - dd / 7))

    # 拱券:石头一圈(亮暗交替的楔石)+ 拱心石
    ring = []
    for a in range(0, 181, 3):
        rad = math.radians(a)
        for rr in (r + 0.6, r + 1.6):
            x = int(round(cx + math.cos(rad) * rr))
            y = int(round(spring - math.sin(rad) * rr / 1.05))
            ring.append((x, y, a))
    for x, y, a in ring:
        col = CREAM if (a // 15) % 2 == 0 else STONE[4]
        c.set(x, y, col)
    for y in range(spring, floor_y + 1):   # 拱脚往下的门框
        for x in (AX0 - 1, AX0 - 2, AX1 + 1, AX1 + 2):
            c.set(x, y, STONE[4] if (y // 3) % 2 == 0 else STONE[3])
    ky = int(round(spring - r / 1.05)) - 2
    c.rect(int(cx) - 1, ky, int(cx) + 1, ky + 3, STONE[5]); c.hline(int(cx) - 1, int(cx) + 1, ky + 3, STONE[2])
    # 拱上一块空门牌(以后可以写巷名)
    c.rect(24, 49, 35, 52, WOOD_D); c.rect(25, 50, 34, 51, WOOD); c.hline(25, 34, 50, WOOD_L)

    # 底层两侧窗
    c.window(6, 59, 6, 8, sill=CREAM)
    c.window(48, 59, 5, 8, lit=True, sill=CREAM)
    c.drips(L, R, 69, 6, maxlen=6)
    c.grime_bottom(L, R, H - 1, 9, k=0.5)
    # 立体:右侧暗边、左侧亮边
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8); c.tint(L, y, WARMGRAY[5], 0.3)
    return c


def key_hint():
    """Q 键帽:顶面浅色,下沿两行深一档,中间画 Q。"""
    c = Canvas(9, 9)
    top, side, ink = (236, 230, 218), (160, 150, 134), (58, 42, 32)
    for y in range(9):
        for x in range(9):
            corner = (x in (0, 8)) and (y in (0, 8))
            if corner:
                continue
            c.set(x, y, top if y < 7 else side)
    Q = [".###.", "#...#", "#...#", "#..#.", ".##.#"]
    for y, row in enumerate(Q):
        for x, ch in enumerate(row):
            if ch == "#":
                c.set(2 + x, 1 + y, ink)
    return c


if __name__ == "__main__":
    arch_house().save("out/arch_house.png")
    key_hint().save("out/key_q.png")
