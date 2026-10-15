"""管道局 v2:浑身铜金板甲的兵。脸不画——全包头盔,只留一道粉光观察缝。
上身/头盔/肩甲是手摆的像素格子(甲片的高光线、缝、铆钉都是手点的),腿和胳膊按 IK 走,一节一节画成甲。
朝右画,每帧 100ms。"""
from PIL import Image
import math
from lib import put

PAL = {
    # 铜金:a 最暗(缝) → g 高光
    'a': '#22160c', 'b': '#4a3016', 'c': '#7a4f22', 'd': '#a67330', 'e': '#cc9a42', 'f': '#ebc86a', 'g': '#fff1b8',
    # 藏青衬布 / 黑铁
    'n': '#141927', 'm': '#24324e', 'i': '#1c1f24', 'j': '#363d45', 'k': '#5a626a',
    # 粉色能量
    'p': '#ffbcd7', 'q': '#d86e9a', 'r': '#8c3e6a', 'P': '#fff4f8',
    # 刀刃钢
    's': '#e4e6e2', 't': '#a8aca8', 'u': '#6a6e6c',
}
DIM = {'a': 'a', 'b': 'a', 'c': 'b', 'd': 'c', 'e': 'c', 'f': 'd', 'g': 'e', 'k': 'j', 'j': 'i', 'm': 'n', 'p': 'q', 'P': 'p'}


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


# ---------------------------------------------------------------- 手摆的甲片(照 sketch2 的整只拆出来)
HELM = [                           # 尖顶往后翘的猪嘴盔:眉沿压低、面甲往前拱,只露一道粉缝
    "..ef........",
    "..cdef......",
    ".bcdeffe....",
    ".bcdeeffe...",
    "bccdddeeed..",
    "bcccddddddc.",
    "abcaaqqppPa.",
    "abccdddddeed",
    ".abccddddcc.",
    "..abbccb....",
]
HELM_OX, HELM_OY = -2, -10          # 头盔左上角相对"颈点"(胸甲顶行 x=cx)
TORSO = [
    "....ajjjjd...",
    "....ncdeed...",
    "...bncdeffd..",
    "..bccbcdefffe",
    ".bcccbbcdeeed",
    ".bcccbbcddpqd",
    ".bcccbbcddrqd",
    ".abccnabcdddc",
    "..abcnabbccb.",
    "..abbn.bbcbb.",
    "...ijjjjkji..",
]
TORSO_OX = -4                      # 胸甲左上角相对胯中点 x;底行=腰带
CORE = (10, 5)                     # 胸口粉核在 TORSO 里的位置
TASSETS = [
    ".cdaecdaecd.",
    ".bcabdcabdc.",
    "..b.abc.ab..",
]
TASSETS_OX = -4
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
PAUL_OX, PAUL_OY = -6, -6          # 肩甲左上角相对肩点


