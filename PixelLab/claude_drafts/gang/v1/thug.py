"""收钱小弟:下水道帮最普通的杂兵。朝右画,游戏里翻面。
帧画布 W×H,脚底在最后一行。身体 = 上身格子(可前倾/后仰剪切) + 腿格子 + 程序画的前臂和铁管。"""
from PIL import Image
import math, sys
from lib import grid, hexc, put

W, H = 34, 26
FOOT = H - 1

PAL = dict(
    # 头罩/油布大衣:压得很暗,整个人是一块深剪影,只有围巾跳出来
    H='#5a6050', h='#353a30', j='#25281f', e='#0e0d0a', n='#b48a68',
    **{'1': '#58584a', '2': '#414135', '3': '#35352b', '4': '#2a2a22', '5': '#1f1f19'},
    # 帮派围巾(全身唯一的点缀色)
    R='#bc4652', r='#88303c',
    # 裤子/靴子
    t='#2e3036', T='#212228', b='#141210', B='#28241f',
    # 手
    K='#a07a5a', k='#7a5840',
)
PIPE = ['#b06c40', '#7e4428', '#4e2a18']  # 亮 / 中 / 暗(管口)
SMEAR = '#e0c8b0'

# 上身:hood + 围巾 + 驼背大衣,最后一行是腰(剪切的支点)
UPPER = [
    "....jhh.....",
    "...jhHHh....",
    "...jhHHHh...",
    "..jjhHjeen..",
    "..jjhhjee...",
    "...jjhhj....",
    "..rRRRRR....",
    "..r4322R1...",
    "...543221...",
    "...543221...",
    "...5432211..",
    "...5433221..",
    "..54433221..",
]
UPPER_SHOULDER = (7, 7)   # 前肩在上身格子里的位置
# 大衣下摆(参差+碎点),画在腿前面
HEM = {
    'stand': [
        "..5443.221..",
        "..5.4...21..",
        "..5.........",
    ],
    'swing': [  # 走路/挥动时下摆往后甩
        ".55443.221..",
        "5.54.3..2...",
        "5...........",
    ],
}
LEGS = {
    'stand': [
        "...tT.tT....",
        "...tT.tT....",
        "...tT..tT...",
        "...tT..tT...",
        "...tT..tT...",
        "..bBB..bBB..",
    ],
    'w0': [  # 大步:前腿迈出
        "...tT.tT....",
        "...tT..tT...",
        "..tT....tT..",
        "..tT.....tT.",
        ".tT......tT.",
        "bBB......bBB",
    ],
    'w1': [
        "...tT.tT....",
        "...tT.tT....",
        "...tT..tT...",
        "..tT...tT...",
        "..tT....tT..",
        ".bBB...bBB..",
    ],
    'w2': [  # 交叉
        "....tTT.....",
        "....tTT.....",
        "....tTT.....",
        "....tTt.....",
        "....tTt.....",
        "...bBbBB....",
    ],
    'w3': [
        "...tT.tT....",
        "...tT.tT....",
        "...tT..tT...",
        "...tT..tT...",
        "...tT...tT..",
        "..bBB...bBB.",
    ],
    'lunge': [  # 前弓步
        "...tT.tT....",
        "..tT...tT...",
        "..tT....tT..",
        ".tT......tT.",
        ".tT.......tT",
        "bBB.......bBB",
    ],
    'brace': [  # 后仰蓄力:重心在后腿
        "...tT.tT....",
        "..tT..tT....",
        "..tT..tT....",
        ".tT....tT...",
        ".tT....tT...",
        "bBB....bBB..",
    ],
}


def paste_grid(canvas, rows, ox, oy, pal, shear=0.0, pivot=None):
    """shear: 每往上一行向前(右)偏多少格;pivot=剪切不动的行"""
    if pivot is None:
        pivot = len(rows) - 1
    for y, r in enumerate(rows):
        dx = int(round(shear * (pivot - y)))
        for x, c in enumerate(r):
            if c in '. ':
                continue
            put(canvas, ox + x + dx, oy + y, pal[c])


def line_pts(x0, y0, x1, y1):
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy
    return pts


