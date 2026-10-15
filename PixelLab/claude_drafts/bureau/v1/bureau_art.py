"""管道局(守序邪恶):粉发女王那一伙。照 queen.png 的画法——
藏青近黑的制服 + 金扣金领、蓝裤子膝上一道金箍、黑靴、浅粉皮肤点一只眼,不描边,色块两三档;
武器发粉光(女王的能量色)。和奥斯卡帮反着来:站得笔直、大檐帽、齐步走、动作干净利落。
朝右画,每帧 100ms。复用 gang_art 的 Spec(上身格子 + 两段腿 + 程序画武器)。"""
import math
from gang_art import Spec, put, line_pts, lerp, SMEAR, SPARK, DUST

NAVY = '#2b3d5a'
BPAL = dict(
    C='#3b4f74', c='#26324a', v='#16181f',                 # 帽子:亮/暗/帽檐
    G='#d2b46a', g='#9c8048',                              # 金
    h='#2e2224', S='#f3ccb5', s='#d6a896', e='#2a2838',    # 头发/皮肤/眼
    J='#2b2f37', j='#1f2228', L='#3d4450',                 # 制服:中/暗/亮边
    k='#18191d', K='#d2b46a',                              # 腰带/扣
    T='#4a5d7b', t='#2b3d5a', U='#6a7fa0',                 # 裤子:中/暗/亮
    P='#ffbcd7', p='#cf6c93', q='#91477a',                 # 粉色能量
    W='#f4efe4', w='#c9c1b0',                              # 纸(罚单/本子)
    M='#8a8e8c', m='#5a5e5e', N='#b07a46',                 # 金属刀片/暗/黄铜
)
BOOT = ('#1c1c22', '#121216')
PINK = ['#ffbcd7', '#cf6c93', '#91477a']


