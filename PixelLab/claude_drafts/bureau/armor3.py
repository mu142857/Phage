"""管道局 v3:浑身铜金板甲,不露脸,不要粉色(用户 2026-10-15)。每种兵一个身材一个头盔:
戟卫=标准猪嘴盔;盾卫=矮壮桶盔;重弩手=瘦、宽檐铁帽+锁子甲;队长=最高、倒三角、鳍冠栅栏面甲+披风;
稽查员=圆肚子短腿、高筒盔头顶一根冒汽的小管子;刀翼兵=细腰长腿、尖嘴盔。
上身/头盔/肩甲/腰甲裙是手摆的像素格子,四肢 IK 粗甲管。朝右画,每帧 100ms。"""
from PIL import Image
import math
from lib import put

PAL = {
    # 铜金:a 最暗(缝) → g 高光
    'a': '#22160c', 'b': '#4a3016', 'c': '#7a4f22', 'd': '#a67330', 'e': '#cc9a42', 'f': '#ebc86a', 'g': '#fff1b8',
    # 藏青衬布
    'n': '#141927', 'm': '#24324e', 'o': '#3a4c72',
    # 黑铁 / 锁子甲
    'i': '#141619', 'j': '#363d45', 'k': '#5a626a', 'l': '#868e96',
    # 刀刃钢
    's': '#eceee8', 't': '#aeb2ae', 'u': '#6a6e6c',
    # 蒸汽
    'w': '#d8dad6', 'x': '#9a9c98',
}
DIM = {'a': 'a', 'b': 'a', 'c': 'b', 'd': 'c', 'e': 'c', 'f': 'd', 'g': 'e', 'l': 'k', 'k': 'j', 'j': 'i', 'o': 'm', 'm': 'n',
       's': 't', 't': 'u'}
SMEAR = ('#fff4d8', '#cdb88e')


def col(ch, dim=False):
    if dim:
        ch = DIM.get(ch, ch)
    return PAL[ch]


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


def stamp(c, rows, x0, y0, dim=False):
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in '. ':
                put(c, x0 + x, y0 + y, col(ch, dim))


def knee_pt(hx, hy, fx, fy, L1, L2, bend):
    dx, dy = fx - hx, fy - hy
    d = max(0.01, math.hypot(dx, dy))
    d2 = min(d, L1 + L2 - 0.01)
    a = (L1 ** 2 - L2 ** 2 + d2 ** 2) / (2 * d2)
    h = math.sqrt(max(0.0, L1 ** 2 - a ** 2))
    mx, my = hx + dx * a / d, hy + dy * a / d
    px, py = -dy / d, dx / d
    if px * bend < 0:
        px, py = -px, -py
    return mx + px * h, my + py * h


def sprite(rows, dim=False):
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    stamp(im, rows, 0, 0, dim)
    return im


def _paste_clip(c, im, x, y):
    px = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            p = px[xx, yy]
            if p[3]:
                put(c, x + xx, y + yy, p)


def paste_rot(c, spr, anchor, at, ang):
    """spr 朝上画、anchor 是它挂在杆上的点;ang = 杆的朝向(度,屏幕坐标,-90=朝上)"""
    paste_dir(c, spr.rotate(-90, expand=True), (spr.height - 1 - anchor[1], anchor[0]), at, ang)


def paste_dir(c, spr, anchor, at, ang):
    """spr 朝右画;ang = 朝向(度,屏幕坐标,0=朝右,-90=朝上)"""
    R = max(spr.width, spr.height) * 2 + 2
    big = Image.new('RGBA', (R * 2 + 1, R * 2 + 1), (0, 0, 0, 0))
    big.paste(spr, (R - anchor[0], R - anchor[1]))
    rot = big.rotate(-ang, resample=Image.NEAREST, center=(R, R)) if ang else big
    _paste_clip(c, rot, int(round(at[0])) - R, int(round(at[1])) - R)


def pole(c, hx, hy, ang, length, grip, head=None, anchor=(0, 0), shaft=('j', 'c')):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    pts = line_pts(hx - ux * grip, hy - uy * grip, hx + ux * (length - grip), hy + uy * (length - grip))
    for i, (x, y) in enumerate(pts):
        put(c, x, y, col(shaft[1] if i % 6 == 3 else shaft[0]))
    if head is not None:
        paste_rot(c, head, anchor, pts[-1], ang)
    return pts[-1]


def smear(c, cx, cy, r, a0, a1):
    for rr, cc, skip in ((r, SMEAR[0], 0.0), (r - 1, SMEAR[1], 0.3), (r - 2, SMEAR[1], 0.6)):
        for k in range(100):
            t = k / 99
            if t < skip:
                continue
            a = math.radians(a0 + (a1 - a0) * t)
            put(c, round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), cc)