class Armor:
    W, H = 50, 44
    CX = 20
    LEG = 11
    THIGH, SHIN = 5.2, 5.0
    UARM, FARM = 4.6, 4.8
    DEFAULT = dict(dx=0, dy=0, lean=0, ff=2, fb=-3, lf=0, lb=0, hand=(1, 7), bhand=(1, 6), air=0, tuck=0.0,
                   visor=1, core=1, dust=())
    HELM = HELM
    TORSO = TORSO
    PAUL = PAUL
    TASSETS = TASSETS

    def pose(self, **kw):
        d = dict(self.DEFAULT)
        d.update(kw)
        return d

    @property
    def F(self):
        return self.H - 1

    # ---------------------------------------------------------- 四肢:一节一节的粗甲管,迎面那侧亮
    def limb(self, c, x0, y0, x1, y1, w0, w1, back, ramp='bcde', hi=True):
        L = max(0.01, math.hypot(x1 - x0, y1 - y0))
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        fx, fy = uy, -ux                       # 朝前(脸朝的那侧)的法线
        if fx < 0 or (fx == 0 and fy > 0):
            fx, fy = -fx, -fy
        r = max(w0, w1) / 2 + 1
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
                    ch = 'f'
                if t > 0.9 and i > 0:
                    ch = ramp[i - 1]
                put(c, x, y, col(ch, back))

    def leg(self, c, hx, hy, fx, lift, back, tuck=0.0):
        F = self.F
        fy = F - 2 - lift                      # 脚踝
        if tuck:
            fx = lerp(fx, hx + 1, tuck)
        kx, ky = knee_pt(hx, hy, fx, fy, self.THIGH, self.SHIN, 1)
        self.limb(c, kx, ky, fx, fy, 4.6, 4.0, back)
        self.limb(c, hx, hy, kx, ky, 5.4, 4.8, back)
        kx, ky = int(round(kx)), int(round(ky))
        stamp(c, [".eff.", "deffe", "cdedc", ".bcb."], kx - 2, ky - 2, back)
        bx, by = int(round(fx)), F - lift
        stamp(c, [".cdef..", "bcdeefe", "ijjjkkj"], bx - 2, by - 2, back)

    def arm(self, c, sx, sy, hx, hy, back):
        ex, ey = knee_pt(sx, sy, hx, hy, self.UARM, self.FARM, -1)
        self.limb(c, sx, sy, ex, ey, 3.6, 3.2, back)
        self.limb(c, ex, ey, hx, hy, 3.6, 3.0, back)
        ex, ey = int(round(ex)), int(round(ey))
        stamp(c, [".e.", "efd", ".c."], ex - 1, ey - 1, back)
        hx, hy = int(round(hx)), int(round(hy))
        stamp(c, ["cde", "jkk", "ijk", ".ij"], hx - 1, hy - 2, back)

    # ---------------------------------------------------------- 钩子
    def behind(self, c, g, p):
        pass

    def held_back(self, c, g, p):
        """前手武器里要画在身子后面的部分"""
        pass

    def front(self, c, g, p):
        pass

    def helm_extra(self, c, g, p):
        pass

    def render(self, p):
        c = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        F = self.F
        air = round(p['air'])
        cx = self.CX + round(p['dx'])
        hip = F - self.LEG + round(p['dy']) - air
        lean = round(p['lean'])
        n = len(self.TORSO)
        ttop = hip - n - 2
        g = dict(cx=cx, hip=hip, ttop=ttop)
        g['neck'] = (cx + lean, ttop)
        g['sf'] = (cx - 3 + lean, ttop + 5)
        g['sb'] = (cx - 4 + lean, ttop + 4)
        g['hf'] = (g['sf'][0] + p['hand'][0], g['sf'][1] + p['hand'][1])
        g['hb'] = (g['sb'][0] + p['bhand'][0], g['sb'][1] + p['bhand'][1])
        self.behind(c, g, p)
        # 后:胳膊、肩甲、腿
        self.arm(c, *g['sb'], *g['hb'], back=True)
        stamp(c, self.PAUL, g['sb'][0] + PAUL_OX, g['sb'][1] + PAUL_OY, dim=True)
        self.leg(c, cx - 3, hip, cx - 3 + p['fb'], round(p['lb']) + air, True, p['tuck'])
        self.held_back(c, g, p)
        # 身子:胸甲(前倾时上面几行往前挪)
        for y, r in enumerate(self.TORSO):
            sx = round(lean * (n - 1 - y) / (n - 1))
            stamp(c, [r], cx + TORSO_OX + sx, ttop + y)
        cxo = cx + TORSO_OX + CORE[0] + round(lean * (n - 1 - CORE[1]) / (n - 1))
        if p['core'] > 1:
            put(c, cxo, ttop + CORE[1], col('P'))
        elif not p['core']:
            put(c, cxo, ttop + CORE[1], col('r'))
            put(c, cxo + 1, ttop + CORE[1], col('r'))
        self.leg(c, cx + 3, hip, cx + 3 + p['ff'], round(p['lf']) + air, False, p['tuck'])
        stamp(c, self.TASSETS, cx + TASSETS_OX, ttop + n)
        # 头盔
        nx, ny = g['neck']
        stamp(c, self.HELM, nx + HELM_OX, ny + HELM_OY)
        if not p['visor']:
            for x in range(5, 10):
                put(c, nx + HELM_OX + x, ny + HELM_OY + 6, col('a'))
        self.helm_extra(c, g, p)
        # 前胳膊 + 前肩甲
        self.arm(c, *g['sf'], *g['hf'], back=False)
        stamp(c, self.PAUL, g['sf'][0] + PAUL_OX, g['sf'][1] + PAUL_OY)
        self.front(c, g, p)
        for (ex, ey, k) in p['dust']:
            put(c, ex, ey, ['#8a7a66', '#6a5c4c'][k % 2])
        return c

    # ---------------------------------------------------------- 通用动作
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

    def salute(self, **kw):
        """拳头捶胸甲"""
        keys = [(3, 7), (3, 4), (2, 2), (2, 2), (2, 2), (2, 2), (3, 4), (3, 7)]
        out = []
        for i, h in enumerate(keys):
            d = dict(hand=h, core=2 if i in (2, 3) else 1)
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


