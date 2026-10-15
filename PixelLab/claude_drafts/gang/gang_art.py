"""下水道帮全家:深色头罩/油布大衣剪影 + 红围巾(帮派标记) + 各自的家伙。
奥斯卡的节奏:每帧 100ms 等长,动作靠中间帧。朝右画,游戏里翻面。
画布 W×H,靴底 = 最后一行(进游戏时最后一行落在地面线上面一行)。
每种怪 = 一个 Spec(上身格子/腿长/配色/武器画法) + 一组姿势关键帧。"""
from PIL import Image
import math, os, sys
from lib import put

# ---------------------------------------------------------------- 通用色
BASE_PAL = dict(
    H='#5a6050', h='#353a30', j='#25281f', e='#0e0d0a', n='#b48a68',
    **{'1': '#58584a', '2': '#414135', '3': '#35352b', '4': '#2a2a22', '5': '#1f1f19'},
    R='#bc4652', r='#88303c',
    K='#a07a5a', k='#7a5840',
)
LEG_FRONT = ('#30323a', '#222329')
LEG_BACK = ('#25262c', '#1a1b20')
BOOT_FRONT = ('#2c2822', '#161412')
BOOT_BACK = ('#1e1b17', '#110f0d')
PIPE = ['#b06c40', '#7e4428', '#4e2a18']
STEEL = ['#d8dce0', '#9aa0a8', '#5a6068']
SMEAR = ['#e8d4bc', '#bfa28a']
SPARK = ['#fff0b0', '#ffc860', '#e07830']
DUST = ['#8a7a66', '#6a5c4c']


def lerp(a, b, t):
    return a + (b - a) * t


def line_pts(x0, y0, x1, y1):
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
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


class Spec:
    W, H = 36, 28
    BASE_X = 10
    UPPER = []
    SHOULDER = (7, 7)
    NECK_BACK = (2, 6)
    HIP_FRONT, HIP_BACK = 6, 4
    LEG_LEN = 7            # 胯到靴底
    THIGH = SHIN = 3.4
    HEMS = []
    HEM_FRONT_FROM = 6
    TAIL_LEN = 4
    PAL = BASE_PAL
    LEG_W = 2

    def __init__(self):
        self.pal = dict(BASE_PAL)
        self.pal.update(self.PAL)

    # 钩子:身后画(在后腿之前)/身前画(最后)
    def behind(self, c, g, p):
        pass

    def front(self, c, g, p):
        pass

    # ---------------------------------------------------------- 画
    @property
    def FOOT(self):
        return self.H - 1

    def knee(self, hx, hy, fx, fy):
        dx, dy = fx - hx, fy - hy
        d = max(0.01, math.hypot(dx, dy))
        d2 = min(d, self.THIGH + self.SHIN - 0.01)
        a = (self.THIGH ** 2 - self.SHIN ** 2 + d2 ** 2) / (2 * d2)
        hgt = math.sqrt(max(0.0, self.THIGH ** 2 - a ** 2))
        mx, my = hx + dx * a / d, hy + dy * a / d
        px, py = -dy / d, dx / d
        if px < 0:
            px, py = -px, -py
        return mx + px * hgt, my + py * hgt

    def leg(self, c, hx, hy, fx, lift, cols, boots, tuck=0.0):
        F = self.FOOT
        ay = F - 1 - lift
        if tuck:
            # 收腿:脚往胯下面收(跳/落时用)
            fx = lerp(fx, hx + 1, tuck)
        kx, ky = self.knee(hx, hy, fx, ay)
        pts = line_pts(hx, hy, kx, ky) + line_pts(kx, ky, fx, ay)
        for (x, y) in pts:
            put(c, x, y, cols[0])
            if self.LEG_W > 1:
                put(c, x + 1, y, cols[1])
        by = F - lift
        bx = int(round(fx))
        put(c, bx - 1, by, boots[1])
        put(c, bx, by, boots[0])
        put(c, bx + 1, by, boots[0])
        put(c, bx + 2, by, boots[1])
        put(c, bx + 1, ay, boots[1])

    def tail(self, c, nx, ny, sway, phase, up=0.0):
        for i in range(1, self.TAIL_LEN + 1):
            base = lerp(100, 175, sway)
            base = lerp(base, 220, up)                     # up=1 往上飘(下落时)
            ang = math.radians(base + math.sin(phase + i * 1.3) * 10 * max(sway, up))
            x = nx + math.cos(ang) * i * 1.05
            y = ny + math.sin(ang) * i * (1.0 - 0.6 * sway * (1 - up))
            put(c, round(x), round(y), self.pal['R'] if i == 1 else self.pal['r'])

    def upper(self, c, ox, top, shear):
        rows = len(self.UPPER)
        for y, r in enumerate(self.UPPER):
            dx = int(round(shear * (rows - 1 - y)))
            for x, ch in enumerate(r):
                if ch != '.':
                    put(c, ox + x + dx, top + y, self.pal[ch])

    def arm(self, c, sx, sy, hx, hy):
        for (x, y) in line_pts(sx, sy, hx, hy):
            put(c, x, y, self.pal['3'])
            put(c, x, y + 1, self.pal['4'])
        put(c, hx, hy, self.pal['K'])
        put(c, hx, hy + 1, self.pal['k'])

    def render(self, p):
        c = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        F = self.FOOT
        ox = self.BASE_X + round(p['dx'])
        dy = round(p['dy'])
        rows = len(self.UPPER)
        hip_y = F - self.LEG_LEN + dy - round(p.get('air', 0))
        top = hip_y - rows + 1
        shear = p['shear']

        def shx(y):
            return int(round(shear * (rows - 1 - y)))
        g = dict(ox=ox, top=top, hip_y=hip_y, shx=shx, rows=rows, F=F)
        g['sx'] = ox + self.SHOULDER[0] + shx(self.SHOULDER[1])
        g['sy'] = top + self.SHOULDER[1]
        g['hx'] = g['sx'] + round(p['hand'][0])
        g['hy'] = g['sy'] + round(p['hand'][1])
        air = round(p.get('air', 0))
        tuck = p.get('tuck', 0.0)
        self.behind(c, g, p)
        self.leg(c, ox + self.HIP_BACK, hip_y, ox + self.HIP_BACK + p['foot_back'],
                 round(p['lift_back']) + air, LEG_BACK, BOOT_BACK, tuck)
        self.tail(c, ox + self.NECK_BACK[0] + shx(self.NECK_BACK[1]), top + self.NECK_BACK[1],
                  p['tail'], p['tail_phase'], p.get('tail_up', 0.0))
        self.upper(c, ox, top, shear)
        hem = self.HEMS[p['hem']]
        hsx = int(round(-shear * 0.6))
        for y, r in enumerate(hem):
            for x, ch in enumerate(r):
                if ch != '.':
                    put(c, ox + x + hsx, top + rows + y, self.pal[ch])
        self.leg(c, ox + self.HIP_FRONT, hip_y + 1, ox + self.HIP_FRONT + p['foot_front'],
                 round(p['lift_front']) + air, LEG_FRONT, BOOT_FRONT, tuck)
        for y, r in enumerate(hem[:2]):
            for x, ch in enumerate(r):
                if ch != '.' and x >= self.HEM_FRONT_FROM:
                    put(c, ox + x + hsx, top + rows + y, self.pal[ch])
        self.front(c, g, p)
        for (ex, ey, k) in p.get('dust', []):
            put(c, ex, ey, DUST[k % 2])
        return c

    # ---------------------------------------------------------- 姿势
    DEFAULT = dict(dx=0, dy=0, shear=0.0, hand=(2, 5), foot_front=2, foot_back=-1, lift_front=0, lift_back=0,
                   tail=0.0, tail_phase=0.0, hem=0)

    def pose(self, **kw):
        d = dict(self.DEFAULT); d.update(kw); return d

    # 通用:下落(往下掉,大衣往上翻,围巾往上飘)和落地(蹲一下,扬灰)
    def fall_anim(self, **kw):
        fr = []
        for i in range(4):
            fr.append(self.pose(air=3, tuck=0.6, shear=-0.05, hem=1, tail=0.3, tail_up=1.0, tail_phase=i * 1.7,
                                foot_front=2, foot_back=-2, lift_front=1 + (i % 2), lift_back=i % 2, **kw))
        return fr

    def land_anim(self, **kw):
        F = self.FOOT
        cx = self.BASE_X + 6
        def dust(r):
            pts = []
            for s in (-1, 1):
                for k in range(3):
                    pts.append((cx + s * (r + k * 2), F - (k % 2), k))
            return pts
        k = [
            self.pose(dy=3, shear=0.25, hem=1, tail=0.5, tail_up=0.6, foot_front=3, foot_back=-3, dust=dust(5)),
            self.pose(dy=2, shear=0.2, hem=1, tail=0.4, tail_up=0.3, foot_front=3, foot_back=-3, dust=dust(8)),
            self.pose(dy=1, shear=0.1, tail=0.3, foot_front=3, foot_back=-2, dust=dust(11)),
            self.pose(dy=0, shear=0.05, tail=0.2, foot_front=2, foot_back=-1),
        ]
        for p in k:
            p.update(kw)
        return k