class Bureau(Spec):
    W, H = 36, 30
    BASE_X = 11
    UPPER = [
        "....cCCCc...",
        "...cCCCCCc..",
        "...gGGGGGvvv",
        "...hhhSSS...",
        "...hhhSeS...",
        "....hhsSs...",
        "....jjSj....",
        "...jJGGJL...",
        "..jjJJJGLL..",
        "..jjJJJJGL..",
        "...jJJJJGL..",
        "...jJJJJGL..",
        "...kkkKkkk..",
    ]
    SHOULDER = (7, 8)
    HIP_FRONT, HIP_BACK = 6, 4
    LEG_LEN = 11
    THIGH = SHIN = 5.0
    HEMS = [[], []]
    PAL = BPAL

    def __init__(self):
        super().__init__()
        self.pal.update(BPAL)

    def tail(self, c, nx, ny, sway, phase, up=0.0):
        pass

    def leg(self, c, hx, hy, fx, lift, cols, boots, tuck=0.0):
        F = self.FOOT
        ay = F - 1 - lift
        if tuck:
            fx = lerp(fx, hx + 1, tuck)
        kx, ky = self.knee(hx, hy, fx, ay)
        front = cols[0] == '#front'
        hi, lo = (self.pal['U'], self.pal['T']) if front else (self.pal['T'], self.pal['t'])
        thigh = line_pts(hx, hy, kx, ky)
        shin = line_pts(kx, ky, fx, ay)
        for (x, y) in thigh:
            put(c, x, y, hi)
            put(c, x + 1, y, lo)
        for i, (x, y) in enumerate(shin):
            boot = i >= len(shin) - 3
            put(c, x, y, BOOT[0] if boot else hi)
            put(c, x + 1, y, BOOT[1] if boot else lo)
        # 膝上一道金箍
        put(c, round(kx), round(ky) - 1, self.pal['G'])
        put(c, round(kx) + 1, round(ky) - 1, self.pal['g'])
        by = F - lift
        bx = int(round(fx))
        for dx, col in ((-1, BOOT[1]), (0, BOOT[0]), (1, BOOT[0]), (2, BOOT[1])):
            put(c, bx + dx, by, col)

    def render(self, p):
        # 前后腿用标记区分颜色(亮的在前)
        import gang_art as GA
        saved = (GA.LEG_FRONT, GA.LEG_BACK)
        GA.LEG_FRONT, GA.LEG_BACK = ('#front', ''), ('#back', '')
        try:
            return super().render(p)
        finally:
            GA.LEG_FRONT, GA.LEG_BACK = saved

    def arm(self, c, sx, sy, hx, hy):
        pts = line_pts(sx, sy, hx, hy)
        for i, (x, y) in enumerate(pts):
            put(c, x, y, self.pal['J'] if i < len(pts) - 2 else self.pal['G'])   # 袖口一圈金
            put(c, x, y + 1, self.pal['j'])
        put(c, hx, hy, self.pal['S'])
        put(c, hx, hy + 1, self.pal['s'])

    def stick(self, c, hx, hy, ang, length, body, tip_len=2, back=1, tip=PINK):
        a = math.radians(ang)
        ux, uy = math.cos(a), math.sin(a)
        pts = line_pts(hx - ux * back, hy - uy * back, hx + ux * (length - back), hy + uy * (length - back))
        n = len(pts)
        for i, (x, y) in enumerate(pts):
            if i >= n - tip_len:
                put(c, x, y, tip[0] if i == n - 1 else tip[1])
            else:
                put(c, x, y, body)
        return pts

    def smear_arc(self, c, cx, cy, r, a0, a1, cols=(PINK[0], PINK[1])):
        for rr, col, skip in ((r, cols[0], 0.0), (r - 1, cols[1], 0.35)):
            for k in range(70):
                t = k / 69
                if t < skip:
                    continue
                a = math.radians(a0 + (a1 - a0) * t)
                put(c, round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), col)

    # 齐步走:膝盖抬得高、身子笔直、一步一顿(所有人同一个节拍)
    def march(self, n=8, hand_amp=3.0, base_hand=(1, 6), **kw):
        fr = []
        for i in range(n):
            ph = i / n
            ffx = 3.0 * math.cos(2 * math.pi * ph)
            ffl = max(0.0, -math.sin(2 * math.pi * ph)) * 3.0
            fbx = 3.0 * math.cos(2 * math.pi * (ph + .5))
            fbl = max(0.0, -math.sin(2 * math.pi * (ph + .5))) * 3.0
            dy = 1 if math.cos(4 * math.pi * ph) > 0.3 else 0
            swing = hand_amp * math.cos(2 * math.pi * (ph + .5))
            p = self.pose(dy=dy, hand=(base_hand[0] + swing, base_hand[1] - abs(swing) * 0.4),
                          foot_front=2 + ffx, lift_front=ffl, foot_back=-1 + fbx, lift_back=fbl, **kw)
            fr.append(p)
        return fr

    def salute(self, **kw):
        k = [self.pose(hand=(1, 6), **kw), self.pose(hand=(2, 2), **kw), self.pose(hand=(1, -4), **kw),
             self.pose(hand=(1, -5), **kw), self.pose(hand=(1, -5), **kw), self.pose(hand=(1, -5), **kw),
             self.pose(hand=(2, 0), **kw), self.pose(hand=(1, 6), **kw)]
        return k


