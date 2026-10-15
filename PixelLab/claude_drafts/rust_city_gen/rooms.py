# 铁锈城室内素材:整屋外壳(墙/护墙板/地板/天花梁/门洞/夜窗)+ 家具 + 被翻乱的东西 + 分赃窝/仓库的东西。
# 画法照用户的楼:没有硬缝,很多色块叠出来的斑驳;暗处一两处暖光。
import math
from pxlib import *
from props import CLOTH, MOSS

WALLPAPER_GREEN = [(36, 44, 40), (50, 62, 54), (66, 80, 68), (84, 98, 82), (104, 116, 96), (124, 132, 110)]
WALLPAPER_ROSE = [(52, 36, 36), (74, 52, 50), (98, 70, 64), (122, 90, 80), (146, 112, 96), (166, 134, 114)]
WALL_DIRTY = [(40, 36, 30), (56, 50, 42), (74, 66, 54), (94, 84, 68), (114, 102, 82), (134, 120, 96)]
PLANK = [(44, 30, 22), (62, 42, 30), (84, 58, 40), (106, 74, 50), (128, 92, 62), (146, 108, 74)]
CONC_FLOOR = [(34, 34, 32), (48, 47, 44), (62, 60, 55), (78, 75, 68), (94, 90, 80), (110, 104, 92)]
NIGHT = [(14, 18, 30), (24, 30, 46), (40, 48, 66)]
GOLD = [(120, 84, 30), (176, 132, 50), (222, 182, 84), (250, 226, 150)]
FLOOR_Y = 80


# ============================================================
# 整屋外壳
# ============================================================
def room_shell(W, wall=WALLPAPER_GREEN, wain=PLANK, floor="planks", seed=500, ceiling=8,
               doors=(), windows=(), beams=True, wain_top=60, stripes=False, brick=False):
    """doors=[(x, kind)] x=门洞左边;kind: out(通外面,夜色)/room(关着的屋门)/heavy(铁门)/arch(拱形穿堂口)。
    windows=[(x, y, w, h)]。返回 canvas(W×90)。"""
    H = 90
    c = Canvas(W, H, seed)
    rng = c.rng
    # 墙
    c.wall(0, ceiling, W - 1, FLOOR_Y - 1, wall, base=2.7, spread=2.2, scale=9)
    if stripes:   # 旧墙纸的竖条纹:很淡、断断续续
        for x in range(0, W, 6):
            for y in range(ceiling, wain_top):
                if rng.random() < 0.7:
                    c.darken(x, y, 0.9)
    if brick:     # 砖墙:不画缝,只留很淡的横纹(用户的画法)
        c.bricks(0, ceiling, W - 1, FLOOR_Y - 1, wall)
    c.stains(0, ceiling, W - 1, wain_top, int(W / 14), (40, 32, 24), r=6, t=0.4)
    c.drips(0, W - 1, ceiling + 2, int(W / 10), maxlen=14, color=(40, 32, 24))
    # 顶:天花板压暗 + 檐线
    for y in range(0, ceiling):
        for x in range(W):
            c.set(x, y, shade(wall[0], 0.7 + 0.1 * (y / ceiling)))
    c.hline(0, W - 1, ceiling, wall[4]); c.hline(0, W - 1, ceiling + 1, wall[1])
    if beams:   # 木梁截面,一根根
        for bx in range(18, W - 8, 46):
            c.rect(bx, 0, bx + 5, ceiling + 2, PLANK[2]); c.vline(bx, 0, ceiling + 2, PLANK[4]); c.vline(bx + 5, 0, ceiling + 2, PLANK[0])
            c.hline(bx, bx + 5, ceiling + 3, shade(wall[1], 0.7))
    # 护墙板
    if wain:
        c.wall(0, wain_top + 1, W - 1, FLOOR_Y - 4, wain, base=2.3, spread=1.4, scale=6)
        for x in range(10, W, 20):   # 竖分板,淡
            for y in range(wain_top + 2, FLOOR_Y - 4):
                if rng.random() < 0.75:
                    c.darken(x, y, 0.82)
        c.hline(0, W - 1, wain_top, wain[5]); c.hline(0, W - 1, wain_top + 1, wain[3])
        for x in range(W):
            c.darken(x, wain_top + 2, 0.8)
    # 踢脚线
    c.rect(0, FLOOR_Y - 3, W - 1, FLOOR_Y - 1, PLANK[1]); c.hline(0, W - 1, FLOOR_Y - 3, PLANK[3])
    # 地板
    if floor == "planks":
        c.wall(0, FLOOR_Y, W - 1, H - 1, PLANK, base=2.6, spread=1.4, scale=7)
        for y in range(FLOOR_Y + 3, H, 3):     # 板缝:很淡、断续
            for x in range(W):
                if rng.random() < 0.6:
                    c.darken(x, y, 0.86)
        for y in range(FLOOR_Y + 1, H, 3):     # 板头接缝错开
            for x in range(rng.randint(0, 20), W, rng.randint(18, 34)):
                c.darken(x, y, 0.8); c.darken(x, y + 1, 0.8)
    else:
        c.wall(0, FLOOR_Y, W - 1, H - 1, CONC_FLOOR, base=2.5, spread=1.6, scale=6)
        c.stains(0, FLOOR_Y + 2, W - 1, H - 1, int(W / 24), (20, 20, 22), r=5, t=0.5)   # 油渍
    c.hline(0, W - 1, FLOOR_Y, shade(PLANK[5] if floor == "planks" else CONC_FLOOR[5], 1.0))
    # 窗
    for (wx, wy, ww, wh) in windows:
        night_window(c, wx, wy, ww, wh)
    # 门
    for (dx, kind) in doors:
        doorway(c, dx, kind)
    # 两侧墙厚 + 角落压暗
    for y in range(H):
        for x in range(4):
            c.darken(x, y, 0.45 + x * 0.12)
            c.darken(W - 1 - x, y, 0.45 + x * 0.12)
    for y in range(ceiling, ceiling + 10):
        for x in range(W):
            c.darken(x, y, 0.75 + 0.025 * (y - ceiling))
    return c