# ================================================================ 身子
class Armor:
    W, H, CX = 70, 50, 30
    LEG, THIGH, SHIN = 11, 5.2, 5.0
    THIGH_W, SHIN_W = (5.4, 4.8), (4.6, 4.0)
    THIGH_RAMP = SHIN_RAMP = 'bcde'
    UARM, FARM = 4.6, 4.8
    UARM_W, FARM_W = (3.6, 3.2), (3.6, 3.0)
    UARM_RAMP = FARM_RAMP = 'bcde'
    HIPS = (-3, 3)
    TOVER = 2                      # 腰甲裙压在胯上几行
    NECK = (0, 0)
    SF, SB = (-3, 5), (-4, 4)      # 前/后肩点,相对 (cx, 胸甲顶)
    HELM_O = (-2, -10)
    TORSO_OX = -4
    TASSETS_OX = -4
    PAUL_O = (-6, -6)
    BADGE = (9, 5)                 # 胸口局徽(敬礼时闪一下)
    KNEE = [".eff.", "deffe", "cdedc", ".bcb."]
    KNEE_O = (-2, -2)
    BOOT = [".cdef..", "bcdeefe", "ijjjkkj"]
    BOOT_O = (-2, -2)
    ELBOW = [".e.", "efd", ".c."]
    GAUNT = ["cde", "jkk", "ijk", ".ij"]
    GAUNT_O = (-1, -2)
    HELM = [
        "..ef........",
        "..cdef......",
        ".bcdeffe....",
        ".bcdeeffe...",
        "bccdddeeed..",
        "bcccddddddc.",
        "abcaaiiiiia.",
        "abccdddddeed",
        ".abccddddcc.",
        "..abbccb....",
    ]
    TORSO = [
        "....ajjjjd...",
        "....ncdeed...",
        "...bncdeffd..",
        "..bccbcdefffe",
        ".bcccbbcdeeed",
        ".bcccbbcdjkdd",
        ".bcccbbcdijdd",
        ".abccnabcdddc",
        "..abcnabbccb.",
        "..abbn.bbcbb.",
        "...ijjjjkji..",
    ]
    TASSETS = [
        ".cdaecdaecd.",
        ".bcabdcabdc.",
        "..b.abc.ab..",
    ]
    PAUL = [
        "...fe.....",
        "..efgfe...",
        ".defggfe..",
        "cdeffffed.",
        "bcdeeeeedc",
        "abcddddddc",
        ".abbbbbbba",
        "..bdeeedba",
        "..abccdcb.",
    ]
    DEFAULT = dict(dx=0, dy=0, lean=0, ff=2, fb=-3, lf=0, lb=0, hand=(1, 7), bhand=(1, 6), air=0, tuck=0.0,
                   glint=0, dust=(), steam=0)

    def pose(self, **kw):
        d = dict(self.DEFAULT)
        d.update(kw)
        return d

    @property
    def F(self):
        return self.H - 1

    def limb(self, c, x0, y0, x1, y1, w0, w1, back, ramp='bcde', hi=True):
        L = max(0.01, math.hypot(x1 - x0, y1 - y0))
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        fx, fy = uy, -ux
        if fx < 0 or (fx == 0 and fy > 0):
            fx, fy = -fx, -fy
        r = max(w0, w1) / 2 + 1
        hi_ch = 'f' if ramp[-1] in 'de' else ramp[-1]
        for y in range(int(min(y0, y1) - r), int(max(y0, y1) + r) + 1):
            for x in range(int(min(x0, x1) - r), int(max(x0, x1) + r) + 1):
                px, py = x + 0.5 - (x0 + 0.5), y + 0.5 - (y0 + 0.5)
                t = (px * ux + py * uy) / L
                if t < -0.05 or t > 1.05:
                    continue
                s = px * fx + py * fy
                w = lerp(w0, w1, max(0.0, min(1.0, t)))
                if abs(s) > w / 2:
                    continue
                k = (s + w / 2) / max(0.01, w)
                i = min(len(ramp) - 1, int(k * len(ramp)))
                ch = ramp[i]
                if hi and i == len(ramp) - 1 and t < 0.45:
                    ch = hi_ch
                if t > 0.9 and i > 0:
                    ch = ramp[i - 1]
                put(c, x, y, col(ch, back))

    def leg(self, c, hx, hy, fx, lift, back, tuck=0.0):
        F = self.F
        fy = F - 2 - lift
        if tuck:
            fx = lerp(fx, hx + 1, tuck)
        kx, ky = knee_pt(hx, hy, fx, fy, self.THIGH, self.SHIN, 1)
        self.limb(c, kx, ky, fx, fy, *self.SHIN_W, back, self.SHIN_RAMP)
        self.limb(c, hx, hy, kx, ky, *self.THIGH_W, back, self.THIGH_RAMP)
        kx, ky = int(round(kx)), int(round(ky))
        stamp(c, self.KNEE, kx + self.KNEE_O[0], ky + self.KNEE_O[1], back)
        bx, by = int(round(fx)), F - lift
        stamp(c, self.BOOT, bx + self.BOOT_O[0], by + self.BOOT_O[1] + 2 - len(self.BOOT) + 1, back)

    def arm(self, c, sx, sy, hx, hy, back):
        ex, ey = knee_pt(sx, sy, hx, hy, self.UARM, self.FARM, -1)
        self.limb(c, sx, sy, ex, ey, *self.UARM_W, back, self.UARM_RAMP)
        self.limb(c, ex, ey, hx, hy, *self.FARM_W, back, self.FARM_RAMP)
        ex, ey = int(round(ex)), int(round(ey))
        stamp(c, self.ELBOW, ex - 1, ey - 1, back)
        hx, hy = int(round(hx)), int(round(hy))
        stamp(c, self.GAUNT, hx + self.GAUNT_O[0], hy + self.GAUNT_O[1], back)

    # 钩子
    def behind(self, c, g, p):
        pass

    def held_back(self, c, g, p):
        pass

    def front(self, c, g, p):
        pass

    def helm_extra(self, c, g, p):
        pass

    def geom(self, p):
        F = self.F
        air = round(p['air'])
        cx = self.CX + round(p['dx'])
        hip = F - self.LEG + round(p['dy']) - air
        lean = round(p['lean'])
        n = len(self.TORSO)
        ttop = hip - n - self.TOVER + len(self.TASSETS) - 1
        g = dict(cx=cx, hip=hip, ttop=ttop, air=air, lean=lean, n=n)
        g['neck'] = (cx + self.NECK[0] + lean, ttop + self.NECK[1])
        g['sf'] = (cx + self.SF[0] + lean, ttop + self.SF[1])
        g['sb'] = (cx + self.SB[0] + lean, ttop + self.SB[1])
        g['hf'] = (g['sf'][0] + p['hand'][0], g['sf'][1] + p['hand'][1])
        g['hb'] = (g['sb'][0] + p['bhand'][0], g['sb'][1] + p['bhand'][1])
        return g

    def render(self, p):
        c = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        g = self.geom(p)
        cx, hip, ttop, air, lean, n = g['cx'], g['hip'], g['ttop'], g['air'], g['lean'], g['n']
        self.behind(c, g, p)
        self.arm(c, *g['sb'], *g['hb'], back=True)
        stamp(c, self.PAUL, g['sb'][0] + self.PAUL_O[0], g['sb'][1] + self.PAUL_O[1], dim=True)
        self.leg(c, cx + self.HIPS[0], hip, cx + self.HIPS[0] + p['fb'], round(p['lb']) + air, True, p['tuck'])
        self.held_back(c, g, p)
        for y, r in enumerate(self.TORSO):
            sx = round(lean * (n - 1 - y) / (n - 1))
            stamp(c, [r], cx + self.TORSO_OX + sx, ttop + y)
        if p['glint']:
            bx = cx + self.TORSO_OX + self.BADGE[0] + round(lean * (n - 1 - self.BADGE[1]) / (n - 1))
            put(c, bx, ttop + self.BADGE[1], col('g'))
            put(c, bx + 1, ttop + self.BADGE[1] - 1, col('g'))
        self.leg(c, cx + self.HIPS[1], hip, cx + self.HIPS[1] + p['ff'], round(p['lf']) + air, False, p['tuck'])
        stamp(c, self.TASSETS, cx + self.TASSETS_OX, ttop + n)
        nx, ny = g['neck']
        stamp(c, self.HELM, nx + self.HELM_O[0], ny + self.HELM_O[1])
        self.helm_extra(c, g, p)
        self.arm(c, *g['sf'], *g['hf'], back=False)
        stamp(c, self.PAUL, g['sf'][0] + self.PAUL_O[0], g['sf'][1] + self.PAUL_O[1])
        self.front(c, g, p)
        for (ex, ey, k) in p['dust']:
            put(c, ex, ey, ['#8a7a66', '#6a5c4c'][k % 2])
        return c

    # 通用动作
    def breathe(self, n=8, **kw):
        out = []
        for i in range(n):
            d = dict(dy=1 if i in (3, 4, 5) else 0)
            d.update(kw)
            out.append(self.pose(**d))
        return out

    def march(self, n=8, stride=3.6, lift=3.0, **kw):
        """齐步走:膝盖抬高、一步一顿"""
        fr = []
        for i in range(n):
            ph = i / n
            d = dict(ff=1 + stride * math.cos(2 * math.pi * ph), lf=max(0.0, -math.sin(2 * math.pi * ph)) * lift,
                     fb=-2 + stride * math.cos(2 * math.pi * (ph + .5)),
                     lb=max(0.0, -math.sin(2 * math.pi * (ph + .5))) * lift,
                     dy=1 if math.cos(4 * math.pi * ph) > 0.3 else 0)
            d.update(kw)
            fr.append(self.pose(**d))
        return fr

    def salute(self, rest=(1, 7), **kw):
        """拳头捶胸甲,局徽一闪"""
        hx, hy = rest
        keys = [rest, (3, 4), (4, 2), (4, 2), (4, 2), (4, 2), (3, 4), rest]
        out = []
        for i, h in enumerate(keys):
            d = dict(hand=h, glint=1 if i in (2, 3) else 0)
            d.update(kw)
            out.append(self.pose(**d))
        return out

    def fall_anim(self, **kw):
        return [self.pose(air=3, tuck=0.6, ff=2, fb=-3, lf=1 + i % 2, lb=i % 2, **kw) for i in range(4)]

    def land_anim(self, **kw):
        F = self.F
        cx = self.CX

        def dust(r):
            return [(cx + s * (r + k * 2), F - (k % 2), k) for s in (-1, 1) for k in range(3)]
        out = [self.pose(dy=3, ff=4, fb=-4, dust=dust(6)), self.pose(dy=2, ff=4, fb=-4, dust=dust(9)),
               self.pose(dy=1, ff=3, fb=-3, dust=dust(12)), self.pose()]
        for p in out:
            p.update(kw)
        return out