# ================================================================ 巡查员:警棍头发粉光,"站住!出示凭证!"
class Inspector(Bureau):
    DEFAULT = dict(Spec.DEFAULT, hand=(1, 6), baton=80, arm=True, smear=None, palm=False, foot_front=2, foot_back=-1)

    def behind(self, c, g, p):
        if p['smear']:
            a0, a1 = p['smear']
            self.smear_arc(c, g['hx'], g['hy'], 7, a0, a1)

    def front(self, c, g, p):
        if p['baton'] is not None:
            self.stick(c, g['hx'], g['hy'], p['baton'], 8, '#30323a')
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        if p['palm']:
            # 举起手掌:站住
            put(c, g['hx'] + 1, g['hy'] - 1, self.pal['S'])
            put(c, g['hx'] + 1, g['hy'] - 2, self.pal['S'])

    def anims(self):
        P = self.pose
        idle = [P(dy=1 if i in (2, 3) else 0, hand=(1, 6), baton=80 - (6 if i in (4, 5) else 0)) for i in range(6)]
        walk = self.march(baton=95)
        alert = [P(hand=(1, 6), baton=80), P(hand=(3, 2), baton=None, palm=True), P(hand=(4, 0), baton=None, palm=True),
                 P(hand=(5, -1), baton=None, palm=True), P(hand=(5, -1), baton=None, palm=True),
                 P(hand=(5, -1), baton=None, palm=True), P(hand=(3, 2), baton=70), P(hand=(1, 6), baton=80)]
        attack = [
            P(hand=(1, 5), baton=70),
            P(hand=(2, 1), baton=10, foot_back=-2),
            P(hand=(1, -4), baton=-80, foot_back=-3),
            P(dy=0, hand=(-1, -6), baton=-130, foot_back=-3),                       # 举过头(前摇)
            P(dy=0, hand=(-1, -6), baton=-135, foot_back=-3),
            P(dx=1, hand=(4, -3), baton=-40, foot_front=4, foot_back=-3, smear=(-150, -40)),
            P(dx=2, hand=(5, 1), baton=20, foot_front=5, foot_back=-4, smear=(-90, 20)),     # 判定
            P(dx=2, hand=(5, 3), baton=50, foot_front=5, foot_back=-4, smear=(-30, 50)),     # 判定
            P(dx=2, hand=(4, 4), baton=60, foot_front=5, foot_back=-4),
            P(dx=1, hand=(3, 5), baton=70, foot_front=3, foot_back=-2),
            P(hand=(1, 6), baton=80),
            P(hand=(1, 6), baton=80),
        ]
        return dict(Idle=idle, Walk=walk, Alert=alert, Attack=attack, Salute=self.salute(baton=None),
                    Fall=self.fall_anim(hand=(1, -3), baton=-60), Land=self.land_anim(hand=(2, 4), baton=70))


# ================================================================ 盾卫:一人高的方盾(藏青 + 金边 + 粉色局徽)
class Riot(Bureau):
    W, H = 38, 30
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 3), shield_dx=0, shake=0, bash=0, arm=True, clang=0, foot_front=2, foot_back=-1)

    def shield(self, c, x, y):
        w, h = 5, 16
        for yy in range(h):
            for xx in range(w):
                col = '#2b3d5a' if xx < w - 1 else '#1f2c44'
                if yy == 0 or xx == 0:
                    col = self.pal['G']
                elif yy == h - 1:
                    col = self.pal['g']
                put(c, x + xx, y + yy, col)
        # 局徽:一节管子 + 粉点
        for yy in range(5, 10):
            put(c, x + 2, y + yy, '#3b4f74')
        put(c, x + 2, y + 7, PINK[0])
        put(c, x + 3, y + 7, PINK[1])

    def front(self, c, g, p):
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        sx = g['sx'] + 2 + p['shield_dx'] - p['shake']
        self.shield(c, sx, g['sy'] - 6)
        if p['bash']:
            for k in range(p['bash']):
                y = g['sy'] - 4 + k * 5
                for x in range(g['ox'] - 2 - k, g['ox'] + 1):
                    if (x + k) % 3:
                        put(c, x, y, SMEAR[1])
        if p['clang']:
            for (dx, dy, k) in ((6, -4, 0), (7, -6, 1), (7, -1, 1), (8, -3, 2)):
                put(c, sx + dx, g['sy'] + dy, SPARK[k])

    def anims(self):
        P = self.pose
        idle = [P(dy=1 if i in (2, 3) else 0) for i in range(6)]
        walk = self.march(hand_amp=0.0, base_hand=(3, 3))
        attack = [P(), P(shield_dx=-1, foot_back=-2), P(dx=-1, shield_dx=-2, foot_back=-3), P(dx=-1, shield_dx=-2, foot_back=-3),
                  P(dx=2, shield_dx=3, foot_front=5, foot_back=-4, bash=2), P(dx=3, shield_dx=4, foot_front=5, foot_back=-4, bash=2),
                  P(dx=3, shield_dx=3, foot_front=5, foot_back=-4), P(dx=2, shield_dx=1, foot_front=4, foot_back=-3),
                  P(dx=1, foot_front=3, foot_back=-2), P()]
        block = [P(shake=1, clang=1), P(shake=1), P()]
        return dict(Idle=idle, Walk=walk, Attack=attack, Block=block, Salute=self.salute(),
                    Fall=self.fall_anim(), Land=self.land_anim())