def sprite(rows, dim=False):
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    stamp(im, rows, 0, 0, dim)
    return im


def paste_rot(c, spr, anchor, at, ang):
    """spr 朝上画、anchor 是它挂在杆上的点;ang = 杆的朝向(度,屏幕坐标,-90=朝上)"""
    R = max(spr.width, spr.height) * 2 + 2
    big = Image.new('RGBA', (R * 2 + 1, R * 2 + 1), (0, 0, 0, 0))
    big.paste(spr, (R - anchor[0], R - anchor[1]))
    rot = big.rotate(-(ang + 90), resample=Image.NEAREST, center=(R, R))
    c.alpha_composite(rot, (int(round(at[0])) - R, int(round(at[1])) - R)) if 0 else _paste_clip(c, rot, int(round(at[0])) - R, int(round(at[1])) - R)


def _paste_clip(c, im, x, y):
    for yy in range(im.height):
        for xx in range(im.width):
            px = im.getpixel((xx, yy))
            if px[3]:
                put(c, x + xx, y + yy, px)


def pole(c, hx, hy, ang, length, grip, head=None, anchor=(0, 0), shaft=('j', 'k')):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    pts = line_pts(hx - ux * grip, hy - uy * grip, hx + ux * (length - grip), hy + uy * (length - grip))
    for i, (x, y) in enumerate(pts):
        put(c, x, y, col(shaft[1] if i % 6 == 3 else shaft[0]))
    if head is not None:
        paste_rot(c, head, anchor, pts[-1], ang)
    return pts[-1]


def smear(c, cx, cy, r, a0, a1, cols=('#ffbcd7', '#d86e9a')):
    for rr, cc, skip in ((r, cols[0], 0.0), (r - 1, cols[1], 0.3), (r - 2, cols[1], 0.6)):
        for k in range(100):
            t = k / 99
            if t < skip:
                continue
            a = math.radians(a0 + (a1 - a0) * t)
            put(c, round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), cc)


def paste_dir(c, spr, anchor, at, ang):
    """spr 朝右画;ang = 朝向(度,屏幕坐标,0=朝右,-90=朝上)"""
    R = max(spr.width, spr.height) * 2 + 2
    big = Image.new('RGBA', (R * 2 + 1, R * 2 + 1), (0, 0, 0, 0))
    big.paste(spr, (R - anchor[0], R - anchor[1]))
    rot = big.rotate(-ang, resample=Image.NEAREST, center=(R, R)) if ang else big
    _paste_clip(c, rot, int(round(at[0])) - R, int(round(at[1])) - R)


# ================================================================ 戟卫:长戟,大斧刃一道粉刃口
HALBERD = sprite([
    "....g.....",
    "....f.....",
    "...efe....",
    "...ded.de.",
    "bc.cddeeep",
    ".bccdeeeep",
    "...cddeeep",
    "...bcddeqp",
    "...bc.dqq.",
    "....d.....",
    "....k.....",
])


