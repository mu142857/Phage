"""把 armor3 画的管道局六种兵导进工程:entities/bureau/<type>/ 下的帧条 + SpriteFrames + 怪的 tscn,
以及共用的死亡粒子 / 弩箭 / 罚章。改了画就重跑这个。(没有发光层:管道局不点粉光)"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(1, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gang"))   # build_gang/gang_art 在隔壁
import armor3 as A
from build_gang import particles, hexf, fnum

PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
BDIR = "entities/bureau/"

LOOPS = {"Idle", "Walk", "Fly", "Hold", "Dive", "Fall"}


class WingGame(A.Wingblade):
    """刀翼兵进游戏:原点在脚底(悬空高度由节点自己飞),俯冲的位移也交给节点,画里不挪身子"""
    DEFAULT = dict(A.Wingblade.DEFAULT, air=0)

    def anims(self):
        P = self.pose
        idle = [P(air=1 if i in (1, 2) else 0, flap=i) for i in range(6)]
        fly = [P(air=i % 2, flap=i, spread=0.6, ff=1, fb=-4, lean=1, blade=70) for i in range(6)]
        rise = [P(spread=0.7, flap=1, blade=10), P(spread=1.0, flap=2, blade=-20, lean=-1),
                P(spread=1.0, flap=3, blade=-30, lean=-1), P(spread=1.0, flap=4, blade=-30, lean=-1)]
        dive = [P(spread=0.1, blade=40, hand=(7, 4), trail=3, lean=2), P(spread=0.1, blade=45, hand=(7, 4), trail=2, lean=2)]
        recover = [P(spread=0.5, blade=60, trail=1), P(spread=0.4), P(spread=0.3), P()]
        return dict(Idle=idle, Fly=fly, Rise=rise, Dive=dive, Recover=recover,
                    Salute=self.salute(rest=(5, 4), air=0, tuck=0.4), Fall=self.fall_anim(spread=1.0))


SPECS = dict(A.SPECS)
SPECS["wingblade"] = WingGame

TYPES = {
    # name: (根节点名, 身体框(w,h), 攻击框(cx,cy,w,h) or None, exports)
    "halberdier": ("Halberdier", (10, 30), (22, -14, 30, 28),
                   dict(max_health=600, move_speed=20.0, attack_range=34.0, attack_cooldown=1.6, mob_damage=100,
                        hit_frames="PackedInt32Array(6, 7)", death_amount=26, death_height=14.0, bark_height=36.0,
                        knockback_speed=40.0)),
    "tower": ("TowerGuard", (14, 26), (28, -14, 26, 28),
              dict(max_health=800, move_speed=14.0, attack_range=36.0, attack_cooldown=1.8, mob_damage=70,
                   hit_frames="PackedInt32Array(4, 5, 6)", death_amount=30, death_height=12.0, bark_height=32.0,
                   knockback_speed=30.0, edge_probe_distance=10.0)),
    "arbalest": ("Arbalester", (8, 28), None,
                 dict(max_health=320, move_speed=24.0, attack_cooldown=2.2, mob_damage=90, death_amount=20,
                      death_height=12.0, bark_height=36.0)),
    "commander": ("Commander", (11, 33), (17, -15, 24, 30),
                  dict(max_health=1100, move_speed=18.0, attack_range=26.0, attack_cooldown=1.5, mob_damage=130,
                       hit_frames="PackedInt32Array(5, 6)", death_amount=34, death_height=15.0, bark_height=42.0,
                       knockback_speed=35.0)),
    "stamper": ("Stamper", (14, 28), (22, -14, 26, 28),
                dict(max_health=1000, move_speed=13.0, attack_range=30.0, attack_cooldown=2.2, mob_damage=160,
                     hit_frames="PackedInt32Array(7, 8)", heavy="true", death_amount=34, death_height=13.0,
                     bark_height=40.0, edge_probe_distance=10.0)),
    "wingblade": ("Wingblade", (8, 26), (10, -12, 18, 24),
                  dict(max_health=500, move_speed=40.0, attack_cooldown=2.4, mob_damage=110, death_amount=26,
                       death_height=14.0, bark_height=36.0)),
}


def export(name):
    spec = SPECS[name]()
    anims = spec.anims()
    d = PROJ + BDIR + name + "/"
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
        exts.append(f'[ext_resource type="Texture2D" path="res://{BDIR}{name}/{png}" id="{eid}"]')
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
    root, (bw, bh), atk, exports = TYPES[name]
    W, H = spec.W, spec.H
    ox = W / 2 - spec.CX
    oy = -H / 2
    L = ['[gd_scene format=3]', '',
         f'[ext_resource type="Script" path="res://{BDIR}{name}/{name}.gd" id="1"]',
         '[ext_resource type="Shader" path="res://asstes/shaders/hurt.tres" id="2"]',
         f'[ext_resource type="SpriteFrames" path="res://{BDIR}{name}/{name}_frames.tres" id="3"]', '',
         '[sub_resource type="ShaderMaterial" id="Hurt"]\nresource_local_to_scene = true\nshader = ExtResource("2")\nshader_parameter/Enabled = false\nshader_parameter/Tint = Color(1, 0.95, 0.85, 1)', '',
         f'[sub_resource type="RectangleShape2D" id="Body"]\nsize = Vector2({bw}, {bh})', '']
    if atk:
        L += [f'[sub_resource type="RectangleShape2D" id="Atk"]\nsize = Vector2({atk[2]}, {atk[3]})', '']
    L += ['[sub_resource type="Animation" id="Flash"]\nresource_name = "HitFlash"\nlength = 0.1\ntracks/0/type = "value"\ntracks/0/imported = false\ntracks/0/enabled = true\ntracks/0/path = NodePath("AnimatedSprite2D:material:shader_parameter/Enabled")\ntracks/0/interp = 1\ntracks/0/loop_wrap = true\ntracks/0/keys = {\n"times": PackedFloat32Array(0, 0.1),\n"transitions": PackedFloat32Array(1, 1),\n"update": 1,\n"values": [true, false]\n}', '',
          '[sub_resource type="Animation" id="Reset"]\nlength = 0.001\ntracks/0/type = "value"\ntracks/0/imported = false\ntracks/0/enabled = true\ntracks/0/path = NodePath("AnimatedSprite2D:material:shader_parameter/Enabled")\ntracks/0/interp = 1\ntracks/0/loop_wrap = true\ntracks/0/keys = {\n"times": PackedFloat32Array(0),\n"transitions": PackedFloat32Array(1),\n"update": 1,\n"values": [false]\n}', '',
          '[sub_resource type="AnimationLibrary" id="Lib"]\n_data = {\n&"HitFlash": SubResource("Flash"),\n&"RESET": SubResource("Reset")\n}', '']
    props = "\n".join(f"{k} = {fnum(v)}" for k, v in exports.items())
    L += [f'[node name="{root}" type="CharacterBody2D"]\nz_index = 10\ncollision_layer = 4\ncollision_mask = 1\nfloor_snap_length = 2.0\nscript = ExtResource("1")\n{props}', '',
          f'[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\nmaterial = SubResource("Hurt")\nsprite_frames = ExtResource("3")\nanimation = &"{anim_names[0]}"\noffset = Vector2({fnum(float(ox))}, {fnum(float(oy))})', '',
          f'[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\nposition = Vector2(0, {fnum(-bh / 2)})\nshape = SubResource("Body")', '',
          '[node name="HitEffectPlayer" type="AnimationPlayer" parent="."]\nlibraries/ = SubResource("Lib")', '']
    if atk:
        L += ['[node name="AttackCheck" type="Area2D" parent="."]\ncollision_layer = 0\ncollision_mask = 6', '',
              f'[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackCheck"]\nposition = Vector2({atk[0]}, {atk[1]})\nshape = SubResource("Atk")\ndebug_color = Color(0.9, 0.7, 0.2, 0.3)', '']
    open(PROJ + BDIR + f"{name}/{name}.tscn", "w").write("\n".join(L))


def shared():
    die = "res://entities/gang/gang_death.gd"
    # 死亡:铜金甲片 + 藏青衬布
    particles(BDIR + "bureau_death.tscn", die, [hexf('#4a3016'), hexf('#a67330'), hexf('#ebc86a'), hexf('#24324e')],
              26, (6, 12), (0, -12))
    # 重弩箭 9×3:钢头 + 黑铁杆 + 藏青尾羽(不要粉)
    im = Image.new("RGBA", (9, 3), (0, 0, 0, 0))
    for x in range(1, 7):
        im.putpixel((x, 1), (90, 98, 106, 255))
    for x, c in ((7, (174, 178, 174, 255)), (8, (236, 238, 232, 255))):
        im.putpixel((x, 1), c)
    im.putpixel((7, 0), (174, 178, 174, 255)); im.putpixel((7, 2), (106, 110, 108, 255))
    im.putpixel((0, 0), (58, 76, 114, 255)); im.putpixel((0, 2), (36, 50, 78, 255)); im.putpixel((1, 0), (36, 50, 78, 255))
    os.makedirs(PROJ + BDIR + "arbalest", exist_ok=True)
    im.save(PROJ + BDIR + "arbalest/heavy_bolt.png")
    open(PROJ + BDIR + "arbalest/heavy_bolt.tscn", "w").write('''[gd_scene format=3]

[ext_resource type="Script" path="res://entities/bureau/arbalest/heavy_bolt.gd" id="1"]
[ext_resource type="Texture2D" path="res://entities/bureau/arbalest/heavy_bolt.png" id="2"]

[sub_resource type="RectangleShape2D" id="Shape"]
size = Vector2(7, 2)

[node name="HeavyBolt" type="Area2D"]
z_index = 12
collision_layer = 0
collision_mask = 6
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("Shape")
''')
    # 罚章:砸在地上的藏青方印(9×3),慢慢淡掉
    s = Image.new("RGBA", (11, 3), (0, 0, 0, 0))
    for x in range(11):
        s.putpixel((x, 2), (36, 50, 78, 255))
        if x in (0, 10):
            continue
        s.putpixel((x, 1), (36, 50, 78, 255) if x % 2 else (58, 76, 114, 255))
    for x in (2, 5, 8):
        s.putpixel((x, 0), (58, 76, 114, 255))
    os.makedirs(PROJ + BDIR + "stamper", exist_ok=True)
    s.save(PROJ + BDIR + "stamper/fine_stamp.png")
    # 砸地扬灰
    particles(BDIR + "stamper/stamp_dust.tscn", die, [hexf('#4a4036'), hexf('#8a7a66'), hexf('#b8a888')],
              14, (8, 1), (0, -1), vel=(30, 90), grav=180, scale=(1.0, 2.0), life=0.9, direction=(0, -1), spread=80.0)


if __name__ == "__main__":
    names = sys.argv[1:] or list(TYPES)
    for n in names:
        spec, an = export(n)
        if os.path.exists(PROJ + BDIR + f"{n}/{n}.gd"):
            scene(n, spec, an)
        else:
            scene(n, spec, an)
        print(n, an)
    shared()
