# 锅炉管道巷布局
from kit import *
import props as P
import boiler as B

A = Alley("levels/rust_city/boiler_alley", "boiler_alley", "BoilerAlley", 800, back_key="boiler_back", player_x=24,
          back_modulate="Color(0.7, 0.66, 0.64, 1)")
A.save("boiler_back", B.boiler_back())
gate, gate_lamp = B.boiler_gate(); A.save("boiler_gate", gate)
ph, ph_vents = B.pipe_house(); A.save("pipe_house", ph)
bh, bh_fire = B.boiler_house(); A.save("boiler_house", bh)
A.save("water_tank", B.water_tank())
A.save("catwalk", B.catwalk())
bb, bb_fire, bb_top = B.big_boiler(); A.save("big_boiler", bb)
A.save("crate_steel", P.crate_panel(seed=220, paint=(70, 78, 86)))
A.save("crate_steel2", P.crate_panel(12, 12, 221, paint=(96, 84, 60)))
A.save("barrel_oil", P.barrel(seed=222, col=(50, 50, 52)))
A.tex("black1", "res://levels/rust_city/black_building_1.png")
G = GROUND
STEAM = "res://levels/rust_city/alley_fx/steam.tscn"
FIREC = "Color(1, 0.45, 0.15, 1)"


def bridge(name, key, wall_a, wall_b, H, seed, ramp=B.COPPER):
    """管桥:量出两栋楼在管子高度的墙边,正好从这面墙跨到那面墙(两头各吃进墙里一格)。"""
    y = G - H + 3
    left = A.edge(wall_a, y, "right") - 1
    right = A.edge(wall_b, y, "left")
    W = right - left + 1
    A.save(key, B.pipe_bridge(W, 0, H, seed, ramp=ramp))
    A.prop(name, key, left, G, solid=False)
    A.platform(left, right, G - H, name)
    return left, W


A.building("Gate", "boiler_gate", -4, G)
x, y = A.world_of("Gate", *gate_lamp); A.glow("GateRedLight", x, y, scale=0.35, energy=2.5, color="Color(1, 0.2, 0.15, 1)")
A.building("PipeHouse1", "pipe_house", 54, G)
for i, (vx, vy) in enumerate(ph_vents):
    x, y = A.world_of("PipeHouse1", vx, vy); A.fx(f"Steam_PH1_{i}", STEAM, x, y)
A.building("BoilerHouse1", "boiler_house", 214, G)
l, w = bridge("Bridge1", "pipe_bridge30", "PipeHouse1", "BoilerHouse1", 30, 203)
A.fx("Steam_B1", STEAM, l + w // 2 + 4, G - 30)
for i, (fx, fy) in enumerate(bh_fire):
    x, y = A.world_of("BoilerHouse1", fx, fy)
    A.glow(f"Fire1_{i}", x, y, scale=1.0 if i == 0 else 0.6, energy=3.0 if i == 0 else 1.8, color=FIREC)
A.prop("Tank", "water_tank", 298, G, solid=False)
A.platform(300, 336, G - 64 + 3, "TankTop")
A.prop("Catwalk1", "catwalk", 340, G, solid=False)
A.platform(340, 403, G - 40 + 4, "Catwalk1")
A.prop("CrateS1", "crate_steel", 406, G)
A.prop("CrateS2", "crate_steel2", 406, G - 11)
A.building("PipeHouse2", "pipe_house", 420, G, flip=True)
for i, (vx, vy) in enumerate(ph_vents):
    x, y = A.world_of("PipeHouse2", A.flip_x("PipeHouse2", vx), vy); A.fx(f"Steam_PH2_{i}", STEAM, x, y)
A.prop("CrateS3", "crate_steel", 486, G)
A.prop("CrateS4", "crate_steel2", 488, G - 11)
A.building("Black1", "black1", 598, G)
l, w = bridge("Bridge2", "pipe_bridge40", "PipeHouse2", "Black1", 40, 213, ramp=B.IRONP)
A.fx("Steam_B2", STEAM, l + w // 3, G - 40)
A.building("BoilerHouse2", "boiler_house", 640, G, flip=True)
x, y = A.world_of("BoilerHouse2", A.flip_x("BoilerHouse2", int(bh_fire[0][0])), bh_fire[0][1]); A.glow("Fire2", x, y, scale=1.0, energy=3.0, color=FIREC)
A.prop("BarrelO", "barrel_oil", 662, G)
A.prop("CrateS5", "crate_steel2", 672, G)
A.prop("CrateS6", "crate_steel", 673, G - 12)
A.prop("Catwalk2", "catwalk", 686, G, solid=False)
A.platform(686, 749, G - 40 + 4, "Catwalk2")
A.building("BigBoiler", "big_boiler", 720, G)
A.platform(740, 770, G - 96 + bb_top, "BoilerTop")
x, y = A.world_of("BigBoiler", *bb_fire); A.glow("BigFire", x, y, scale=1.1, energy=3.2, color=FIREC)
A.fx("Steam_Top", STEAM, 720 + 61, G - 96 + 2)
A.lamp("Lamp1", 52 + 2)
A.lamp("Lamp2", 416)

A.door("ToMainStreet", 24, "res://levels/rust_arena/rust_city.tscn", 4)

# 前景:头顶横过的粗管、竖管剪影
A.save("front_pipe", B.front_pipe())
A.save("front_vpipe", B.front_vpipe())
A.front_item("front_pipe", -80, -2, swing=False)          # 一根横贯整条巷子,两头都在画外
A.front_item("front_vpipe", 300, -14, swing=False)
A.front_item("front_vpipe", 840, -14, swing=False)
# 巷子里的人(NPC + 角落里的帮派),见 people.py
A.people()
A.write()
