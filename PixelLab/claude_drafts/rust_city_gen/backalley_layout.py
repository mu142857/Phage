# 后巷布局:晾衣巷尽头 DeadEnd 那扇小门(门 id 8)进来。宽 480。
# 0~72 进来的楼背面(门 x=25)→ 铁栅门 x=90(伏击开始砸下来)→ 三栋楼背面(两栋带消防梯)→ 尽头帮派墙。
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import props as P
import backalley as BA
from pxlib import CONCRETE, BRICK, GREENGRAY

W = 480
A = Alley("levels/rust_city/back_alley", "back_alley", "BackAlley", W, back_key="back_far", player_x=25,
          back_modulate="Color(0.62, 0.62, 0.66, 1)", canvas_modulate=0.36, buildings_brightness=0.55)
A.save("back_far", BA.back_far())
A.save("entry_back", BA.entry_back())
A.save("tenement_a", BA.tenement(411, 100, 124, CONCRETE, ac=2, tally=12))
A.save("tenement_b", BA.tenement(412, 110, 124, BRICK, escapes=[(8, 58, 100), (40, 96, 78)],
                                  lit_window=(1, 74), ac=1, tag=(70, 108, 0.8)))
A.save("tenement_c", BA.tenement(413, 118, 124, GREENGRAY, escapes=[(10, 60, 100), (50, 104, 78)], ac=2, tally=7))
A.save("gang_wall", BA.gang_wall())
A.save("gate", BA.gate())
A.save("dumpster", BA.dumpster())
A.save("pallets", BA.pallets())
A.save("scarf_flag", BA.scarf_flag())
for i in range(4):
    A.save(f"bag{i}", BA.trash_bag(461 + i, w=9 + i % 3, h=8 + (i * 2) % 3))
A.save("barrel_dark", P.barrel(seed=470, col=(54, 58, 56)))
G = GROUND

# ---- 楼 ----
A.building("EntryBack", "entry_back", 0, G)
A.building("TenementA", "tenement_a", 72, G)
A.building("TenementB", "tenement_b", 172, G)
A.building("TenementC", "tenement_c", 282, G)
A.building("GangWall", "gang_wall", 400, G)
# 消防梯平台(图里 y=100/78 → 世界 56/34)
A.platform(172 + 8, 172 + 58, G - 124 + 100, "EscapeB1")
A.platform(172 + 40, 172 + 96, G - 124 + 78, "EscapeB2")
A.platform(282 + 10, 282 + 60, G - 124 + 100, "EscapeC1")
A.platform(282 + 50, 282 + 104, G - 124 + 78, "EscapeC2")

# ---- 道具 ----
A.prop("Dumpster", "dumpster", 106, G)
A.prop("Bag0", "bag0", 134, G, solid=False)
A.prop("Bag1", "bag1", 146, G, solid=False, flip=True)
A.prop("Bag2", "bag2", 176, G, solid=False)
A.prop("Pallets", "pallets", 236, G)
A.prop("Bag3", "bag3", 258, G, solid=False)
A.prop("Barrel", "barrel_dark", 352, G)
A.prop("Bag4", "bag1", 388, G, solid=False)
A.prop("Bag5", "bag0", 398, G, solid=False, flip=True)
A.node("ScarfFlag", "Sprite2D", "Laundry", position=V(436, 26), texture=A.E("scarf_flag"), centered="false",
       material='SubResource("ClothSwing")')

# ---- 灯:只有几颗光秃秃的灯泡 ----
A.glow("EntryBulb", 25, G - 118 + 99, scale=0.55, energy=3.0)
A.glow("BulbB", 172 + 74 + 3, G - 124 + 30 + 4, scale=0.5, energy=2.2)       # 那扇亮着的窗
A.glow("WallBulb", 452, 44, scale=0.8, energy=1.5, color="Color(0.9, 0.62, 0.42, 1)")

# ---- 门:回晾衣巷 ----
A.door("ToLaundryAlley", 25, "res://levels/rust_city/laundry_alley/laundry_alley.tscn", 8)

# ---- 伏击:铁栅门 + 放哨的 + 脚本 ----
A.ext["ambush"] = ("Script", "res://levels/rust_city/back_alley/back_alley_ambush.gd")
A.ext["lookout"] = ("PackedScene", "res://entities/gang/lookout/lookout.tscn")
A.subs.append('[sub_resource type="RectangleShape2D" id="GateShape"]\nsize = Vector2(10, 92)')
A.node("Gate", "StaticBody2D", ".", position=V(96, 0), z_index="9", collision_mask="0")
A.node("CollisionShape2D", "CollisionShape2D", "Gate", position=V(0, 34), shape='SubResource("GateShape")',
       disabled="true")
A.node("Sprite2D", "Sprite2D", "Gate", position=V(0, -40), texture=A.E("gate"))
A.node("Lookout", None, ".", inst="lookout", position=V(162, G))
A.node("Ambush", "Node2D", ".", script=A.E("ambush"), trigger_x="176.0", arena_left="100.0", arena_right="470.0",
       gate_path='NodePath("../Gate")', door_path='NodePath("../ToLaundryAlley")', lookout_path='NodePath("../Lookout")',
       perch_xs="PackedFloat32Array(240, 359)")

# ---- 前景:头顶横过去的电线和挂着的破布 ----
for i, (x, w) in enumerate([(40, 90), (250, 70), (520, 90)]):
    k = f"front_line{i}"
    A.save(k, P.laundry_line(w, seed=930 + i, density=0.35))
    A.front_item(k, x, -12)
A.write()
