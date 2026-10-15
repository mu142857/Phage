"""收钱小弟 v2:按奥斯卡的节奏,每帧 100ms,攻击 12 帧。
朝右画,游戏里翻面。帧画布 W×H,脚底(靴底)在最后一行 FOOT,地面线在画布外下方一格。
姿势用关键帧描述,中间帧插值;腿用两段(大腿/小腿)按脚的位置算膝盖。"""
from PIL import Image
import math, sys, os
from lib import put

W, H = 36, 28
FOOT = H - 1
BASE_X = 10            # 站立时上身格子的左边

PAL = dict(
    H='#5a6050', h='#353a30', j='#25281f', e='#0e0d0a', n='#b48a68',
    **{'1': '#58584a', '2': '#414135', '3': '#35352b', '4': '#2a2a22', '5': '#1f1f19'},
    R='#bc4652', r='#88303c',
    K='#a07a5a', k='#7a5840',
)
LEG_FRONT = ('#30323a', '#222329')   # 亮边 / 暗边
LEG_BACK = ('#25262c', '#1a1b20')
BOOT_FRONT = ('#2c2822', '#161412')
BOOT_BACK = ('#1e1b17', '#110f0d')
PIPE = ['#b06c40', '#7e4428', '#4e2a18']
SMEAR = ['#e8d4bc', '#bfa28a']
SPARK = ['#fff0b0', '#ffc860', '#e07830']

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
SHOULDER = (7, 7)
NECK_BACK = (2, 6)
HEMS = [
    ["..5443.221..",   # 0 静止
     "..5.4...21..",
     "..5........."],
    [".55443.221..",   # 1 往后甩
     "5.54.3..2...",
     "5..........."],
]
HIP_FRONT, HIP_BACK = 6, 4      # 胯在上身格子里的 x
THIGH, SHIN = 3.4, 3.4


def lerp(a, b, t):
    return a + (b - a) * t


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


def knee(hx, hy, fx, fy):
    """两段腿,膝盖往前(+x)弯"""
    dx, dy = fx - hx, fy - hy
    d = max(0.01, math.hypot(dx, dy))
    d2 = min(d, THIGH + SHIN - 0.01)
    a = (THIGH ** 2 - SHIN ** 2 + d2 ** 2) / (2 * d2)
    hgt = math.sqrt(max(0.0, THIGH ** 2 - a ** 2))
    mx, my = hx + dx * a / d, hy + dy * a / d
    # 垂直方向取朝前的那边
    px, py = -dy / d, dx / d
    if px < 0:
        px, py = -px, -py
    return mx + px * hgt, my + py * hgt


def draw_leg(c, hx, hy, fx, lift, cols, boots):
    ay = FOOT - 1 - lift
    kx, ky = knee(hx, hy, fx, ay)
    pts = line_pts(round(hx), round(hy), round(kx), round(ky)) + line_pts(round(kx), round(ky), round(fx), ay)
    for (x, y) in pts:
        put(c, x, y, cols[0])
        put(c, x + 1, y, cols[1])
    by = FOOT - lift
    put(c, round(fx) - 1, by, boots[1])
    put(c, round(fx), by, boots[0])
    put(c, round(fx) + 1, by, boots[0])
    put(c, round(fx) + 2, by, boots[1])
    put(c, round(fx) + 1, ay, boots[1])


def draw_pipe(c, hx, hy, ang, length, back):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    x0, y0 = round(hx - ux * back), round(hy - uy * back)
    x1, y1 = round(hx + ux * (length - back)), round(hy + uy * (length - back))
    pts = line_pts(x0, y0, x1, y1)
    for i, (x, y) in enumerate(pts):
        put(c, x, y, PIPE[1] if i % 4 == 2 else PIPE[0])
    put(c, *pts[-1], PIPE[2])
    return pts


def draw_arm(c, sx, sy, hx, hy):
    for (x, y) in line_pts(sx, sy, hx, hy):
        put(c, x, y, PAL['3'])
        put(c, x, y + 1, PAL['4'])
    put(c, hx, hy, PAL['K'])
    put(c, hx, hy + 1, PAL['k'])


