# 铁锈城街巷场景生成工具。每条巷子写一个 layout 脚本:画素材 → 摆楼/平台/道具/绳子/灯/门 → write()。
# 约定:地面 y=80;根节点挂 rust_arena/rust_city.gd(相机限位 + 楼压暗 + 主角光不照楼);
#      楼放 Buildings(z2),道具 Props(z4),绳子 Laundry(z5),挡土墙 z9,地面 z10。
import os
from PIL import Image
from pxlib import Canvas
import props as P

PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
GROUND = 80


def V(x, y):
    def f(v):
        v = float(v)
        return str(int(v)) if v.is_integer() else str(v)
    return f"Vector2({f(x)}, {f(y)})"


class Alley:
    def __init__(self, dir_rel, scene_name, root_name, width, back_key=None, back_modulate="Color(0.7, 0.7, 0.72, 1)",
                 canvas_modulate=0.42, player_x=30, buildings_brightness=0.58):
        self.dir = dir_rel.rstrip("/") + "/"
        os.makedirs(PROJ + self.dir, exist_ok=True)
        self.scene_name = scene_name
        self.width = width
        self.ext = {}
        self.subs = []
        self.nodes = []
        self.placed = {}        # 名字 -> (left, top, img, flip)
        self.plat_shapes = set()
        self.rect_shapes = set()
        self.n = 0
        for k, t, p in [("player", "PackedScene", "res://entities/player/player.tscn"),
                        ("script", "Script", "res://levels/rust_arena/rust_city.gd"),
                        ("drop", "Script", "res://interactive/Platform/drop_through_platform.gd"),
                        ("teleport", "PackedScene", "res://interactive/Teleport/teleport.tscn"),
                        ("keyq", "Texture2D", "res://interactive/Teleport/key_q.png"),
                        ("silk", "Shader", "res://asstes/shaders/silk_swing.gdshader"),
                        ("treeswing", "Shader", "res://asstes/shaders/swing.tres"),
                        ("smoke", "PackedScene", "res://asstes/shaders/smokes/back_ground_smoke.tscn"),
                        ("lamp", "Texture2D", "res://levels/rust_city/rust_city_light.png"),
                        ("sky", "Texture2D", "res://levels/rust_city/rust_city_sky.png"),
                        ("bg", "Texture2D", "res://levels/rust_city/rust_city_background.png"),
                        ("city1", "Texture2D", "res://levels/rust_city/rust_city_1.png"),
                        ("city2", "Texture2D", "res://levels/rust_city/rust_city_2.png"),
                        ("ground", "Texture2D", "res://levels/rust_city/rust_city_ground.png")]:
            self.ext[k] = (t, p)
        self.subs += [
            '[sub_resource type="WorldBoundaryShape2D" id="Boundary"]',
            '[sub_resource type="Gradient" id="PlayerGrad"]\ncolors = PackedColorArray(1, 1, 1, 1, 0, 0, 0, 1)',
            '[sub_resource type="GradientTexture2D" id="PlayerLightTex"]\ngradient = SubResource("PlayerGrad")\nfill = 1\nfill_from = Vector2(0.5, 0.5)\nfill_to = Vector2(0.5, 0)',
            '[sub_resource type="Gradient" id="LampGrad"]\noffsets = PackedFloat32Array(0, 0.28960395, 0.40346536, 1)\ncolors = PackedColorArray(1, 1, 1, 1, 0.07484522, 0.07484529, 0.07484522, 1, 0.12955844, 0.12955847, 0.12955841, 1, 0, 0, 0, 1)',
            '[sub_resource type="GradientTexture2D" id="LampLightTex"]\ngradient = SubResource("LampGrad")\nfill = 2\nfill_from = Vector2(0.5, 0.5)\nfill_to = Vector2(0.5, 0)',
            '[sub_resource type="CanvasItemMaterial" id="FarMat"]',
            '[sub_resource type="ShaderMaterial" id="ClothSwing"]\nshader = ExtResource("silk")\nshader_parameter/Strength = 0.6\nshader_parameter/Speed = 1.3',
            '[sub_resource type="ShaderMaterial" id="TreeSwing"]\nshader = ExtResource("treeswing")\nshader_parameter/Strength = 1.0\nshader_parameter/Speed = 2.0',
            '[sub_resource type="ShaderMaterial" id="ClothSwingFront"]\nshader = ExtResource("silk")\nshader_parameter/Strength = 1.4\nshader_parameter/Speed = 1.0',
        ]
        # 2026-10-15 用户嫌巷子太亮、黑衣人不显眼:整体压暗(原来 0.537 / 楼 0.72)
        self.node(root_name, "Node2D", None, script=self.E("script"), camera_limit_left="0", camera_limit_right=str(width),
                  buildings_brightness=str(buildings_brightness))
        self.node("Walls", "Node2D", z_index="10")
        self.node("StaticBody2D", "StaticBody2D", "Walls", collision_mask="0")
        self.node("Ground", "CollisionShape2D", "Walls/StaticBody2D", position=V(0, GROUND), shape='SubResource("Boundary")')
        self.node("LeftWall", "CollisionShape2D", "Walls/StaticBody2D", position=V(0, 0), rotation="1.5707964", shape='SubResource("Boundary")')
        self.node("RightWall", "CollisionShape2D", "Walls/StaticBody2D", position=V(width, 0), rotation="-1.5707964", shape='SubResource("Boundary")')
        self.node("Buildings", "Node2D", z_index="2")
        self.node("Props", "Node2D", z_index="4")
        self.node("Laundry", "Node2D", z_index="5")
        self.back_key = back_key
        self.back_modulate = back_modulate
        self.canvas_modulate = canvas_modulate
        self.player_x = player_x
        self.front = []
        self.surfaces = [(0, width, GROUND, "ground")]   # (x0, x1, y, 名字)

    # ---------------- 基础 ----------------
    def E(self, k):
        return f'ExtResource("{k}")'

    def node(self, name, typ=None, parent=".", inst=None, **props):
        head = f'[node name="{name}"'
        if typ:
            head += f' type="{typ}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if inst:
            head += f' instance=ExtResource("{inst}")'
        head += "]"
        body = "\n".join(f"{k} = {v}" for k, v in props.items())
        self.nodes.append(head + ("\n" + body if body else ""))

    def uid(self, base):
        self.n += 1
        return f"{base}{self.n}"

    def tex(self, key, path=None):
        """登记贴图;path 省略 = 本巷目录下 key.png。返回 (key, Image)。"""
        path = path or ("res://" + self.dir + key + ".png")
        self.ext[key] = ("Texture2D", path)
        return Image.open(PROJ + path[len("res://"):]).convert("RGBA")

    def save(self, key, canvas):
        im = canvas.im if isinstance(canvas, Canvas) else canvas
        im.save(PROJ + self.dir + key + ".png")
        return self.tex(key)

    # ---------------- 摆放 ----------------
    def sprite(self, parent, name, key, left, bottom, flip=False, img=None, **extra):
        if img is None:
            if key in self.ext:
                img = Image.open(PROJ + self.ext[key][1][6:]).convert("RGBA")
            else:
                img = self.tex(key)
        w, h = img.size
        props = dict(position=V(left + w / 2, bottom - h / 2))
        if flip:
            props["scale"] = V(-1, 1)
        props["texture"] = self.E(key)
        props.update(extra)
        self.node(name, "Sprite2D", parent, **props)
        self.placed[name] = (left, bottom - h, img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img)
        return (left, bottom - h, w, h)

    def flip_x(self, name, lx):
        left, top, img = self.placed[name]
        return img.width - 1 - lx

    def building(self, name, key, left, bottom, flip=False, **extra):
        return self.sprite("Buildings", name, key, left, bottom, flip, **extra)

    def edge(self, name, y, side):
        """楼 name 在世界 y 这一行的墙边:side='right' 最右不透明像素+1,'left' 最左不透明像素。"""
        left, top, img = self.placed[name]
        row = int(y - top)
        assert 0 <= row < img.height, (name, y)
        xs = [x for x in range(img.width) if img.getpixel((x, row))[3] > 0]
        assert xs, (name, y)
        return left + (xs[-1] + 1 if side == "right" else xs[0])

    # ---------------- 碰撞 ----------------
    def platform(self, x0, x1, y, label=None):
        w = int(x1 - x0 + 1)
        if w not in self.plat_shapes:
            self.plat_shapes.add(w)
            self.subs.append(f'[sub_resource type="RectangleShape2D" id="Plat{w}"]\nsize = Vector2({w}, 2)')
            self.subs.append(f'[sub_resource type="RectangleShape2D" id="PlatDetect{w}"]\nsize = Vector2({w}, 8)')
        cx = x0 + w / 2
        name = "Plat_" + (label or str(self.uid("")))
        self.surfaces.append((x0, x1, y, name))
        self.node(name, "StaticBody2D", "Walls", collision_mask="0", script=self.E("drop"))
        self.node("CollisionShape2D", "CollisionShape2D", f"Walls/{name}", position=V(cx, y + 1), shape=f'SubResource("Plat{w}")', one_way_collision="true")
        self.node("Area2D", "Area2D", f"Walls/{name}", collision_layer="0", collision_mask="2")
        self.node("CollisionShape2D", "CollisionShape2D", f"Walls/{name}/Area2D", position=V(cx, y - 3), shape=f'SubResource("PlatDetect{w}")')

    def solid(self, name, x0, y0, w, h):
        self.surfaces.append((x0, x0 + w, y0, name))
        sid = f"Rect{w}x{h}"
        if sid not in self.rect_shapes:
            self.rect_shapes.add(sid)
            self.subs.append(f'[sub_resource type="RectangleShape2D" id="{sid}"]\nsize = Vector2({w}, {h})')
        self.node(name, "CollisionShape2D", "Walls/StaticBody2D", position=V(x0 + w / 2, y0 + h / 2), shape=f'SubResource("{sid}")')

    def poly(self, name, pts):
        s = ", ".join(f"{x}, {y}" for x, y in pts)
        self.node(name, "CollisionPolygon2D", "Walls/StaticBody2D", polygon=f"PackedVector2Array({s})")
        # 斜坡能走:沿每条非竖直的上表面边,每 6 格登记一小段可站表面(给可达性检查用)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            if ax == bx:
                continue
            n = max(1, int(abs(bx - ax) / 6))
            for i in range(n + 1):
                t = i / n
                x = ax + (bx - ax) * t
                y = ay + (by - ay) * t
                if y < GROUND - 1:
                    self.surfaces.append((x - 3, x + 3, y, name + f"_slope{i}"))

    # ---------------- 道具 ----------------
    def prop(self, name, key, left, bottom, solid=True, flip=False, z=None):
        extra = {"z_index": str(z)} if z is not None else {}
        l, t, w, h = self.sprite("Props", name, key, left, bottom, flip, **extra)
        if solid:
            self.solid(name, l, t, w, h)
        return (l, t, w, h)

    def stone_terrain(self, name, x0, width, top_y, base_y=GROUND, steps_l=4, steps_r=4, step_w=4, seed=41, ramp=None, z=9, step_from=None):
        """一段石砌高台:顶面 top_y,两头台阶(碰撞是斜坡)。step_from=台阶起步高度(叠在下一层台地上时用)。"""
        rise = int(base_y - top_y)
        sf = step_from if step_from is not None else base_y
        kw = {} if ramp is None else {"ramp": ramp}
        c = P.stone_wall(width, rise, seed=seed, steps_l=steps_l, steps_r=steps_r, step_w=step_w, step_rise=int(sf - top_y), **kw)
        key = f"{name.lower()}"
        self.save(key, c)
        # 图:顶面在图里 y=TOPPAD
        self.sprite(".", name, key, x0, top_y - P.TOPPAD + c.h, z_index=str(z))
        lw = steps_l * step_w
        rw = steps_r * step_w
        pts = [(x0, base_y)] + ([(x0, sf)] if sf != base_y else []) + [(x0 + lw, top_y), (x0 + width - rw, top_y), (x0 + width, base_y)]
        self.poly(name + "Col", pts)
        self.surfaces.append((x0 + lw, x0 + width - rw, top_y, name))

    # ---------------- 绳子 / 灯 ----------------
    def line_between(self, a, b, y, kind="laundry", sag=None, seed=None, lights=2, density=0.75):
        """在楼 a 的右墙和楼 b 的左墙之间拉一根绳,两头钉在墙上(世界 y 是钉子高度)。"""
        x0 = self.edge(a, y, "right")
        x1 = self.edge(b, y, "left")
        return self.line_at(x0, x1, y, kind, sag, seed, lights, density)

    def line_at(self, x0, x1, y, kind="laundry", sag=None, seed=None, lights=2, density=0.75):
        w = int(x1 - x0)
        seed = seed if seed is not None else int(x0 * 7 + y)
        name = self.uid("Line" if kind == "laundry" else "Bulbs")
        key = f"{name.lower()}"
        if kind == "laundry":
            c = P.laundry_line(w, sag, seed=seed, density=density)
            self.save(key, c)
            self.node(name, "Sprite2D", "Laundry", position=V(x0, y - 2), texture=self.E(key), centered="false", material='SubResource("ClothSwing")')
        elif kind == "lanterns":
            import market as M
            c, centers = M.lantern_line(w, sag, seed=seed)
            self.save(key, c)
            self.node(name, "Sprite2D", "Laundry", position=V(x0, y - 2), texture=self.E(key), centered="false",
                      light_mask="2", material='SubResource("ClothSwing")')
            if lights and centers:
                step = max(1, len(centers) // lights)
                for i, (bx, by) in enumerate(centers[step // 2::step][:lights]):
                    self.node(f"Glow{i}", "PointLight2D", f"Laundry/{name}", position=V(bx, by), scale=V(0.75, 0.75),
                              color="Color(0.95, 0.42, 0.2, 1)", energy="2.6", range_item_cull_mask="7", texture='SubResource("LampLightTex")')
        else:
            c, bulbs = P.bulb_line(w, sag, seed=seed)
            self.save(key, c)
            self.node(name, "Sprite2D", "Laundry", position=V(x0, y - 2), texture=self.E(key), centered="false", light_mask="2")
            if lights and bulbs:
                step = max(1, len(bulbs) // lights)
                for i, (bx, by) in enumerate(bulbs[step // 2::step][:lights]):
                    self.node(f"Glow{i}", "PointLight2D", f"Laundry/{name}", position=V(bx, by), scale=V(0.5, 0.5),
                              color="Color(0.85, 0.55, 0.22, 1)", energy="3.0", range_item_cull_mask="7", texture='SubResource("LampLightTex")')
        return name

    def lamp(self, name, x, bottom=GROUND):
        self.node(name, "Sprite2D", "Buildings", light_mask="2", z_index="9", position=V(x, bottom - 16), texture=self.E("lamp"))
        self.node("PointLight2D", "PointLight2D", f"Buildings/{name}", position=V(0, -7.5), scale=V(0.640625, 0.640625),
                  color="Color(0.70145446, 0.41482437, 0.10370845, 1)", energy="7.6", range_item_cull_mask="2", texture='SubResource("LampLightTex")')

    def glow(self, name, x, y, scale=0.45, energy=3.5, color="Color(0.85, 0.6, 0.3, 1)", mask=7):
        self.node(name, "PointLight2D", "Buildings", position=V(x, y), scale=V(scale, scale), color=color,
                  energy=str(energy), range_item_cull_mask=str(mask), texture='SubResource("LampLightTex")')

    def fx(self, name, res_path, x, y, **extra):
        key = "fx_" + res_path.split("/")[-1].split(".")[0]
        self.ext[key] = ("PackedScene", res_path)
        self.node(name, None, ".", inst=key, position=V(x, y), **extra)

    def world_of(self, name, lx, ly):
        """楼/道具 name 贴图里的 (lx,ly) → 世界坐标(已考虑翻面)。"""
        left, top, img = self.placed[name]
        return (left + lx, top + ly)

    # ---------------- 门 ----------------
    def door(self, name, x, scene_path, teleport_id, y=76, preserve=True):
        props = dict(position=V(x, y), scene_path=f'"{scene_path}"', teleport_id=str(teleport_id))
        if preserve:
            props["preserve_player_state"] = "true"
        self.node(name, None, ".", inst="teleport", **props)
        self.node("Hint", "Sprite2D", name, modulate="Color(1.8, 1.8, 1.8, 1)", light_mask="0", z_index="100", position=V(0, -22), texture=self.E("keyq"))

    def people(self):
        """这条巷子的人(NPC + 角落里的帮派)在单独的 <巷名>_people.tscn(people.py 生成),重跑布局冲不掉。"""
        self.ext["people"] = ("PackedScene", f"res://{self.dir}{self.scene_name}_people.tscn")
        self.node("People", None, ".", inst="people")

    def front_item(self, key, x, y, swing=True, modulate="Color(0.05, 0.05, 0.06, 1)"):
        self.front.append((key, x, y, swing, modulate))

    def check_reach(self, max_up=32, max_gap=14):
        """从地面出发找能到的表面:往上最多 max_up,水平缺口最多 max_gap;往下随便落。"""
        surf = self.surfaces
        seen = {0}
        todo = [0]
        while todo:
            a = surf[todo.pop()]
            for k, b in enumerate(surf):
                if k in seen:
                    continue
                gap = max(b[0] - a[1], a[0] - b[1], 0)
                if a[2] - b[2] <= max_up and gap <= max_gap:
                    seen.add(k); todo.append(k)
        bad = [b for k, b in enumerate(surf) if k not in seen]
        for b in bad:
            print(f"  !! 跳不上去: {b[3]} y={b[2]} x={b[0]}..{b[1]}")
        print(f"reach check: {len(surf) - 1} surfaces, {len(bad)} bad")

    # ---------------- 写出 ----------------
    def write(self):
        self.check_reach()
        n = self.node
        n("Player", None, ".", inst="player", modulate="Color(0.68512195, 0.68512195, 0.68512195, 1)", position=V(self.player_x, 70))
        n("PointLight2D", "PointLight2D", "Player", position=V(0, -7), scale=V(3.0664063, 1.21875), texture='SubResource("PlayerLightTex")')
        cm = self.canvas_modulate
        n("CanvasModulate", "CanvasModulate", color=f"Color({cm}, {cm}, {cm}, 1)")

        def para(name, s, rw, times, z=None, **p):
            props = {}
            if z is not None:
                props["z_index"] = str(z)
            if s != 1:
                props["scroll_scale"] = V(s, s)
            if rw:
                props["repeat_size"] = V(rw, 0)
                props["repeat_times"] = str(times)
            props.update(p)
            n(name, "Parallax2D", ".", **props)
        para("0point0xMoving", 0, 160, 2, light_mask="0")
        n("Sprite2D", "Sprite2D", "0point0xMoving", light_mask="0", texture=self.E("sky"), centered="false")
        para("0point2xMoving", 0.2, 160, 2, light_mask="2", visibility_layer="2")
        n("Sprite2D", "Sprite2D", "0point2xMoving", light_mask="0", texture=self.E("bg"), centered="false")
        para("0point4xMoving", 0.4, 160, 5)
        n("Sprite2D", "Sprite2D", "0point4xMoving", modulate="Color(0.2809047, 0.29556337, 0.29849514, 1)", material='SubResource("FarMat")', texture=self.E("city1"), centered="false")
        para("0point6xMoving", 0.6, 160, 6)
        n("Sprite2D", "Sprite2D", "0point6xMoving", texture=self.E("city2"), centered="false")
        if self.back_key:
            bw = Image.open(PROJ + self.ext[self.back_key][1][6:]).size[0]
            para("0point8xMoving", 0.8, bw, max(2, int(0.8 * self.width / bw) + 2))
            n("Sprite2D", "Sprite2D", "0point8xMoving", modulate=self.back_modulate, light_mask="3", texture=self.E(self.back_key), centered="false")
        para("1point0xMoving", 1, 160, int(self.width / 160) + 3, z=10)
        n("Ground", "Sprite2D", "1point0xMoving", light_mask="3", position=V(-160, 0), texture=self.E("ground"), centered="false")
        para("1point2xMoving", 1.2, None, None, z=11)
        for i, (key, x, y, swing, mod) in enumerate(self.front):
            extra = {"material": 'SubResource("ClothSwingFront")'} if swing else {}
            n(f"Front{i}", "Sprite2D", "1point2xMoving", modulate=mod, light_mask="0", position=V(x, y), texture=self.E(key), centered="false", **extra)
        n("BackGroundSmoke", None, ".", inst="smoke", light_mask="0", z_index="11")

        out = [f"[gd_scene format=3]", ""]
        for k, (t, p) in self.ext.items():
            out.append(f'[ext_resource type="{t}" path="{p}" id="{k}"]')
        out.append("")
        for s in self.subs:
            out += [s, ""]
        for nd in self.nodes:
            out += [nd, ""]
        path = PROJ + self.dir + self.scene_name + ".tscn"
        open(path, "w").write("\n".join(out))
        print("wrote", path)
        return path