# ================================================================ 弩手:金框粉弦的能量弩,单膝跪下齐射
class Gunner(Bureau):
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 1), bow=0, loaded=True, recoil=0, arm=True, foot_front=2, foot_back=-1, glow=0)

    def front(self, c, g, p):
        a = math.radians(p['bow'])
        ux, uy = math.cos(a), math.sin(a)
        vx, vy = -uy, ux
        hx, hy = g['hx'] - p['recoil'], g['hy']
        for i in range(-4, 5):
            put(c, round(hx + ux * i), round(hy + uy * i), self.pal['G'] if i % 3 else self.pal['g'])
        fx, fy = hx + ux * 4, hy + uy * 4
        for j in range(-3, 4):
            bend = 1 if abs(j) == 3 else 0
            put(c, round(fx - ux * bend + vx * j), round(fy - uy * bend + vy * j), PINK[1] if abs(j) < 3 else PINK[2])
        if p['loaded']:
            for i in range(-1, 4):
                put(c, round(hx + ux * i - vx), round(hy + uy * i - vy), PINK[0] if i >= 2 else PINK[1])
        if p['glow']:
            put(c, round(fx + ux * 2), round(fy + uy * 2), PINK[0])
            put(c, round(fx + ux * 3), round(fy + uy * 3), PINK[0])
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'] - p['recoil'], g['hy'])

    def anims(self):
        P = self.pose
        kneel = dict(dy=4, foot_front=4, foot_back=-5, lift_back=0)
        idle = [P(dy=1 if i in (2, 3) else 0, hand=(2, 4), bow=70) for i in range(6)]
        walk = self.march(base_hand=(2, 4), hand_amp=0.0, bow=75)
        aim = [P(hand=(2, 3), bow=50), P(hand=(3, 1), bow=20, dy=2, foot_front=3, foot_back=-3),
               P(hand=(4, 0), bow=4, **kneel), P(hand=(4, 0), bow=0, **kneel)]
        hold = [P(hand=(4, 0), bow=0, glow=i % 2, **kneel) for i in range(4)]
        shoot = [P(hand=(4, 0), bow=-4, recoil=2, loaded=False, **kneel), P(hand=(4, 0), bow=-6, recoil=1, loaded=False, **kneel),
                 P(hand=(4, 0), bow=-2, loaded=False, **kneel), P(hand=(4, 0), bow=0, loaded=False, **kneel)]
        reload = [P(hand=(3, 2), bow=40, loaded=False, **kneel), P(hand=(2, 4), bow=80, loaded=False, **kneel),
                  P(hand=(1, 4), bow=85, loaded=False, **kneel), P(hand=(1, 4), bow=85, loaded=True, **kneel),
                  P(hand=(2, 3), bow=60, loaded=True, dy=2, foot_front=3, foot_back=-3), P(hand=(2, 4), bow=70)]
        return dict(Idle=idle, Walk=walk, Aim=aim, Hold=hold, Shoot=shoot, Reload=reload, Salute=self.salute(bow=75),
                    Fall=self.fall_anim(hand=(1, -2), bow=-60), Land=self.land_anim(hand=(2, 3), bow=50))


