"""把 gang_art 画的帧导进工程:entities/gang/<type>/ 下的帧条 + SpriteFrames + 怪的 tscn,
以及共用的死亡粒子/瓶子/碎片/震波/盾火星场景。改了画就重跑这个。"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gang_art as GA

PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
GDIR = "entities/gang/"

LOOPS = {"Idle", "Walk", "Run", "Fall", "Bag", "Hold"}

TYPES = {
    # name: (根节点名, 脚底中心在画布里的 x, 身体框(w,h), 攻击框(cx,cy,w,h) or None, exports, 跟节点额外)
    "thug": ("Thug", 15, (8, 18), (13, -11, 18, 22),
             dict(max_health=300, move_speed=26.0, attack_range=20.0, attack_cooldown=1.3,
                  hit_frames="PackedInt32Array(7, 8)", death_amount=18, death_height=10.0, bark_height=24.0)),
    "knife": ("Knife", 14, (7, 15), (9, -8, 14, 16),
              dict(max_health=180, move_speed=55.0, attack_cooldown=1.6, death_amount=14, death_height=8.0,
                   bark_height=20.0)),
    "shield": ("ShieldGuy", 15, (10, 20), (16, -12, 22, 8),
               dict(max_health=420, move_speed=16.0, attack_range=24.0, attack_cooldown=1.6,
                    hit_frames="PackedInt32Array(4, 5, 6)", death_amount=24, death_height=11.0, bark_height=26.0)),
    "thrower": ("Thrower", 15, (8, 18), None,
                dict(max_health=220, move_speed=24.0, attack_cooldown=2.0, death_amount=18, death_height=10.0,
                     bark_height=24.0)),
    "brute": ("Brute", 21, (16, 26), (21, -9, 28, 18),
              dict(max_health=1200, move_speed=15.0, attack_range=30.0, attack_cooldown=2.2, heavy="true",
                   hit_frames="PackedInt32Array(9, 10)", death_amount=40, death_height=14.0, bark_height=34.0,
                   edge_probe_distance=12.0)),
    "chain": ("ChainThug", 15, (8, 18), (17, -12, 26, 10),
              dict(max_health=280, move_speed=24.0, attack_range=30.0, attack_cooldown=1.6,
                   hit_frames="PackedInt32Array(7, 8)", death_amount=18, death_height=10.0, bark_height=24.0)),
    "crossbow": ("Crossbow", 14, (7, 15), None,
                 dict(max_health=200, move_speed=34.0, attack_cooldown=1.6, death_amount=14, death_height=8.0,
                      bark_height=20.0)),
    "roller": ("Roller", 15, (8, 18), None,
               dict(max_health=300, move_speed=22.0, attack_cooldown=1.8, death_amount=18, death_height=10.0,
                    bark_height=30.0)),
    "lookout": ("Lookout", 14, (7, 14), None,
                dict(max_health=120, move_speed=40.0, death_amount=12, death_height=7.0, bark_height=20.0)),
}


def fnum(v):
    if isinstance(v, str):
        return v
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return str(int(v)) + ".0" if v.is_integer() else str(v)
    return str(v)


def export(name):
    spec = GA.SPECS[name]()
    anims = spec.anims()
    d = PROJ + GDIR + name + "/"
    os.makedirs(d, exist_ok=True)
    W, H = spec.W, spec.H
    exts, subs, animtxt = [], [], []
    n_sub = 0
    for i, (an, poses) in enumerate(anims.items()):
        fr = [spec.render(p) for p in poses]
        strip = Image.new("RGBA", (W * len(fr), H))
        for k, f in enumerate(fr):
            strip.alpha_composite(f, (k * W, 0))
        png = f"{name}_{an.lower()}.png"
        strip.save(d + png)
        eid = f"{i + 1}"
        exts.append(f'[ext_resource type="Texture2D" path="res://{GDIR}{name}/{png}" id="{eid}"]')
        ids = []
        for k in range(len(fr)):
            n_sub += 1
            sid = f"A{n_sub}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eid}")\nregion = Rect2({k * W}, 0, {W}, {H})')
            ids.append(sid)
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % s for s in ids)
        animtxt.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": 10.0\n}'
                       % (frames, "true" if an in LOOPS else "false", an))
    tres = ['[gd_resource type="SpriteFrames" format=3]', ""] + exts + [""]
    for s in subs:
        tres += [s, ""]
    tres += ["[resource]", "animations = [" + ", ".join(animtxt) + "]", ""]
    open(d + f"{name}_frames.tres", "w").write("\n".join(tres))
    return spec, list(anims.keys())


def scene(name, spec, anim_names):
    root, feet_cx, (bw, bh), atk, exports = TYPES[name]
    W, H = spec.W, spec.H
    ox = W / 2 - feet_cx
    oy = -H / 2
    first = anim_names[0]
    L = ['[gd_scene format=3]', '',
         f'[ext_resource type="Script" path="res://{GDIR}{name}/{name}.gd" id="1"]',
         '[ext_resource type="Shader" path="res://asstes/shaders/hurt.tres" id="2"]',
         f'[ext_resource type="SpriteFrames" path="res://{GDIR}{name}/{name}_frames.tres" id="3"]', '',
         '[sub_resource type="ShaderMaterial" id="Hurt"]\nresource_local_to_scene = true\nshader = ExtResource("2")\nshader_parameter/Enabled = false\nshader_parameter/Tint = Color(1, 0.95, 0.9, 1)', '',
         f'[sub_resource type="RectangleShape2D" id="Body"]\nsize = Vector2({bw}, {bh})', '']
    if atk:
        L += [f'[sub_resource type="RectangleShape2D" id="Atk"]\nsize = Vector2({atk[2]}, {atk[3]})', '']
    L += ['[sub_resource type="Animation" id="Flash"]\nresource_name = "HitFlash"\nlength = 0.1\ntracks/0/type = "value"\ntracks/0/imported = false\ntracks/0/enabled = true\ntracks/0/path = NodePath("AnimatedSprite2D:material:shader_parameter/Enabled")\ntracks/0/interp = 1\ntracks/0/loop_wrap = true\ntracks/0/keys = {\n"times": PackedFloat32Array(0, 0.1),\n"transitions": PackedFloat32Array(1, 1),\n"update": 1,\n"values": [true, false]\n}', '',
          '[sub_resource type="Animation" id="Reset"]\nlength = 0.001\ntracks/0/type = "value"\ntracks/0/imported = false\ntracks/0/enabled = true\ntracks/0/path = NodePath("AnimatedSprite2D:material:shader_parameter/Enabled")\ntracks/0/interp = 1\ntracks/0/loop_wrap = true\ntracks/0/keys = {\n"times": PackedFloat32Array(0),\n"transitions": PackedFloat32Array(1),\n"update": 1,\n"values": [false]\n}', '',
          '[sub_resource type="AnimationLibrary" id="Lib"]\n_data = {\n&"HitFlash": SubResource("Flash"),\n&"RESET": SubResource("Reset")\n}', '']
    props = "\n".join(f"{k} = {fnum(v)}" for k, v in exports.items())
    L += [f'[node name="{root}" type="CharacterBody2D"]\nz_index = 10\ncollision_layer = 4\ncollision_mask = 1\nfloor_snap_length = 2.0\nscript = ExtResource("1")\n{props}', '',
          f'[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\nmaterial = SubResource("Hurt")\nsprite_frames = ExtResource("3")\nanimation = &"{first}"\noffset = Vector2({fnum(float(ox))}, {fnum(float(oy))})', '',
          f'[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\nposition = Vector2(0, {fnum(-bh / 2)})\nshape = SubResource("Body")', '',
          '[node name="HitEffectPlayer" type="AnimationPlayer" parent="."]\nlibraries/ = SubResource("Lib")', '']
    if atk:
        L += ['[node name="AttackCheck" type="Area2D" parent="."]\ncollision_layer = 0\ncollision_mask = 2', '',
              f'[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackCheck"]\nposition = Vector2({atk[0]}, {atk[1]})\nshape = SubResource("Atk")\ndebug_color = Color(0.9, 0.2, 0.2, 0.3)', '']
    open(PROJ + GDIR + f"{name}/{name}.tscn", "w").write("\n".join(L))


def particles(path, script, colors, amount, extents, offset, vel=(50, 200), grav=300, scale=(2.0, 3.0), life=1.1,
              z=20, direction=(0, -1), spread=45.0, lifetime=None):
    cols = ", ".join(f"{c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}, 1" for c in colors)
    offs = ", ".join(f"{i / (len(colors) - 1):.3f}" for i in range(len(colors)))
    lt = f"\nlifetime = {lifetime}" if lifetime else ""
    s = f'''[gd_scene format=3]

[ext_resource type="Script" path="{script}" id="1"]

[sub_resource type="Gradient" id="Col"]
offsets = PackedFloat32Array({offs})
colors = PackedColorArray({cols})

[sub_resource type="GradientTexture1D" id="ColTex"]
gradient = SubResource("Col")

[sub_resource type="Gradient" id="Alpha"]
offsets = PackedFloat32Array(0, 0.2, 0.82, 1)
colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)

[sub_resource type="GradientTexture1D" id="AlphaTex"]
gradient = SubResource("Alpha")

[sub_resource type="Curve" id="Scale"]
_data = [Vector2(0, 1), 0.0, 0.0, 0, 0, Vector2(1, 0), 0.0, 0.0, 0, 0]
point_count = 2

[sub_resource type="CurveTexture" id="ScaleTex"]
curve = SubResource("Scale")

[sub_resource type="ParticleProcessMaterial" id="Mat"]
particle_flag_disable_z = true
emission_shape = 3
emission_box_extents = Vector3({extents[0]}, {extents[1]}, 1)
emission_shape_offset = Vector3({offset[0]}, {offset[1]}, 0)
direction = Vector3({direction[0]}, {direction[1]}, 0)
spread = {spread}
initial_velocity_min = {vel[0]}
initial_velocity_max = {vel[1]}
gravity = Vector3(0, {grav}, 0)
scale_min = {scale[0]}
scale_max = {scale[1]}
scale_curve = SubResource("ScaleTex")
color_ramp = SubResource("AlphaTex")
color_initial_ramp = SubResource("ColTex")

[node name="FX" type="GPUParticles2D"]
z_index = {z}
emitting = false
amount = {amount}{lt}
one_shot = true
explosiveness = 1.0
process_material = SubResource("Mat")
script = ExtResource("1")

[node name="Timer" type="Timer" parent="."]
wait_time = {life}
autostart = true

[connection signal="timeout" from="Timer" to="." method="_on_timer_timeout"]
'''
    open(PROJ + path, "w").write(s)


def hexf(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def shared():
    die = "res://entities/gang/gang_death.gd"
    # 死亡:大衣的灰绿 + 红围巾
    particles(GDIR + "gang_death.tscn", die, [hexf('#2a2a22'), hexf('#58584a'), hexf('#5a6050'), hexf('#bc4652')],
              18, (5, 10), (0, -10))
    # 瓶子碎:玻璃绿 + 亮白
    particles(GDIR + "thrower/bottle_shatter.tscn", die, [hexf('#28382c'), hexf('#7aa088'), hexf('#d8e8dc')],
              10, (2, 1), (0, -1), vel=(30, 90), grav=260, scale=(1.0, 2.0), life=0.9, direction=(0, -1), spread=70.0)
    # 盾火星:往前上方溅
    particles(GDIR + "shield/clang_sparks.tscn", die, [hexf('#e07830'), hexf('#ffc860'), hexf('#fff0b0')],
              8, (1, 3), (0, 0), vel=(40, 110), grav=200, scale=(1.0, 1.0), life=0.6, direction=(0, -1), spread=80.0,
              lifetime=0.4)
    # 瓶子
    b = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    GA.bottle(b, 2, 4, 0)
    b.save(PROJ + GDIR + "thrower/bottle.png")
    open(PROJ + GDIR + "thrower/bottle.tscn", "w").write('''[gd_scene format=3]

[ext_resource type="Script" path="res://entities/gang/thrower/bottle.gd" id="1"]
[ext_resource type="Texture2D" path="res://entities/gang/thrower/bottle.png" id="2"]

[sub_resource type="RectangleShape2D" id="Shape"]
size = Vector2(4, 4)

[node name="Bottle" type="Area2D"]
z_index = 12
collision_layer = 0
collision_mask = 3
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("Shape")
''')
    # 弩箭 6×3:箭杆 + 钢头 + 尾羽
    if os.path.isdir(PROJ + GDIR + "crossbow"):
        im = Image.new("RGBA", (7, 3), (0, 0, 0, 0))
        for x in range(1, 6):
            im.putpixel((x, 1), (216, 208, 184, 255))
        im.putpixel((6, 1), (232, 236, 240, 255)); im.putpixel((5, 0), (154, 160, 168, 255)); im.putpixel((5, 2), (154, 160, 168, 255))
        im.putpixel((0, 0), (188, 70, 82, 255)); im.putpixel((0, 2), (188, 70, 82, 255)); im.putpixel((1, 0), (136, 48, 60, 255))
        im.save(PROJ + GDIR + "crossbow/bolt.png")
        open(PROJ + GDIR + "crossbow/bolt.tscn", "w").write('''[gd_scene format=3]

[ext_resource type="Script" path="res://entities/gang/crossbow/bolt.gd" id="1"]
[ext_resource type="Texture2D" path="res://entities/gang/crossbow/bolt.png" id="2"]

[sub_resource type="RectangleShape2D" id="Shape"]
size = Vector2(5, 2)

[node name="Bolt" type="Area2D"]
z_index = 12
collision_layer = 0
collision_mask = 2
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
light_mask = 0
texture = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("Shape")
''')
    # 滚桶:4 帧横排
    if os.path.isdir(PROJ + GDIR + "roller"):
        import math
        sheet = Image.new("RGBA", (12 * 4, 11), (0, 0, 0, 0))
        for k in range(4):
            GA.barrel_side(sheet, 12 * k + 6, 5, k * (math.pi / 2) / 3)   # 每帧箍挪 1 格,4 帧一圈
        sheet.save(PROJ + GDIR + "roller/rolling_barrel.png")
        open(PROJ + GDIR + "roller/rolling_barrel.tscn", "w").write('''[gd_scene format=3]

[ext_resource type="Script" path="res://entities/gang/roller/rolling_barrel.gd" id="1"]
[ext_resource type="Texture2D" path="res://entities/gang/roller/rolling_barrel.png" id="2"]

[sub_resource type="RectangleShape2D" id="Shape"]
size = Vector2(9, 8)

[node name="RollingBarrel" type="Area2D"]
z_index = 10
collision_layer = 4
collision_mask = 2
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
position = Vector2(0, -5)
texture = ExtResource("2")
hframes = 4

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -4)
shape = SubResource("Shape")
''')
        particles(GDIR + "roller/barrel_break.tscn", die, [hexf('#5e2a1c'), hexf('#8a4430'), hexf('#b0603e'), hexf('#3a2a22')],
                  14, (4, 3), (0, -4), vel=(40, 140), grav=320, scale=(1.0, 2.0), life=1.0, spread=70.0)
    open(PROJ + GDIR + "brute/shockwave.tscn", "w").write('''[gd_scene format=3]

[ext_resource type="Script" path="res://entities/gang/brute/shockwave.gd" id="1"]

[sub_resource type="RectangleShape2D" id="Shape"]
size = Vector2(6, 5)

[node name="Shockwave" type="Area2D"]
collision_layer = 0
collision_mask = 2
script = ExtResource("1")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -2.5)
shape = SubResource("Shape")
''')


if __name__ == "__main__":
    names = sys.argv[1:] or list(TYPES)
    for n in names:
        spec, an = export(n)
        scene(n, spec, an)
        print(n, an)
    shared()
