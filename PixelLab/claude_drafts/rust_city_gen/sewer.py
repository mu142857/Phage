# 下水道(管道局的地盘)素材:拱顶 + 潮湿石墙一跨一跨的拱龛 + 沿墙走的铜管(两头都有去处)+ 墙根水线
# + 人走的石沿 + 下面一条水渠。管道局的东西:检查站铁栅门、办公桌、价目牌、藏青局旗、黄铜笼灯、码得整整齐齐的箱子。
import math
from pxlib import *
from boiler import hpipe, vpipe, fitting, elbow, into_wall, flange_end, base_plate, valve, gauge, IRONP

SEW = [(20, 24, 22), (29, 34, 31), (39, 45, 40), (51, 57, 50), (64, 69, 59), (80, 83, 70)]
SEW_DEEP = [(12, 14, 14), (17, 20, 19), (23, 27, 25), (30, 34, 31), (38, 42, 38), (46, 50, 44)]
VAULT = [(26, 20, 17), (38, 28, 22), (52, 37, 28), (66, 48, 36), (82, 62, 46), (98, 76, 56)]
MOSS = [(36, 50, 30), (52, 70, 40), (74, 92, 52)]
WATER = [(10, 18, 20), (16, 28, 30), (24, 40, 42), (40, 62, 60), (70, 96, 88)]
NAVY = [(16, 20, 32), (26, 34, 54), (40, 54, 84), (60, 78, 116)]
BRASS_R = [(74, 50, 22), (122, 84, 34), (166, 115, 48), (204, 154, 66), (235, 200, 106)]
BRASSP = [(74, 50, 22), (122, 84, 34), (166, 115, 48), (210, 162, 74)]   # 管子用 4 阶
DARK = (8, 9, 10)

GROUND_Y = 80     # 世界地面;墙图高 90,图里第 80 行 = 地面


def _course_lines(c, x0, y0, x1, y1, every=5, k=0.9, p=0.5):
    """石墙的层线:很淡、断断续续(用户的墙几乎不画缝)"""
    for y in range(y0 + every - 1, y1, every):
        for x in range(x0, x1 + 1):
            if c.rng.random() < p:
                c.darken(x, y, k)