class Halberdier(Armor):
    W, H, CX = 76, 52, 34
    DEFAULT = dict(Armor.DEFAULT, hand=(7, 3), pole=-72, grip=11, sm=None)

    def front(self, c, g, p):
        hx, hy = g['hf']
        pole(c, hx, hy, p['pole'], 30, p['grip'], HALBERD, (4, 10), shaft=('j', 'c'))
        if p['sm']:
            smear(c, hx, hy, 30 - p['grip'] + 6, *p['sm'])

    def anims(self):
        P = self.pose
        idle = self.breathe()
        walk = self.march()
        attack = [P(), P(hand=(5, 1), pole=-90, fb=-4), P(pole=-120, grip=8, hand=(2, -3), fb=-5, lean=-1),
                  P(pole=-150, grip=6, hand=(0, -5), fb=-5, lean=-1, dy=1),
                  P(pole=-155, grip=6, hand=(0, -5), fb=-5, lean=-1, dy=1),
                  P(pole=-70, grip=6, hand=(6, -3), dx=2, ff=5, fb=-5, lean=1, sm=(-160, -70)),
                  P(pole=-5, grip=6, hand=(8, 1), dx=3, ff=6, fb=-6, lean=2, dy=1, sm=(-100, -5)),
                  P(pole=25, grip=6, hand=(8, 3), dx=3, ff=6, fb=-6, lean=2, dy=2),
                  P(pole=22, grip=6, hand=(8, 3), dx=3, ff=6, fb=-6, lean=2, dy=2),
                  P(pole=-30, grip=8, hand=(7, 3), dx=2, ff=4, fb=-4, lean=1), P(pole=-60, hand=(7, 3), dx=1),
                  P()]
        return dict(Idle=idle, Walk=walk, Attack=attack, Salute=self.salute(), Fall=self.fall_anim(),
                    Land=self.land_anim())


# ================================================================ 盾卫:一人高铜塔盾 + 从盾上沿捅出来的长矛(方阵)
TOWER = sprite([
    ".bdeef..",
    "bcdeffg.",
    "bcdeeffe",
    "bcdeeffe",
    "bcddeefe",
    "bcddqqee",
    "bcdqppqe",
    "bcddqqee",
    "bcddqqee",
    "bcddqqee",
    "bcdqppqe",
    "bcddqqee",
    "bcddddee",
    "bccdddde",
    "bccdddde",
    "bcccddde",
    "abccddde",
    "abccdddd",
    ".abccddc",
    "..abccc.",
    "...abc..",
])
SPEAR = sprite([
    "jkkcdeefg",
    ".....dee.",
])


class TowerShield(Armor):
    W, H, CX = 64, 46, 24
    DEFAULT = dict(Armor.DEFAULT, hand=(8, 4), bhand=(5, 0), spear=-3, reach=0, push=0, clang=0)

    def held_back(self, c, g, p):
        hx, hy = g['hb']
        a = math.radians(p['spear'])
        ux, uy = math.cos(a), math.sin(a)
        hx, hy = hx + ux * p['reach'], hy + uy * p['reach']
        tip = pole(c, hx, hy, p['spear'], 22, 7, shaft=('j', 'c'))
        paste_dir(c, SPEAR, (0, 0), tip, p['spear'])
        if p['reach'] > 3:
            for k in range(3):
                put(c, round(tip[0] + 9 + k * 2), round(tip[1]), col('p' if k else 'P'))

    def front(self, c, g, p):
        hx, hy = g['hf']
        sx, sy = hx - 3 + p['push'], hy - 9
        _paste_clip(c, TOWER, sx, sy)
        if p['clang']:
            for (dx, dy, cc) in ((8, 4, '#fff0b0'), (9, 2, '#ffc860'), (9, 7, '#ffc860'), (10, 5, '#e07830'), (11, 3, '#e07830')):
                put(c, sx + dx, sy + dy, cc)

    def anims(self):
        P = self.pose
        idle = self.breathe()
        walk = self.march(stride=3.0, lift=2.2)
        attack = [P(), P(reach=-2, fb=-4), P(reach=-4, fb=-5, lean=-1), P(reach=-4, fb=-5, lean=-1, dy=1),
                  P(reach=8, dx=1, ff=4, fb=-5, lean=1), P(reach=10, dx=2, ff=5, fb=-5, lean=1),
                  P(reach=10, dx=2, ff=5, fb=-5, lean=1), P(reach=4, dx=1, ff=3, fb=-4), P(reach=1), P()]
        bash = [P(), P(push=-1, fb=-4, lean=-1), P(push=-2, fb=-5, lean=-1, dy=1), P(push=-2, fb=-5, lean=-1, dy=1),
                P(push=3, dx=3, ff=6, fb=-6, lean=2), P(push=4, dx=4, ff=6, fb=-6, lean=2),
                P(push=3, dx=4, ff=5, fb=-5, lean=1), P(push=1, dx=3, ff=4, fb=-4), P(dx=1), P()]
        block = [P(push=-1, clang=1, dx=-1, dy=1), P(push=-1, dy=1), P()]
        salute = [P(spear=s, bhand=h) for s, h in ((-3, (5, -1)), (-40, (4, -3)), (-90, (3, -5)), (-90, (3, -5)),
                                                    (-90, (3, -5)), (-90, (3, -5)), (-40, (4, -3)), (-3, (5, -1)))]
        return dict(Idle=idle, Walk=walk, Attack=attack, Bash=bash, Block=block, Salute=salute,
                    Fall=self.fall_anim(), Land=self.land_anim())