# ================================================================ 戟卫:标准身材,猪嘴盔,长戟
HALBERD = sprite([
    "....s.....",
    "....t.....",
    "...efe....",
    "...ded.de.",
    "bc.cddeets",
    ".bccdeeets",
    "...cddeets",
    "...bcddtts",
    "...bc.dtt.",
    "....d.....",
    "....k.....",
])


class Halberdier(Armor):
    W, H, CX = 76, 52, 34
    DEFAULT = dict(Armor.DEFAULT, hand=(7, 3), pole=-72, grip=11, sm=None)

    def front(self, c, g, p):
        hx, hy = g['hf']
        pole(c, hx, hy, p['pole'], 30, p['grip'], HALBERD, (4, 10))
        if p['sm']:
            smear(c, hx, hy, 30 - p['grip'] + 6, *p['sm'])

    def anims(self):
        P = self.pose
        attack = [P(), P(hand=(5, 1), pole=-90, fb=-4), P(pole=-120, grip=8, hand=(2, -3), fb=-5, lean=-1),
                  P(pole=-150, grip=6, hand=(0, -5), fb=-5, lean=-1, dy=1),
                  P(pole=-155, grip=6, hand=(0, -5), fb=-5, lean=-1, dy=1),
                  P(pole=-70, grip=6, hand=(6, -3), dx=2, ff=5, fb=-5, lean=1, sm=(-160, -70)),
                  P(pole=-5, grip=6, hand=(8, 1), dx=3, ff=6, fb=-6, lean=2, dy=1, sm=(-100, -5)),
                  P(pole=25, grip=6, hand=(8, 3), dx=3, ff=6, fb=-6, lean=2, dy=2),
                  P(pole=22, grip=6, hand=(8, 3), dx=3, ff=6, fb=-6, lean=2, dy=2),
                  P(pole=-30, grip=8, hand=(7, 3), dx=2, ff=4, fb=-4, lean=1), P(pole=-60, hand=(7, 3), dx=1),
                  P()]
        salute = [P(pole=-72, hand=(7, 3))] + [P(pole=-90, hand=(5, 0), glint=1 if i in (2, 3) else 0) for i in range(6)] + [P()]
        return dict(Idle=self.breathe(), Walk=self.march(), Attack=attack, Salute=salute, Fall=self.fall_anim(),
                    Land=self.land_anim())