def draw_pipe(c, hx, hy, ang_deg, length=11, back=3):
    """铁管:手握点 (hx,hy),角度 0=朝右,90=朝下;握点后面露 back 格"""
    a = math.radians(ang_deg)
    ux, uy = math.cos(a), math.sin(a)
    x0, y0 = round(hx - ux * back), round(hy - uy * back)
    x1, y1 = round(hx + ux * (length - back)), round(hy + uy * (length - back))
    pts = line_pts(x0, y0, x1, y1)
    for i, (x, y) in enumerate(pts):
        col = PIPE[1] if (i % 4 == 2) else PIPE[0]
        put(c, x, y, col)
    put(c, *pts[-1], PIPE[2])
    put(c, *pts[0], PIPE[1])
    return pts


def draw_arm(c, sx, sy, hx, hy):
    for (x, y) in line_pts(sx, sy, hx, hy):
        put(c, x, y, PAL['3'])
        put(c, x, y + 1, PAL['4'])
    put(c, hx, hy, PAL['K'])
    put(c, hx, hy + 1, PAL['k'])


SMEAR2 = '#b89a84'


def smear(c, cx, cy, r, a0, a1):
    for rr, col in ((r - 1, SMEAR2), (r - 2, SMEAR2), (r, SMEAR)):
        for k in range(60):
            t = k / 59
            # 尾巴那头细:只画外圈
            if rr != r and t < 0.35:
                continue
            a = math.radians(a0 + (a1 - a0) * t)
            put(c, round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), col)


SPARK = ['#ffd68a', '#f0a050']
# 围巾尾巴:从后颈往后垂,风大一点就飘起来(相对后颈点的偏移)
TAILS = {
    'hang': [(-1, 1), (-1, 2), (-2, 3)],
    'flow': [(-1, 0), (-2, 1), (-3, 1), (-4, 2)],
    'up':   [(-1, 0), (-2, -1), (-3, -1), (-4, -2)],
}


def frame(legs='stand', hem='stand', shear=0.0, dx=0, dy=0, hand=None, pipe_ang=None,
          pipe_first=False, smear_arc=None, pipe_len=11, pipe_back=2, tail='hang',
          spark=False, flash=False):
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    lg = LEGS[legs]
    ox = 8 + dx
    leg_top = FOOT - len(lg) + 1
    up_top = leg_top - len(UPPER) + 2 + dy
    rows = len(UPPER)
    def shx(y):
        return int(round(shear * (rows - 1 - y)))
    sx = ox + UPPER_SHOULDER[0] + shx(UPPER_SHOULDER[1])
    sy = up_top + UPPER_SHOULDER[1]
    hx, hy = sx + hand[0], sy + hand[1]
    if smear_arc:
        a0, a1 = smear_arc
        smear(c, hx, hy, pipe_len - pipe_back, a0, a1)
    pts = None
    if pipe_first:
        pts = draw_pipe(c, hx, hy, pipe_ang, pipe_len, pipe_back)
    # 围巾尾巴(在身后,先画)
    nx, ny = ox + 2 + shx(6), up_top + 6
    for (tx, ty) in TAILS[tail]:
        put(c, nx + tx, ny + ty, PAL['r'])
    put(c, nx + TAILS[tail][0][0], ny + TAILS[tail][0][1], PAL['R'])
    paste_grid(c, lg, ox, leg_top, PAL)
    paste_grid(c, UPPER, ox, up_top, PAL, shear=shear)
    paste_grid(c, HEM[hem], ox + int(round(-shear)), up_top + rows, PAL)
    if not pipe_first:
        pts = draw_pipe(c, hx, hy, pipe_ang, pipe_len, pipe_back)
    draw_arm(c, sx, sy, hx, hy)
    if spark and pts:
        ex, ey = pts[-1]
        put(c, ex - 1, ey - 1, SPARK[0])
        put(c, ex - 2, ey - 2, SPARK[1])
        put(c, ex + 1, ey - 2, SPARK[1])
    if flash:
        px = c.load()
        for y in range(H):
            for x in range(W):
                if px[x, y][3]:
                    r, g, b, a = px[x, y]
                    px[x, y] = (min(255, r + 70), min(255, g + 60), min(255, b + 60), a)
    return c