def _arch_ring(c, cx, top, r, thick, ramp, inner_dark=None):
    """半圆拱圈:拱石一块块明暗交替(不描黑缝),里面压暗成拱龛"""
    for y in range(top, top + r + 1):
        for x in range(cx - r - thick, cx + r + thick + 1):
            dx, dy = x - cx, (top + r) - y
            d = math.hypot(dx, dy)
            if r <= d < r + thick and dy >= 0:
                ang = math.degrees(math.atan2(dy, dx))
                block = int(ang // 14)
                base = ramp[3] if block % 2 else ramp[2]
                if d > r + thick - 1.2:
                    base = ramp[4] if dy > r * 0.4 else ramp[3]
                c.set(x, y, base)


def _bay_dark(c, cx, top, r, bottom, ramp):
    """拱龛里:比墙深一截的暗面(上沿拱形)"""
    for y in range(top, bottom + 1):
        for x in range(cx - r + 1, cx + r):
            dx = x - cx
            if y < top + r:
                dy = (top + r) - y
                if dx * dx + dy * dy >= (r - 0.5) ** 2:
                    continue
            p = c.get(x, y)
            if p[3]:
                c.px[x, y] = rgba(mix(shade(p, 0.55), SEW_DEEP[1], 0.35))


def tunnel_wall(W, seed=601, bays=None, pipe_y=(15, 26), H=90):
    """一整面墙:顶上拱顶带 + 墙面 + 一跨一跨的拱龛 + 两根沿墙铜管。
    bays = [(中心x, 半径, 种类)],种类:plain / tunnel(黑洞,通别的渠)/ outlet(出水口铁栅,墙上一道水痕)"""
    c = Canvas(W, H, seed)
    rng = c.rng
    # 墙面
    c.wall(0, 0, W - 1, GROUND_Y - 1, SEW, base=2.6, spread=1.5, scale=9,
           accents=[((60, 44, 30), 0.35), (MOSS[1], 0.35), ((92, 94, 82), 0.18)])
    _course_lines(c, 0, 12, W - 1, GROUND_Y - 2, every=6, k=0.92, p=0.35)
    # 拱顶带(砖拱,暖一点的褐)
    c.wall(0, 0, W - 1, 10, VAULT, base=2.0, spread=1.2, scale=7, accents=[((40, 30, 24), 0.4)])
    c.bricks(0, 0, W - 1, 10, VAULT, bw=5, bh=2)
    c.hline(0, W - 1, 10, VAULT[4])            # 拱脚湿亮的一道
    c.hline(0, W - 1, 11, VAULT[1])
    for x in range(W):                         # 拱顶往下渗的黑
        if rng.random() < 0.3:
            c.darken(x, 12, 0.7)
    # 拱龛
    bays = bays or []
    for cx, r, kind in bays:
        top = 18
        bottom = GROUND_Y - 1
        _bay_dark(c, cx, top, r, bottom, SEW)
        _arch_ring(c, cx, top - 2, r + 1, 3, SEW)
        # 龛两边的墩子:亮一点的竖条 + 墩帽
        for side in (-1, 1):
            px0 = cx + side * (r + 2) - (3 if side < 0 else 0)
            for y in range(top + r, bottom + 1):
                for x in range(px0, px0 + 4):
                    c.tint(x, y, SEW[4], 0.35)
            c.hline(px0 - 1, px0 + 4, top + r, SEW[5])
            c.hline(px0 - 1, px0 + 4, top + r + 1, SEW[2])
        if kind == "tunnel":
            for y in range(top + 4, bottom + 1):
                for x in range(cx - r + 4, cx + r - 3):
                    dx, dy = x - cx, (top + r) - y
                    if y < top + r and dx * dx + dy * dy >= (r - 4) ** 2:
                        continue
                    t = (y - top) / (bottom - top)
                    c.set(x, y, mix(DARK, SEW_DEEP[2], 0.15 + 0.25 * t * (rng.random() * 0.4 + 0.6)))
            # 远处一点点光(水面反光)
            for x in range(cx - r + 7, cx + r - 6):
                if rng.random() < 0.5:
                    c.set(x, bottom - 1, WATER[2])
            c.hline(cx - 3, cx + 3, bottom - 2, WATER[3])
        elif kind == "outlet":
            oy = top + r + 10
            ow = min(r - 3, 9)
            c.rect(cx - ow, oy, cx + ow, oy + 9, DARK)
            for x in range(cx - ow, cx + ow + 1, 2):
                c.vline(x, oy, oy + 9, IRONP[1])
            c.hline(cx - ow - 1, cx + ow + 1, oy - 1, IRONP[3]); c.hline(cx - ow - 1, cx + ow + 1, oy + 10, IRONP[0])
            for y in range(oy + 11, bottom + 1):          # 水痕往下流
                for x in range(cx - 3, cx + 4):
                    if rng.random() < 0.7:
                        c.tint(x, y, MOSS[0] if abs(x - cx) > 1 else WATER[3], 0.5)
    # 青苔:墙根和拱脚
    for x in range(W):
        h = int(2 + 3 * (0.5 + 0.5 * math.sin(x * 0.11 + seed)) * rng.random())
        for y in range(GROUND_Y - h, GROUND_Y):
            c.tint(x, y, MOSS[1], 0.45)
        if rng.random() < 0.18:
            for y in range(12, 12 + rng.randint(1, 4)):
                c.tint(x, y, MOSS[0], 0.5)
    c.grime_bottom(0, W - 1, GROUND_Y - 1, 10, k=0.6)
    c.drips(0, W - 1, 12, W // 14, maxlen=9, color=SEW_DEEP[3])
    # 沿墙两根管(管道局的):粗的铜管 + 细的铁管,吊卡钉在墙上;两头长出图外
    py0, py1 = pipe_y
    hpipe(c, 0, W - 1, py0, d=5, ramp=BRASSP, flange=24, rust=False)
    hpipe(c, 0, W - 1, py1, d=3, ramp=IRONP, flange=18, rust=True)
    for x in range(10, W, 48):
        c.vline(x, py0 - 3, py0 - 1, IRON_D); c.vline(x + 1, py0 - 3, py0 - 1, IRONP[2])
        c.vline(x + 6, py1 - 2, py1 - 1, IRON_D)
    # 管下的水渍
    for x in range(0, W, 3):
        if rng.random() < 0.25:
            for y in range(py0 + 5, py0 + 5 + rng.randint(2, 7)):
                c.tint(x, y, SEW_DEEP[2], 0.5)
    return c


def branch(c, x, from_y, to_y, kind="valve", d=3, ramp=None):
    """从粗管往下分一根支管:顶上一个三通;下头接阀门/压力表后拐进墙,或者落地"""
    ramp = ramp or BRASSP
    vpipe(c, x, from_y + 4, to_y, d=d, ramp=ramp, flange=12)
    fitting(c, x - 2, from_y - 1, d + 4, 7, ramp)
    if kind == "valve":
        valve(c, x + 1, to_y - 6, r=3, col=(60, 78, 116))
        into_wall(c, x, to_y, d, ramp)
    elif kind == "gauge":
        gauge(c, x + d + 3, to_y - 8)
        c.hline(x + d, x + d + 1, to_y - 8, ramp[2])
        into_wall(c, x, to_y, d, ramp)
    elif kind == "floor":
        base_plate(c, x, GROUND_Y - 1, d)


def walkway(W, seed=611, H=10):
    """人走的石沿(顶面 = 图第 0 行 = 世界 y80)+ 下面一条水渠(到屏幕底)"""
    c = Canvas(W, H, seed)
    rng = c.rng
    # 石沿:顶上一道湿亮的边,正面一块块条石(地面可以有缝)
    c.wall(0, 0, W - 1, 4, STONE, base=2.6, spread=1.0, scale=6)
    c.hline(0, W - 1, 0, STONE[5])
    c.hline(0, W - 1, 1, STONE[3])
    x = 0
    while x < W:
        bw = rng.randint(9, 15)
        c.vline(x, 2, 4, STONE[0])
        c.set(x + 1, 2, STONE[4])
        x += bw
    c.hline(0, W - 1, 5, SEW_DEEP[0])
    # 水:暗青,横的波纹亮线,靠近石沿有一道阴影
    for y in range(6, H):
        for xx in range(W):
            c.set(xx, y, WATER[1] if y > 6 else WATER[0])
    for k in range(W // 5):
        y = rng.randint(7, H - 1)
        x0 = rng.randint(0, W - 1)
        ln = rng.randint(2, 6)
        c.hline(x0, x0 + ln, y, WATER[2] if rng.random() < 0.7 else WATER[3])
    return c


def water_glint(W, seed=612, H=4):
    """水面上一层碎亮点(另放一层,用着色器左右晃)"""
    c = Canvas(W, H, seed)
    for k in range(W // 9):
        x = c.rng.randint(0, W - 3)
        y = c.rng.randint(0, H - 1)
        c.hline(x, x + c.rng.randint(1, 3), y, WATER[4] if c.rng.random() < 0.4 else WATER[3])
    return c


# ---------------------------------------------------------------- 管道局的东西
def grate_gate(h=44, seed=621):
    """检查站铁栅门:黄铜框 + 一排黑铁栅 + 顶上一块藏青牌(铜管局徽)。门往上收进拱顶。"""
    w = 14
    c = Canvas(w, h, seed)
    for x in range(1, w - 1, 3):
        c.vline(x, 6, h - 1, IRONP[2]); c.vline(x + 1, 6, h - 1, IRONP[1])
    for y in (14, 28, h - 4):
        c.hline(0, w - 1, y, BRASS_R[2]); c.hline(0, w - 1, y + 1, BRASS_R[0])
    c.vline(0, 0, h - 1, BRASS_R[3]); c.vline(w - 1, 0, h - 1, BRASS_R[1])
    c.rect(0, 0, w - 1, 6, NAVY[1])
    c.hline(0, w - 1, 0, BRASS_R[4]); c.hline(0, w - 1, 6, BRASS_R[1])
    emblem(c, w // 2 - 1, 1, BRASS_R)
    for x in range(1, w - 1, 3):                # 栅脚尖头
        c.set(x, h - 1, IRONP[3])
    return c


def emblem(c, x, y, ramp):
    """局徽:一节竖管,上下两个阀门盘(4 宽 5 高)"""
    c.hline(x - 1, x + 2, y, ramp[3]); c.hline(x - 1, x + 2, y + 4, ramp[2])
    c.vline(x, y + 1, y + 3, ramp[3]); c.vline(x + 1, y + 1, y + 3, ramp[1])


def desk(seed=622):
    """收费台:藏青木台面包铜边,台上一摞账本、印泥盒、一盏小台灯"""
    W, H = 22, 16
    c = Canvas(W, H, seed)
    c.rect(1, 8, W - 2, H - 1, NAVY[1])
    c.hline(0, W - 1, 7, BRASS_R[3]); c.hline(0, W - 1, 8, BRASS_R[1])
    c.vline(1, 9, H - 1, BRASS_R[2]); c.vline(W - 2, 9, H - 1, BRASS_R[0])
    c.rect(3, 10, W - 4, 13, NAVY[0])          # 抽屉
    for x in (7, 14):
        c.set(x, 11, BRASS_R[3])
    emblem(c, W // 2 - 1, 10, BRASS_R)
    # 账本
    for i, col in enumerate([(92, 40, 30), (40, 60, 52), (110, 92, 60), (60, 42, 64)]):
        c.hline(3, 9, 6 - i, col); c.set(9, 6 - i, CREAM)
    # 印泥盒 + 印章
    c.rect(12, 5, 14, 6, NAVY[2]); c.set(13, 4, BRASS_R[3]); c.set(13, 3, BRASS_R[2])
    # 台灯
    c.vline(18, 2, 6, BRASS_R[1]); c.hline(16, 20, 1, BRASS_R[3]); c.hline(17, 19, 0, BRASS_R[4])
    c.set(18, 2, LIT[2])
    return c


DIGITS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}


def price_board(fee, seed=623):
    """价目牌:藏青牌子铜边,一枚铜板 × 数字(看得懂:过这儿要这么多钱)"""
    s = str(fee)
    W = 12 + 4 * len(s) + 2
    H = 11
    c = Canvas(W, H + 6, seed)
    c.rect(0, 0, W - 1, H - 1, NAVY[1])
    c.hline(0, W - 1, 0, BRASS_R[3]); c.hline(0, W - 1, H - 1, BRASS_R[0])
    c.vline(0, 0, H - 1, BRASS_R[2]); c.vline(W - 1, 0, H - 1, BRASS_R[1])
    # 铜板
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx * dx + dy * dy <= 5:
                c.set(4 + dx, 5 + dy, BRASS_R[3] if dx + dy < 0 else BRASS_R[2])
    c.set(4, 5, BRASS_R[0])
    # ×
    c.set(8, 4, CREAM); c.set(10, 6, CREAM); c.set(9, 5, CREAM); c.set(8, 6, CREAM); c.set(10, 4, CREAM)
    for i, ch in enumerate(s):
        for y, row in enumerate(DIGITS[ch]):
            for x, b in enumerate(row):
                if b == "1":
                    c.set(12 + i * 4 + x, 3 + y, CREAM)
    # 两根吊链
    for x in (2, W - 3):
        for y in range(H, H + 6, 2):
            c.set(x, y, IRONP[2])
    im = c.im.transpose(0)  # 占位(不翻)
    return c


def banner(seed=624, h=26):
    """藏青局旗:从管子上垂下来,铜边,中间铜色局徽,下摆剪成燕尾"""
    W = 10
    c = Canvas(W, h, seed)
    c.hline(0, W - 1, 0, BRASS_R[2]); c.hline(0, W - 1, 1, BRASS_R[0])
    for y in range(2, h):
        for x in range(1, W - 1):
            if y > h - 4 and abs(x - (W - 1) / 2) < (y - (h - 4)) + 0.5:
                continue
            col = NAVY[2] if x < 3 else NAVY[1]
            if x == W - 2:
                col = NAVY[0]
            c.set(x, y, col)
        if y < h - 3:
            c.set(1, y, BRASS_R[1]); c.set(W - 2, y, BRASS_R[0])
    emblem(c, W // 2 - 1, 8, BRASS_R)
    return c


def cage_lamp(seed=625, chain=10):
    """黄铜笼灯:一截吊链 + 笼子 + 里面的灯泡(亮的那几格画暖色,点灯用 PointLight)"""
    W, H = 7, chain + 9
    c = Canvas(W, H, seed)
    for y in range(0, chain, 2):
        c.set(3, y, IRONP[2]); c.set(3, y + 1, IRONP[1])
    y0 = chain
    c.hline(1, 5, y0, BRASS_R[3]); c.hline(2, 4, y0 - 1, BRASS_R[2])
    for y in range(y0 + 1, y0 + 7):
        c.set(1, y, BRASS_R[2]); c.set(5, y, BRASS_R[1])
        for x in range(2, 5):
            c.set(x, y, LIT[1] if 2 <= y - y0 <= 5 else LIT[0])
        c.set(3, y, LIT[2] if 3 <= y - y0 <= 4 else LIT[1])
    c.hline(1, 5, y0 + 7, BRASS_R[1]); c.set(3, y0 + 8, BRASS_R[0])
    return c


def bureau_crate(seed=626, w=13, h=11):
    """管道局的箱子:深木板 + 铜包角 + 正面一个局徽印"""
    c = Canvas(w, h, seed)
    c.rect(0, 0, w - 1, h - 1, WOOD)
    for y in range(2, h, 3):
        c.hline(0, w - 1, y, WOOD_D)
    c.hline(0, w - 1, 0, WOOD_L)
    c.mottle(0, 0, w - 1, h - 1, amt=0.12)
    for (x, y) in ((0, 0), (w - 2, 0), (0, h - 2), (w - 2, h - 2)):
        c.rect(x, y, x + 1, y + 1, BRASS_R[2])
        c.set(x, y, BRASS_R[3])
    emblem(c, w // 2 - 1, 3, [NAVY[0], NAVY[1], NAVY[2], NAVY[3]])
    return c


def ladder(h, seed=627):
    """铁梯子(5 宽)"""
    c = Canvas(5, h, seed)
    c.vline(0, 0, h - 1, IRONP[2]); c.vline(4, 0, h - 1, IRONP[1])
    for y in range(2, h, 4):
        c.hline(0, 4, y, IRONP[3]); c.hline(1, 3, y + 1, IRONP[0])
    for y in range(h):
        if c.rng.random() < 0.15:
            c.tint(0, y, RUST[1], 0.5)
    return c


def manhole_shaft(seed=628, w=16):
    """拱顶上的井口:一圈石沿 + 里面黑(或者一点天光)"""
    c = Canvas(w, 12, seed)
    c.rect(2, 0, w - 3, 9, DARK)
    for y in range(0, 10):
        c.set(1, y, VAULT[3]); c.set(w - 2, y, VAULT[1])
    c.hline(0, w - 1, 10, VAULT[4]); c.hline(0, w - 1, 11, VAULT[1])
    return c


def light_shaft(h=60, w=12, seed=629):
    """井口漏下来的一道光(半透明,放在最前面别挡人)"""
    c = Canvas(w, h, seed)
    for y in range(h):
        a = int(70 * (1 - y / h) ** 1.5)
        for x in range(w):
            edge = min(x, w - 1 - x)
            if edge < 2:
                aa = a // 3
            else:
                aa = a
            if aa > 0:
                c.set(x, y, (200, 190, 160), aa)
    return c


def gang_breach(seed=631):
    """奥斯卡帮砸开的墙洞:一圈碎砖 + 黑洞 + 洞边喷的红围巾结"""
    W, H = 30, 34
    c = Canvas(W, H, seed)
    rng = c.rng
    cx, cy = 15, 17
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - cx) / 13.5, (y - cy) / 15.5) + (rng.random() - 0.5) * 0.18
            if d < 0.78:
                c.set(x, y, DARK)
            elif d < 1.0:
                c.set(x, y, SEW[rng.randint(2, 4)] if rng.random() < 0.8 else VAULT[3])
    # 地上碎砖
    for k in range(14):
        x = rng.randint(2, W - 3)
        y = H - 1 - rng.randint(0, 3)
        c.set(x, y, SEW[rng.randint(2, 5)])
    return c


def gang_tag(seed=632):
    """红围巾结喷漆(奥斯卡帮记号)"""
    from backalley import _tag_scarf
    c = Canvas(16, 14, seed)
    _tag_scarf(c, 8, 7, 1.0)
    return c


def front_chains(W=900, seed=641):
    """最前面一层:拱顶垂下来的铁链和一截管子剪影"""
    c = Canvas(W, 24, seed)
    rng = c.rng
    x = 10
    while x < W:
        L = rng.randint(8, 22)
        for y in range(0, L, 2):
            c.set(x, y, (40, 40, 40)); c.set(x, y + 1, (30, 30, 30))
        if rng.random() < 0.4:
            c.rect(x - 2, L, x + 2, L + 2, (36, 36, 36))
        x += rng.randint(50, 110)
    return c
