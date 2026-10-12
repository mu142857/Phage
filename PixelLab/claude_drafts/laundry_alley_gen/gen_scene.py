# 生成 levels/rust_city/laundry_alley/laundry_alley.tscn
import sys
from PIL import Image

PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
D = "levels/rust_city/laundry_alley/"
OUT = PROJ + D + "laundry_alley.tscn"
if len(sys.argv) > 1:
    OUT = sys.argv[1]

GROUND = 80
TERRACE_TOP = 66
WIDTH = 800

ext = {}      # key -> (type, path)
def res(key, typ, path):
    ext[key] = (typ, path)
    return key

def tex(name):
    return res(name, "Texture2D", "res://" + D + name + ".png")

def size(name):
    return Image.open(PROJ + D + name + ".png").size

for n in ["house_ochre", "house_green", "house_brick", "dead_end", "terrace", "crate", "crate_small",
          "barrel", "line_a", "line_b", "line_c", "line_d", "bulbs", "alley_mouth", "alley_back"]:
    tex(n)
res("player", "PackedScene", "res://entities/player/player.tscn")
res("script", "Script", "res://levels/rust_arena/rust_city.gd")
res("drop", "Script", "res://interactive/Platform/drop_through_platform.gd")
res("teleport", "PackedScene", "res://interactive/Teleport/teleport.tscn")
res("hint", "Texture2D", "res://interactive/Teleport/enter_hint.png")
res("silk", "Shader", "res://asstes/shaders/silk_swing.gdshader")
res("smoke", "PackedScene", "res://asstes/shaders/smokes/back_ground_smoke.tscn")
res("lamp", "Texture2D", "res://levels/rust_city/rust_city_light.png")
res("sky", "Texture2D", "res://levels/rust_city/rust_city_sky.png")
res("bg", "Texture2D", "res://levels/rust_city/rust_city_background.png")
res("city1", "Texture2D", "res://levels/rust_city/rust_city_1.png")
res("city2", "Texture2D", "res://levels/rust_city/rust_city_2.png")
res("ground", "Texture2D", "res://levels/rust_city/rust_city_ground.png")
res("yellow1", "Texture2D", "res://levels/rust_city/yellow_building_1.png")
res("black2", "Texture2D", "res://levels/rust_city/black_building_2.png")

nodes = []
def node(name, typ=None, parent=".", inst=None, **props):
    head = f'[node name="{name}"'
    if typ:
        head += f' type="{typ}"'
    if parent is not None:
        head += f' parent="{parent}"'
    if inst:
        head += f' instance=ExtResource("{inst}")'
    head += "]"
    body = "\n".join(f"{k} = {v}" for k, v in props.items())
    nodes.append(head + ("\n" + body if body else ""))

def V(x, y):
    def f(v):
        return str(int(v)) if float(v).is_integer() else str(v)
    return f"Vector2({f(x)}, {f(y)})"

def E(k):
    return f'ExtResource("{k}")'

def sprite(parent, name, key, left, bottom, flip=False, w=None, h=None, **extra):
    if w is None:
        w, h = size(key)
    props = dict(position=V(left + w / 2, bottom - h / 2))
    if flip:
        props["scale"] = V(-1, 1)
    props["texture"] = E(key)
    props.update(extra)
    node(name, "Sprite2D", parent, **props)

