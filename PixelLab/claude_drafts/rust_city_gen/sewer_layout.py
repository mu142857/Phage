# 下水道三段(管道局的地盘)。主街井盖(门 id 6)→ 一段【过段费】→(41)二段【赔灯费】→(42)三段【清场费,奥斯卡帮砸进来】
# →(43)爬出井口到竞技场街。每段:kit 室内模式 + 手画的拱顶石墙/石沿水渠 + 管道局检查站 + 怪直接写在场景里。
#   python3 sewer_layout.py          全部
#   python3 sewer_layout.py 2        只生成第二段
import sys, math
from PIL import Image
from kit import *
import sewer as S
from pxlib import Canvas, shade, mix, LIT, RUST

DIR = "levels/rust_city/sewer"
MAIN = "res://levels/rust_arena/rust_city.tscn"
ARENA_ST = "res://levels/rust_city/arena_street/arena_street.tscn"
WARM = "Color(0.95, 0.68, 0.36, 1)"
G = GROUND

MOBS = {
    "halberdier": "res://entities/bureau/halberdier/halberdier.tscn",
    "tower": "res://entities/bureau/tower/tower.tscn",
    "arbalest": "res://entities/bureau/arbalest/arbalest.tscn",
    "commander": "res://entities/bureau/commander/commander.tscn",
    "stamper": "res://entities/bureau/stamper/stamper.tscn",
    "wingblade": "res://entities/bureau/wingblade/wingblade.tscn",
}
COINS = dict(halberdier=3, tower=3, arbalest=2, commander=8, stamper=6, wingblade=5)


def scene_path(n):
    return f"res://{DIR}/sewer_{n}.tscn"


class SewerRoom:
    def __init__(self, n, W, player_x=30, cm=0.45):
        self.n, self.W = n, W
        self.A = Alley(DIR, f"sewer_{n}", f"Sewer{n}", W, interior=True, canvas_modulate=cm, brightness=0.8,
                       player_x=player_x)
        self.A.ext["gate"] = ("PackedScene", f"res://{DIR}/bureau_gate.tscn")
        self.A.ext["squad"] = ("Script", "res://entities/bureau/bureau_squad.gd")
        self.A.ext["room"] = ("Script", f"res://{DIR}/sewer_{n}.gd")
        self.k = 0
        self.lamps = []
        self.mobs = []          # (parent, name, kind, x, y, extra)
        self.squads = []        # (name, props)

    def wall(self, bays, branches=(), extra=None, seed=None):
        c = S.tunnel_wall(self.W, seed=seed or 600 + self.n, bays=bays)
        for (x, kind, to_y) in branches:
            S.branch(c, x, 15, to_y, kind)
        if extra:
            extra(c)
        self.A.save(f"wall{self.n}", c)
        self.A.building("Wall", f"wall{self.n}", 0, 90)

    def floor(self):
        self.A.save(f"walkway{self.n}", S.walkway(self.W, seed=610 + self.n))
        self.A.save(f"glint{self.n}", S.water_glint(self.W, seed=620 + self.n))
        self.A.node("Floor", "Node2D", ".", z_index="10")
        self.A.node("Walkway", "Sprite2D", "Floor", light_mask="3", position=V(0, G), texture=self.A.E(f"walkway{self.n}"), centered="false")
        self.A.node("Glint", "Sprite2D", "Floor", light_mask="0", modulate="Color(0.8, 0.85, 0.85, 0.7)", position=V(0, G + 6),
                    texture=self.A.E(f"glint{self.n}"), centered="false", material='SubResource("ClothSwingFront")')

    def deco(self, key, canvas, left, bottom, parent="Buildings", **extra):
        self.A.save(key, canvas)
        self.k += 1
        name = f"{key.capitalize()}{self.k}"
        self.A.sprite(parent, name, key, left, bottom, **extra)
        return name

    def lamp(self, x, chain=8, energy=3.0):
        self.A.save(f"cage_lamp{chain}", S.cage_lamp(chain=chain))
        self.k += 1
        self.A.sprite("Buildings", f"Lamp{self.k}", f"cage_lamp{chain}", x - 3, 11 + chain + 9, light_mask="2")
        name = f"LampGlow{self.k}"
        self.A.glow(name, x, 11 + chain + 4, scale=1.1, energy=energy, color=WARM)
        self.lamps.append(f"Buildings/{name}")

    def manhole(self, x, light=True):
        """拱顶上的井口 + 梯子(+ 井口漏下来的光)"""
        self.deco("manhole_shaft", S.manhole_shaft(), x - 8, 12)
        self.deco("ladder", S.ladder(G - 11), x - 2, G)
        if light:
            self.A.save("light_shaft", S.light_shaft(h=G - 10))
            self.A.node("LightShaft", "Sprite2D", ".", z_index="11", light_mask="0", position=V(x - 6, 10),
                        texture=self.A.E("light_shaft"), centered="false")

    def gate(self, x):
        self.A.node("Gate", None, "Props", inst="gate", position=V(x + 7, G))

    def checkpoint(self, desk_x, fee, board_y=40):
        self.deco("desk", S.desk(), desk_x, G, parent="Props")
        self.deco(f"price{fee}", S.price_board(fee), desk_x - 2, board_y + 17)

    def crate(self, x, bottom=G, seed=0):
        key = f"bcrate{seed % 3}"
        self.A.save(key, S.bureau_crate(seed=626 + seed % 3))
        self.k += 1
        return self.A.prop(f"Crate{self.k}", key, x, bottom)

    def banner(self, x, h=24):
        self.deco(f"banner{h}", S.banner(h=h), x, 21 + h)

    def mob(self, kind, name, x, parent="Bureau", y=G, **extra):
        self.mobs.append((parent, name, kind, x, y, extra))

    def squad(self, name, **props):
        self.squads.append((name, props))

    def door(self, name, x, scene, tid, y=76):
        self.A.door(name, x, scene, tid, y=y)

    def write(self, room_props):
        A = self.A
        for k, p in MOBS.items():
            A.ext["m_" + k] = ("PackedScene", p)
        A.node("Bureau", "Node2D", ".")
        for name, props in self.squads:
            pp = {k: (str(v) if not isinstance(v, str) else v) for k, v in props.items()}
            A.node(name, "Node2D", "Bureau", script=A.E("squad"), **pp)
        for parent, name, kind, x, y, extra in self.mobs:
            props = dict(position=V(x, y), coins=str(COINS[kind]))
            props.update({k: str(v) for k, v in extra.items()})
            A.node(name, None, parent, inst="m_" + kind, **props)
        rp = dict(room_props)
        if self.lamps and self.n == 1:
            rp["lamps"] = "[" + ", ".join(f'NodePath("../{p}")' for p in self.lamps) + "]"
        A.node("Room", "Node", ".", script=A.E("room"), **rp)
        A.write()