# ================================================================ 收钱小弟
class Thug(Spec):
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
    HEMS = [
        ["..5443.221..", "..5.4...21..", "..5........."],
        [".55443.221..", "5.54.3..2...", "5..........."],
    ]
    DEFAULT = dict(Spec.DEFAULT, pipe=55, pipe_len=10, pipe_back=2, pipe_behind=False, arm=True)

    def pipe(self, c, g, p):
        hx, hy = g['hx'], g['hy']
        ang = p['pipe']
        L, back = p['pipe_len'], p['pipe_back']
        if ang == 'drag':
            reach = g['F'] - hy
            ang = 180 - math.degrees(math.asin(max(-1, min(1, reach / (L - back)))))
        a = math.radians(ang)
        ux, uy = math.cos(a), math.sin(a)
        pts = line_pts(hx - ux * back, hy - uy * back, hx + ux * (L - back), hy + uy * (L - back))
        for i, (x, y) in enumerate(pts):
            put(c, x, y, PIPE[1] if i % 4 == 2 else PIPE[0])
        put(c, *pts[-1], PIPE[2])
        g['tip'] = pts[-1]

    def smear(self, c, g, p):
        if not p.get('smear'):
            return
        a0, a1 = p['smear']
        r = p['pipe_len'] - p['pipe_back']
        for rr, col, skip in ((r, SMEAR[0], 0.0), (r - 1, SMEAR[1], 0.3), (r - 2, SMEAR[1], 0.55)):
            for k in range(80):
                t = k / 79
                if t < skip:
                    continue
                a = math.radians(a0 + (a1 - a0) * t)
                put(c, round(g['hx'] + math.cos(a) * rr), round(g['hy'] + math.sin(a) * rr), col)

    def behind(self, c, g, p):
        self.smear(c, g, p)
        if p['pipe_behind']:
            self.pipe(c, g, p)

    def front(self, c, g, p):
        if not p['pipe_behind']:
            self.pipe(c, g, p)
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        for (k, (ex, ey)) in enumerate(p.get('sparks', [])):
            tx, ty = g.get('tip', (0, 0))
            put(c, tx + ex, ty + ey, SPARK[min(k, 2)])

    def anims(self):
        P = self.pose
        idle = []
        for i in range(8):
            t = i / 8
            breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi)
            tap = max(0.0, math.sin(t * 2 * math.pi * 2 - 0.6))
            idle.append(P(dy=round(breath), hand=(2, 5 - round(tap)), pipe=55 - tap * 9,
                          tail=0.15 + 0.1 * breath, tail_phase=t * 6.28))
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 3.2 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.6
            fbx, fbl = 3.2 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.6
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            sparks = [(0, -1), (-1, -2), (1, -3)] if i in (0, 4) else ([(-2, -3), (0, -4)] if i in (1, 5) else [])
            walk.append(P(dy=dy, shear=0.22, hand=(-4, 5), pipe='drag', pipe_len=12, pipe_back=1, pipe_behind=True,
                          arm=False, foot_front=1 + ffx, lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl,
                          tail=0.75, tail_phase=ph * 12.6, hem=1 if i % 4 in (0, 1) else 0, sparks=sparks))
        alert = [
            P(), P(dy=-1, shear=-0.1, hand=(2, 4), pipe=50, tail=0.3),
            P(dy=-1, shear=-0.05, hand=(3, 2), pipe=20, pipe_back=1, tail=0.3),
            P(shear=0.2, hand=(4, 1), pipe=-10, pipe_back=1, tail=0.5, foot_front=3),
            P(shear=0.3, hand=(5, 0), pipe=-14, pipe_back=1, tail=0.7, foot_front=3),
            P(shear=0.25, hand=(4, 1), pipe=-8, pipe_back=1, tail=0.6, foot_front=3),
            P(shear=0.3, hand=(5, 0), pipe=-14, pipe_back=1, tail=0.7, foot_front=3),
            P(shear=0.25, hand=(4, 1), pipe=-8, pipe_back=1, tail=0.6, foot_front=3),
        ]
        attack = [
            P(hand=(2, 4), pipe=40, tail=0.2),
            P(dy=-1, shear=-0.05, hand=(3, 1), pipe=0, pipe_back=1, tail=0.25),
            P(dy=-1, shear=-0.15, hand=(2, -2), pipe=-60, pipe_back=1, tail=0.3, foot_back=-3),
            P(shear=-0.22, hand=(0, -5), pipe=-112, pipe_back=1, pipe_behind=True, tail=0.35, foot_back=-4, foot_front=2),
            P(dy=1, shear=-0.3, dx=-1, hand=(-1, -5), pipe=-138, pipe_back=1, pipe_behind=True, tail=0.4, foot_back=-4, foot_front=2),
            P(dy=1, shear=-0.32, dx=-1, hand=(-1, -5), pipe=-142, pipe_back=1, pipe_behind=True, tail=0.45, foot_back=-4, foot_front=2),
            P(shear=0.15, dx=1, hand=(3, -3), pipe=-70, pipe_back=1, tail=0.8, hem=1, foot_back=-4, foot_front=4, smear=(-160, -75)),
            P(shear=0.45, dx=2, hand=(5, -1), pipe=-8, pipe_back=1, tail=1.0, hem=1, foot_back=-5, foot_front=5, smear=(-110, -10)),
            P(dy=1, shear=0.55, dx=3, hand=(4, 3), pipe=52, pipe_back=1, tail=1.0, hem=1, foot_back=-5, foot_front=5,
              smear=(-35, 50), sparks=[(1, -1), (2, -2), (-1, -2)]),
            P(dy=1, shear=0.5, dx=3, hand=(4, 4), pipe=66, pipe_back=1, tail=0.8, hem=1, foot_back=-5, foot_front=5),
            P(shear=0.3, dx=2, hand=(3, 4), pipe=62, pipe_back=2, tail=0.5, foot_back=-3, foot_front=4),
            P(shear=0.1, dx=1, hand=(2, 5), pipe=57, tail=0.3, foot_back=-2, foot_front=3),
        ]
        for lst in (alert, attack):
            for i, p in enumerate(lst):
                p['tail_phase'] = i * 1.2
        fall = self.fall_anim(hand=(1, -4), pipe=-100, pipe_back=1)
        land = self.land_anim(hand=(4, 3), pipe=60, pipe_back=1)
        land[-1].update(hand=(2, 5), pipe=55, pipe_back=2)
        return dict(Idle=idle, Walk=walk, Alert=alert, Attack=attack, Fall=fall, Land=land)


SPECS = {'thug': Thug}