# ---------------- 子资源 ----------------
subs = []
subs.append('[sub_resource type="WorldBoundaryShape2D" id="Boundary"]')
subs.append('[sub_resource type="Gradient" id="PlayerGrad"]\ncolors = PackedColorArray(1, 1, 1, 1, 0, 0, 0, 1)')
subs.append('[sub_resource type="GradientTexture2D" id="PlayerLightTex"]\ngradient = SubResource("PlayerGrad")\nfill = 1\nfill_from = Vector2(0.5, 0.5)\nfill_to = Vector2(0.5, 0)')
subs.append('[sub_resource type="Gradient" id="LampGrad"]\noffsets = PackedFloat32Array(0, 0.28960395, 0.40346536, 1)\ncolors = PackedColorArray(1, 1, 1, 1, 0.07484522, 0.07484529, 0.07484522, 1, 0.12955844, 0.12955847, 0.12955841, 1, 0, 0, 0, 1)')
subs.append('[sub_resource type="GradientTexture2D" id="LampLightTex"]\ngradient = SubResource("LampGrad")\nfill = 2\nfill_from = Vector2(0.5, 0.5)\nfill_to = Vector2(0.5, 0)')
subs.append('[sub_resource type="CanvasItemMaterial" id="FarMat"]')
subs.append('[sub_resource type="ShaderMaterial" id="ClothSwing"]\nshader = ExtResource("silk")\nshader_parameter/Strength = 0.6\nshader_parameter/Speed = 1.3')
subs.append('[sub_resource type="ShaderMaterial" id="ClothSwingFront"]\nshader = ExtResource("silk")\nshader_parameter/Strength = 1.4\nshader_parameter/Speed = 1.0')
subs.append('[sub_resource type="RectangleShape2D" id="Crate"]\nsize = Vector2(12, 12)')
subs.append('[sub_resource type="RectangleShape2D" id="CrateSmall"]\nsize = Vector2(9, 8)')
subs.append('[sub_resource type="RectangleShape2D" id="Barrel"]\nsize = Vector2(8, 11)')
plat_shapes = {}
def plat_shape(w):
    if w not in plat_shapes:
        plat_shapes[w] = f"Plat{w}"
        subs.append(f'[sub_resource type="RectangleShape2D" id="Plat{w}"]\nsize = Vector2({w}, 2)')
        subs.append(f'[sub_resource type="RectangleShape2D" id="PlatDetect{w}"]\nsize = Vector2({w}, 8)')
    return plat_shapes[w]

# ---------------- 根 ----------------
node("LaundryAlley", "Node2D", None, script=E("script"), camera_limit_left="0", camera_limit_right=str(WIDTH))

# ---------------- 碰撞 ----------------
node("Walls", "Node2D", z_index="10")
node("StaticBody2D", "StaticBody2D", "Walls", collision_mask="0")
node("Ground", "CollisionShape2D", "Walls/StaticBody2D", position=V(0, GROUND), shape='SubResource("Boundary")')
node("LeftWall", "CollisionShape2D", "Walls/StaticBody2D", position=V(0, 0), rotation="1.5707964", shape='SubResource("Boundary")')
node("RightWall", "CollisionShape2D", "Walls/StaticBody2D", position=V(WIDTH, 0), rotation="-1.5707964", shape='SubResource("Boundary")')
# 高台(两头台阶做成斜坡碰撞)
TX0, TW = 140, size("terrace")[0]
node("Terrace", "CollisionPolygon2D", "Walls/StaticBody2D",
     polygon=f"PackedVector2Array({TX0}, {GROUND}, {TX0 + 16}, {TERRACE_TOP}, {TX0 + TW - 16}, {TERRACE_TOP}, {TX0 + TW}, {GROUND})")

def solid(name, shape, cx, cy):
    node(name, "CollisionShape2D", "Walls/StaticBody2D", position=V(cx, cy), shape=f'SubResource("{shape}")')

plat_i = [0]
def platform(x0, x1, y, label):
    """单向平台:上表面在世界 y,横跨 x0..x1。"""
    w = x1 - x0 + 1
    sh = plat_shape(w)
    cx = x0 + w / 2
    name = f"Plat_{label}"
    node(name, "StaticBody2D", "Walls", collision_mask="0", script=E("drop"))
    node("CollisionShape2D", "CollisionShape2D", f"Walls/{name}", position=V(cx, y + 1), shape=f'SubResource("{sh}")', one_way_collision="true")
    node("Area2D", "Area2D", f"Walls/{name}", collision_layer="0", collision_mask="2")
    node("CollisionShape2D", "CollisionShape2D", f"Walls/{name}/Area2D", position=V(cx, y - 3), shape=f'SubResource("PlatDetect{w}")')

# ---------------- 建筑(z=2) ----------------
node("Buildings", "Node2D", z_index="2")
B = "Buildings"
OCH_W, OCH_H = size("house_ochre")
GR_W, GR_H = size("house_green")
BR_W, BR_H = size("house_brick")
DE_W, DE_H = size("dead_end")

sprite(B, "AlleyMouth", "alley_mouth", 2, GROUND)
# 1 赭黄公寓(消防梯在右)
OX = 36
sprite(B, "HouseOchre1", "house_ochre", OX, GROUND)
for ly, lab in [(34, "a"), (54, "b"), (74, "c")]:
    platform(OX + 30, OX + OCH_W - 1, GROUND - OCH_H + ly, f"Ochre1{lab}")