def gate_scene():
    """检查站铁栅门场景(StaticBody2D,碰撞 14×44,贴图原点在脚底)"""
    img = S.grate_gate()
    img.save(PROJ + DIR + "/grate_gate.png")
    open(PROJ + DIR + "/bureau_gate.tscn", "w").write(f'''[gd_scene format=3]

[ext_resource type="Script" path="res://{DIR}/bureau_gate.gd" id="1"]
[ext_resource type="Texture2D" path="res://{DIR}/grate_gate.png" id="2"]

[sub_resource type="RectangleShape2D" id="Shape"]
size = Vector2(12, 44)

[node name="BureauGate" type="StaticBody2D"]
collision_mask = 0
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2(0, -22)
texture = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -22)
shape = SubResource("Shape")
''')


def broken_lamp(seed=651):
    """被打坏的笼灯:笼子歪了、灯泡碎了(不亮),地上一小撮碎玻璃另画"""
    c = Canvas(9, 17, seed)
    for y in range(0, 8, 2):
        c.set(4, y, (82, 76, 68))
    pts = [(2, 8), (6, 9)]
    c.hline(2, 6, 8, S.BRASS_R[2])
    for y in range(9, 15):
        c.set(2 + (y - 9) // 3, y, S.BRASS_R[2]); c.set(6 + (y - 9) // 4, y, S.BRASS_R[1])
    for y in range(10, 14):
        c.set(4 + (y - 10) // 2, y, (60, 52, 40))
    c.set(4, 11, (120, 110, 90)); c.set(5, 13, (150, 140, 120))
    c.hline(3, 7, 15, S.BRASS_R[1])
    return c


def glass_bits(seed=652):
    c = Canvas(9, 2, seed)
    for x in (0, 2, 3, 6, 8):
        c.set(x, 1, (150, 160, 150))
    c.set(4, 0, (200, 206, 196))
    return c


def ceiling_hole(seed=653, w=30):
    """拱顶被砸穿的洞:黑洞 + 一圈碎砖 + 断掉的铁栅"""
    c = Canvas(w, 16, seed)
    rng = c.rng
    for y in range(16):
        for x in range(w):
            d = abs(x - w / 2) / (w / 2) + y / 18 + (rng.random() - 0.5) * 0.2
            if d < 0.85:
                c.set(x, y, S.DARK)
            elif d < 1.05:
                c.set(x, y, S.VAULT[rng.randint(1, 4)])
    for x in range(3, w - 3, 3):
        L = rng.randint(2, 6)
        c.vline(x, 9, 9 + L, (70, 60, 52))
    return c


# =================================================================== 第一段【过段费】
def room1():
    R = SewerRoom(1, 560)
    R.wall([(110, 22, "outlet"), (222, 24, "plain"), (446, 26, "tunnel"), (530, 20, "tunnel")],
           branches=[(150, "valve", 58), (392, "gauge", 62), (306, "floor", G)])
    R.floor()
    R.manhole(30)
    R.door("ToStreet", 30, MAIN, 6)
    # 检查站
    R.checkpoint(250, 20)
    R.banner(196)
    R.banner(352)
    R.lamp(236)
    R.lamp(318, chain=6)
    R.lamp(470, chain=10, energy=1.8)
    R.gate(330)
    R.crate(372, seed=0); R.crate(385, seed=1); R.crate(378, bottom=G - 11, seed=2)
    R.crate(410, seed=1)
    R.mob("stamper", "Stamper", 284)
    R.mob("halberdier", "GuardL", 238)
    R.mob("halberdier", "GuardR", 316)
    R.door("ToSewer2", 532, scene_path(2), 41)
    R.write(dict(room_key='"sewer_1"', fee="20", fee_name='"过段费"', officer_path='NodePath("../Bureau/Stamper")',
                 gate_path='NodePath("../Props/Gate")'))


# =================================================================== 第二段【赔灯费】
def room2():
    R = SewerRoom(2, 640)
    R.wall([(24, 20, "tunnel"), (206, 24, "outlet"), (404, 26, "plain"), (560, 22, "outlet")],
           branches=[(96, "gauge", 60), (300, "valve", 56), (482, "floor", G)], seed=642)
    R.floor()
    R.door("ToSewer1", 24, scene_path(1), 41)
    # 被"打坏"的那盏灯(一进门就看见)
    R.deco("broken_lamp", broken_lamp(), 58, 11 + 17)
    R.deco("glass_bits", glass_bits(), 59, G, parent="Props")
    R.checkpoint(128, 30)
    R.lamp(176)
    R.lamp(300, chain=6)
    R.lamp(430)
    R.lamp(570, chain=6)
    R.banner(250, h=28)
    R.banner(520)
    R.crate(466, seed=0); R.crate(479, seed=2); R.crate(472, bottom=G - 11, seed=1)
    R.gate(596)
    R.door("ToSewer3", 622, scene_path(3), 42)
    R.mob("stamper", "Stamper", 162)
    # 一整队:面朝左(朝进来的方向),在 250~520 之间齐步巡逻
    R.squad("Squad", facing=-1.0, patrol_left=240.0, patrol_right=470.0, march_speed=11.0)
    for name, kind, x in (("Tower1", "tower", 262), ("Tower2", "tower", 286), ("Halberd", "halberdier", 312),
                          ("Commander", "commander", 340), ("Arbalest1", "arbalest", 368), ("Arbalest2", "arbalest", 392)):
        R.mob(kind, name, x, parent="Bureau/Squad")
    R.write(dict(room_key='"sewer_2"', fee="30", fee_name='"赔灯费"', officer_path='NodePath("../Bureau/Stamper")',
                 gate_path='NodePath("../Props/Gate")'))


# =================================================================== 第三段【清场费】
def room3():
    R = SewerRoom(3, 640)

    def gang_marks(c):
        from backalley import _tag_scarf
        _tag_scarf(c, 264, 44, 1.0)
        _tag_scarf(c, 360, 56, 0.8)
    R.wall([(24, 20, "tunnel"), (150, 22, "outlet"), (312, 30, "plain"), (520, 24, "plain")],
           branches=[(214, "valve", 60), (448, "gauge", 58)], extra=gang_marks, seed=663)
    R.floor()
    R.door("ToSewer2", 24, scene_path(2), 42)
    R.deco("ceiling_hole", ceiling_hole(), 305, 16)
    R.checkpoint(470, 50)
    R.lamp(150)
    R.lamp(292, chain=10, energy=1.6)
    R.lamp(412)
    R.lamp(560, chain=6)
    R.banner(436)
    R.banner(540, h=28)
    R.crate(540, seed=1); R.crate(553, seed=0); R.crate(546, bottom=G - 11, seed=2)
    R.gate(584)
    R.manhole(616)
    R.door("ToArenaStreet", 616, ARENA_ST, 43)
    R.mob("stamper", "Stamper", 500)
    R.squad("Squad", facing=-1.0, march_speed=12.0)
    for name, kind, x in (("Halberd1", "halberdier", 410), ("Halberd2", "halberdier", 434),
                          ("Arbalest1", "arbalest", 458), ("Arbalest2", "arbalest", 480)):
        R.mob(kind, name, x, parent="Bureau/Squad")
    R.write(dict(room_key='"sewer_3"', fee="50", fee_name='"清场费"', officer_path='NodePath("../Bureau/Stamper")',
                 gate_path='NodePath("../Props/Gate")'))


if __name__ == "__main__":
    gate_scene()
    which = sys.argv[1:] or ["1", "2", "3"]
    for w in which:
        {"1": room1, "2": room2, "3": room3}[w]()