# ================================================================ 刀仔:矮、快、尖帽兜、长围巾,反手握一把短刀
class Knife(Spec):
    UPPER = [
        "....jhhh....",
        "...jhHHHh...",
        "..jhhHHHHhh.",
        "..jjhHjeeen.",
        "..jjhhjee...",
        "...jjhj.....",
        "..rRRRRR....",
        "..r432R1....",
        "...54321....",
        "...54321....",
        "..544321....",
    ]
    SHOULDER = (6, 7)
    HIP_FRONT, HIP_BACK = 5, 3
    HEMS = [
        ["..5443.21...", "..5.4..2....", "..5........."],
        [".55443.21...", "5.54.3.2....", "5..........."],
    ]
    TAIL_LEN = 6
    DEFAULT = dict(Spec.DEFAULT, knife=110, glint=0, streak=0, slash=None, arm=True)

    def front(self, c, g, p):
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        a = math.radians(p['knife'])
        ux, uy = math.cos(a), math.sin(a)
        hx, hy = g['hx'], g['hy']
        for i in range(1, 4):
            put(c, round(hx + ux * i), round(hy + uy * i), STEEL[0] if i < 3 else STEEL[1])
        tx, ty = round(hx + ux * 3), round(hy + uy * 3)
        if p['glint']:
            put(c, tx, ty, '#ffffff')
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(c, tx + dx, ty + dy, '#f0f4ff')
            if p['glint'] > 1:
                for (dx, dy) in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                    put(c, tx + dx, ty + dy, '#c8d0e0')

    def behind(self, c, g, p):
        # 冲刺拖出来的速度线
        for k in range(min(2, p['streak'])):
            y = g['top'] + 5 + k * 6
            x1 = g['ox'] + 1 - k * 2
            for x in range(x1 - 4 - p['streak'] * 2, x1):
                if (x + k * 2) % 4 != 0:
                    put(c, x, y, '#9a8a74' if x > x1 - 4 else '#6e6252')
        if p['slash']:
            a0, a1, r = p['slash']
            for rr, col in ((r, SMEAR[0]), (r - 1, SMEAR[1])):
                for k in range(60):
                    t = k / 59
                    a = math.radians(a0 + (a1 - a0) * t)
                    put(c, round(g['sx'] + math.cos(a) * rr), round(g['sy'] + math.sin(a) * rr), col)

    def anims(self):
        P = self.pose
        idle = []
        for i in range(8):
            bounce = i % 2
            idle.append(P(dy=bounce, shear=0.2, hand=(2, 3 + bounce), knife=100 + 10 * (i % 4 == 0),
                          tail=0.3 + 0.1 * bounce, tail_phase=i * 0.8, foot_front=3, foot_back=-2))
        run = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 4 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 2.2
            fbx, fbl = 4 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 2.2
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            run.append(P(dy=dy + 1, shear=0.45, hand=(1, 4), knife=150, foot_front=2 + ffx, lift_front=ffl,
                         foot_back=-1 + fbx, lift_back=fbl, tail=1.0, tail_phase=ph * 12.6, hem=1))
        attack = [
            P(dy=1, shear=0.3, hand=(1, 3), knife=120, tail=0.4, foot_front=3, foot_back=-2),
            P(dy=2, shear=0.5, hand=(-1, 3), knife=150, tail=0.5, foot_front=4, foot_back=-4),          # 蹲
            P(dy=3, shear=0.6, hand=(-2, 2), knife=170, tail=0.6, foot_front=4, foot_back=-5, glint=1), # 刀光一闪(前摇)
            P(dy=3, shear=0.6, hand=(-2, 2), knife=170, tail=0.6, foot_front=4, foot_back=-5, glint=2),
            P(dy=2, shear=0.7, hand=(3, 1), knife=20, tail=1.0, hem=1, foot_front=6, foot_back=-6, lift_back=1,
              streak=3, slash=(-60, 40, 7)),                                                         # 冲 + 划
            P(dy=2, shear=0.7, hand=(5, 2), knife=40, tail=1.0, hem=1, foot_front=6, foot_back=-6, streak=3,
              slash=(-20, 70, 7)),
            P(dy=2, shear=0.6, hand=(5, 3), knife=70, tail=1.0, hem=1, foot_front=6, foot_back=-6, streak=2),
            P(dy=2, shear=0.3, hand=(4, 3), knife=80, tail=0.8, foot_front=6, foot_back=-5,
              dust=[(self.BASE_X + 13, 27, 0), (self.BASE_X + 15, 26, 1), (self.BASE_X + 17, 27, 0)]),   # 刹住
            P(dy=1, shear=0.1, hand=(3, 3), knife=90, tail=0.6, foot_front=5, foot_back=-4,
              dust=[(self.BASE_X + 16, 26, 1), (self.BASE_X + 19, 27, 0)]),
            P(dy=1, shear=0.0, hand=(2, 3), knife=100, tail=0.4, foot_front=4, foot_back=-3),
            P(dy=1, shear=0.1, hand=(2, 3), knife=100, tail=0.35, foot_front=3, foot_back=-2),
            P(dy=0, shear=0.2, hand=(2, 3), knife=100, tail=0.3, foot_front=3, foot_back=-2),
        ]
        for i, p in enumerate(attack):
            p['tail_phase'] = i * 1.3
        # 往后蹦一下拉开距离(6 帧):起跳-空中-落
        hop = [
            P(dy=2, shear=0.3, hand=(1, 3), knife=120, tail=0.5, foot_front=3, foot_back=-2),
            P(air=3, tuck=0.5, shear=-0.2, hand=(0, 1), knife=140, tail=0.6, tail_up=0.5, foot_front=1, foot_back=-1),
            P(air=5, tuck=0.8, shear=-0.3, hand=(0, 0), knife=150, tail=0.6, tail_up=0.8, foot_front=1, foot_back=-1),
            P(air=3, tuck=0.6, shear=-0.2, hand=(0, 1), knife=140, tail=0.5, tail_up=0.6, foot_front=2, foot_back=-1),
            P(dy=2, shear=0.3, hand=(1, 3), knife=120, tail=0.4, foot_front=3, foot_back=-3),
            P(dy=1, shear=0.2, hand=(2, 3), knife=100, tail=0.3, foot_front=3, foot_back=-2),
        ]
        fall = self.fall_anim(hand=(1, -2), knife=150)
        land = self.land_anim(hand=(2, 3), knife=100)
        return dict(Idle=idle, Run=run, Attack=attack, Hop=hop, Fall=fall, Land=land)


# ================================================================ 井盖盾兵:块头大,前面举一块井盖,后手一根钢筋
IRON = dict(rim='#6a6c6e', a='#4e5054', b='#3c3e42', c='#2c2e32', rust='#6e4a34', pat='#26282b')