# ================================================================ 队长:帽子更高、金肩章、粉色绶带,一手哨子一手指挥旗
class Captain(Bureau):
    W, H = 40, 46
    UPPER = [
        "...cCCCCc...",
        "...cCCCCCc..",
        "..cCCGCCCCc.",
        "...gGGGGGvvv",
        "...hhhSSS...",
        "...hhhSeS...",
        "....hhsSs...",
        "....jjSj....",
        "..GjJGGJLG..",
        "..GjJpJGLL..",
        "..jjJJpJGL..",
        "...jJJJpGL..",
        "...jJJJJpL..",
        "...kkkKkkk..",
    ]
    SHOULDER = (7, 9)
    DEFAULT = dict(Spec.DEFAULT, hand=(2, 4), flag=-84, wave=0, whistle=0, arm=True, smear=None, foot_front=2, foot_back=-1)

    def behind(self, c, g, p):
        if p['smear']:
            a0, a1 = p['smear']
            self.smear_arc(c, g['hx'], g['hy'], 8, a0, a1)

    def front(self, c, g, p):
        pts = self.stick(c, g['hx'], g['hy'], p['flag'], 21, '#9c8048', tip_len=1, tip=('#d2b46a', '#d2b46a'), back=2)
        # 旗面:藏青 + 金边 + 粉点,挂在杆头,往后飘(wave 让它抖)
        tx, ty = pts[-1]
        for yy in range(4):
            for xx in range(5):
                x = tx - 1 - xx
                y = ty + yy + (1 if (xx + p['wave']) % 3 == 0 and yy == 3 else 0)
                col = '#2b3d5a' if yy not in (0,) else '#d2b46a'
                if xx == 2 and yy == 2:
                    col = PINK[0]
                put(c, x, y, col)
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])
        if p['whistle']:
            # 嘴边一个金哨子 + 往前的声波
            mx, my = g['ox'] + 9, g['top'] + 6
            put(c, mx, my, '#d2b46a')
            for k in range(p['whistle']):
                r = 3 + k * 3
                for a in range(-35, 36, 12):
                    aa = math.radians(a)
                    put(c, round(mx + math.cos(aa) * r), round(my + math.sin(aa) * r), PINK[0] if k == p['whistle'] - 1 else PINK[1])

    def anims(self):
        P = self.pose
        idle = [P(dy=1 if i in (2, 3) else 0, flag=-84, wave=i) for i in range(6)]
        walk = self.march(base_hand=(2, 4), hand_amp=0.0, flag=-84)
        for i, p in enumerate(walk):
            p['wave'] = i
        command = [P(flag=-84), P(hand=(2, 1), flag=-84, wave=1), P(hand=(1, -5), flag=-80, wave=2),
                   P(hand=(1, -6), flag=-85, wave=3, whistle=1), P(hand=(1, -6), flag=-85, wave=4, whistle=2),
                   P(hand=(1, -6), flag=-85, wave=5, whistle=3), P(hand=(2, -4), flag=-40, wave=6, whistle=3),
                   P(hand=(4, -1), flag=-5, wave=7, whistle=2), P(hand=(4, 0), flag=0, wave=8), P(hand=(2, 4), flag=-84)]
        attack = [P(flag=-84), P(hand=(1, 1), flag=-100, foot_back=-2), P(hand=(-1, -5), flag=-130, foot_back=-3),
                  P(hand=(-1, -5), flag=-135, foot_back=-3), P(dx=1, hand=(4, -2), flag=-30, foot_front=4, foot_back=-3, smear=(-150, -30)),
                  P(dx=2, hand=(5, 2), flag=30, foot_front=5, foot_back=-4, smear=(-70, 30)),
                  P(dx=2, hand=(5, 3), flag=45, foot_front=5, foot_back=-4), P(dx=1, hand=(3, 4), flag=-20, foot_front=3, foot_back=-2),
                  P(flag=-70), P(flag=-84)]
        return dict(Idle=idle, Walk=walk, Command=command, Attack=attack, Salute=self.salute(flag=-84),
                    Fall=self.fall_anim(flag=-60), Land=self.land_anim(flag=-80))