def draw_smear(c, cx, cy, r, a0, a1):
    for rr, col, skip in ((r, SMEAR[0], 0.0), (r - 1, SMEAR[1], 0.3), (r - 2, SMEAR[1], 0.55)):
        for k in range(80):
            t = k / 79
            if t < skip:
                continue
            a = math.radians(a0 + (a1 - a0) * t)
            put(c, round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), col)


def draw_tail(c, nx, ny, sway, phase):
    """围巾尾巴:sway 0=垂着,1=水平往后飘;phase 让尾巴梢抖一抖"""
    n = 4
    for i in range(1, n + 1):
        ang = math.radians(lerp(100, 175, sway) + math.sin(phase + i * 1.3) * 10 * sway)
        x = nx + math.cos(ang) * i * 1.05
        y = ny + math.sin(ang) * i * 1.0 * (1 - 0.6 * sway) + (i * 0.15 if sway > 0.5 else 0)
        put(c, round(x), round(y), PAL['R'] if i == 1 else PAL['r'])


def paste_upper(c, ox, top, shear):
    rows = len(UPPER)
    for y, r in enumerate(UPPER):
        dx = int(round(shear * (rows - 1 - y)))
        for x, ch in enumerate(r):
            if ch != '.':
                put(c, ox + x + dx, top + y, PAL[ch])


def render(p):
    """p: 姿势字典(见 POSE_DEFAULT)"""
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ox = BASE_X + round(p['dx'])
    dy = round(p['dy'])
    rows = len(UPPER)
    hip_y = FOOT - 7 + dy                     # 胯 = 上身格子最后一行
    top = hip_y - rows + 1
    shear = p['shear']
    def shx(y):
        return int(round(shear * (rows - 1 - y)))
    sx = ox + SHOULDER[0] + shx(SHOULDER[1])
    sy = top + SHOULDER[1]
    hx, hy = sx + round(p['hand'][0]), sy + round(p['hand'][1])
    pipe_len, back = p['pipe_len'], p['pipe_back']
    ang = p['pipe']
    if ang == 'drag':                         # 管头正好擦着地
        reach = FOOT - hy
        L = pipe_len - back
        ang = 180 - math.degrees(math.asin(max(-1, min(1, reach / L))))
    if p.get('smear'):
        a0, a1 = p['smear']
        draw_smear(c, hx, hy, pipe_len - back, a0, a1)
    if p['pipe_behind']:
        pts = draw_pipe(c, hx, hy, ang, pipe_len, back)
    # 后腿 → 围巾尾巴 → 上身 → 下摆 → 前腿(前腿压住下摆一点) → 铁管/胳膊
    draw_leg(c, ox + HIP_BACK, hip_y, ox + HIP_BACK + p['foot_back'], round(p['lift_back']), LEG_BACK, BOOT_BACK)
    draw_tail(c, ox + NECK_BACK[0] + shx(NECK_BACK[1]), top + NECK_BACK[1], p['tail'], p['tail_phase'])
    paste_upper(c, ox, top, shear)
    hem = HEMS[p['hem']]
    for y, r in enumerate(hem):
        for x, ch in enumerate(r):
            if ch != '.':
                put(c, ox + x + int(round(-shear * 0.6)), top + rows + y, PAL[ch])
    draw_leg(c, ox + HIP_FRONT, hip_y + 1, ox + HIP_FRONT + p['foot_front'], round(p['lift_front']), LEG_FRONT, BOOT_FRONT)
    # 前腿上段被大衣盖住:重画下摆前沿
    for y, r in enumerate(hem[:2]):
        for x, ch in enumerate(r):
            if ch != '.' and x >= 6:
                put(c, ox + x + int(round(-shear * 0.6)), top + rows + y, PAL[ch])
    if not p['pipe_behind']:
        pts = draw_pipe(c, hx, hy, ang, pipe_len, back)
    if p.get('arm', True):
        draw_arm(c, sx, sy, hx, hy)
    for (k, (ex, ey)) in enumerate(p.get('sparks', [])):
        tx, ty = pts[-1]
        put(c, tx + ex, ty + ey, SPARK[min(k, 2)])
    return c