class Shield(Spec):
    W, H = 40, 30
    BASE_X = 10
    UPPER = [
        ".....jhh......",
        "....jhHHh.....",
        "....jhHHHh....",
        "...jjhHjeen...",
        "...jjhhjee....",
        "....jjhhj.....",
        "..rRRRRRRR....",
        ".5r43322R11...",
        ".54433222111..",
        ".54433222211..",
        ".544332222111.",
        ".544333222211.",
        ".54443332222..",
        "..5444332222..",
    ]
    SHOULDER = (8, 8)
    NECK_BACK = (2, 6)
    HIP_FRONT, HIP_BACK = 7, 4
    LEG_LEN = 7
    HEMS = [
        ["..54443.3221.", "..5.44..3.21.", "..5.....3...."],
        [".554443.3221.", "5.5.44..3.2..", "5............"],
    ]
    HEM_FRONT_FROM = 7
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 3), shield=(4, 3), spear=0, spear_out=0, shield_shake=0, clang=0, arm=True)

    def disc(self, c, cx, cy):
        rx, ry = 3.6, 6.6
        for y in range(-7, 8):
            for x in range(-4, 5):
                d = (x / rx) ** 2 + (y / ry) ** 2
                if d > 1.0:
                    continue
                if d > 0.62:
                    col = IRON['rim'] if (y < 0 and x <= 0) else IRON['b']
                    if y > 2:
                        col = IRON['c']
                else:
                    # 井盖花纹:中间一圈 + 格子
                    col = IRON['a'] if y < 0 else IRON['b']
                    if abs(d - 0.3) < 0.08 or (x == 0 and y % 2 == 0) or (y == 0 and x % 2 == 0):
                        col = IRON['pat']
                put(c, cx + x, cy + y, col)
        for (x, y) in ((1, 3), (2, 2), (-2, 4), (1, -4)):
            put(c, cx + x, cy + y, IRON['rust'])

    def behind(self, c, g, p):
        # 钢筋:后手握着,从盾后面伸出来
        sx, sy = g['sx'] - 3, g['sy'] + 1
        L = 12 + p['spear_out']
        ang = math.radians(p['spear'])
        hx = sx + p['spear_out']
        pts = line_pts(hx - 4 * math.cos(ang), sy - 4 * math.sin(ang), hx + L * math.cos(ang), sy + L * math.sin(ang))
        for i, (x, y) in enumerate(pts):
            put(c, x, y, PIPE[1] if i % 3 == 1 else PIPE[0])
        tx, ty = pts[-1]
        put(c, tx, ty, STEEL[0])
        if p['spear_out'] > 4:
            for k in range(3, 9):
                put(c, tx - k - 2, ty - 1, SMEAR[1] if k % 2 else SMEAR[0])
                put(c, tx - k - 2, ty + 1, SMEAR[1])

    def front(self, c, g, p):
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        cx = g['sx'] + p['shield'][0] - p['shield_shake']
        cy = g['sy'] + p['shield'][1]
        self.disc(c, cx, cy)
        if p['clang']:
            for (dx, dy, k) in ((5, -3, 0), (6, -5, 1), (6, 0, 1), (7, -2, 2), (5, 3, 2)):
                put(c, cx + dx, cy + dy, SPARK[k])

    def anims(self):
        P = self.pose
        idle = []
        for i in range(8):
            t = i / 8
            breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi)
            idle.append(P(dy=round(breath), shield=(4, 3 + round(breath)), spear=-8, tail=0.15, tail_phase=t * 6.28))
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 2.6 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.2
            fbx, fbl = 2.6 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.2
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            walk.append(P(dy=dy, shear=0.12, shield=(4, 3 + dy), spear=-8, foot_front=2 + ffx, lift_front=ffl,
                          foot_back=-1 + fbx, lift_back=fbl, tail=0.4, tail_phase=ph * 12.6))
        attack = [
            P(shield=(4, 3), spear=-8, tail=0.2),
            P(dx=-1, shield=(3, 4), spear=-4, spear_out=-2, tail=0.25, foot_back=-3),
            P(dx=-1, dy=1, shear=-0.1, shield=(3, 4), spear=-2, spear_out=-4, tail=0.3, foot_back=-3),   # 往回收(前摇)
            P(dx=-1, dy=1, shear=-0.1, shield=(3, 4), spear=-2, spear_out=-4, tail=0.3, foot_back=-3),
            P(dx=1, shear=0.25, shield=(4, 3), spear=0, spear_out=9, tail=0.8, hem=1, foot_front=4, foot_back=-4),  # 捅(判定)
            P(dx=1, shear=0.3, shield=(4, 3), spear=0, spear_out=11, tail=0.9, hem=1, foot_front=4, foot_back=-4),
            P(dx=1, shear=0.25, shield=(4, 3), spear=0, spear_out=10, tail=0.7, foot_front=4, foot_back=-4),
            P(shear=0.15, shield=(4, 3), spear=-3, spear_out=5, tail=0.5, foot_front=3, foot_back=-3),
            P(shear=0.05, shield=(4, 3), spear=-6, spear_out=1, tail=0.3, foot_front=2, foot_back=-2),
            P(shield=(4, 3), spear=-8, tail=0.2),
        ]
        block = [
            P(dx=-1, shield=(4, 3), shield_shake=1, spear=-8, clang=1, tail=0.4),
            P(dx=-1, shield=(4, 3), shield_shake=1, spear=-8, tail=0.3),
            P(shield=(4, 3), spear=-8, tail=0.2),
        ]
        for lst in (attack, block):
            for i, p in enumerate(lst):
                p['tail_phase'] = i * 1.1
        fall = self.fall_anim(shield=(3, 1), spear=-30)
        land = self.land_anim(shield=(4, 4), spear=-8)
        return dict(Idle=idle, Walk=walk, Attack=attack, Block=block, Fall=fall, Land=land)


SPECS.update(knife=Knife, shield=Shield)


# ================================================================ 扔瓶子的:背一麻袋瓶子,站远了往你头上扔
GLASS = ['#7aa088', '#3e5a44', '#28382c']
SACK = ['#5a4632', '#463626', '#33271b']


def bottle(c, x, y, ang=0):
    """瓶子:3 格瓶身 + 1 格瓶颈,ang 0=瓶口朝上"""
    a = math.radians(ang - 90)
    ux, uy = math.cos(a), math.sin(a)
    for i, col in ((0, GLASS[2]), (1, GLASS[1]), (2, GLASS[0]), (3, GLASS[1])):
        put(c, round(x + ux * i), round(y + uy * i), col)
    put(c, round(x + ux * 1 + 1), round(y + uy * 1), GLASS[2])


class Thrower(Thug):
    DEFAULT = dict(Spec.DEFAULT, hand=(2, 4), bottle_ang=0, has_bottle=True, arm=True, swing=None)

    def behind(self, c, g, p):
        # 背上的麻袋,露几个瓶口
        bx = g['ox'] + g['shx'](8) + 0
        by = g['top'] + 7
        rows = ["..ss...", ".sSSs..", "sSSSSs.", "sSSSSSs", "sSSSSSs", ".sSSSs.", "..sss.."]
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch != '.':
                    put(c, bx + x - 3, by + y, SACK[0] if ch == 'S' and y < 3 else (SACK[1] if ch == 'S' else SACK[2]))
        for (x, y) in ((-1, -1), (1, -2), (2, -1)):
            put(c, bx + x, by + y, GLASS[1]); put(c, bx + x, by + y - 1, GLASS[0])
        if p['swing']:
            a0, a1 = p['swing']
            for k in range(50):
                t = k / 49
                a = math.radians(a0 + (a1 - a0) * t)
                put(c, round(g['sx'] + math.cos(a) * 6), round(g['sy'] + math.sin(a) * 6), SMEAR[0] if t > 0.4 else SMEAR[1])

    def front(self, c, g, p):
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        if p['has_bottle']:
            bottle(c, g['hx'], g['hy'] - 1, p['bottle_ang'])

    def anims(self):
        P = self.pose
        idle = []
        toss = [0, 1, 3, 4, 3, 1, 0, 0]
        for i in range(8):
            idle.append(P(dy=1 if i in (3, 4, 5) else 0, hand=(3, 4 - min(toss[i], 2)), bottle_ang=toss[i] * 45,
                          tail=0.15, tail_phase=i * 0.8))
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 3.0 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.5
            fbx, fbl = 3.0 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.5
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            walk.append(P(dy=dy, shear=0.18, hand=(2 + round(math.sin(2 * math.pi * ph)), 5), foot_front=1 + ffx,
                          lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl, tail=0.6, tail_phase=ph * 12.6,
                          hem=1 if i % 4 in (0, 1) else 0))
        throw = [
            P(hand=(2, 4), tail=0.2, has_bottle=False),
            P(shear=-0.05, hand=(-2, 0), tail=0.25, has_bottle=False),                         # 伸手到背后摸瓶
            P(shear=-0.1, hand=(-3, -2), tail=0.3, bottle_ang=-30),
            P(dy=-1, shear=-0.2, hand=(-2, -5), tail=0.35, bottle_ang=-60, foot_back=-3),      # 举
            P(dy=0, shear=-0.3, dx=-1, hand=(-3, -6), tail=0.4, bottle_ang=-120, foot_back=-4), # 拉满(前摇)
            P(dy=0, shear=-0.32, dx=-1, hand=(-3, -6), tail=0.45, bottle_ang=-130, foot_back=-4),
            P(shear=0.2, dx=1, hand=(3, -5), tail=0.8, bottle_ang=40, hem=1, foot_front=4, foot_back=-4,
              swing=(-150, -50)),                                                              # 甩
            P(shear=0.35, dx=1, hand=(5, -1), tail=1.0, has_bottle=False, hem=1, foot_front=4, foot_back=-4,
              swing=(-80, -10)),                                                               # 出手(这帧生成瓶子)
            P(shear=0.25, dx=1, hand=(4, 2), tail=0.7, has_bottle=False, foot_front=3, foot_back=-3),
            P(shear=0.1, hand=(2, 4), tail=0.4, has_bottle=False, foot_front=2, foot_back=-2),
        ]
        for i, p in enumerate(throw):
            p['tail_phase'] = i * 1.2
        fall = self.fall_anim(hand=(1, -3), bottle_ang=0)
        land = self.land_anim(hand=(3, 3), bottle_ang=20)
        return dict(Idle=idle, Walk=walk, Throw=throw, Fall=fall, Land=land)