# ================================================================ 重弩手:扛铜重弩,单膝跪地射粉色能量弩箭
def _arbalest(loaded, charge):
    im = Image.new('RGBA', (23, 10), (0, 0, 0, 0))
    for (x, y) in line_pts(19, 1, 9, 4) + line_pts(19, 8, 9, 5):       # 弦
        put(im, x, y, col('q'))
    stamp(im, [
        "..jjjjjjjjjjjjjjjjk",
        "bcdeedkkkkkkkkkkkjk",
        "bcddcdjjjjjjjjjjjjk",
        "abb.ij..........ij.",
        "....ij.............",
    ], 0, 3)
    for (x, y, ch) in ((18, 2, 'j'), (18, 1, 'k'), (19, 0, 'k'), (19, 1, 'j'), (18, 7, 'j'), (18, 8, 'k'), (19, 9, 'k'), (19, 8, 'j'),
                       (17, 3, 'k'), (17, 6, 'j')):
        put(im, x, y, col(ch))
    if loaded:
        stamp(im, ["rqqqqqppppP" if charge < 2 else "qppppppPPPP"], 9, 3)
        put(im, 20, 3, col('P'))
    put(im, 4, 4, col('P' if charge > 1 else 'p'))      # 弩机上的能量核
    return im


ARB_BOLT = None


class Arbalest(Armor):
    W, H, CX = 60, 46, 22
    DEFAULT = dict(Armor.DEFAULT, hand=(7, 0), bhand=(5, 1), aim=-20, loaded=1, recoil=0, charge=0)
    KNEEL = dict(dy=5, ff=4, fb=-6)

    def front(self, c, g, p):
        hx, hy = g['hf'][0] - p['recoil'], g['hf'][1]
        paste_dir(c, _arbalest(p['loaded'], p['charge']), (5, 4), (hx, hy), p['aim'])

    def anims(self):
        P = self.pose
        K = self.KNEEL
        idle = self.breathe()
        walk = self.march()
        aim = [P(), P(aim=-10, dy=2, ff=4, fb=-4), P(aim=0, **K), P(aim=0, **K)]
        hold = [P(aim=0, charge=1 + i % 2, **K) for i in range(4)]
        shoot = [P(aim=-4, recoil=3, loaded=0, **K), P(aim=-6, recoil=2, loaded=0, **K),
                 P(aim=-2, recoil=1, loaded=0, **K), P(aim=0, loaded=0, **K)]
        reload = [P(aim=30, hand=(5, 2), loaded=0, **K), P(aim=60, hand=(4, 3), loaded=0, **K),
                  P(aim=60, hand=(4, 3), **K), P(aim=20, hand=(5, 2), dy=2, ff=4, fb=-4), P()]
        return dict(Idle=idle, Walk=walk, Aim=aim, Hold=hold, Shoot=shoot, Reload=reload, Salute=self.salute(),
                    Fall=self.fall_anim(), Land=self.land_anim())