# ================================================================ 稽查员:金边眼镜、抱着本子,撕罚单甩过来
class Auditor(Bureau):
    UPPER = [
        "....cCCCc...",
        "...cCCCCCc..",
        "...gGGGGGvvv",
        "...hhhSSS...",
        "...hhGSGe...",
        "....hhsSs...",
        "....jjSj....",
        "...jJGGJL...",
        "..jjJJJGLL..",
        "..jjJJJJGL..",
        "...jJJJJGL..",
        "...jJJJJGL..",
        "...kkkKkkk..",
    ]
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 2), book=True, ticket=None, pen=0, arm=True, foot_front=2, foot_back=-1, swish=None)

    def behind(self, c, g, p):
        if p['swish']:
            a0, a1 = p['swish']
            self.smear_arc(c, g['sx'], g['sy'], 6, a0, a1, cols=('#f4efe4', '#c9c1b0'))

    def front(self, c, g, p):
        if p['book']:
            bx, by = g['sx'] + 1, g['sy'] + 1
            for yy in range(7):
                for xx in range(5):
                    col = '#5a3e2c' if xx == 0 or yy in (0, 6) else ('#f4efe4' if yy % 2 else '#c9c1b0')
                    put(c, bx + xx, by + yy, col)
            put(c, bx + 3, by + 2, PINK[1])     # 一个粉章
            if p['pen']:
                put(c, bx + 2 + p['pen'] % 2, by + 3, '#2a2838')
        if p['ticket'] is not None:
            tx, ty = g['hx'] + p['ticket'][0], g['hy'] + p['ticket'][1]
            for yy in range(3):
                for xx in range(4):
                    put(c, tx + xx, ty + yy, '#f4efe4' if yy != 1 else '#c9c1b0')
            put(c, tx + 2, ty + 1, PINK[0])
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])

    def anims(self):
        P = self.pose
        idle = [P(hand=(3, 3 + (i % 2)), pen=i, dy=1 if i in (2, 3) else 0) for i in range(8)]
        walk = self.march(base_hand=(3, 2), hand_amp=0.0)
        throw = [P(hand=(3, 2)), P(hand=(4, 1), ticket=(0, -1)), P(hand=(4, 1), ticket=(0, -1)),        # 撕下一张
                 P(hand=(1, -3), ticket=(-1, -2), foot_back=-2), P(hand=(0, -4), ticket=(-2, -2), foot_back=-3),   # 举(前摇)
                 P(hand=(0, -4), ticket=(-2, -2), foot_back=-3),
                 P(dx=1, hand=(5, -1), ticket=None, foot_front=4, foot_back=-3, swish=(-140, -20)),        # 甩出去(这帧出手)
                 P(dx=1, hand=(5, 1), foot_front=4, foot_back=-3, swish=(-60, 10)),
                 P(hand=(4, 2), foot_front=3, foot_back=-2), P(hand=(3, 2))]
        return dict(Idle=idle, Walk=walk, Throw=throw, Salute=self.salute(),
                    Fall=self.fall_anim(hand=(1, -2)), Land=self.land_anim(hand=(3, 2)))