POSE_DEFAULT = dict(dx=0, dy=0, shear=0.0, hand=(2, 5), pipe=55, pipe_len=10, pipe_back=2,
                    pipe_behind=False, foot_front=2, foot_back=-1, lift_front=0, lift_back=0,
                    tail=0.0, tail_phase=0.0, hem=0)


def pose(**kw):
    d = dict(POSE_DEFAULT); d.update(kw); return d


def tween(a, b, t):
    out = dict(a if t < 0.5 else b)
    for k in ('dx', 'dy', 'shear', 'foot_front', 'foot_back', 'lift_front', 'lift_back', 'tail', 'tail_phase'):
        out[k] = lerp(a[k], b[k], t)
    out['hand'] = (lerp(a['hand'][0], b['hand'][0], t), lerp(a['hand'][1], b['hand'][1], t))
    if isinstance(a['pipe'], (int, float)) and isinstance(b['pipe'], (int, float)):
        out['pipe'] = lerp(a['pipe'], b['pipe'], t)
    out['smear'] = None; out['sparks'] = []
    return out


# ---------------- 待机 8 帧:喘气,铁管在脚前一下一下磕地 ----------------
def idle():
    fr = []
    for i in range(8):
        t = i / 8
        breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi)          # 0→1→0
        tap = max(0.0, math.sin(t * 2 * math.pi * 2 - 0.6))       # 一圈磕两下
        fr.append(pose(dy=round(breath), hand=(2, 5 - round(tap)), pipe=55 - tap * 9,
                       tail=0.15 + 0.1 * breath, tail_phase=t * 6.28))
    return fr


# ---------------- 走路 8 帧:铁管拖地刮出火星 ----------------
def walk():
    fr = []
    for i in range(8):
        ph = i / 8
        def leg(phi):
            x = 3.2 * math.cos(2 * math.pi * phi)
            lift = max(0.0, -math.sin(2 * math.pi * phi)) * 1.6
            return x, lift
        ffx, ffl = leg(ph)
        fbx, fbl = leg(ph + 0.5)
        dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
        sparks = []
        if i in (0, 4):
            sparks = [(0, -1), (-1, -2), (1, -3)]
        elif i in (1, 5):
            sparks = [(-2, -3), (0, -4)]
        fr.append(pose(dx=0, dy=dy, shear=0.22, hand=(-4, 5), pipe='drag', pipe_len=12, pipe_back=1,
                       pipe_behind=True, arm=False,
                       foot_front=1 + ffx, lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl,
                       tail=0.75, tail_phase=ph * 12.6, hem=1 if i % 4 in (0, 1) else 0, sparks=sparks))
    return fr


# ---------------- 发现 8 帧:一愣 → 铁管往前一指,喊"交钱!"时戳两下 ----------------
def alert():
    k = [
        pose(),
        pose(dy=-1, shear=-0.1, hand=(2, 4), pipe=50, tail=0.3),                       # 一愣,挺起来
        pose(dy=-1, shear=-0.05, hand=(3, 2), pipe=20, pipe_back=1, tail=0.3),
        pose(shear=0.2, hand=(4, 1), pipe=-10, pipe_back=1, tail=0.5, foot_front=3),    # 指过去
        pose(shear=0.3, hand=(5, 0), pipe=-14, pipe_back=1, tail=0.7, foot_front=3),    # 戳
        pose(shear=0.25, hand=(4, 1), pipe=-8, pipe_back=1, tail=0.6, foot_front=3),
        pose(shear=0.3, hand=(5, 0), pipe=-14, pipe_back=1, tail=0.7, foot_front=3),    # 再戳
        pose(shear=0.25, hand=(4, 1), pipe=-8, pipe_back=1, tail=0.6, foot_front=3),
    ]
    for i, p in enumerate(k):
        p['tail_phase'] = i * 1.4
    return k