# ================================================================ 队长:粉盔缨 + 藏青披风 + 大剑
GREATSWORD = sprite([
    "....e..............",
    "jjkdesssssssssssssP",
    "....dtttttttttttqp.",
    "....c..............",
])


class Commander(Armor):
    W, H, CX = 68, 52, 30
    DEFAULT = dict(Armor.DEFAULT, sword=-60, sm=None, cape=0, shout=0, hand=(6, 4))

    def behind(self, c, g, p):
        sx, sy = g['sb'][0] - 1, g['ttop'] + 1
        sway = (0, 1, 2, 1)[p['cape'] % 4]
        hip = g['hip']
        rows = hip + 8 - sy
        for i in range(rows):
            t = i / max(1, rows - 1)
            x0 = round(sx - 1 - t * (3 + sway))
            x1 = round(sx + 4 - t * 1)
            for x in range(x0, x1 + 1):
                ch = 'n' if x < x0 + 2 else 'm'
                if x == x0:
                    ch = 'c' if i % 3 == 0 else 'b'
                put(c, x, sy + i, col(ch))
        for x in range(round(sx - 4 - sway), sx + 4):
            if (x + p['cape']) % 2:
                put(c, x, sy + rows, col('d'))

    def helm_extra(self, c, g, p):
        nx, ny = g['neck']
        top = ny + HELM_OY
        sway = (0, 1, 0, -1)[p['cape'] % 4]
        # 一把往后甩的粉色马鬃:顶上亮、下面暗,尾巴随披风摆
        for i in range(9):
            x = nx + 2 - i
            y = top - 1 + i // 2 + (sway if i > 5 else 0)
            put(c, x, y, col('p'))
            put(c, x, y + 1, col('q'))
            if 2 < i < 8:
                put(c, x, y + 2, col('r'))
        put(c, nx, top, col('p'))
        if p['shout']:
            mx, my = nx + 10, top + 6
            for k in range(p['shout']):
                r = 3 + k * 3
                for a in range(-40, 41, 10):
                    aa = math.radians(a)
                    put(c, round(mx + math.cos(aa) * r), round(my + math.sin(aa) * r), col('p' if k == p['shout'] - 1 else 'q'))

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
        return dict(Idle=idle, Walk=walk, Command=command, Attack=attack, Salute=self.salute(),
                    Fall=self.fall_anim(cape=2), Land=self.land_anim())


# ================================================================ 稽查员:巨型印章锤,砸地留一个粉色罚章
STAMP = sprite([
    ".bcdeeep..",
    "bcdeffeepq",
    "bcdeeeeepq",
    "bcddddddpq",
    "abccccccqr",
    ".abbbbbbq.",
    "....jk....",
])


class Stamper(Armor):
    W, H, CX = 66, 50, 28
    DEFAULT = dict(Armor.DEFAULT, ham=-128, grip=3, hand=(5, 1), seal=0)

    def front(self, c, g, p):
        hx, hy = g['hf']
        pole(c, hx, hy, p['ham'], 13, p['grip'], STAMP, (4, 6), shaft=('j', 'c'))
        if p['seal']:
            F = self.F
            sx = g['cx'] + 15
            fade = p['seal'] >= 4
            for x in range(sx, sx + 9):
                put(c, x, F, col('r' if fade else 'q'))
            if not fade:
                for x in (sx + 1, sx + 3, sx + 5, sx + 7):
                    put(c, x, F - 1, col('p'))
            for k in range(min(p['seal'], 3) * 2):
                for s in (-1, 1):
                    put(c, sx + 4 + s * (6 + k * 2), F - (k % 2), '#8a7a66')

    def anims(self):
        P = self.pose
        idle = self.breathe()
        walk = self.march()
        attack = [P(), P(ham=-110, hand=(3, -1), fb=-4, lean=-1), P(ham=-150, hand=(0, -4), fb=-5, lean=-1, dy=1),
                  P(ham=-175, hand=(-1, -6), fb=-5, lean=-2, dy=1), P(ham=-178, hand=(-1, -6), fb=-5, lean=-2, dy=1),
                  P(ham=-60, hand=(6, -3), dx=2, ff=5, fb=-5, lean=1),
                  P(ham=30, hand=(8, 3), dx=3, ff=6, fb=-6, lean=2, dy=2, seal=1),
                  P(ham=36, hand=(8, 4), dx=3, ff=6, fb=-6, lean=2, dy=3, seal=2),
                  P(ham=36, hand=(8, 4), dx=3, ff=6, fb=-6, lean=2, dy=3, seal=3),
                  P(ham=-10, hand=(7, 3), dx=2, ff=4, fb=-4, seal=4), P(ham=-80, hand=(6, 1), dx=1, seal=4),
                  P(seal=4)]
        return dict(Idle=idle, Walk=walk, Attack=attack, Salute=self.salute(), Fall=self.fall_anim(),
                    Land=self.land_anim())