ANIMS = {
    # 站着:铁管斜拄在脚前,管头一下一下磕地
    'idle': [
        frame(hand=(2, 5), pipe_ang=55, pipe_len=10),
        frame(hand=(2, 5), pipe_ang=55, pipe_len=10),
        frame(hand=(2, 4), pipe_ang=50, pipe_len=10, dy=1),
        frame(hand=(2, 5), pipe_ang=55, pipe_len=10, dy=1),
    ],
    # 走路:铁管拖在身后刮地,两步各擦一下火星
    'walk': [
        frame('w0', 'swing', shear=0.2, hand=(0, 5), pipe_ang=152, pipe_len=11, tail='flow', spark=True),
        frame('w1', 'swing', shear=0.2, hand=(0, 6), pipe_ang=150, pipe_len=11, tail='flow', dy=1),
        frame('w2', 'stand', shear=0.2, hand=(0, 5), pipe_ang=152, pipe_len=11, tail='hang'),
        frame('w0', 'swing', shear=0.2, hand=(0, 5), pipe_ang=152, pipe_len=11, tail='flow', spark=True),
        frame('w1', 'swing', shear=0.2, hand=(0, 6), pipe_ang=150, pipe_len=11, tail='flow', dy=1),
        frame('w3', 'stand', shear=0.2, hand=(0, 5), pipe_ang=152, pipe_len=11, tail='hang'),
    ],
    # 看见人:铁管往前一指("交钱!")
    'alert': [
        frame(shear=0.15, hand=(3, 1), pipe_ang=-15, pipe_back=1, tail='hang'),
        frame(shear=0.3, hand=(4, 0), pipe_ang=-8, pipe_back=1, tail='flow'),
    ],
    'attack': [
        frame('brace', shear=-0.1, hand=(3, -2), pipe_ang=-62, pipe_back=1, tail='hang'),  # 举起
        frame('brace', shear=-0.35, hand=(-1, -4), pipe_ang=-150, pipe_back=1, pipe_first=True, tail='hang'),  # 憋住(前摇)
        frame('lunge', 'swing', shear=0.45, dx=2, hand=(5, -1), pipe_ang=-10, pipe_back=1,
              tail='up', smear_arc=(-105, -15)),                                              # 挥
        frame('lunge', 'swing', shear=0.5, dx=3, hand=(4, 3), pipe_ang=50, pipe_back=1,
              tail='up', smear_arc=(-50, 45)),                                                # 砸到底
        frame('lunge', 'swing', shear=0.4, dx=3, hand=(3, 4), pipe_ang=68, pipe_back=1, tail='flow'),
        frame('stand', shear=0.1, dx=1, hand=(2, 5), pipe_ang=58, pipe_len=10, tail='hang'),
    ],
}

def export(out):
    import os
    os.makedirs(out, exist_ok=True)
    order = ['idle', 'walk', 'alert', 'attack']
    durs = {'idle': 260, 'walk': 110, 'alert': 220, 'attack': [260, 380, 70, 110, 140, 200]}
    for k in order:
        fr = ANIMS[k]
        strip = Image.new('RGBA', (W * len(fr), H))
        for i, f in enumerate(fr):
            strip.alpha_composite(f, (i * W, 0))
        strip.save(f'{out}/thug_{k}.png')
        big = []
        for f in fr:
            b = Image.new('RGBA', (W, H), (92, 76, 66, 255)); b.alpha_composite(f)
            big.append(b.resize((W * 8, H * 8), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        d = durs[k]
        big[0].save(f'{out}/thug_{k}_x8.gif', save_all=True, append_images=big[1:], loop=0,
                    duration=d if isinstance(d, list) else [d] * len(big), disposal=2)


if __name__ == '__main__':
    out = sys.argv[1]
    if len(sys.argv) > 2:
        export(sys.argv[2])
    order = ['idle', 'walk', 'alert', 'attack']
    sheet = Image.new('RGBA', (W * 6, H * len(order)), (0, 0, 0, 0))
    for r, k in enumerate(order):
        for i, f in enumerate(ANIMS[k]):
            sheet.alpha_composite(f, (i * W, r * H))
    sheet.save(out + '/thug_sheet.png')
    bg = Image.new('RGBA', sheet.size, (92, 76, 66, 255))
    bg.alpha_composite(sheet)
    bg.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(out + '/thug_sheet_x8.png')