# ---------------- 攻击 12 帧:举 → 憋(前摇两帧) → 挥 → 砸 → 收 ----------------
def attack():
    stand = pose()
    k = [
        pose(hand=(2, 4), pipe=40, tail=0.2),                                               # 0 起
        pose(dy=-1, shear=-0.05, hand=(3, 1), pipe=0, pipe_back=1, tail=0.25),               # 1 往上带
        pose(dy=-1, shear=-0.15, hand=(2, -2), pipe=-60, pipe_back=1, tail=0.3,
             foot_back=-3),                                                                  # 2 举过肩
        pose(shear=-0.22, hand=(0, -5), pipe=-112, pipe_back=1, pipe_behind=True, tail=0.35,
             foot_back=-4, foot_front=2),                                                    # 3 拉到脑后
        pose(dy=1, shear=-0.3, dx=-1, hand=(-1, -5), pipe=-138, pipe_back=1, pipe_behind=True,
             tail=0.4, foot_back=-4, foot_front=2),                                          # 4 憋住(前摇)
        pose(dy=1, shear=-0.32, dx=-1, hand=(-1, -5), pipe=-142, pipe_back=1, pipe_behind=True,
             tail=0.45, foot_back=-4, foot_front=2),                                         # 5 憋住(微抖)
        pose(shear=0.15, dx=1, hand=(3, -3), pipe=-70, pipe_back=1, tail=0.8, hem=1,
             foot_back=-4, foot_front=4, smear=(-160, -75)),                                 # 6 挥出去
        pose(shear=0.45, dx=2, hand=(5, -1), pipe=-8, pipe_back=1, tail=1.0, hem=1,
             foot_back=-5, foot_front=5, smear=(-110, -10)),                                 # 7 横扫(判定)
        pose(dy=1, shear=0.55, dx=3, hand=(4, 3), pipe=52, pipe_back=1, tail=1.0, hem=1,
             foot_back=-5, foot_front=5, smear=(-35, 50), sparks=[(1, -1), (2, -2), (-1, -2)]),  # 8 砸地(判定)
        pose(dy=1, shear=0.5, dx=3, hand=(4, 4), pipe=66, pipe_back=1, tail=0.8, hem=1,
             foot_back=-5, foot_front=5),                                                    # 9 压住
        pose(shear=0.3, dx=2, hand=(3, 4), pipe=62, pipe_back=2, tail=0.5,
             foot_back=-3, foot_front=4),                                                    # 10 收
        pose(shear=0.1, dx=1, hand=(2, 5), pipe=57, tail=0.3, foot_back=-2, foot_front=3),   # 11 回位
    ]
    for i, p in enumerate(k):
        p['tail_phase'] = i * 1.1
    return k


ANIMS = {'idle': idle(), 'walk': walk(), 'alert': alert(), 'attack': attack()}
ORDER = ['idle', 'walk', 'alert', 'attack']


def frames(name):
    return [render(p) for p in ANIMS[name]]


def export(out):
    os.makedirs(out, exist_ok=True)
    for k in ORDER:
        fr = frames(k)
        strip = Image.new('RGBA', (W * len(fr), H))
        for i, f in enumerate(fr):
            strip.alpha_composite(f, (i * W, 0))
        strip.save(f'{out}/thug_{k}.png')
        big = []
        for f in fr:
            b = Image.new('RGBA', (W, H + 1), (92, 76, 66, 255))
            for x in range(W):
                b.putpixel((x, H), (150, 128, 96, 255))   # 地面线
            b.alpha_composite(f)
            big.append(b.resize((W * 8, (H + 1) * 8), Image.NEAREST).convert('RGB').convert('P', palette=Image.ADAPTIVE))
        big[0].save(f'{out}/thug_{k}_x8.gif', save_all=True, append_images=big[1:], loop=0, duration=100, disposal=2)
    # 总表
    rows = len(ORDER); cols = max(len(ANIMS[k]) for k in ORDER)
    sheet = Image.new('RGBA', (W * cols, (H + 2) * rows), (92, 76, 66, 255))
    for r, k in enumerate(ORDER):
        for i, f in enumerate(frames(k)):
            for x in range(W):
                sheet.putpixel((i * W + x, r * (H + 2) + H), (150, 128, 96, 255))
            sheet.alpha_composite(f, (i * W, r * (H + 2)))
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(f'{out}/thug_sheet_x6.png')


if __name__ == '__main__':
    export(sys.argv[1])