# 2 绿灰楼(高台上):雨棚可站
GX = 160
sprite(B, "HouseGreen", "house_green", GX, TERRACE_TOP)
platform(GX + 11, GX + 44, TERRACE_TOP - GR_H + 80, "GreenAwning")
# 3 红砖窄楼(高台上):中层阳台可站
RX = 236
sprite(B, "HouseBrick1", "house_brick", RX, TERRACE_TOP)
platform(RX + 4, RX + 39, TERRACE_TOP - BR_H + 60, "Brick1Balcony")
# 4 用户的黄楼
sprite(B, "YellowBuilding1", "yellow1", 384, GROUND, w=71, h=83)
# 5 赭黄公寓翻面(消防梯在左)
OX2 = 462
sprite(B, "HouseOchre2", "house_ochre", OX2, GROUND, flip=True)
for ly, lab in [(34, "a"), (54, "b"), (74, "c")]:
    platform(OX2, OX2 + OCH_W - 31, GROUND - OCH_H + ly, f"Ochre2{lab}")
# 6 红砖窄楼翻面
RX2 = 532
sprite(B, "HouseBrick2", "house_brick", RX2, GROUND, flip=True)
platform(RX2 + 4, RX2 + 39, GROUND - BR_H + 60, "Brick2Balcony")
# 7 用户的黑楼
sprite(B, "BlackBuilding2", "black2", 584, GROUND, w=55, h=112)
# 8 巷子尽头的大墙:两根管子可站
DX = WIDTH - DE_W
sprite(B, "DeadEnd", "dead_end", DX, GROUND)
platform(DX, WIDTH - 1, GROUND - DE_H + 66, "BigPipe")
platform(DX, DX + 30, GROUND - DE_H + 44, "SmallPipe")

# ---------------- 箱子/桶(z=4,实心) ----------------
node("Props", "Node2D", z_index="4")
def crate(name, key, left, bottom, shape):
    w, h = size(key)
    sprite("Props", name, key, left, bottom)
    solid(name, shape, left + w / 2, bottom - h / 2)
crate("CrateA", "crate", 104, GROUND, "Crate")
crate("CrateB", "crate", 116, GROUND, "Crate")
crate("CrateC", "crate_small", 111, GROUND - 12, "CrateSmall")
crate("Barrel1", "barrel", 129, GROUND, "Barrel")
crate("CrateD", "crate", 696, GROUND, "Crate")
crate("CrateE", "crate", 708, GROUND, "Crate")
crate("CrateF", "crate", 702, GROUND - 12, "Crate")
crate("Barrel2", "barrel", 684, GROUND, "Barrel")

# ---------------- 高台(z=9,压住楼脚) ----------------
sprite(".", "TerraceWall", "terrace", TX0, TERRACE_TOP + size("terrace")[1], z_index="9")

# ---------------- 晾衣绳/灯串(z=5,摇摆) ----------------
node("Laundry", "Node2D", z_index="5")
LINES = [("LineA", "line_a", 92, 4), ("LineB", "line_b", 206, 0), ("LineC", "line_c", 364, 10),
         ("LineD", "line_d", 522, 6), ("LineA2", "line_a", 630, -4)]
for name, key, x, y in LINES:
    w, h = size(key)
    node(name, "Sprite2D", "Laundry", position=V(x, y), texture=E(key), centered="false", material='SubResource("ClothSwing")')
BULBS = [("Bulbs1", 282, 10), ("Bulbs2", 612, 22)]
for name, x, y in BULBS:
    node(name, "Sprite2D", "Laundry", position=V(x, y), texture=E("bulbs"), centered="false", light_mask="2")
    # 灯泡下面挂暖光(灯泡在贴图 x=8,24,...,72,绳子下垂)
    for i, bx in enumerate([24, 56]):
        t = bx / 87
        by = int(round(7 * 4 * t * (1 - t))) + 2
        node(f"Glow{i}", "PointLight2D", f"Laundry/{name}", position=V(bx, by), scale=V(0.5, 0.5),
             color="Color(0.85, 0.55, 0.22, 1)", energy="3.0", range_item_cull_mask="3", texture='SubResource("LampLightTex")')