# ================================================================ 大块头:驼成一座小山,头很小,扛一把大扳手
WRENCH = ['#8a8478', '#5e5a52', '#3e3b36', '#7e4428']


class Brute(Spec):
    W, H = 52, 38
    BASE_X = 14
    UPPER = [
        ".......554.........",
        ".....55544332......",
        "...555444333221....",
        "..5554443332222jhh.",
        "..554443432222jhHHh",
        ".5544434332221jhHHh",
        ".554443433222jjjeen",
        ".5544434332221Ree..",
        ".554443433RRRRRR...",
        ".55444343322R2211..",
        ".554443433222222111",
        ".5544434332222221K.",
        "..54443433222221...",
        "..55443433222221...",
        "...5443433222221...",
        "...544343322221....",
        "...54434332221.....",
    ]
    SHOULDER = (14, 9)
    NECK_BACK = (13, 7)
    HIP_FRONT, HIP_BACK = 9, 5
    LEG_LEN = 9
    THIGH = SHIN = 4.6
    HEMS = [
        ["...5443.3222....", "...5.44..3.2....", "...5.....3......"],
        ["..55443.3222....", ".5.5.44..3.2....", ".5..............."],
    ]
    HEM_FRONT_FROM = 9
    TAIL_LEN = 5
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 7), wrench=70, wrench_behind=False, smash=None, quake=0, arm=True,
                   foot_front=3, foot_back=-2)

    def leg(self, c, hx, hy, fx, lift, cols, boots, tuck=0.0):
        super().leg(c, hx, hy, fx, lift, cols, boots, tuck)
        super().leg(c, hx + 1, hy, fx + 1, lift, cols, boots, tuck)   # 粗腿

    def arm(self, c, sx, sy, hx, hy):
        for (x, y) in line_pts(sx, sy, hx, hy):
            put(c, x, y, self.pal['2'])
            put(c, x + 1, y, self.pal['3'])
            put(c, x, y + 1, self.pal['4'])
        put(c, hx, hy, self.pal['K']); put(c, hx + 1, hy, self.pal['K'])
        put(c, hx, hy + 1, self.pal['k']); put(c, hx + 1, hy + 1, self.pal['k'])

    def wrench(self, c, g, p):
        a = math.radians(p['wrench'])
        ux, uy = math.cos(a), math.sin(a)
        vx, vy = -uy, ux
        hx, hy = g['hx'], g['hy']
        L = 14
        for i in range(-2, L):
            for j, col in ((0, WRENCH[1]), (1, WRENCH[2])):
                x, y = hx + ux * i + vx * j, hy + uy * i + vy * j
                put(c, round(x), round(y), WRENCH[3] if (i % 6 == 3 and j == 0) else col)
        # 扳手头:一个粗"C",开口朝前
        head = ["..XXXX.",
                ".XXXXXX",
                "XXX....",
                "XX.....",
                "XXX....",
                ".XXXXXX",
                "..XXXX."]
        tx, ty = hx + ux * L, hy + uy * L
        for r, row in enumerate(head):
            for q, ch in enumerate(row):
                if ch != 'X':
                    continue
                j = r - 3
                x, y = tx + ux * q + vx * j, ty + uy * q + vy * j
                put(c, round(x), round(y), WRENCH[0] if j < 0 else (WRENCH[1] if j < 2 else WRENCH[2]))
        g['tip'] = (round(tx + ux * 4), round(ty + uy * 4))

    def behind(self, c, g, p):
        if p['smash']:
            a0, a1 = p['smash']
            for rr, col in ((18, SMEAR[0]), (17, SMEAR[1]), (16, SMEAR[1])):
                for k in range(90):
                    t = k / 89
                    a = math.radians(a0 + (a1 - a0) * t)
                    put(c, round(g['hx'] + math.cos(a) * rr), round(g['hy'] + math.sin(a) * rr), col)
        if p['wrench_behind']:
            self.wrench(c, g, p)

    def front(self, c, g, p):
        if not p['wrench_behind']:
            self.wrench(c, g, p)
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        if p['quake']:
            F = self.FOOT
            tx = g.get('tip', (g['hx'], F))[0]
            for k in range(p['quake'] * 3):
                for s in (-1, 1):
                    x = tx + s * (2 + k * 2)
                    put(c, x, F - (k % 2), DUST[k % 2])
                    if k < 3:
                        put(c, x, F - 1 - (k % 2), SPARK[min(k, 2)])

    def anims(self):
        P = self.pose
        idle = []
        for i in range(8):
            t = i / 8
            breath = 0.5 - 0.5 * math.cos(t * 2 * math.pi)
            idle.append(P(dy=round(breath * 2), hand=(3, 6 + round(breath)), wrench=34 - round(breath) * 4, tail=0.1, tail_phase=t * 6.28))
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 3.4 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.4
            fbx, fbl = 3.4 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.4
            dy = 2 if math.cos(4 * math.pi * ph) > 0.2 else 0
            walk.append(P(dy=dy, shear=0.1, hand=(2, 7), wrench=30 + dy * 3, foot_front=3 + ffx, lift_front=ffl,
                          foot_back=-2 + fbx, lift_back=fbl, tail=0.3, tail_phase=ph * 12.6))
        attack = [
            P(hand=(3, 6), wrench=34, tail=0.1),
            P(dy=1, hand=(3, 4), wrench=10, tail=0.15),
            P(dy=0, shear=-0.05, hand=(2, 0), wrench=-20, tail=0.2),
            P(dy=-1, shear=-0.12, hand=(1, -4), wrench=-70, tail=0.25, foot_back=-4),
            P(dy=-2, shear=-0.2, hand=(0, -8), wrench=-110, wrench_behind=True, tail=0.3, foot_back=-5),
            P(dy=-2, shear=-0.25, hand=(-1, -9), wrench=-140, wrench_behind=True, tail=0.35, foot_back=-5),   # 举到顶(前摇)
            P(dy=-2, shear=-0.27, hand=(-1, -9), wrench=-145, wrench_behind=True, tail=0.35, foot_back=-5),
            P(dy=-2, shear=-0.27, hand=(-1, -9), wrench=-147, wrench_behind=True, tail=0.35, foot_back=-5),
            P(dy=0, shear=0.2, hand=(5, -4), wrench=-40, tail=0.8, hem=1, foot_front=6, foot_back=-5,
              smash=(-150, -40)),                                                                       # 抡下来
            P(dy=3, shear=0.35, hand=(6, 4), wrench=60, tail=1.0, hem=1, foot_front=6, foot_back=-6, smash=(-60, 55),
              quake=1),                                                                                 # 砸地(判定+震波)
            P(dy=3, shear=0.35, hand=(6, 5), wrench=70, tail=0.9, hem=1, foot_front=6, foot_back=-6, quake=2),
            P(dy=2, shear=0.3, hand=(6, 5), wrench=72, tail=0.6, foot_front=6, foot_back=-6, quake=3),
            P(dy=1, shear=0.15, hand=(4, 6), wrench=45, tail=0.3, foot_front=4, foot_back=-4),
            P(dy=0, shear=0.0, hand=(3, 6), wrench=34, tail=0.15),
        ]
        for i, p in enumerate(attack):
            p['tail_phase'] = i * 1.0
        fall = self.fall_anim(hand=(1, -6), wrench=-100, wrench_behind=True)
        land = self.land_anim(hand=(4, 5), wrench=38)
        for p in land:
            p['quake'] = 0
        land[0]['quake'] = 2
        return dict(Idle=idle, Walk=walk, Attack=attack, Fall=fall, Land=land)