# ================================================================ 刀翼兵(精英):背一对机械刀翼,悬空,升高再俯冲
class Wingblade(Armor):
    W, H, CX = 76, 56, 36
    DEFAULT = dict(Armor.DEFAULT, spread=0.3, flap=0, air=5, tuck=0.5, trail=0, blade=60, hand=(5, 4), ff=2, fb=-3)

    def behind(self, c, g, p):
        bx, by = g['sb'][0] - 1, g['ttop'] + 3
        lengths = (16, 20, 21, 17, 12)
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
                    put(c, round(x - vx), round(y - vy), col('q' if k % 4 == 0 else 'u'))
            for k in (2, 3):
                put(c, round(bx + ux * k), round(by + uy * k), col('d' if k == 2 else 'e'))
        stamp(c, [".de.", "defe", "cdpd", ".bc."], bx - 1, by - 1)
        for k in range(p['trail']):
            y = g['ttop'] + 6 + k * 4
            for x in range(g['cx'] - 12 - k * 3, g['cx'] - 3):
                if (x + k) % 2:
                    put(c, x, y, col('p' if x > g['cx'] - 7 else 'q'))

    def front(self, c, g, p):
        hx, hy = g['hf']
        paste_dir(c, sprite(["jdssssssP", "..tttttqp"]), (1, 0), (hx, hy), p['blade'])

    def anims(self):
        P = self.pose
        idle = [P(air=5 + (1 if i in (1, 2) else 0), flap=i) for i in range(6)]
        walk = [P(air=6 + (i % 2), flap=i, spread=0.6, ff=1, fb=-4, lean=1, blade=70) for i in range(6)]
        attack = [P(), P(air=9, spread=0.7, flap=1, blade=10), P(air=13, spread=1.0, flap=2, blade=-20, lean=-1),
                  P(air=14, spread=1.0, flap=3, blade=-30, lean=-1), P(air=14, spread=1.0, flap=4, blade=-30, lean=-1),
                  P(air=9, dx=6, spread=0.2, blade=30, hand=(7, 3), trail=2, lean=2),
                  P(air=4, dx=12, spread=0.1, blade=40, hand=(7, 4), trail=3, lean=2),
                  P(air=2, dx=14, spread=0.1, blade=45, hand=(7, 4), trail=2, lean=2),
                  P(air=3, dx=14, spread=0.5, blade=60, trail=1), P(air=5, dx=12, spread=0.4), P(air=5, dx=6, spread=0.3),
                  P()]
        return dict(Idle=idle, Walk=walk, Attack=attack, Salute=self.salute(air=5, tuck=0.5),
                    Fall=self.fall_anim(spread=1.0), Land=self.land_anim(tuck=0.0, air=0))


class Bare(Armor):
    def anims(self):
        return dict(Idle=self.breathe(), Walk=self.march())


SPECS = dict(halberdier=Halberdier, tower=TowerShield, arbalest=Arbalest, commander=Commander, stamper=Stamper,
             wingblade=Wingblade, bare=Bare)