# ---------------- 路灯(沿用主街的灯) ----------------
def lamp(name, x, bottom):
    node(name, "Sprite2D", "Buildings", light_mask="2", z_index="9", position=V(x, bottom - 16), texture=E("lamp"))
    node("PointLight2D", "PointLight2D", f"Buildings/{name}", position=V(0, -7.5), scale=V(0.640625, 0.640625),
         color="Color(0.70145446, 0.41482437, 0.10370845, 1)", energy="7.6", range_item_cull_mask="2", texture='SubResource("LampLightTex")')
lamp("Lamp1", 94, GROUND)
lamp("Lamp2", 318, TERRACE_TOP)
lamp("Lamp3", 456, GROUND)
lamp("Lamp4", 650, GROUND)
# 尽头那扇门上的小灯
node("DoorBulb", "PointLight2D", "Buildings", position=V(DX + 40, GROUND - DE_H + 95), scale=V(0.45, 0.45),
     color="Color(0.85, 0.6, 0.3, 1)", energy="3.5", range_item_cull_mask="3", texture='SubResource("LampLightTex")')

# ---------------- 主角 ----------------
node("Player", None, ".", inst="player", modulate="Color(0.68512195, 0.68512195, 0.68512195, 1)", position=V(22, 70))
node("PointLight2D", "PointLight2D", "Player", position=V(0, -7), scale=V(3.0664063, 1.21875), texture='SubResource("PlayerLightTex")')
node("CanvasModulate", "CanvasModulate", color="Color(0.5370987, 0.5370987, 0.5370987, 1)")

# ---------------- 回主街的口子 ----------------
node("ToMainStreet", None, ".", inst="teleport", position=V(20, 76),
     scene_path='"res://levels/rust_arena/rust_city.tscn"', teleport_id="1", preserve_player_state="true")
node("Hint", "Sprite2D", "ToMainStreet", z_index="100", position=V(0, -22), texture=E("hint"))

# ---------------- 视差 ----------------
def para(name, s, repeat_w, times, z=None, **p):
    props = {}
    if z is not None:
        props["z_index"] = str(z)
    if s != 1:
        props["scroll_scale"] = V(s, s)
    if repeat_w:
        props["repeat_size"] = V(repeat_w, 0)
        props["repeat_times"] = str(times)
    props.update(p)
    node(name, "Parallax2D", ".", **props)
para("0point0xMoving", 0, 160, 2, light_mask="0")
node("Sprite2D", "Sprite2D", "0point0xMoving", light_mask="0", texture=E("sky"), centered="false")
para("0point2xMoving", 0.2, 160, 2, light_mask="2", visibility_layer="2")
node("Sprite2D", "Sprite2D", "0point2xMoving", light_mask="0", texture=E("bg"), centered="false")
para("0point4xMoving", 0.4, 160, 5)
node("Sprite2D", "Sprite2D", "0point4xMoving", modulate="Color(0.2809047, 0.29556337, 0.29849514, 1)", material='SubResource("FarMat")', texture=E("city1"), centered="false")
para("0point6xMoving", 0.6, 160, 6)
node("Sprite2D", "Sprite2D", "0point6xMoving", texture=E("city2"), centered="false")
para("0point8xMoving", 0.8, 320, 3)
node("Sprite2D", "Sprite2D", "0point8xMoving", modulate="Color(0.7, 0.7, 0.72, 1)", light_mask="3", texture=E("alley_back"), centered="false")
para("1point0xMoving", 1, 160, 8, z=10)
node("Ground", "Sprite2D", "1point0xMoving", light_mask="3", position=V(-160, 0), texture=E("ground"), centered="false")
para("1point2xMoving", 1.2, None, None, z=11)
for i, (key, x, y) in enumerate([("line_c", 60, -8), ("line_a", 380, -6), ("line_b", 640, -7), ("line_d", 860, -5)]):
    node(f"FrontCloth{i}", "Sprite2D", "1point2xMoving", modulate="Color(0.05, 0.05, 0.06, 1)", light_mask="0",
         position=V(x, y), texture=E(key), centered="false", material='SubResource("ClothSwingFront")')
node("BackGroundSmoke", None, ".", inst="smoke", light_mask="0", z_index="11")

# ---------------- 写文件 ----------------
lines = [f'[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]', ""]
for k, (t, p) in ext.items():
    lines.append(f'[ext_resource type="{t}" path="{p}" id="{k}"]')
lines.append("")
for s in subs:
    lines += [s, ""]
for n in nodes:
    lines += [n, ""]
open(OUT, "w").write("\n".join(lines))
print("wrote", OUT)
