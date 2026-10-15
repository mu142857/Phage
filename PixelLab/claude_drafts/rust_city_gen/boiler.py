# 锅炉管道巷素材
import math
from pxlib import *

COPPER = [(70, 40, 24), (110, 66, 38), (150, 96, 56), (186, 132, 82)]
VERDI = [(34, 56, 50), (52, 84, 72), (76, 116, 98), (110, 150, 126)]
IRONP = [(34, 32, 30), (56, 52, 48), (82, 76, 68), (112, 104, 92)]
FIRE = [(120, 40, 16), (200, 84, 30), (246, 150, 60), (255, 214, 130)]


def hpipe(c, x0, x1, y, d=6, ramp=COPPER, flange=14, rust=True):
    """横管:上亮下暗的圆柱,法兰一节一节,底下锈水。y=管顶。"""
    for yy in range(y, y + d):
        t = (yy - y) / max(1, d - 1)
        k = 3 if t < 0.2 else (2 if t < 0.5 else (1 if t < 0.85 else 0))
        c.hline(x0, x1, yy, ramp[k])
    for x in range(x0 + 4, x1 - 2, flange):
        c.vline(x, y - 1, y + d, ramp[1]); c.vline(x + 1, y - 1, y + d, ramp[3])
        c.set(x, y - 1, ramp[3]); c.set(x + 1, y + d, ramp[0])
    if rust:
        c.drips(x0, x1, y + d, max(1, (x1 - x0) // 8), maxlen=7, color=RUST[1])


def vpipe(c, x, y0, y1, d=4, ramp=COPPER, flange=16):
    for xx in range(x, x + d):
        t = (xx - x) / max(1, d - 1)
        k = 3 if t < 0.25 else (2 if t < 0.55 else (1 if t < 0.85 else 0))
        c.vline(xx, y0, y1, ramp[k])
    for y in range(y0 + 6, y1, flange):
        c.hline(x - 1, x + d, y, ramp[1]); c.hline(x - 1, x + d, y + 1, ramp[3])


# ---- 管子的每一头都要有去处:拐弯(弯头)、拐进墙里(插墙接头)、顶在墙上(法兰)、落地(底座) ----
def fitting(c, x, y, w, h, ramp):
    """方形管件(弯头/三通都用它):上左亮、下右暗、四角螺栓。x,y=左上。"""
    c.rect(x, y, x + w - 1, y + h - 1, ramp[2])
    c.hline(x, x + w - 1, y, ramp[3]); c.vline(x, y, y + h - 1, ramp[3])
    c.hline(x, x + w - 1, y + h - 1, ramp[0]); c.vline(x + w - 1, y, y + h - 1, ramp[0])
    for (bx, by) in [(x + 1, y + 1), (x + w - 2, y + 1), (x + 1, y + h - 2), (x + w - 2, y + h - 2)]:
        c.set(bx, by, ramp[1])


def elbow(c, px, py, dh, dv, ramp):
    """横管(管顶 py,粗 dh)和竖管(左边 px,粗 dv)在这里拐弯/相交:盖一个管件。"""
    fitting(c, px - 1, py - 1, dv + 2, dh + 2, ramp)


def into_wall(c, x, y, d, ramp, horizontal=True):
    """管子在这里拐进墙里:一个管件,中间一块黑(管口朝墙里去),旁边墙上一圈影子。"""
    w = d + 2
    fitting(c, x - 1, y - 1, w, w, ramp)
    c.rect(x + 1, y + 1, x + d - 2, y + d - 2, (18, 16, 15))
    c.set(x + 1, y + 1, ramp[0])
    for i in range(-2, w):
        c.darken(x - 2, y + i, 0.7); c.darken(x + w - 1, y + i, 0.75)
    for i in range(-2, w):
        c.darken(x + i, y + w - 1, 0.7)


def flange_end(c, x, y, d, ramp, side):
    """横管顶在墙上的那一头:两列宽的法兰圈,比管子上下各多出一格。side=+1 墙在右,-1 墙在左。"""
    c.vline(x, y - 1, y + d, ramp[0] if side > 0 else ramp[3])
    c.vline(x - side, y - 1, y + d, ramp[3] if side > 0 else ramp[1])
    c.set(x - side, y - 1, ramp[3]); c.set(x - side, y + d, ramp[1])
    c.set(x - side, y + d // 2, ramp[1])


def base_plate(c, x, y_bottom, d, ramp=None):
    """竖管落地:底下一块方底座。"""
    ramp = ramp or IRONP
    c.rect(x - 2, y_bottom - 1, x + d + 1, y_bottom, ramp[1])
    c.hline(x - 2, x + d + 1, y_bottom - 1, ramp[3])
    c.set(x - 2, y_bottom, ramp[0]); c.set(x + d + 1, y_bottom, ramp[0])


def valve(c, x, y, r=3, col=(150, 50, 40)):
    """阀门手轮:一个圈 + 十字辐条。"""
    for a in range(0, 360, 20):
        c.set(int(round(x + math.cos(math.radians(a)) * r)), int(round(y + math.sin(math.radians(a)) * r)), col)
    c.hline(x - r + 1, x + r - 1, y, shade(col, 0.7)); c.vline(x, y - r + 1, y + r - 1, shade(col, 0.7))
    c.set(x, y, IRON_L)


def gauge(c, x, y):
    """压力表:白圆盘 + 红指针。"""
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                c.set(x + dx, y + dy, (210, 204, 186))
    for a in range(0, 360, 30):
        c.set(int(round(x + math.cos(math.radians(a)) * 2.6)), int(round(y + math.sin(math.radians(a)) * 2.6)), IRON_D)
    c.set(x, y, (160, 40, 30)); c.set(x + 1, y - 1, (160, 40, 30))


# ------------------------------------------------------------
# 锅炉房:砖砌,高拱窗里透火光,底层炉口(炉门开着,里面火红),高烟囱
# ------------------------------------------------------------
def boiler_house(seed=201):
    W, H = 80, 104
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 69, 24
    c.wall(L, TOP, R, H - 1, BRICK, base=2.6, spread=1.6, scale=8)
    c.bricks(L, TOP, R, H - 1, BRICK)
    c.stains(L, TOP, R, H - 1, 22, (30, 22, 18), r=6, t=0.55)
    # 锯齿屋顶(工厂式)
    for i in range(3):
        x0 = L + i * 23
        for k in range(10):
            c.hline(x0 + k * 2, x0 + 22, TOP - 1 - k, IRONP[1] if k else IRONP[3])
        c.vline(x0 + 22, TOP - 11, TOP - 1, IRONP[0])
        c.vline(x0 + 21, TOP - 10, TOP - 2, (200, 120, 50))      # 天窗透火光
    c.hline(L - 1, R + 1, TOP - 1, STONE[4])
    # 烟囱
    c.wall(R - 1, 0, R + 8, TOP - 1, BRICK, base=2.6, spread=1.4, scale=5)
    c.bricks(R - 1, 0, R + 8, TOP - 1, BRICK)
    c.hline(R - 2, R + 9, 0, STONE[4]); c.hline(R - 2, R + 9, 1, STONE[2])
    c.wall(R + 1, TOP, R + 8, H - 1, BRICK, base=1.6, spread=1.2, scale=5)
    c.bricks(R + 1, TOP, R + 8, H - 1, BRICK)
    # 高拱窗(火光)
    for wx in (8, 26, 44):
        for y in range(30, 56):
            for x in range(wx, wx + 10):
                if y < 35 and (x - (wx + 4.5)) ** 2 + ((y - 35) * 1.3) ** 2 > 22:
                    continue
                t = (y - 30) / 26
                col = mix(FIRE[2], FIRE[1], t) if (x - wx) % 3 else WOOD_D
                if (y - 30) % 6 == 5:
                    col = WOOD_D
                c.set(x, y, col)
        c.hline(wx - 1, wx + 10, 56, STONE[4])
    c.ledge(L, R, 60, light=STONE[5])
    c.drips(L, R, 63, 10, maxlen=9, color=(30, 22, 18))
    # 炉口(拱形铁门敞开,里面火)
    fx0, fx1, ftop = 20, 44, 72
    cx = (fx0 + fx1) / 2
    for y in range(ftop, H):
        for x in range(fx0, fx1 + 1):
            if y < ftop + 6 and (x - cx) ** 2 + ((y - (ftop + 6)) * 2) ** 2 > ((fx1 - fx0) / 2) ** 2:
                continue
            t = (y - ftop) / (H - ftop)
            d = abs(x - cx) / ((fx1 - fx0) / 2)
            col = mix(FIRE[3], FIRE[1], min(1, d * 0.8 + (1 - t) * 0.4))
            c.set(x, y, col)
    for y in range(ftop + 8, H, 3):          # 炉栅
        c.hline(fx0 + 2, fx1 - 2, y, FIRE[0])
    for a in range(0, 181, 6):               # 铁拱圈
        rad = math.radians(a)
        c.set(int(round(cx + math.cos(rad) * 13)), int(round(ftop + 6 - math.sin(rad) * 7)), IRONP[3])
        c.set(int(round(cx + math.cos(rad) * 14)), int(round(ftop + 6 - math.sin(rad) * 7.5)), IRONP[1])
    c.rect(fx0 - 6, ftop + 4, fx0 - 2, H - 1, IRONP[1]); c.vline(fx0 - 6, ftop + 4, H - 1, IRONP[3])  # 打开的炉门
    for y in range(ftop + 6, H - 1, 4):
        c.set(fx0 - 4, y, IRON_D)
    # 墙上的管子、表、阀
    hpipe(c, 46, R, 66, d=4, ramp=VERDI, flange=10)
    vpipe(c, 54, 66, H - 1, d=4, ramp=VERDI)
    into_wall(c, 45, 66, 4, VERDI)                      # 左头:从墙里出来
    flange_end(c, R, 66, 4, VERDI, +1)                  # 右头:顶进烟囱柱
    elbow(c, 54, 66, 4, 4, VERDI)                       # 三通
    base_plate(c, 54, H - 1, 4)
    gauge(c, 62, 76); valve(c, 60, 88, 3)
    c.grime_bottom(L, R, H - 1, 8, k=0.5)
    for y in range(TOP, H):
        c.darken(R, y, 0.6)
    fire_spots = [(cx, ftop + 14), (13, 44), (49, 44)]
    return c, fire_spots


# ------------------------------------------------------------
# 管道楼:水泥楼正面爬满竖管横管,阀门、压力表,外挂铁梯
# ------------------------------------------------------------
def pipe_house(seed=202):
    W, H = 62, 96
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 59, 10
    c.wall(L, TOP, R, H - 1, CONCRETE, base=2.7, spread=2.6, scale=9)
    c.stains(L, TOP, R, H - 1, 18, (40, 34, 24), r=5, t=0.5)
    c.hline(L - 1, R + 1, TOP - 1, CONCRETE[5]); c.hline(L - 1, R + 1, TOP, CONCRETE[1])
    c.rect(40, 0, 54, TOP - 2, IRONP[1]); c.hline(40, 54, 0, IRONP[3])        # 屋顶风机房
    for x in range(42, 53, 2):
        c.vline(x, 2, TOP - 3, IRONP[0])
    for y in (34, 58):
        c.ledge(L, R, y, light=CONCRETE[5])
    for (x, y, lit) in [(8, 16, True), (24, 16, False), (8, 40, False), (24, 40, True), (8, 64, True)]:
        c.window(x, y, 6, 9, lit=lit)
    # 竖管三根 + 横管两根 + 阀门表
    # 铜管:从地里上来,一直爬到屋顶,拐弯钻进风机房
    vpipe(c, 34, 4, H - 1, d=5, ramp=COPPER)
    hpipe(c, 34, 40, 2, d=5, ramp=COPPER, flange=99, rust=False)
    elbow(c, 34, 2, 5, 5, COPPER)
    flange_end(c, 40, 2, 5, COPPER, +1)
    base_plate(c, 34, H - 1, 5)
    # 铁管:风机房底下出来,直下到地
    vpipe(c, 49, TOP - 1, H - 1, d=4, ramp=IRONP)
    c.hline(48, 54, TOP - 1, IRONP[0]); c.hline(48, 54, TOP, IRONP[3])
    base_plate(c, 49, H - 1, 4)
    # 绿管:从两扇窗中间的墙里出来,横走,拐弯往下落地
    vpipe(c, 43, 29, H - 1, d=3, ramp=VERDI)
    hpipe(c, 16, 45, 26, d=4, ramp=VERDI, flange=12)
    into_wall(c, 15, 26, 4, VERDI)
    elbow(c, 43, 26, 4, 3, VERDI)
    base_plate(c, 43, H - 1, 3)
    # 铜横管:从铜竖管分出来(三通),往右走到墙角拐过去
    hpipe(c, 34, R + 1, 74, d=5, ramp=COPPER, flange=12)
    elbow(c, 34, 74, 5, 5, COPPER)
    valve(c, 36, 52, 3); valve(c, 44, 86, 2, (60, 120, 100)); gauge(c, 55, 44); gauge(c, 22, 82)
    c.door(10, H - 14, 8, 14, color=IRONP[1], knob=True, step=False)
    c.grime_bottom(L, R, H - 1, 10, k=0.45)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8)
    vents = [(36, 52), (56, 74)]
    return c, vents


# ------------------------------------------------------------
# 横穿巷子的管桥:两根粗管叠着,下面铁支架落地。顶面可站。
# ------------------------------------------------------------
def pipe_bridge(W=96, top=0, H=None, seed=203, ramp=COPPER, second=True):
    H = H or 60
    c = Canvas(W, H, seed)
    # 支架
    for lx in (6, W - 10):
        for y in range(top + 6, H):
            c.set(lx, y, IRONP[3]); c.set(lx + 1, y, IRONP[2]); c.set(lx + 2, y, IRONP[1]); c.set(lx + 3, y, IRONP[0])
            if (y - top) % 9 == 0:
                c.hline(lx - 1, lx + 4, y, IRONP[1])
        c.rect(lx - 2, H - 2, lx + 5, H - 1, STONE[3])
        for i in range(8):     # 斜撑
            c.set(lx + 4 + i, top + 8 + i, IRONP[1]) if lx < W // 2 else c.set(lx - 1 - i, top + 8 + i, IRONP[1])
    hpipe(c, 0, W - 1, top, d=7, ramp=ramp, flange=16)
    flange_end(c, 0, top, 7, ramp, -1); flange_end(c, W - 1, top, 7, ramp, +1)
    if second:
        hpipe(c, 0, W - 1, top + 9, d=4, ramp=VERDI, flange=12)
        flange_end(c, 0, top + 9, 4, VERDI, -1); flange_end(c, W - 1, top + 9, 4, VERDI, +1)
    return c


# ------------------------------------------------------------
# 水塔:铆钉铁罐 + 四条腿 + 顶上检修口(罐顶可站)
# ------------------------------------------------------------
def water_tank(seed=204):
    W, H = 40, 64
    c = Canvas(W, H, seed)
    TY0, TY1 = 4, 30
    for x in range(2, W - 2):
        t = (x - 2) / (W - 5)
        k = 0.7 + 0.6 * math.sin(math.pi * t)
        for y in range(TY0, TY1):
            c.set(x, y, shade(IRONP[2], k))
        if (x - 2) % 6 == 0:
            for y in range(TY0, TY1, 3):
                c.set(x, y, shade(IRONP[3], k))
    for y in (TY0 + 8, TY0 + 17):
        for x in range(2, W - 2):
            c.set(x, y, shade(IRONP[1], 0.9))
    for x in range(1, W - 1):                 # 锥顶
        c.set(x, TY0 - 1, IRONP[3])
    for i in range(3):
        c.hline(4 + i * 3, W - 5 - i * 3, TY0 - 2 - i, IRONP[2] if i else IRONP[3])
    c.rect(W // 2 - 2, 0, W // 2 + 1, 1, IRONP[1])
    c.mottle(2, TY0, W - 3, TY1, amt=0.16, scale=4, accent=RUST[1], accent_amt=0.4)
    c.stains(2, TY0, W - 3, TY1, 10, RUST[1], r=4, t=0.6)
    c.drips(2, W - 3, TY1, 10, maxlen=12, color=RUST[1])
    for lx in (5, 14, 24, W - 8):           # 腿
        c.vline(lx, TY1, H - 1, IRONP[2]); c.vline(lx + 1, TY1, H - 1, IRONP[0])
    for y in range(TY1 + 4, H - 4, 10):
        for i in range(9):
            c.set(5 + i, y + i // 2, IRONP[1]); c.set(W - 8 - i, y + i // 2, IRONP[1])
    for y in range(TY0 + 2, H):               # 爬梯
        c.set(W - 3, y, IRON_L) if y > TY1 else None
        if y % 3 == 0 and y > TY1:
            c.hline(W - 5, W - 3, y, IRON_L)
    return c


# ------------------------------------------------------------
# 铁格栅走道(带栏杆,下有支腿)。顶面 y=4。
# ------------------------------------------------------------
def catwalk(W=64, H=40, seed=205):
    c = Canvas(W, H, seed)
    c.railing(0, W - 1, 4, h=4, top=IRONP[3], post_a=IRONP[3], post_b=IRONP[1], base=IRONP[2])
    for x in range(0, W):
        c.set(x, 5, IRONP[1] if x % 2 else IRONP[0])
        c.set(x, 6, IRONP[0])
    for lx in (3, W - 5):
        c.vline(lx, 7, H - 1, IRONP[2]); c.vline(lx + 1, 7, H - 1, IRONP[0])
    for i in range(10):
        c.set(5 + i, 7 + i, IRONP[1]); c.set(W - 6 - i, 7 + i, IRONP[1])
    return c


# ------------------------------------------------------------
# 尽头:卧式大锅炉(铆钉筒体 + 火箱 + 表盘一排 + 往上走的粗管)
# ------------------------------------------------------------
def big_boiler(seed=206):
    W, H = 80, 96
    c = Canvas(W, H, seed)
    # 后墙(暗砖)
    c.wall(0, 0, W - 1, H - 1, BRICK, base=1.6, spread=1.2, scale=8)
    c.bricks(0, 0, W - 1, H - 1, BRICK)
    for y in range(H):
        for x in range(W):
            c.darken(x, y, 0.6)
    # 筒体:横放圆柱 y 40..76
    BY0, BY1 = 40, 76
    for y in range(BY0, BY1):
        t = (y - BY0) / (BY1 - BY0 - 1)
        k = 0.65 + 0.7 * math.sin(math.pi * t) * (1.1 - 0.3 * t)
        for x in range(4, W - 4):
            c.set(x, y, shade(IRONP[2], k))
    for x in range(10, W - 6, 12):            # 环向铆钉缝
        for y in range(BY0, BY1, 2):
            c.set(x, y, shade(IRONP[3], 1.1))
    c.mottle(4, BY0, W - 5, BY1, amt=0.16, scale=5, accent=RUST[1], accent_amt=0.4)
    c.stains(4, BY0, W - 5, BY1, 16, RUST[1], r=5, t=0.6)
    c.drips(4, W - 5, BY1, 14, maxlen=10, color=RUST[1])
    # 火箱(下半截发红)
    for y in range(BY1, H):
        c.hline(14, W - 14, y, IRONP[1])
    for x in range(26, 54):
        for y in range(82, H - 2):
            c.set(x, y, mix(FIRE[2], FIRE[0], abs(x - 40) / 14))
    for x in range(27, 54, 3):
        c.vline(x, 82, H - 3, FIRE[0])
    # 表盘一排 + 阀
    for gx in (16, 28, 40, 52, 64):
        gauge(c, gx, BY0 + 6)
    valve(c, 22, BY0 + 22, 3); valve(c, 58, BY0 + 22, 3, (60, 120, 100))
    # 上走的粗管(到画外)
    vpipe(c, 12, 0, BY0, d=7, ramp=COPPER)
    vpipe(c, 58, 0, BY0, d=5, ramp=VERDI)
    hpipe(c, 0, 12, 16, d=5, ramp=COPPER)
    elbow(c, 12, 16, 5, 7, COPPER)
    flange_end(c, 0, 16, 5, COPPER, -1)
    # 筒顶可站(检修台)
    c.railing(20, 50, BY0 - 1, h=4, top=IRONP[3], post_a=IRONP[3], post_b=IRONP[1], base=IRONP[2])
    return c, (40, 88), BY0 - 1


# ------------------------------------------------------------
# 入口:砖门房 + 铆钉大铁门(一扇开一道缝)+ 门顶横管 + 红警示灯
# ------------------------------------------------------------
def boiler_gate(seed=207):
    W, H = 56, 64
    c = Canvas(W, H, seed)
    c.wall(0, 12, W - 1, H - 1, BRICK, base=2.6, spread=1.4, scale=7)
    c.bricks(0, 12, W - 1, H - 1, BRICK)
    c.stains(0, 12, W - 1, H - 1, 12, (30, 22, 18), r=5, t=0.5)
    c.hline(0, W - 1, 12, STONE[5]); c.hline(0, W - 1, 13, STONE[3])
    vpipe(c, 2, 6, H - 1, d=5, ramp=COPPER)
    hpipe(c, 2, W - 8, 4, d=6, ramp=COPPER, flange=12)
    vpipe(c, W - 9, 6, 12, d=5, ramp=COPPER, flange=99)
    elbow(c, 2, 4, 6, 5, COPPER)
    elbow(c, W - 9, 4, 6, 5, COPPER)
    c.hline(W - 11, W - 3, 12, COPPER[0]); c.hline(W - 11, W - 3, 11, COPPER[3])   # 插进门房顶的法兰
    base_plate(c, 2, H - 1, 5)
    # 门洞
    DX0, DX1, DY = 12, 45, 24
    c.rect(DX0 - 2, DY - 2, DX1 + 2, H - 1, STONE[3]); c.hline(DX0 - 2, DX1 + 2, DY - 2, STONE[5])
    for y in range(DY, H):                     # 门缝里的光
        c.hline(DX0, DX1, y, mix((200, 120, 60), (90, 50, 26), (y - DY) / (H - DY)))
    for (x0, x1) in ((DX0, 26), (31, DX1)):    # 两扇门,中间留缝
        for y in range(DY, H):
            for x in range(x0, x1 + 1):
                c.set(x, y, IRONP[2] if (x - x0) % 4 else IRONP[1])
            if (y - DY) % 8 == 0:
                c.hline(x0, x1, y, IRONP[3])
        for y in range(DY + 2, H - 1, 4):
            c.set(x0 + 1, y, IRON_L); c.set(x1 - 1, y, IRON_L)
        c.mottle(x0, DY, x1, H - 1, amt=0.14, scale=3, accent=RUST[1], accent_amt=0.35)
        c.stains(x0, DY, x1, H - 1, 6, RUST[1], r=3, t=0.6)
    # 红警示灯 + 一块空铁牌
    c.rect(26, 16, 31, 19, (40, 40, 40)); c.hline(27, 30, 17, (220, 60, 40)); c.hline(27, 30, 18, (160, 40, 30))
    c.rect(36, 15, 50, 21, IRONP[1]); c.rect(37, 16, 49, 20, (170, 140, 60))
    for x in range(38, 49, 3):
        c.set(x, 18, (60, 50, 30))
    c.grime_bottom(0, W - 1, H - 1, 8, k=0.5)
    return c, (28, 18)


# ------------------------------------------------------------
# 远景:厂房锯齿顶、烟囱、发红的窗
# ------------------------------------------------------------
def boiler_back(W=320, H=90, seed=208):
    c = Canvas(W, H, seed)
    rng = c.rng
    x = 0
    while x < W:
        bw = rng.randint(40, 70)
        top = rng.randint(24, 46)
        x1 = min(W - 1, x + bw)
        c.wall(x, top, x1, H - 1, rng.choice([BRICK, CONCRETE, IRONP + [IRONP[3], IRONP[3]]]), base=2.0, spread=1.4, scale=8)
        for k in range(0, bw, 12):              # 锯齿顶
            for i in range(6):
                c.hline(x + k + i, x + k + 11, top - 1 - i, IRONP[1])
        for wy in range(top + 6, H - 10, 12):
            for wx in range(x + 4, x1 - 6, 9):
                if rng.random() < 0.3:
                    c.rect(wx, wy, wx + 2, wy + 3, shade(mix(FIRE[2], FIRE[1], rng.random()), 0.7))
                else:
                    c.rect(wx, wy, wx + 2, wy + 3, (30, 26, 24))
        if rng.random() < 0.7:                  # 烟囱
            cx = x + rng.randint(4, bw - 8)
            ctop = rng.randint(0, 12)
            c.rect(cx, ctop, cx + 4, top, BRICK[1])
            c.hline(cx - 1, cx + 5, ctop, STONE[3])
        if rng.random() < 0.6:                  # 管子横过去
            py = rng.randint(top + 4, H - 20)
            hpipe(c, x, x1, py, d=3, ramp=IRONP, flange=10, rust=False)
        x = x1 + rng.randint(0, 6)
    for yy in range(H):
        for xx in range(W):
            p = c.get(xx, yy)
            if p[3] and not (p[0] > 180 and p[1] < 170):
                c.px[xx, yy] = rgba(mix(shade(p, 0.5), (34, 28, 26), 0.3))
    return c


def front_pipe(W=1100, d=8, seed=209):
    c = Canvas(W, d + 6, seed)
    hpipe(c, 0, W - 1, 3, d=d, ramp=IRONP, flange=24, rust=False)
    for x in range(20, W, 60):      # 吊卡
        c.vline(x, 0, 3, IRON_D)
    return c


def front_vpipe(H=116, d=7, seed=210):
    c = Canvas(d + 2, H, seed)
    vpipe(c, 1, 0, H - 1, d=d, ramp=IRONP, flange=20)
    return c
