# 楼梯坡巷布局:地面一层层往上抬 80 → 68 → 56 → 44,最上面是观景小广场
from kit import *
import props as P
import stairs as S
from pxlib import PLASTER_PINK, OCHRE, BRICK

A = Alley("levels/rust_city/stair_alley", "stair_alley", "StairAlley", 720, back_key="stair_back", player_x=24,
          back_modulate="Color(0.72, 0.72, 0.76, 1)")
A.save("stair_back", S.stair_back())
mouth, mouth_lamp = S.stair_mouth(); A.save("stair_mouth", mouth)
ha, ha_lamp = S.hill_house_a(301); A.save("hill_a_cream", ha)
hap, hap_lamp = S.hill_house_a(321, PLASTER_PINK, S.SHUTTER_GREEN); A.save("hill_a_pink", hap)
hb, hb_bal = S.hill_house_b(302); A.save("hill_b_ochre", hb)
hb2, _ = S.hill_house_b(322, PLASTER_PINK); A.save("hill_b_pink", hb2)
hc, hc_lamp, hc_chim = S.hill_house_c(303); A.save("hill_c", hc)
A.save("rail12", S.stair_rail(18, 12, 3))
A.save("bench", S.bench()); A.save("telescope", S.telescope()); A.save("lookout", S.lookout_rail())
for i in range(5):
    A.save(f"pot{i}", S.potted(330 + i, big=(i % 2 == 0)))
G = GROUND
L1, L2, L3 = 68, 56, 44
STEAM = "res://levels/rust_city/alley_fx/steam.tscn"

# ---- 三层台地(后叠的盖住前面的墙面) ----
A.stone_terrain("Terrace1", 104, 616, L1, steps_l=3, steps_r=0, step_w=6, seed=341)
A.stone_terrain("Terrace2", 244, 476, L2, steps_l=3, steps_r=0, step_w=6, seed=342, step_from=L1)
A.stone_terrain("Terrace3", 384, 336, L3, steps_l=3, steps_r=0, step_w=6, seed=343, step_from=L2)
for i, (x, base) in enumerate([(104, G), (244, L1), (384, L2)]):
    A.sprite(".", f"Rail{i}", "rail12", x, base, z_index="9")

# ---- 房子 ----
A.building("Mouth", "stair_mouth", -4, G)
x, y = A.world_of("Mouth", *mouth_lamp); A.glow("MouthLamp", x, y, scale=0.5, energy=2.6)
A.building("HillB1", "hill_b_ochre", 56, G)
A.platform(56, 95, G - 74 + hb_bal, "HillB1Balcony")
A.building("HillA1", "hill_a_cream", 130, L1)
x, y = A.world_of("HillA1", *ha_lamp); A.glow("HillA1Lamp", x, y, scale=0.45, energy=2.6)
A.building("HillC1", "hill_c", 182, L1)
x, y = A.world_of("HillC1", *hc_lamp); A.glow("HillC1Lamp", x, y, scale=0.45, energy=2.6)
x, y = A.world_of("HillC1", hc_chim[0] + 1, hc_chim[1]); A.fx("ChimneySmoke1", STEAM, x, y)
A.building("HillB2", "hill_b_pink", 268, L2, flip=True)
A.platform(268, 307, L2 - 74 + hb_bal, "HillB2Balcony")
A.building("HillA2", "hill_a_pink", 312, L2)
x, y = A.world_of("HillA2", *hap_lamp); A.glow("HillA2Lamp", x, y, scale=0.45, energy=2.6)
A.building("HillC2", "hill_c", 410, L3, flip=True)
x, y = A.world_of("HillC2", A.flip_x("HillC2", hc_chim[0] + 1), hc_chim[1]); A.fx("ChimneySmoke2", STEAM, x, y)
A.building("HillA3", "hill_a_cream", 464, L3, flip=True)
x, y = A.world_of("HillA3", A.flip_x("HillA3", ha_lamp[0]), ha_lamp[1]); A.glow("HillA3Lamp", x, y, scale=0.45, energy=2.6)

# ---- 观景小广场 ----
A.prop("Bench", "bench", 560, L3, solid=False)
A.prop("Telescope", "telescope", 640, L3, solid=False)
A.prop("Lookout", "lookout", 670, L3, solid=False)
A.lamp("PlazaLamp", 600, L3)
A.lamp("Lamp1", 112, L1 + 0) if False else None
A.lamp("Lamp1", 238, L1)
for i, (x, base) in enumerate([(46, G), (124, L1), (176, L1), (262, L2), (404, L3), (520, L3), (530, L3)]):
    A.prop(f"Pot{i}", f"pot{i % 5}", x, base, solid=False)

# ---- 台地墙上的点缀 ----
A.save("cellar_door", S.cellar_door()); A.save("barred_window", S.barred_window())
A.save("spout", S.spout()); A.save("hill_tree", S.hill_tree())
for i in range(4):
    A.save(f"moss{i}", S.moss_curtain(10 + i * 3, 8 + i * 2, 380 + i))
deco = [("barred_window", 150, 78), ("moss0", 196, L1 + 9), ("cellar_door", 288, G), ("spout", 340, G),
        ("moss1", 268, L2 + 11), ("cellar_door", 430, G), ("barred_window", 470, 66), ("moss2", 500, L3 + 15),
        ("spout", 556, G), ("barred_window", 610, 64), ("moss3", 640, L3 + 17), ("cellar_door", 690, G), ("moss1", 420, L3 + 11)]
for i, (k, x, bottom) in enumerate(deco):
    A.sprite(".", f"WallDeco{i}", k, x, bottom, z_index="9")
A.sprite("Props", "Tree", "hill_tree", 516, L3 + 2, material='SubResource("TreeSwing")', modulate="Color(0.72, 0.72, 0.72, 1)")

# ---- 绳子 ----
A.line_between("HillB1", "HillA1", 34, density=0.7)
A.line_between("HillC1", "HillB2", 40, kind="bulbs", lights=1)
A.line_between("HillA2", "HillC2", 22, density=0.6)

A.door("ToMainStreet", 24, "res://levels/rust_arena/rust_city.tscn", 5)
# 后楼梯:山顶那户人家的门穿下去,出来是晾衣巷消防梯顶层
A.door("ToLaundryTop", 496, "res://levels/rust_city/laundry_alley/laundry_alley.tscn", 26, y=40)

for i, x in enumerate([30, 250, 520, 760]):
    k = f"front_vines{i}"
    A.save(k, S.front_vines(seed=360 + i))
    A.front_item(k, x, -2, modulate="Color(0.04, 0.05, 0.04, 1)")
# 巷子里的人(NPC + 角落里的帮派),见 people.py
A.people()
A.write()