# ================================================================ 刀翼兵(精英):背后一对小号机械刀翼(女王那对翅膀的缩小版),悬空、俯冲
class Bladewing(Bureau):
    W, H = 46, 34
    BASE_X = 16
    DEFAULT = dict(Spec.DEFAULT, hand=(3, 4), spread=0.0, flap=0, arm=True, air=2, tuck=0.3, foot_front=2, foot_back=-2,
                   trail=0, blade=60)

    def wings(self, c, g, p):
        # 四片长刀从背上的黄铜轴扇出去:最上一片朝上偏后,最下一片朝后;片与片之间留缝,一片一片看得清
        bx, by = g['ox'] + 3, g['top'] + 9
        lengths = (12, 14, 12, 9)
        for i, L in enumerate(lengths):
            base = -112 - i * 24 - 14 * p['spread'] * (1.5 - i) * 0.6
            ang = math.radians(base + (2 if (p['flap'] + i) % 2 else -2))
            L = L + round(2 * p['spread'])
            ux, uy = math.cos(ang), math.sin(ang)
            vx, vy = -uy, ux
            for k in range(2, L + 1):
                x, y = bx + ux * k, by + uy * k
                w = 2 if k < L - 2 else 1        # 刀身两格宽,刀尖一格
                put(c, round(x), round(y), '#e8eae4' if k >= L - 1 else '#b4b8b2')
                if w == 2:
                    put(c, round(x + vx), round(y + vy), '#70746f')
            # 刀根一个黄铜铆钉
            put(c, round(bx + ux * 3), round(by + uy * 3), '#c08a50')
        for dx, dy, col in ((0, 0, '#b07a46'), (1, 0, '#d6a65e'), (0, 1, '#7a5230'), (1, 1, '#b07a46'), (-1, 0, '#7a5230'), (0, -1, '#d6a65e')):
            put(c, bx + dx, by + dy, col)

    def behind(self, c, g, p):
        self.wings(c, g, p)
        for k in range(p['trail']):
            y = g['top'] + 6 + k * 4
            for x in range(g['ox'] - 6 - k * 3, g['ox'] + 2):
                if (x + k) % 2:
                    put(c, x, y, PINK[1] if x > g['ox'] - 3 else PINK[2])

    def front(self, c, g, p):
        self.stick(c, g['hx'], g['hy'], p['blade'], 6, '#b8bcb8', tip_len=2, tip=('#ffffff', PINK[0]))
        if p['arm']:
            self.arm(c, g['sx'], g['sy'], g['hx'], g['hy'])

    def anims(self):
        P = self.pose
        idle = [P(air=2 + (1 if i in (1, 2) else 0), flap=i, spread=0.2) for i in range(6)]
        walk = [P(air=3 + (i % 2), flap=i, spread=0.5, foot_front=1, foot_back=-3, tuck=0.5, blade=70) for i in range(6)]
        attack = [P(air=3, spread=0.3), P(air=6, spread=0.7, flap=1, blade=20), P(air=9, spread=1.0, flap=2, blade=-20),
                  P(air=10, spread=1.0, flap=3, blade=-30), P(air=10, spread=1.0, flap=4, blade=-30),          # 升高(前摇)
                  P(air=6, dx=4, spread=0.2, blade=30, hand=(5, 3), trail=2), P(air=2, dx=8, spread=0.1, blade=40, hand=(5, 4), trail=3),   # 俯冲(判定)
                  P(air=1, dx=10, spread=0.1, blade=45, hand=(5, 4), trail=2), P(air=2, dx=10, spread=0.4, blade=60, trail=1),
                  P(air=2, dx=8, spread=0.3), P(air=2, dx=4, spread=0.2), P(air=2, spread=0.2)]
        return dict(Idle=idle, Walk=walk, Attack=attack, Salute=self.salute(air=2, spread=0.2),
                    Fall=self.fall_anim(spread=1.0), Land=self.land_anim(spread=0.3))


SPECS = dict(inspector=Inspector, riot=Riot, gunner=Gunner, captain=Captain, auditor=Auditor, bladewing=Bladewing)