# ================================================================ 放哨的:平时缩成一个垃圾袋,看见人就站起来吹哨叫人,然后跑
BAG = ['#3a3d3a', '#2a2c2a', '#1c1d1c', '#5a5e58']


class Lookout(Knife):
    TAIL_LEN = 7
    DEFAULT = dict(Spec.DEFAULT, hand=(2, 4), whistle=0, bag=None, arm=True)

    def front(self, c, g, p):
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        if p['whistle']:
            # 手捂到嘴边,哨子一个亮点 + 往前一圈圈的声波
            mx, my = g['ox'] + 10 + g['shx'](3), g['top'] + 4
            put(c, mx, my, '#e8e0a0')
            for k in range(p['whistle']):
                r = 3 + k * 3
                for a in range(-40, 41, 10):
                    aa = math.radians(a)
                    put(c, round(mx + math.cos(aa) * r), round(my + math.sin(aa) * r), '#d8d0c0' if k == p['whistle'] - 1 else '#a09888')

    def behind(self, c, g, p):
        pass

    def render(self, p):
        if p.get('bag') is None:
            return super().render(p)
        # 垃圾袋:p['bag'] = (起伏, 冒头程度 0~1)
        c = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        breath, peek = p['bag']
        F = self.FOOT
        cx = self.BASE_X + 6
        h = 10 + breath
        for y in range(h):
            t = y / max(1, h - 1)
            half = int(round(1.5 + 4.5 * math.sin(min(1.0, t * 1.15) * math.pi * 0.62)))
            yy = F - (h - 1) + y
            for x in range(-half, half + 1):
                col = BAG[1]
                if x < -half + 2 or y > h - 3:
                    col = BAG[2]
                elif x > half - 2 and y < h - 3:
                    col = BAG[0]
                if y in (3, 4) and x == half - 2:
                    col = BAG[3]                     # 塑料反光
                put(c, cx + x, yy, col)
        # 扎口
        put(c, cx, F - h, BAG[2]); put(c, cx - 1, F - h - 1, BAG[1]); put(c, cx + 1, F - h - 1, BAG[0])
        if peek > 0:
            # 袋口里冒出一点红围巾
            put(c, cx + 2, F - h + 2, self.pal['r'])
            if peek > 0.5:
                put(c, cx + 3, F - h + 2, self.pal['R']); put(c, cx + 4, F - h + 3, self.pal['r'])
        return c

    def anims(self):
        P = self.pose
        bag = [P(bag=(b, 0)) for b in (0, 0, 0, 1, 1, 1, 0, 0)]
        reveal = [
            P(bag=(0, 0.3)), P(bag=(1, 0.8)),
            P(dy=4, shear=0.4, hand=(1, 2), tail=0.2, foot_front=2, foot_back=-2, hem=1),
            P(dy=2, shear=0.25, hand=(2, 3), tail=0.5, tail_up=0.4, foot_front=2, foot_back=-2, hem=1),
            P(dy=-1, shear=0.0, hand=(2, 3), tail=0.7, tail_up=0.5, foot_front=2, foot_back=-1),
            P(dy=0, shear=0.05, hand=(2, 4), tail=0.5, foot_front=2, foot_back=-1),
            P(dy=0, shear=0.1, hand=(2, 4), tail=0.35, foot_front=2, foot_back=-1),
            P(dy=0, shear=0.1, hand=(2, 4), tail=0.3, foot_front=2, foot_back=-1),
        ]
        idle = [P(dy=i % 2, shear=0.1, hand=(2, 4), tail=0.3, tail_phase=i * 0.9, foot_front=2, foot_back=-1)
                for i in range(6)]
        whistle = [
            P(shear=0.05, hand=(2, 2), tail=0.3),
            P(shear=0.0, dy=-1, hand=(3, -2), tail=0.35),
            P(shear=-0.1, dy=-1, hand=(3, -3), tail=0.5, whistle=1),
            P(shear=-0.15, dy=-1, hand=(3, -3), tail=0.7, tail_up=0.3, whistle=2),
            P(shear=-0.15, dy=-1, hand=(3, -3), tail=0.8, tail_up=0.4, whistle=3),
            P(shear=-0.1, dy=-1, hand=(3, -3), tail=0.8, tail_up=0.3, whistle=1),
            P(shear=-0.15, dy=-1, hand=(3, -3), tail=0.8, tail_up=0.4, whistle=2),
            P(shear=-0.15, dy=-1, hand=(3, -3), tail=0.8, tail_up=0.4, whistle=3),
            P(shear=0.0, dy=0, hand=(3, 0), tail=0.5),
            P(shear=0.1, hand=(2, 4), tail=0.35),
        ]
        for lst in (reveal, whistle):
            for i, p in enumerate(lst):
                p['tail_phase'] = i * 1.3
        run = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 4 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 2.2
            fbx, fbl = 4 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 2.2
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            run.append(P(dy=dy + 1, shear=0.45, hand=(-1 + round(2 * math.cos(2 * math.pi * ph)), 4),
                         foot_front=2 + ffx, lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl, tail=1.0,
                         tail_phase=ph * 12.6, hem=1))
        return dict(Bag=bag, Reveal=reveal, Idle=idle, Whistle=whistle, Run=run)


SPECS.update(thrower=Thrower, brute=Brute, lookout=Lookout)


# ================================================================ 链子小弟:收钱小弟的同伙,甩一根铁链子。
# 链子在头顶转两圈(前摇)再横着抽过去,够得远、在腰那么高 —— 要跳过去。
CHAIN = ['#9a9890', '#62605a', '#c8c4b8']