def doorway(c, x, kind="out", w=11, h=19):
    """门洞,左边 x,下沿在地板线。"""
    y0 = FLOOR_Y - h
    c.rect(x - 2, y0 - 2, x + w + 1, FLOOR_Y - 1, PLANK[1])     # 门框
    c.hline(x - 2, x + w + 1, y0 - 2, PLANK[4]); c.vline(x - 2, y0 - 2, FLOOR_Y - 1, PLANK[3])
    if kind == "out":        # 开着,外面是夜里的街:蓝黑,远处一点暖光
        for y in range(y0, FLOOR_Y):
            t = (y - y0) / h
            c.hline(x, x + w - 1, y, mix(NIGHT[2], NIGHT[0], t))
        c.set(x + 3, y0 + 5, LIT[1]); c.set(x + 7, y0 + 3, (200, 90, 60))
        c.hline(x, x + w - 1, FLOOR_Y - 1, (60, 58, 56))
    elif kind == "arch":     # 拱形穿堂口:里面是更暗的走廊
        cx = x + (w - 1) / 2
        for y in range(y0 - 3, FLOOR_Y):
            for xx in range(x, x + w):
                if y < y0 + 3 and (xx - cx) ** 2 + ((y - (y0 + 3)) * 1.3) ** 2 > (w / 2) ** 2:
                    continue
                c.set(xx, y, mix((26, 22, 20), (12, 11, 10), (y - y0) / h))
    elif kind == "heavy":    # 铁门 + 门闩
        for y in range(y0, FLOOR_Y):
            for xx in range(x, x + w):
                c.set(xx, y, (70, 66, 60) if (xx - x) % 4 else (52, 50, 46))
        c.mottle(x, y0, x + w - 1, FLOOR_Y - 1, amt=0.14, scale=3, accent=RUST[1], accent_amt=0.4)
        for y in range(y0 + 2, FLOOR_Y - 1, 5):
            c.set(x + 1, y, IRON_L); c.set(x + w - 2, y, IRON_L)
        c.rect(x - 3, y0 + 8, x + w + 2, y0 + 9, IRON_D); c.hline(x - 3, x + w + 2, y0 + 8, IRON_L)   # 门闩
    else:                    # room:关着的屋门 + 门牌
        c.rect(x, y0, x + w - 1, FLOOR_Y - 1, (78, 52, 38))
        c.mottle(x, y0, x + w - 1, FLOOR_Y - 1, amt=0.12, scale=3, accent=(50, 34, 26), accent_amt=0.3)
        c.rect(x + 2, y0 + 2, x + w - 3, y0 + 7, (66, 44, 32)); c.rect(x + 2, y0 + 10, x + w - 3, FLOOR_Y - 3, (66, 44, 32))
        c.set(x + w - 3, y0 + h // 2 + 1, BRASS)
        c.rect(x + w // 2 - 1, y0 - 5, x + w // 2 + 1, y0 - 4, BRASS)    # 门牌(空)


def night_window(c, x, y, w, h, curtain=None):
    for yy in range(y, y + h):
        c.hline(x, x + w - 1, yy, mix(NIGHT[1], NIGHT[0], (yy - y) / h))
    rng = c.rng
    for _ in range(max(1, w * h // 18)):    # 远处的亮窗
        c.set(rng.randint(x + 1, x + w - 2), rng.randint(y + h // 3, y + h - 2), shade(LIT[1], 0.7))
    c.vline(x + w // 2, y, y + h - 1, WOOD); c.hline(x, x + w - 1, y + h // 2, WOOD)
    c.rect(x - 1, y - 1, x + w, y - 1, WOOD_L); c.vline(x - 1, y, y + h, WOOD); c.vline(x + w, y, y + h, WOOD_D)
    c.hline(x - 2, x + w + 1, y + h, CREAM); c.hline(x - 2, x + w + 1, y + h + 1, shade(CREAM, 0.55))
    if curtain:
        for yy in range(y - 1, y + h + 1):
            c.set(x, yy, curtain); c.set(x + 1, yy, shade(curtain, 0.8))
            c.set(x + w - 1, yy, curtain); c.set(x + w - 2, yy, shade(curtain, 0.8))


# ============================================================
# 家具(每样一个 canvas,摆的时候当道具)
# ============================================================
def bed(seed=510, blanket=(120, 60, 54)):
    W, H = 26, 12
    c = Canvas(W, H, seed)
    c.rect(0, 2, 2, H - 1, PLANK[2]); c.rect(W - 3, 5, W - 1, H - 1, PLANK[2])     # 床头床尾
    c.hline(0, 2, 2, PLANK[4]); c.hline(W - 3, W - 1, 5, PLANK[4])
    c.rect(3, 6, W - 4, 8, (190, 184, 166))                                           # 床单
    c.rect(3, 5, 8, 6, (214, 208, 190))                                               # 枕头
    c.rect(9, 5, W - 4, 8, blanket); c.mottle(9, 5, W - 4, 8, amt=0.15, scale=2, accent=shade(blanket, 0.6), accent_amt=0.4)
    c.hline(9, W - 4, 5, shade(blanket, 1.2))
    c.rect(3, 9, W - 4, 10, PLANK[1]); c.vline(4, 11, H - 1, PLANK[0]); c.vline(W - 5, 11, H - 1, PLANK[0])
    return c


def table(seed=511, W=20):
    c = Canvas(W, 9, seed)
    c.hline(0, W - 1, 0, PLANK[5]); c.hline(0, W - 1, 1, PLANK[3]); c.hline(1, W - 2, 2, PLANK[1])
    for x in (2, W - 3):
        c.vline(x, 3, 8, PLANK[2]); c.vline(x + 1, 3, 8, PLANK[0])
    return c


def table_flipped(seed=512, W=20):
    """翻倒的桌子:桌面竖着朝外,四条腿朝天。"""
    c = Canvas(W, 11, seed)
    c.rect(0, 2, W - 1, 10, PLANK[3]); c.mottle(0, 2, W - 1, 10, amt=0.12, scale=3, accent=PLANK[1])
    c.hline(0, W - 1, 2, PLANK[5]); c.hline(0, W - 1, 10, PLANK[0])
    for x in (2, W - 4):
        c.vline(x, 0, 2, PLANK[2]); c.vline(x + 1, 0, 2, PLANK[0])
    return c


def chair(seed=513, toppled=False):
    if not toppled:
        c = Canvas(6, 11, seed)
        c.vline(0, 0, 10, PLANK[3]); c.vline(1, 0, 10, PLANK[1])
        c.hline(0, 5, 5, PLANK[4]); c.hline(0, 5, 6, PLANK[2])
        c.vline(5, 6, 10, PLANK[1])
        c.hline(0, 1, 1, PLANK[4]); c.hline(0, 1, 3, PLANK[2])
        return c
    c = Canvas(11, 6, seed)      # 倒地的椅子
    c.hline(0, 10, 5, PLANK[2]); c.hline(0, 10, 4, PLANK[4])
    c.vline(5, 0, 4, PLANK[3]); c.vline(10, 1, 4, PLANK[1]); c.hline(5, 10, 1, PLANK[2])
    return c


def wardrobe(seed=514, open_door=False):
    W, H = 16, 30
    c = Canvas(W, H, seed)
    c.wall(0, 2, W - 1, H - 2, PLANK, base=2.4, spread=1.2, scale=4)
    c.hline(0, W - 1, 0, PLANK[5]); c.hline(0, W - 1, 1, PLANK[3]); c.hline(0, W - 1, H - 1, PLANK[0])
    c.vline(W // 2, 3, H - 3, PLANK[0])
    c.set(W // 2 - 2, H // 2, BRASS); c.set(W // 2 + 1, H // 2, BRASS)
    if open_door:   # 柜门被拉开,衣服掉出来一半
        c.rect(W // 2 + 1, 3, W - 2, H - 3, (16, 14, 12))
        for i, col in enumerate([CLOTH[0], CLOTH[4], CLOTH[3]]):
            c.rect(W // 2 + 2 + i * 2, 5, W // 2 + 3 + i * 2, 14 + i * 3, col)
    return c


def shelf(seed=515, W=22, levels=3, goods=True, H=None):
    H = H or levels * 8 + 2
    c = Canvas(W, H, seed)
    rng = c.rng
    for x in (0, W - 1):
        c.vline(x, 0, H - 1, PLANK[1])
    for i in range(levels):
        y = 1 + i * 8
        c.hline(0, W - 1, y, PLANK[4]); c.hline(0, W - 1, y + 1, PLANK[1])
        if goods and i > 0:
            x = 2
            while x < W - 3:
                k = rng.randrange(4)
                if k == 0:    # 瓶子
                    col = [(60, 100, 70), (110, 70, 40), (70, 90, 110)][rng.randrange(3)]
                    h = rng.randint(2, 4)
                    c.vline(x, y - h, y - 1, col); c.set(x, y - h - 1, shade(col, 1.4)); x += 2
                elif k == 1:  # 罐子
                    c.rect(x, y - 3, x + 2, y - 1, (150, 140, 120)); c.hline(x, x + 2, y - 3, (180, 170, 150)); x += 4
                elif k == 2:  # 书
                    for j in range(rng.randint(2, 4)):
                        c.vline(x + j, y - rng.randint(3, 5), y - 1, CLOTH[rng.randrange(len(CLOTH))])
                    x += 5
                else:
                    x += 2
    return c


def stove(seed=516):
    """铸铁小炉子:炉门透红光,烟囱管往上通到画外(上面那头接天花板)。"""
    W, H = 14, 70
    c = Canvas(W, H, seed)
    c.rect(1, H - 14, W - 2, H - 3, (44, 42, 40)); c.hline(0, W - 1, H - 15, (80, 76, 70))
    c.rect(4, H - 10, W - 5, H - 5, (200, 84, 30)); c.hline(4, W - 5, H - 10, (246, 150, 60))
    c.vline(2, H - 2, H - 1, IRON_D); c.vline(W - 3, H - 2, H - 1, IRON_D)
    for y in range(0, H - 15):       # 烟囱管
        c.set(5, y, (70, 66, 60)); c.set(6, y, (56, 52, 48)); c.set(7, y, (40, 38, 36))
        if y % 14 == 0:
            c.hline(4, 8, y, (80, 76, 70))
    c.hline(4, 8, 0, (80, 76, 70))   # 顶上进天花板的法兰
    return c, (W // 2, H - 8)


def picture(seed=517, w=9, h=7, broken=False):
    c = Canvas(w, h, seed)
    c.rect(0, 0, w - 1, h - 1, GOLD[1]); c.hline(0, w - 1, 0, GOLD[2])
    c.rect(1, 1, w - 2, h - 2, (60, 74, 70))
    c.rect(2, h - 3, w - 3, h - 2, (80, 96, 70)); c.set(w // 2, 2, (200, 190, 150))   # 一张风景
    if broken:
        c.set(2, 1, (200, 210, 214)); c.set(3, 2, (200, 210, 214)); c.set(5, 3, (200, 210, 214))
    return c


def clock(seed=518):
    c = Canvas(7, 7, seed)
    for y in range(7):
        for x in range(7):
            if (x - 3) ** 2 + (y - 3) ** 2 <= 10:
                c.set(x, y, (200, 192, 168) if (x - 3) ** 2 + (y - 3) ** 2 <= 5 else PLANK[2])
    c.vline(3, 1, 3, IRON_D); c.hline(3, 5, 3, IRON_D)
    return c


def bulb(seed=519, cord=8):
    """天花板垂下来的一个灯泡。返回 (canvas, 灯泡在图里的位置)。"""
    c = Canvas(3, cord + 4, seed)
    c.vline(1, 0, cord, (40, 36, 32))
    c.rect(0, cord, 2, cord, IRON); c.set(1, cord + 1, LIT[2]); c.set(0, cord + 2, LIT[1]); c.set(1, cord + 2, LIT[2]); c.set(2, cord + 2, LIT[1]); c.set(1, cord + 3, LIT[1])
    return c, (1, cord + 2)


def rug(seed=520, W=30, col=(120, 50, 44)):
    c = Canvas(W, 2, seed)
    for x in range(W):
        c.set(x, 0, shade(col, 1.1) if x % 4 else (196, 160, 90))
        c.set(x, 1, shade(col, 0.85))
    return c


def clutter(seed=521, W=30):
    """被翻乱的一地:碎盘子、散的衣服、纸、一个歪倒的瓶子。"""
    c = Canvas(W, 4, seed)
    rng = c.rng
    for _ in range(W // 3):
        x = rng.randint(0, W - 4)
        k = rng.randrange(4)
        if k == 0:
            c.set(x, 3, (210, 206, 192)); c.set(x + 1, 3, (180, 176, 162)); c.set(x + 2, 2, (210, 206, 192))   # 碎盘子
        elif k == 1:
            col = CLOTH[rng.randrange(len(CLOTH))]
            c.hline(x, x + 3, 3, col); c.set(x + 1, 2, shade(col, 1.1))                                     # 衣服
        elif k == 2:
            c.hline(x, x + 2, 3, (200, 194, 170))                                                            # 纸
        else:
            c.hline(x, x + 2, 3, (60, 100, 70)); c.set(x + 3, 3, (90, 140, 100))                            # 倒了的瓶子
    return c


def drawers(seed=522, pulled=True):
    """五斗柜:抽屉被拉出来。顶面可站。"""
    W, H = 18, 14
    c = Canvas(W + 3, H, seed)
    c.wall(0, 1, W - 1, H - 1, PLANK, base=2.5, spread=1.0, scale=4)
    c.hline(0, W - 1, 0, PLANK[5])
    for i, y in enumerate((3, 7, 11)):
        c.hline(1, W - 2, y - 1, PLANK[0])
        if pulled and i != 1:
            c.rect(W - 2, y, W + 2, y + 2, PLANK[3]); c.hline(W - 2, W + 2, y, PLANK[4])   # 拉出来的抽屉
        else:
            c.set(W // 2, y + 1, BRASS)
    return c


def stairs(run=30, rise=30, seed=523, rail=True):
    """木楼梯(左低右高):踏步一级级,侧面一块斜板,扶手。碰撞用斜坡。"""
    W, H = run, rise + 1
    c = Canvas(W, H, seed)
    steps = rise // 5
    for i in range(steps):
        x0 = int(i * run / steps)
        y = H - 1 - (i + 1) * 5
        c.rect(x0, y, W - 1, y + 1, PLANK[4]); c.hline(x0, W - 1, y, PLANK[5])
        c.rect(x0, y + 2, W - 1, y + 4, PLANK[1])
    for x in range(W):    # 侧板
        y = int(H - 1 - x * rise / run)
        for yy in range(y, H):
            if c.get(x, yy)[3] == 0:
                c.set(x, yy, shade(PLANK[1], 0.8))
    if rail:
        for x in range(W):
            y = int(H - 1 - x * rise / run) - 9
            if 0 <= y < H:
                c.set(x, y, PLANK[3])
            if x % 6 == 0:
                for yy in range(y + 1, y + 9):
                    if 0 <= yy < H:
                        c.set(x, yy, PLANK[2])
    return c


def loft(W=60, seed=524, rail=True, posts=()):
    """阁楼/走廊楼板:3 格厚木板 + 栏杆 + 竖柱。顶面在图里 y=6。
    posts=[(图里 x, 柱子往下多长)]:柱子一直落到地面或下一层阁楼上,不悬空。"""
    down = max([ln for _, ln in posts], default=0)
    c = Canvas(W, 14 + down, seed)
    y0 = 6
    c.rect(0, y0, W - 1, y0 + 2, PLANK[2]); c.hline(0, W - 1, y0, PLANK[5]); c.hline(0, W - 1, y0 + 2, PLANK[0])
    c.mottle(0, y0 + 1, W - 1, y0 + 2, amt=0.12, scale=3, accent=PLANK[0])
    if rail:
        c.hline(0, W - 1, 0, PLANK[4])
        for x in range(0, W, 3):
            c.vline(x, 1, y0 - 1, PLANK[2])
    for (px_, ln) in posts:
        c.vline(px_, y0 + 3, y0 + 2 + ln, PLANK[3]); c.vline(px_ + 1, y0 + 3, y0 + 2 + ln, PLANK[1])
        c.hline(px_ - 1, px_ + 2, y0 + 3, PLANK[2])                       # 柱头托木
        c.hline(px_ - 1, px_ + 2, y0 + 2 + ln, PLANK[0])                  # 柱脚
    return c


def sacks(seed=525, n=3):
    W = n * 6 + 2
    c = Canvas(W, 9, seed)
    burlap = [(84, 66, 44), (112, 90, 60), (140, 116, 80)]
    for i in range(n):
        x = i * 6 + (1 if i % 2 else 0)
        top = 2 if i % 2 else 0
        for y in range(top, 9):
            for xx in range(x, x + 7):
                d = abs(xx - (x + 3)) / 3.5
                if y < top + 2 and d > 0.6:
                    continue
                c.set(xx, y, burlap[2] if y < top + 3 else (burlap[1] if d < 0.7 else burlap[0]))
        c.hline(x + 2, x + 4, top, (60, 46, 30))
    return c


def coin_pile(seed=526, W=12):
    c = Canvas(W, 5, seed)
    for x in range(W):
        h = int(round(4 * max(0, 1 - abs(x - W / 2) / (W / 2)))) + 1
        for y in range(5 - h, 5):
            c.set(x, y, GOLD[2] if (x + y) % 3 else GOLD[1])
        c.set(x, 5 - h, GOLD[3] if x % 3 == 0 else GOLD[2])
    return c


def ledger(seed=527):
    c = Canvas(8, 3, seed)
    c.rect(0, 1, 7, 2, (90, 30, 26)); c.hline(0, 7, 0, (220, 210, 186)); c.set(3, 0, (40, 30, 26)); c.set(5, 0, (40, 30, 26))
    return c


def cards(seed=528):
    c = Canvas(7, 2, seed)
    for x in range(0, 7, 2):
        c.set(x, 1, (230, 224, 210)); c.set(x + 1, 1, (180, 40, 40) if x % 4 else (30, 30, 30))
    c.set(3, 0, (230, 224, 210))
    return c


def army_crate(seed=529, W=16, H=12):
    """军火箱:深绿漆木箱,四角铁包边,箱面一个喷的记号(交叉的两把刀,没有字)。"""
    c = Canvas(W, H, seed)
    col = (62, 76, 54)
    c.wall(0, 0, W - 1, H - 1, [shade(col, 0.55), shade(col, 0.75), col, shade(col, 1.2)], base=2.0, spread=0.8, scale=3)
    c.hline(0, W - 1, 0, shade(col, 1.35)); c.vline(0, 0, H - 1, shade(col, 1.15))
    c.hline(0, W - 1, H - 1, (24, 22, 20)); c.vline(W - 1, 0, H - 1, shade(col, 0.5))
    for (x, y) in [(0, 0), (W - 2, 0), (0, H - 2), (W - 2, H - 2)]:
        c.rect(x, y, x + 1, y + 1, IRON); c.set(x, y, IRON_L)
    mx, my = W // 2, H // 2
    for i in range(-3, 4):          # 交叉的两把刀
        c.set(mx + i, my + i // 2, (196, 186, 150)); c.set(mx + i, my - i // 2, (196, 186, 150))
    return c


def hoist(seed=530, length=40):
    """天车的链子 + 吊钩(挂在仓库梁上)。"""
    c = Canvas(7, length + 8, seed)
    for y in range(length):
        if (y // 2) % 2 == 0:
            c.set(2, y, IRON); c.set(4, y, IRON)
        else:
            c.set(3, y, IRON_L)
    c.vline(3, length, length + 4, IRON_L); c.set(2, length + 5, IRON_L); c.set(1, length + 4, IRON_L); c.set(4, length + 6, IRON)
    return c


def fish_baskets(seed=531):
    """一摞鱼筐(夜市后仓)。"""
    W, H = 18, 14
    c = Canvas(W, H, seed)
    for i, y in enumerate((7, 0)):
        x0 = 1 if i else 0
        for yy in range(y, y + 7):
            for x in range(x0, x0 + 16):
                c.set(x, yy, (130, 100, 60) if (x + yy) % 3 else (96, 72, 42))
        c.hline(x0, x0 + 15, y, (160, 126, 80))
        for x in range(x0 + 2, x0 + 14, 3):
            c.set(x, y - 1 if y > 0 else y, (150, 160, 166)); c.set(x + 1, y - 1 if y > 0 else y, (120, 130, 140))
    return c


def notice_board(seed=532):
    c = Canvas(16, 11, seed)
    c.rect(0, 0, 15, 10, PLANK[2]); c.rect(1, 1, 14, 9, (110, 86, 56))
    rng = c.rng
    for _ in range(5):
        x, y = rng.randint(1, 10), rng.randint(1, 6)
        c.rect(x, y, x + 3, y + 3, (210, 204, 182) if rng.random() < 0.7 else (200, 160, 150))
        c.set(x + 1, y, (180, 40, 40))
    return c