# ================================================================ 盾卫:矮壮,桶盔,一人高塔盾 + 盾上沿伸出的长矛
TOWER = sprite([
    ".bdeeef..",
    "bcdeeffg.",
    "bcdeeeffe",
    "bcdeeeffe",
    "bcddeeefe",
    "bcddjjjee",
    "bcdjkkkje",
    "bcddjkjee",
    "bcdddjdee",
    "bcdddjdee",
    "bcddjkjee",
    "bcdjkkkje",
    "bcddjjjee",
    "bccdddeee",
    "bccdddeee",
    "bcccddeee",
    "abccdddde",
    "abccdddde",
    "abccddddd",
    ".abccdddc",
    "..abcccc.",
    "...abcc..",
])
SPEAR = sprite([
    "jkkcdeefs",
    ".....det.",
])


class TowerShield(Armor):
    W, H, CX = 66, 46, 24
    LEG, THIGH, SHIN = 9, 4.6, 4.4
    THIGH_W, SHIN_W = (6.4, 5.6), (5.4, 4.8)
    HIPS = (-4, 3)
    SF, SB = (-3, 4), (-5, 3)
    TORSO_OX = TASSETS_OX = -6
    HELM_O = (-3, -8)
    BADGE = (10, 5)
    KNEE = [".eeff.", "deffee", "cdeedc", ".bccb."]
    KNEE_O = (-2, -2)
    BOOT = [".cdeef..", "bcdeeefe", "ijjjjkkj"]
    GAUNT = ["cdee", "jkkk", "ijkk", ".ijj"]
    HELM = [
        ".bcdddeed..",
        "bcdeeeffee.",
        "bcdeeeffeee",
        "bccddeeeeed",
        "bccdaiiiiia",
        "bccddddddde",
        "bccdddejdde",
        "bccdddcjddd",
        "abccddcjccd",
        ".abbbbbbbb.",
    ]
    TORSO = [
        "......ajjjjd..",
        "....bcncdeeed.",
        "...bccncdeeffd",
        "..bcccbcdefffe",
        ".bcccbbcddeeee",
        ".bcccbbcddjkde",
        ".abcccnbcdijdd",
        "..abbcnabbcccc",
        "...ijjjjjjkji.",
    ]
    TASSETS = [
        ".cdaecdaecdaec",
        ".bcabdcabdcabc",
        "..b.abc.ab.ab.",
    ]
    PAUL = [
        "..eff......",
        ".efggfe....",
        "defggffe...",
        "cdeffffeed.",
        "bcdeeeeeedc",
        "abcddddddca",
        ".abbbbbbba.",
        ".bdeeeeedb.",
        ".abccccca..",
        "..bdeeedb..",
        "..abcccb...",
    ]
    PAUL_O = (-6, -6)
    DEFAULT = dict(Armor.DEFAULT, hand=(8, 4), bhand=(6, -1), spear=-3, reach=0, push=0, clang=0, ff=2, fb=-3)

    def held_back(self, c, g, p):
        hx, hy = g['hb']
        a = math.radians(p['spear'])
        ux, uy = math.cos(a), math.sin(a)
        hx, hy = hx + ux * p['reach'], hy + uy * p['reach']
        tip = pole(c, hx, hy, p['spear'], 22, 7)
        paste_dir(c, SPEAR, (0, 0), tip, p['spear'])
        if p['reach'] > 3:
            for k in range(3):
                put(c, round(tip[0] + 10 + k * 2), round(tip[1]), SMEAR[0] if k else '#ffffff')

    def front(self, c, g, p):
        hx, hy = g['hf']
        sx, sy = hx - 3 + p['push'], hy - 9
        _paste_clip(c, TOWER, sx, sy)
        if p['clang']:
            for (dx, dy, cc) in ((9, 4, '#fff0b0'), (10, 2, '#ffc860'), (10, 7, '#ffc860'), (11, 5, '#e07830'), (12, 3, '#e07830')):
                put(c, sx + dx, sy + dy, cc)

    def anims(self):
        P = self.pose
        attack = [P(), P(reach=-2, fb=-4), P(reach=-4, fb=-5, lean=-1), P(reach=-4, fb=-5, lean=-1, dy=1),
                  P(reach=8, dx=1, ff=4, fb=-5, lean=1), P(reach=10, dx=2, ff=5, fb=-5, lean=1),
                  P(reach=10, dx=2, ff=5, fb=-5, lean=1), P(reach=4, dx=1, ff=3, fb=-4), P(reach=1), P()]
        bash = [P(), P(push=-1, fb=-4, lean=-1), P(push=-2, fb=-5, lean=-1, dy=1), P(push=-2, fb=-5, lean=-1, dy=1),
                P(push=3, dx=3, ff=6, fb=-6, lean=2), P(push=4, dx=4, ff=6, fb=-6, lean=2),
                P(push=3, dx=4, ff=5, fb=-5, lean=1), P(push=1, dx=3, ff=4, fb=-4), P(dx=1), P()]
        block = [P(push=-1, clang=1, dx=-1, dy=1), P(push=-1, dy=1), P()]
        salute = [P(spear=s, bhand=h) for s, h in ((-3, (6, -1)), (-40, (4, -3)), (-90, (3, -5)), (-90, (3, -5)),
                                                    (-90, (3, -5)), (-90, (3, -5)), (-40, (4, -3)), (-3, (6, -1)))]
        return dict(Idle=self.breathe(), Walk=self.march(stride=3.0, lift=2.2), Attack=attack, Bash=bash, Block=block,
                    Salute=salute, Fall=self.fall_anim(), Land=self.land_anim())


