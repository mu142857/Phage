# 晾衣巷布局(用 kit 重建)。
from kit import *
import props as P

A = Alley("levels/rust_city/laundry_alley", "laundry_alley", "LaundryAlley", 800, back_key="alley_back", player_x=22)
A.tex("alley_back")
for k in ["house_ochre", "house_green", "house_brick", "dead_end", "arch_house"]:
    A.tex(k)
A.tex("yellow1", "res://levels/rust_city/yellow_building_1.png")
A.tex("black2", "res://levels/rust_city/black_building_2.png")
# 道具贴图(新版)
A.save("crate_slat", P.crate_slat(seed=51))
A.save("crate_slat2", P.crate_slat(seed=57))
A.save("crate_green", P.crate_panel(seed=55))
A.save("box_small", P.box_small())
A.save("barrel_teal", P.barrel())

G, T = GROUND, 66
# ---- 楼 ----
A.building("AlleyMouth", "arch_house", -7, G)               # 过街楼,拱门中心 x≈22
A.building("HouseOchre1", "house_ochre", 36, G)
for ly, lab in [(34, "a"), (54, "b"), (74, "c")]:
    A.platform(36 + 30, 36 + 61, G - 96 + ly, f"Ochre1{lab}")
A.building("HouseGreen", "house_green", 160, T)
A.platform(160 + 11, 160 + 44, T - 104 + 80, "GreenAwning")
A.building("HouseBrick1", "house_brick", 236, T)
A.platform(236 + 4, 236 + 39, T - 86 + 60, "Brick1Balcony")
A.building("YellowBuilding1", "yellow1", 384, G)
A.building("HouseOchre2", "house_ochre", 462, G, flip=True)
for ly, lab in [(34, "a"), (54, "b"), (74, "c")]:
    A.platform(462, 462 + 31, G - 96 + ly, f"Ochre2{lab}")
A.building("HouseBrick2", "house_brick", 532, G, flip=True)
A.platform(532 + 4, 532 + 39, G - 86 + 60, "Brick2Balcony")
A.building("BlackBuilding2", "black2", 584, G)
A.building("DeadEnd", "dead_end", 720, G)
A.platform(720, 799, G - 112 + 66, "BigPipe")
A.platform(720, 750, G - 112 + 44, "SmallPipe")

# ---- 高台 ----
A.stone_terrain("TerraceWall", 140, 232, T, steps_l=4, steps_r=4, step_w=4, seed=41)

# ---- 箱子/桶 ----
A.prop("CrateA", "crate_slat", 104, G)
A.prop("CrateB", "crate_green", 116, G)
A.prop("BoxA", "box_small", 105, G - 12)
A.prop("Barrel1", "barrel_teal", 129, G)
A.prop("Barrel2", "barrel_teal", 684, G, flip=True)
A.prop("CrateD", "crate_slat2", 696, G)
A.prop("CrateE", "crate_slat", 708, G, flip=True)
A.prop("CrateF", "crate_green", 702, G - 12)

# ---- 晾衣绳/灯串:两头钉在墙上 ----
A.line_between("HouseOchre1", "HouseGreen", 4)
A.line_between("HouseOchre1", "HouseGreen", 24, density=0.5)
A.line_between("HouseGreen", "HouseBrick1", 2)
A.line_between("HouseBrick1", "YellowBuilding1", 10, kind="bulbs")
A.line_between("HouseBrick1", "YellowBuilding1", 30, density=0.6)
A.line_between("HouseOchre2", "HouseBrick2", 10)
A.line_between("BlackBuilding2", "DeadEnd", 2)
A.line_between("BlackBuilding2", "DeadEnd", 22, kind="bulbs")

# ---- 灯 ----
A.lamp("Lamp1", 94)
A.lamp("Lamp2", 318, T)
A.lamp("Lamp3", 456)
A.lamp("Lamp4", 650)
A.glow("DoorBulb", 760, 63)

# ---- 回主街 ----
A.door("ToMainStreet", 22, "res://levels/rust_arena/rust_city.tscn", 1)
# 尽头那扇小门:走错路进后巷(伏击战)
A.door("ToBackAlley", 760, "res://levels/rust_city/back_alley/back_alley.tscn", 8)
# 连成网(2026-10-15):红砖楼的门进筒子楼穿过去到夜市;消防梯顶层那扇门通楼梯坡巷山顶
A.door("ToPassage", 554, "res://levels/rust_city/interiors/tenement_passage/tenement_passage.tscn", 20)
A.door("ToStairTop", 88, "res://levels/rust_city/stair_alley/stair_alley.tscn", 26, y=14, hint_y=-12)

# ---- 前景剪影:头顶垂下来的衣服 ----
for i, (x, w) in enumerate([(60, 96), (380, 72), (640, 60), (860, 80)]):
    k = f"front_line{i}"
    A.save(k, P.laundry_line(w, seed=900 + i, density=0.9))
    A.front_item(k, x, -10)
# 巷子里的人(NPC + 角落里的帮派),见 people.py
A.people()
A.write()