class Chain(Thug):
    DEFAULT = dict(Spec.DEFAULT, chain=(90, 9, 0), arm=True, ring=None)

    def chain(self, c, g, p):
        ang, L, curve = p['chain']
        x, y = float(g['hx']), float(g['hy'])
        for i in range(1, int(L) + 1):
            a = math.radians(ang + curve * i / max(1, L))
            x += math.cos(a)
            y += math.sin(a)
            put(c, round(x), round(y), CHAIN[i % 2])
        put(c, round(x), round(y), CHAIN[2])
        put(c, round(x) + 1, round(y), CHAIN[1])
        g['tip'] = (round(x), round(y))

    def behind(self, c, g, p):
        if p['ring']:
            # 头顶转圈的残影:一个扁圆
            cx, cy, r = g['hx'], g['hy'] - 2, p['ring']
            for k in range(36):
                a = math.radians(k * 10)
                put(c, round(cx + math.cos(a) * r), round(cy + math.sin(a) * r * 0.45), SMEAR[1] if k % 3 else SMEAR[0])
        if p.get('lash'):
            y = g['hy']
            for x in range(g['hx'] + 3, g['hx'] + p['lash']):
                if x % 3:
                    put(c, x, y - 1, SMEAR[1])
                    put(c, x, y + 1, SMEAR[1])

    def front(self, c, g, p):
        self.chain(c, g, p)
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])

    def anims(self):
        P = self.pose
        idle = []
        for i in range(8):
            t = i / 8
            sw = math.sin(t * 2 * math.pi)
            idle.append(P(dy=1 if i in (3, 4, 5) else 0, hand=(2, 5), chain=(90 - sw * 18, 9, sw * 20),
                          tail=0.15 + 0.05 * sw, tail_phase=t * 6.28))
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 3.2 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.6
            fbx, fbl = 3.2 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.6
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            walk.append(P(dy=dy, shear=0.2, hand=(0, 5), chain=(130 + 10 * math.sin(2 * math.pi * ph), 11, 40),
                          foot_front=1 + ffx, lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl, tail=0.7,
                          tail_phase=ph * 12.6, hem=1 if i % 4 in (0, 1) else 0))
        alert = []
        for i in range(6):
            alert.append(P(dy=-1 if i else 0, shear=-0.05, hand=(1, -5), chain=(-90 + i * 72, 8, 30), ring=7 if i > 1 else None,
                           tail=0.4, tail_phase=i * 1.3))
        attack = [P(hand=(2, 4), chain=(80, 9, 10), tail=0.2),
                  P(dy=-1, shear=-0.05, hand=(1, -2), chain=(30, 9, 20), tail=0.3)]
        for k in range(4):    # 头顶转两圈(前摇)
            attack.append(P(dy=-1, shear=-0.1, hand=(1, -6), chain=(-90 + k * 100 + 40, 9, 30), ring=8, tail=0.45,
                            foot_back=-3))
        attack += [
            P(shear=0.2, dx=1, hand=(4, -2), chain=(-25, 12, 30), ring=None, tail=0.8, hem=1, foot_front=4, foot_back=-4),
            P(shear=0.4, dx=2, hand=(5, 0), chain=(-2, 20, 4), lash=20, tail=1.0, hem=1, foot_front=5, foot_back=-5),   # 抽(判定)
            P(shear=0.4, dx=2, hand=(5, 1), chain=(4, 20, 6), lash=16, tail=1.0, hem=1, foot_front=5, foot_back=-5),    # 判定
            P(shear=0.3, dx=2, hand=(4, 2), chain=(30, 15, 40), tail=0.8, foot_front=4, foot_back=-4),
            P(shear=0.15, dx=1, hand=(3, 4), chain=(70, 11, 30), tail=0.5, foot_front=3, foot_back=-2),
            P(shear=0.05, hand=(2, 5), chain=(85, 9, 15), tail=0.3),
        ]
        for i, p in enumerate(attack):
            p['tail_phase'] = i * 1.2
        fall = self.fall_anim(hand=(1, -4), chain=(-120, 9, 40))
        land = self.land_anim(hand=(3, 3), chain=(70, 9, 20))
        land[-1].update(hand=(2, 5), chain=(90, 9, 0))
        return dict(Idle=idle, Walk=walk, Alert=alert, Attack=attack, Fall=fall, Land=land)


SPECS['chain'] = Chain


# ================================================================ 拿弩的:瘦,一条腿跪着端弩,弩是大王卖的货。
# 瞄准线(红)由游戏里画,贴图只管端弩/发射/上弦。
WOOD = ['#8a5a36', '#5e3c24', '#3e2818']


class Crossbow(Knife):
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 1), bow_ang=0, loaded=True, recoil=0, arm=True, string_back=0)

    def behind(self, c, g, p):
        pass

    def front(self, c, g, p):
        a = math.radians(p['bow_ang'])
        ux, uy = math.cos(a), math.sin(a)
        vx, vy = -uy, ux
        hx, hy = g['hx'] - p['recoil'], g['hy']
        # 弩身(木托)从肩到手前 7 格
        for i in range(-4, 5):
            put(c, round(hx + ux * i), round(hy + uy * i), WOOD[0] if i % 3 else WOOD[1])
            put(c, round(hx + ux * i + vx), round(hy + uy * i + vy), WOOD[2])
        # 弩臂:前头一道竖的弯弓
        fx, fy = hx + ux * 4, hy + uy * 4
        for j in range(-3, 4):
            bend = 1 if abs(j) == 3 else 0
            put(c, round(fx - ux * bend + vx * j), round(fy - uy * bend + vy * j), STEEL[1] if abs(j) < 3 else STEEL[2])
        # 弦:从弓两头往回拉
        sb = 2 + p['string_back']
        for j in (-3, 3):
            for (x, y) in line_pts(fx - ux + vx * j, fy - uy + vy * j, fx - ux * sb, fy - uy * sb):
                put(c, x, y, '#c8c0a8')
        if p['loaded']:
            for i in range(-1, 4):
                put(c, round(hx + ux * i - vx), round(hy + uy * i - vy), '#d8d0b8' if i < 3 else STEEL[0])
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'] - p['recoil'], g['hy'])

    def anims(self):
        P = self.pose
        idle = []
        for i in range(8):
            br = 1 if i in (3, 4, 5) else 0
            idle.append(P(dy=br, shear=0.1, hand=(2, 4), bow_ang=60, tail=0.25, tail_phase=i * 0.8, foot_front=2,
                          foot_back=-2))
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 3.2 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.6
            fbx, fbl = 3.2 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.6
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            walk.append(P(dy=dy, shear=0.25, hand=(1, 4), bow_ang=70, foot_front=1 + ffx, lift_front=ffl,
                          foot_back=-1 + fbx, lift_back=fbl, tail=0.8, tail_phase=ph * 12.6, hem=1))
        # 端起来瞄:单膝跪下(后脚往后收),弩端平;最后两帧不动(游戏里循环这两帧等瞄准)
        aim = [
            P(dy=1, shear=0.1, hand=(2, 3), bow_ang=40, tail=0.3, foot_front=3, foot_back=-3),
            P(dy=2, shear=0.15, hand=(3, 1), bow_ang=15, tail=0.3, foot_front=3, foot_back=-4),
            P(dy=3, shear=0.2, hand=(4, 0), bow_ang=2, tail=0.3, foot_front=4, foot_back=-5),
            P(dy=3, shear=0.2, hand=(4, 0), bow_ang=0, tail=0.35, foot_front=4, foot_back=-5),
        ]
        hold = [P(dy=3, shear=0.2, hand=(4, 0), bow_ang=0, tail=0.3 + 0.05 * (i % 2), tail_phase=i * 1.5,
                  foot_front=4, foot_back=-5) for i in range(4)]
        shoot = [
            P(dy=3, shear=0.1, hand=(4, 0), bow_ang=-4, recoil=2, loaded=False, string_back=-1, tail=0.6, foot_front=4, foot_back=-5),
            P(dy=3, shear=0.05, hand=(4, 0), bow_ang=-8, recoil=1, loaded=False, string_back=-1, tail=0.5, foot_front=4, foot_back=-5),
            P(dy=3, shear=0.1, hand=(4, 0), bow_ang=-3, loaded=False, string_back=-1, tail=0.4, foot_front=4, foot_back=-5),
            P(dy=3, shear=0.15, hand=(4, 0), bow_ang=0, loaded=False, string_back=-1, tail=0.3, foot_front=4, foot_back=-5),
        ]
        # 上弦:弩口朝下踩住,往回拉
        reload = [
            P(dy=2, shear=0.1, hand=(3, 3), bow_ang=50, loaded=False, string_back=-1, tail=0.3, foot_front=3, foot_back=-3),
            P(dy=1, shear=0.0, hand=(2, 5), bow_ang=85, loaded=False, string_back=-1, tail=0.3, foot_front=3, foot_back=-2),
            P(dy=1, shear=-0.1, hand=(1, 5), bow_ang=88, loaded=False, string_back=1, tail=0.35, foot_front=3, foot_back=-2),
            P(dy=1, shear=-0.15, hand=(0, 4), bow_ang=88, loaded=False, string_back=3, tail=0.35, foot_front=3, foot_back=-2),
            P(dy=1, shear=-0.1, hand=(1, 4), bow_ang=85, loaded=True, string_back=3, tail=0.3, foot_front=3, foot_back=-2),
            P(dy=1, shear=0.0, hand=(2, 4), bow_ang=70, loaded=True, tail=0.3, foot_front=2, foot_back=-2),
            P(dy=0, shear=0.1, hand=(2, 4), bow_ang=60, loaded=True, tail=0.25, foot_front=2, foot_back=-2),
            P(dy=0, shear=0.1, hand=(2, 4), bow_ang=60, loaded=True, tail=0.25, foot_front=2, foot_back=-2),
        ]
        for lst in (aim, shoot, reload):
            for i, p in enumerate(lst):
                p['tail_phase'] = i * 1.2
        fall = self.fall_anim(hand=(1, -2), bow_ang=-60)
        land = self.land_anim(hand=(2, 3), bow_ang=50)
        return dict(Idle=idle, Walk=walk, Aim=aim, Hold=hold, Shoot=shoot, Reload=reload, Fall=fall, Land=land)