# ================================================================ 重弩手:瘦,宽檐铁帽压着脸(只见黑影),锁子甲,黑铁重弩
def _arbalest(loaded):
    im = Image.new('RGBA', (23, 10), (0, 0, 0, 0))
    for (x, y) in line_pts(19, 1, 9, 4) + line_pts(19, 8, 9, 5):
        put(im, x, y, col('u'))
    stamp(im, [
        "..jjjjjjjjjjjjjjjjk",
        "bcdeedkkkkkkkkkkkjk",
        "bcddcdjjjjjjjjjjjjk",
        "abb.ij..........ij.",
        "....ij.............",
    ], 0, 3)
    for (x, y, ch) in ((18, 2, 'j'), (18, 1, 'k'), (19, 0, 'k'), (19, 1, 'j'), (18, 7, 'j'), (18, 8, 'k'), (19, 9, 'k'),
                       (19, 8, 'j'), (17, 3, 'k'), (17, 6, 'j')):
        put(im, x, y, col(ch))
    if loaded:
        stamp(im, ["uttttttttts"], 9, 3)
        put(im, 20, 3, col('s'))
    return im


class Arbalest(Armor):
    W, H, CX = 62, 48, 22
    LEG, THIGH, SHIN = 12, 5.8, 5.6
    THIGH_W, SHIN_W = (4.2, 3.6), (3.6, 3.0)
    THIGH_RAMP = 'nmmo'
    UARM_W, FARM_W = (3.0, 2.8), (3.0, 2.6)
    UARM_RAMP = 'nmmo'
    HIPS = (-2, 2)
    SF, SB = (-2, 4), (-3, 3)
    TORSO_OX = TASSETS_OX = -4
    HELM_O = (-4, -9)
    BADGE = (8, 5)
    KNEE = [".ef", "def", ".c."]
    KNEE_O = (-1, -1)
    BOOT = [".cde..", "bcdeef", "ijjjkj"]
    GAUNT = ["cd", "jk", "ij"]
    GAUNT_O = (-1, -1)
    ELBOW = [".d", "ed"]
    HELM = [
        "....cdeed....",
        "...cdeffed...",
        "..bcdeeeedc..",
        "..bccddddcc..",
        "abbccddddccbb",
        ".aabbbbbbbbaa",
        "...kjkjiiii..",
        "...jkjiiiii..",
        "...kjkjiiii..",
        "....jkjk.....",
    ]
    TORSO = [
        "....jkjk...",
        "...kjkcdd..",
        "..jkjcdeffd",
        ".jkjkcdefff",
        ".kjkjcdeeee",
        ".jkjkcddeed",
        ".kjkjbcdddd",
        ".jkjkjbccc.",
        "..kjkjkjk..",
        "..jkjkjkj..",
        "...ijjeji..",
    ]
    TASSETS = [
        ".jkjkjkjk.",
        "..kjkjkj..",
    ]
    PAUL = [
        ".eff..",
        "deffe.",
        "cdeedc",
        "abccba",
        ".bddb.",
        ".abba.",
    ]
    PAUL_O = (-3, -3)
    DEFAULT = dict(Armor.DEFAULT, hand=(7, 0), bhand=(5, 1), aim=-20, loaded=1, recoil=0, charge=0, ff=2, fb=-2)
    KNEEL = dict(dy=5, ff=4, fb=-6)

    def behind(self, c, g, p):
        # 背上的弩箭匣:铜框,露出一排箭尾
        x0, y0 = g['sb'][0] - 4, g['ttop'] + 1
        stamp(c, [".s.t.s", ".t.u.t", "bcdeed", "bcddcd", "bcddcd", "bcddcd", "bccccd", "abbbbc"], x0, y0)

    def front(self, c, g, p):
        hx, hy = g['hf'][0] - p['recoil'], g['hf'][1]
        paste_dir(c, _arbalest(p['loaded']), (5, 4), (hx, hy), p['aim'])
        if p['charge']:
            a = math.radians(p['aim'])
            for k in range(p['charge']):
                put(c, round(hx + math.cos(a) * (17 + k * 2)), round(hy + math.sin(a) * (17 + k * 2)) - 1, SMEAR[k % 2])

    def anims(self):
        P = self.pose
        K = self.KNEEL
        aim = [P(), P(aim=-10, dy=2, ff=4, fb=-4), P(aim=0, **K), P(aim=0, **K)]
        hold = [P(aim=0, charge=1 + i % 2, **K) for i in range(4)]
        shoot = [P(aim=-4, recoil=3, loaded=0, **K), P(aim=-6, recoil=2, loaded=0, **K),
                 P(aim=-2, recoil=1, loaded=0, **K), P(aim=0, loaded=0, **K)]
        reload = [P(aim=30, hand=(5, 2), loaded=0, **K), P(aim=60, hand=(4, 3), loaded=0, **K),
                  P(aim=60, hand=(4, 3), **K), P(aim=20, hand=(5, 2), dy=2, ff=4, fb=-4), P()]
        salute = [P(aim=a, hand=h, glint=1 if i in (3, 4) else 0) for i, (a, h) in
                  enumerate(((-20, (7, 0)), (-50, (5, -1)), (-80, (4, -2)), (-85, (4, -2)), (-85, (4, -2)), (-85, (4, -2)),
                             (-50, (5, -1)), (-20, (7, 0))))]
        return dict(Idle=self.breathe(), Walk=self.march(stride=4.0), Aim=aim, Hold=hold, Shoot=shoot, Reload=reload,
                    Salute=salute, Fall=self.fall_anim(), Land=self.land_anim())