# ================================================================ 滚桶的:块头中等,扛一只油桶,放下来一脚踹过去
BARREL = ['#5a6460', '#3e4644', '#2a302e', '#8a3a2c']


def barrel_side(c, cx, cy, ang=0.0):
    """油桶侧面(10×9 圆角长方),两道箍随 ang 往一边挪 = 在滚。锈红色,一眼看出是桶。"""
    body = ['#b0603e', '#8a4430', '#5e2a1c']
    hoop = '#3a2a22'
    w, h = 10, 9
    x0, y0 = cx - w // 2, cy - h // 2
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1)) and (y in (0, h - 1)):
                continue
            col = body[0] if y < 2 else (body[1] if y < h - 2 else body[2])
            put(c, x0 + x, y0 + y, col)
    # 箍:沿桶身一圈,滚动时往后挪
    off = (ang / (math.pi / 2)) * 3.0
    for k in range(3):
        hx = x0 + int(round((k * 4 + off) % 11)) - 1
        if 0 <= hx - x0 < w:
            for y in range(h):
                if not ((hx - x0) in (0, w - 1) and y in (0, h - 1)):
                    put(c, hx, y0 + y, hoop)
    put(c, x0 + 2, y0 + 1, '#d8905e')


class Roller(Thug):
    DEFAULT = dict(Spec.DEFAULT, hand=(2, 2), barrel=None, arm=True, kick=0)

    def behind(self, c, g, p):
        pass

    def front(self, c, g, p):
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        if p['barrel'] is not None:
            bx, by, ang = p['barrel']
            barrel_side(c, g['ox'] + bx, g['F'] + by, ang)

    def anims(self):
        P = self.pose
        # 扛着桶(桶在肩上)
        idle = [P(dy=1 if i in (3, 4, 5) else 0, hand=(1, -3), barrel=(6, -22 + (1 if i in (3, 4, 5) else 0), 0.3),
                  tail=0.2, tail_phase=i * 0.8) for i in range(8)]
        walk = []
        for i in range(8):
            ph = i / 8
            ffx, ffl = 3.0 * math.cos(2 * math.pi * ph), max(0.0, -math.sin(2 * math.pi * ph)) * 1.4
            fbx, fbl = 3.0 * math.cos(2 * math.pi * (ph + .5)), max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 1.4
            dy = 1 if math.cos(4 * math.pi * ph) > 0.2 else 0
            walk.append(P(dy=dy, shear=0.15, hand=(1, -3), barrel=(6, -22 + dy, 0.3), foot_front=1 + ffx,
                          lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl, tail=0.6, tail_phase=ph * 12.6))
        kick = [
            P(hand=(1, -3), barrel=(6, -22, 0.3), tail=0.2),
            P(dy=1, shear=0.15, hand=(3, 0), barrel=(10, -16, 0.6), tail=0.25),
            P(dy=2, shear=0.3, hand=(4, 4), barrel=(14, -5, 0.9), tail=0.3, foot_front=3),            # 放下
            P(dy=1, shear=0.1, hand=(2, 5), barrel=(14, -5, 0.9), tail=0.3, foot_front=1, foot_back=-3),
            P(dy=0, shear=-0.15, hand=(0, 4), barrel=(14, -5, 0.9), tail=0.35, foot_front=-1, foot_back=-3,
              lift_front=2),                                                                          # 抬脚(前摇)
            P(dy=0, shear=-0.2, hand=(-1, 4), barrel=(14, -5, 0.9), tail=0.4, foot_front=-2, foot_back=-3,
              lift_front=3),
            P(dy=0, shear=0.3, dx=1, hand=(3, 3), barrel=(16, -5, 1.4), tail=0.8, hem=1, foot_front=7, foot_back=-3,
              lift_front=2),                                                                          # 踹(这帧放出桶)
            P(dy=0, shear=0.25, dx=1, hand=(3, 4), barrel=None, tail=0.9, hem=1, foot_front=6, foot_back=-3, lift_front=1),
            P(dy=0, shear=0.1, hand=(2, 5), barrel=None, tail=0.6, foot_front=3, foot_back=-2),
            P(dy=0, shear=0.05, hand=(2, 5), barrel=None, tail=0.3, foot_front=2, foot_back=-1),
        ]
        # 从身后再摸出一只桶扛上肩
        fetch = [
            P(hand=(2, 5), barrel=None, tail=0.2),
            P(dy=1, shear=-0.1, hand=(-3, 4), barrel=(-4, -5, 0.0), tail=0.25),
            P(dy=2, shear=-0.15, hand=(-3, 2), barrel=(-4, -8, 0.0), tail=0.3),
            P(dy=1, shear=-0.05, hand=(-1, -1), barrel=(0, -15, 0.2), tail=0.3),
            P(dy=0, shear=0.0, hand=(1, -3), barrel=(5, -21, 0.3), tail=0.25),
            P(dy=0, shear=0.0, hand=(1, -3), barrel=(6, -22, 0.3), tail=0.2),
        ]
        for lst in (kick, fetch):
            for i, p in enumerate(lst):
                p['tail_phase'] = i * 1.2
        fall = self.fall_anim(hand=(1, -4), barrel=(6, -24, 0.3))
        land = self.land_anim(hand=(1, -3), barrel=(6, -20, 0.3))
        return dict(Idle=idle, Walk=walk, Kick=kick, Fetch=fetch, Fall=fall, Land=land)


SPECS.update(crossbow=Crossbow, roller=Roller)

def export_type(name, out_dir, preview_dir=None, prefix=None):
    spec = SPECS[name]()
    anims = spec.anims()
    os.makedirs(out_dir, exist_ok=True)
    prefix = prefix or name
    info = {}
    for an, poses in anims.items():
        fr = [spec.render(p) for p in poses]
        strip = Image.new('RGBA', (spec.W * len(fr), spec.H))
        for i, f in enumerate(fr):
            strip.alpha_composite(f, (i * spec.W, 0))
        strip.save(f'{out_dir}/{prefix}_{an.lower()}.png')
        info[an] = len(fr)
    if preview_dir:
        os.makedirs(preview_dir, exist_ok=True)
        cols = max(info.values())
        rows = len(info)
        sheet = Image.new('RGBA', (spec.W * cols, (spec.H + 2) * rows), (92, 76, 66, 255))
        for r, an in enumerate(anims):
            for i, p in enumerate(anims[an]):
                for x in range(spec.W):
                    sheet.putpixel((i * spec.W + x, r * (spec.H + 2) + spec.H), (150, 128, 96, 255))
                sheet.alpha_composite(spec.render(p), (i * spec.W, r * (spec.H + 2)))
        sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save(f'{preview_dir}/{name}_sheet_x5.png')
    return spec, info


if __name__ == '__main__':
    for n in sys.argv[2:]:
        print(n, export_type(n, sys.argv[1], sys.argv[1] + '/preview')[1])