# ================================================================ 队长:最高,倒三角,鳍冠栅栏面甲,藏青披风,大剑
GREATSWORD = sprite([
    "....e..............",
    "jjkdesssssssssssss.",
    "....dtttttttttttts.",
    "....c..............",
])


class Commander(Armor):
    W, H, CX = 70, 56, 30
    LEG, THIGH, SHIN = 12, 5.8, 5.6
    THIGH_W, SHIN_W = (5.4, 4.4), (4.6, 3.6)
    SF, SB = (-3, 5), (-5, 4)
    TORSO_OX, TASSETS_OX = -5, -5
    HELM_O = (-2, -13)
    BADGE = (10, 5)
    HELM = [                       # 头顶一片往后掠的钢刀冠(和刀翼一个路数)+ 栅栏面甲
        "s...........",
        ".st.........",
        "..sst.......",
        "..tssu......",
        ".bcdeffe....",
        "bccdeeffee..",
        "bccdddeeed..",
        "bcccdddddde.",
        "abcaeieieie.",
        "abcaeieieied",
        ".abccdddddc.",
        "..abbccbb...",
    ]
    TORSO = [
        ".....ajjjjjd..",
        "....bncdeeed..",
        "...bcncdeefffd",
        "..bcdcbcdeffffe",
        "..bcccbcdeeeffe",
        "..bcccbbcdeeeed",
        "...bccbbcdjkedd",
        "....bcbbcdijdc.",
        ".....bbbccddc..",
        ".....abbcccb...",
        ".....abbccbb...",
        ".....ijjjkji...",
    ]
    TASSETS = [
        "...cdaecdaec..",
        "...bcabdcabc..",
        "..bcab.dcabc..",
        "..b..abc..ab..",
    ]
    PAUL = [
        "....g.....",
        "...efg....",
        "..defgf...",
        ".defggfe..",
        "cdeffffeed",
        "bcdeeeeedc",
        "abcddddddc",
        ".agfgfgfga",
        "..bdeeedba",
        "..agfgfga.",
    ]
    PAUL_O = (-6, -7)
    DEFAULT = dict(Armor.DEFAULT, sword=-60, sm=None, cape=0, shout=0, hand=(6, 4))

    def behind(self, c, g, p):
        sx, sy = g['sb'][0] - 1, g['ttop'] + 1
        sway = (0, 1, 2, 1)[p['cape'] % 4]
        hip = g['hip']
        rows = hip + 9 - sy
        for i in range(rows):
            t = i / max(1, rows - 1)
            x0 = round(sx - 1 - t * (4 + sway))
            x1 = round(sx + 4 - t * 1)
            for x in range(x0, x1 + 1):
                ch = 'n' if x < x0 + 2 else 'm'
                if x == x0:
                    ch = 'c' if i % 3 == 0 else 'b'
                put(c, x, sy + i, col(ch))
        for x in range(round(sx - 5 - sway), sx + 4):
            if (x + p['cape']) % 2:
                put(c, x, sy + rows, col('d'))

    def helm_extra(self, c, g, p):
        if p['shout']:
            nx, ny = g['neck']
            mx, my = nx + 11, ny + self.HELM_O[1] + 8
            for k in range(p['shout']):
                r = 3 + k * 3
                for a in range(-40, 41, 10):
                    aa = math.radians(a)
                    put(c, round(mx + math.cos(aa) * r), round(my + math.sin(aa) * r),
                        col('g') if k == p['shout'] - 1 else col('e'))

    def front(self, c, g, p):
        hx, hy = g['hf']
        paste_dir(c, GREATSWORD, (4, 1), (hx, hy), p['sword'])
        if p['sm']:
            smear(c, hx, hy, 16, *p['sm'])

    def anims(self):
        P = self.pose
        idle = [P(dy=1 if i in (3, 4, 5) else 0, cape=i // 2) for i in range(8)]
        walk = self.march()
        for i, q in enumerate(walk):
            q['cape'] = i
        command = [P(), P(sword=-80, hand=(4, 0), cape=1), P(sword=-90, hand=(3, -6), cape=2),
                   P(sword=-90, hand=(3, -7), cape=3, shout=1), P(sword=-90, hand=(3, -7), shout=2),
                   P(sword=-90, hand=(3, -7), cape=1, shout=3), P(sword=-40, hand=(6, -2), cape=2, shout=3),
                   P(sword=0, hand=(8, 0), cape=3, shout=2), P(sword=0, hand=(8, 0)), P(sword=-30, hand=(7, 2)), P()]
        attack = [P(), P(sword=-110, hand=(2, -3), fb=-4, lean=-1), P(sword=-150, hand=(0, -5), fb=-5, lean=-1, dy=1),
                  P(sword=-155, hand=(0, -5), fb=-5, lean=-1, dy=1, cape=1),
                  P(sword=-50, hand=(6, -3), dx=2, ff=5, fb=-5, lean=1, sm=(-160, -50), cape=2),
                  P(sword=15, hand=(8, 2), dx=3, ff=6, fb=-6, lean=2, sm=(-80, 15), cape=3, dy=1),
                  P(sword=35, hand=(8, 3), dx=3, ff=6, fb=-6, lean=2, dy=1), P(sword=20, hand=(7, 3), dx=2, ff=4, fb=-4),
                  P(sword=-30, hand=(6, 4), dx=1), P()]
        salute = [P(sword=s, hand=h, glint=1 if i in (3, 4) else 0) for i, (s, h) in
                  enumerate(((-60, (6, 4)), (-80, (4, 0)), (-90, (4, -2)), (-90, (4, -2)), (-90, (4, -2)), (-90, (4, -2)),
                             (-80, (4, 0)), (-60, (6, 4))))]
        return dict(Idle=idle, Walk=walk, Command=command, Attack=attack, Salute=salute,
                    Fall=self.fall_anim(cape=2), Land=self.land_anim())


# ================================================================ 稽查员:圆肚子短腿,高筒盔头顶一根冒汽小管子,印章锤
STAMP = sprite([
    ".bcdeeedj.",
    "bcdeffeemn",
    "bcdeeeeemn",
    "bcddddddmn",
    "abccccccmn",
    ".abbbbbbn.",
    "....jk....",
])


class Stamper(Armor):
    W, H, CX = 66, 50, 28
    LEG, THIGH, SHIN = 9, 4.6, 4.4
    THIGH_W, SHIN_W = (5.8, 5.0), (5.0, 4.4)
    SF, SB = (-2, 4), (-3, 3)
    TORSO_OX = TASSETS_OX = -5
    HELM_O = (-2, -12)
    BADGE = (11, 6)
    HELM = [
        "....jk...",
        "...ijkj..",
        "....jk...",
        ".bcdeeed.",
        "bcdeeffee",
        "bcdeeffee",
        "bcddeeeee",
        "bjkjdeeee",
        "bkikddeed",
        "bjkjaiiia",
        "bccdddddd",
        "abccddddc",
        ".abbcccb.",
    ]
    TORSO = [
        ".....ajjjd.....",
        "....bncdeed....",
        "...bcncdeeed...",
        "..bccbcdeeffd..",
        ".bcccbcddeeffd.",
        ".bcccbbcdeeefffe",
        ".bcccbbcdjkeeeee",
        ".bcccbbcdijeeeed",
        ".abccnabcdddddd.",
        "..abcnabbccccc..",
        "...ijjjjjjkji...",
    ]
    TASSETS = [
        ".cdaecdaecdae",
        ".bcabdcabdcab",
        "..b.abc.ab.a.",
    ]
    PAUL = [
        "..eff...",
        ".efgfe..",
        "deffffd.",
        "cdeeeedc",
        "abccccba",
        ".bdeedb.",
        ".abccba.",
    ]
    PAUL_O = (-4, -4)
    DEFAULT = dict(Armor.DEFAULT, ham=68, grip=7, hand=(8, 3), seal=0)

    def helm_extra(self, c, g, p):
        # 头顶小管子冒汽
        nx, ny = g['neck']
        tx, ty = nx + self.HELM_O[0] + 4, ny + self.HELM_O[1] - 1
        for k in range(3):
            ph = (p['steam'] + k * 3) % 9
            if ph < 7:
                x = tx + (ph // 3) - (1 if k == 1 else 0)
                put(c, x, ty - ph, col('w' if ph < 4 else 'x'))

    def front(self, c, g, p):
        hx, hy = g['hf']
        pole(c, hx, hy, p['ham'], 13, p['grip'], STAMP, (4, 6))
        if p['seal']:
            F = self.F
            sx = g['cx'] + 16
            fade = p['seal'] >= 4
            for x in range(sx, sx + 9):
                put(c, x, F, col('n' if fade else 'm'))
            if not fade:
                for x in (sx + 1, sx + 3, sx + 5, sx + 7):
                    put(c, x, F - 1, col('o'))
            for k in range(min(p['seal'], 3) * 2):
                for s in (-1, 1):
                    put(c, sx + 4 + s * (6 + k * 2), F - (k % 2), '#8a7a66')

    def anims(self):
        P = self.pose
        idle = self.breathe()
        for i, q in enumerate(idle):
            q['steam'] = i
        walk = self.march(stride=3.0, lift=2.4, ham=-50, grip=3, hand=(7, 2))
        for i, q in enumerate(walk):
            q['steam'] = i
        attack = [P(), P(ham=40, hand=(7, 2), grip=5), P(ham=-30, hand=(5, -1), grip=3, fb=-4),
                  P(ham=-110, hand=(2, -3), grip=3, fb=-5, lean=-1),
                  P(ham=-160, hand=(0, -5), grip=3, fb=-5, lean=-2, dy=1), P(ham=-165, hand=(0, -5), grip=3, fb=-5, lean=-2, dy=1),
                  P(ham=-60, hand=(6, -3), grip=3, dx=2, ff=5, fb=-5, lean=1),
                  P(ham=30, hand=(8, 3), grip=3, dx=3, ff=6, fb=-6, lean=2, dy=2, seal=1),
                  P(ham=36, hand=(8, 4), grip=3, dx=3, ff=6, fb=-6, lean=2, dy=3, seal=2),
                  P(ham=36, hand=(8, 4), grip=3, dx=3, ff=6, fb=-6, lean=2, dy=3, seal=3),
                  P(ham=60, hand=(8, 3), grip=5, dx=2, ff=4, fb=-4, seal=4), P(ham=80, hand=(8, 3), grip=6, dx=1, seal=4),
                  P(seal=4)]
        for i, q in enumerate(attack):
            q['steam'] = i
        return dict(Idle=idle, Walk=walk, Attack=attack, Salute=self.salute(rest=(8, 3), ham=-128, grip=3), Fall=self.fall_anim(ham=-128, grip=3),
                    Land=self.land_anim(ham=-128, grip=3))


# ================================================================ 刀翼兵(精英):细腰长腿,尖嘴盔,背上五片钢刀翼,悬空
class Wingblade(Armor):
    W, H, CX = 80, 60, 38
    LEG, THIGH, SHIN = 13, 6.4, 6.2
    THIGH_W, SHIN_W = (4.4, 3.6), (3.6, 2.8)
    UARM_W, FARM_W = (3.2, 2.8), (3.0, 2.6)
    HIPS = (-2, 2)
    SF, SB = (-2, 4), (-3, 3)
    TORSO_OX = TASSETS_OX = -4
    HELM_O = (-3, -8)
    BADGE = (8, 5)
    KNEE = [".ef", "def", ".cc"]
    KNEE_O = (-1, -1)
    BOOT = [".cdee.", "bcdeeff", ".ijjkj"]
    GAUNT = ["cd", "jk", "ij"]
    GAUNT_O = (-1, -1)
    ELBOW = [".e", "ed"]
    HELM = [
        "ef...........",
        ".dfe.........",
        "..cdeffe.....",
        ".bcdeeffee...",
        "bccddddeeeee.",
        "abcaiiiiiddeef",
        ".abccdddddcb..",
        "..abbccb......",
    ]
    TORSO = [
        "...ajjjd..",
        "...ncdeed.",
        "..bncdeffd",
        ".bccbcdeff",
        ".bccbcdeee",
        "..bcbbcdde",
        "...bbbcdd.",
        "...abbccc.",
        "...abbcc..",
        "...ijjkji.",
    ]
    TASSETS = [
        "..cdaecd..",
        "..bcabdc..",
    ]
    PAUL = [
        "....ef.",
        "..deffg",
        "cdeffed",
        "abcddcb",
        ".abbba.",
    ]
    PAUL_O = (-4, -3)
    DEFAULT = dict(Armor.DEFAULT, spread=0.3, flap=0, air=6, tuck=0.4, trail=0, blade=60, hand=(5, 4), ff=2, fb=-3)

    def behind(self, c, g, p):
        bx, by = g['sb'][0] - 1, g['ttop'] + 3
        lengths = (17, 21, 22, 18, 13)
        for i, L in enumerate(lengths):
            base = -100 - i * 22 - 18 * p['spread'] * (2 - i) * 0.5
            ang = math.radians(base + (3 if (p['flap'] + i) % 2 else -3) * (1 - p['spread'] * 0.5))
            L = L + round(4 * p['spread'])
            ux, uy = math.cos(ang), math.sin(ang)
            vx, vy = -uy, ux
            for k in range(3, L + 1):
                x, y = bx + ux * k, by + uy * k
                put(c, round(x), round(y), col('s' if k >= L - 1 else 't'))
                if k < L - 2:
                    put(c, round(x + vx), round(y + vy), col('u'))
                if k < L - 5:
                    put(c, round(x - vx), round(y - vy), col('d' if k % 5 == 0 else 'u'))
            for k in (2, 3):
                put(c, round(bx + ux * k), round(by + uy * k), col('d' if k == 2 else 'e'))
        stamp(c, [".de.", "defe", "cdkd", ".bc."], bx - 1, by - 1)
        for k in range(p['trail']):
            y = g['ttop'] + 6 + k * 4
            for x in range(g['cx'] - 12 - k * 3, g['cx'] - 3):
                if (x + k) % 2:
                    put(c, x, y, SMEAR[0] if x > g['cx'] - 7 else SMEAR[1])

    def front(self, c, g, p):
        hx, hy = g['hf']
        paste_dir(c, sprite(["jdssssss", "..tttttt"]), (1, 0), (hx, hy), p['blade'])

    def anims(self):
        P = self.pose
        idle = [P(air=6 + (1 if i in (1, 2) else 0), flap=i) for i in range(6)]
        walk = [P(air=7 + (i % 2), flap=i, spread=0.6, ff=1, fb=-4, lean=1, blade=70) for i in range(6)]
        attack = [P(), P(air=10, spread=0.7, flap=1, blade=10), P(air=14, spread=1.0, flap=2, blade=-20, lean=-1),
                  P(air=15, spread=1.0, flap=3, blade=-30, lean=-1), P(air=15, spread=1.0, flap=4, blade=-30, lean=-1),
                  P(air=10, dx=6, spread=0.2, blade=30, hand=(7, 3), trail=2, lean=2),
                  P(air=5, dx=12, spread=0.1, blade=40, hand=(7, 4), trail=3, lean=2),
                  P(air=3, dx=14, spread=0.1, blade=45, hand=(7, 4), trail=2, lean=2),
                  P(air=4, dx=14, spread=0.5, blade=60, trail=1), P(air=6, dx=12, spread=0.4), P(air=6, dx=6, spread=0.3),
                  P()]
        return dict(Idle=idle, Walk=walk, Attack=attack, Salute=self.salute(rest=(5, 4), air=6, tuck=0.4),
                    Fall=self.fall_anim(spread=1.0), Land=self.land_anim(tuck=0.0, air=0))


SPECS = dict(halberdier=Halberdier, tower=TowerShield, arbalest=Arbalest, commander=Commander, stamper=Stamper,
             wingblade=Wingblade)
