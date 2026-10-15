# 夜市摊位街布局
from kit import *
import props as P
import market as M

A = Alley("levels/rust_city/night_market", "night_market", "NightMarket", 800, back_key="market_back", player_x=19, back_modulate="Color(0.55, 0.55, 0.58, 1)")
A.save("market_back", M.market_back())
gate, gate_h = M.market_gate(); A.save("market_gate", gate)
ha, ha_h, ha_gy = M.market_house_a(); A.save("market_house_a", ha)
hb, hb_h = M.market_house_b(); A.save("market_house_b", hb)
cart, cart_h, cart_pot = M.noodle_cart(); A.save("noodle_cart", cart)
A.save("market_hall", M.market_hall())
stalls = {}
for key, args in {"stall_fish": (44, 44, "red", "fish", "lantern", 81),
                  "stall_bowls": (40, 44, "teal", "bowls", "dry", 82),
                  "stall_fruit": (44, 44, "mustard", "fruit", "lantern", 83),
                  "stall_dry": (44, 44, "plum", "bottles", "dry", 84),
                  "stall_bowls2": (44, 44, "red", "bowls", "lantern", 85)}.items():
    c, h = M.stall(*args); A.save(key, c); stalls[key] = h
A.tex("yellow2", "res://levels/rust_city/yellow_building_2.png")
A.save("crate_slat", P.crate_slat(seed=61))
A.save("crate_red", P.crate_panel(seed=62, paint=(120, 60, 46)))
A.save("box_small", P.box_small(seed=63))

G = GROUND
LANTERN = "Color(0.95, 0.42, 0.2, 1)"


def stall_at(name, key, left, bottom, flip=False, light=True):
    A.building(name, key, left, bottom, flip)
    A.platform(left + 1, left + A.placed[name][2].width - 2, bottom - 44 + 7, name)   # 雨棚顶
    if light and stalls[key]:
        lx, ly = stalls[key][-1]
        if flip:
            lx = A.flip_x(name, lx)
        x, y = A.world_of(name, lx, ly)
        A.glow(name + "Glow", x, y, scale=0.6, energy=2.4, color=LANTERN)


# ---- 入口牌楼(回主街) ----
A.building("Gate", "market_gate", -6, G)
# ---- 楼和摊 ----
A.building("HouseA1", "market_house_a", 46, G)
A.platform(47, 108, G - 96 + ha_gy, "HouseA1Gallery")
A.prop("StepCrate1", "crate_slat", 98, G, z=6)          # 垫脚:地面→箱子→木走廊
A.prop("StepBox1", "box_small", 100, G - 12, z=6)
stall_at("StallFish", "stall_fish", 112, G)
stall_at("StallBowls", "stall_bowls", 158, G, light=False)
A.building("HouseB1", "market_house_b", 202, G)
for ly in (24, 44, 64, 84):
    y = G - 112 + ly
    if y > 0:
        A.platform(202 + 30, 202 + 48, y, f"HouseB1Balcony{ly}")
A.prop("Cart1", "noodle_cart", 256, G, solid=False)
A.fx("Steam1", "res://levels/rust_city/alley_fx/steam.tscn", 256 + cart_pot[0], G - 30 + cart_pot[1])
# 高台上两个摊 + 粉楼
T = 68
A.stone_terrain("MarketTerrace", 292, 188, T, steps_l=3, steps_r=3, step_w=4, seed=71)
stall_at("StallFruit", "stall_fruit", 306, T)
stall_at("StallDry", "stall_dry", 354, T, light=False)
A.prop("StepCrate2", "crate_red", 342, T, z=6)          # 摊前一个货箱,垫脚上雨棚
A.building("HouseA2", "market_house_a", 404, T, flip=True)
A.platform(405, 466, T - 96 + ha_gy, "HouseA2Gallery")
A.building("Yellow2", "yellow2", 486, G)
stall_at("StallBowls2", "stall_bowls2", 534, G)
A.building("HouseB2", "market_house_b", 582, G, flip=True)
for ly in (24, 44, 64, 84):
    y = G - 112 + ly
    if y > 0:
        A.platform(582, 582 + 18, y, f"HouseB2Balcony{ly}")
A.prop("Cart2", "noodle_cart", 640, G, solid=False, flip=True)
A.fx("Steam2", "res://levels/rust_city/alley_fx/steam.tscn", 640 + (29 - cart_pot[0]), G - 30 + cart_pot[1])
A.prop("CrateA", "crate_slat", 676, G)
A.prop("CrateB", "crate_red", 688, G)
A.prop("BoxA", "box_small", 680, G - 12)
A.building("Hall", "market_hall", 704, G)

# ---- 灯笼串:两头钉在楼墙上 ----
A.line_between("HouseA1", "HouseB1", 20, kind="lanterns", lights=1)
A.line_between("HouseB1", "HouseA2", 14, kind="lanterns", lights=2)
A.line_between("HouseA1", "HouseB1", 6, kind="laundry", density=0.6)
A.line_between("Yellow2", "HouseB2", 24, kind="lanterns", lights=1)
A.line_between("HouseB2", "Hall", 22, kind="lanterns", lights=1)
A.line_between("HouseB2", "Hall", 6, kind="bulbs", lights=1)
# 牌楼和楼上挂的灯笼也亮几个
for i, (lx, ly) in enumerate(gate_h[::2]):
    x, y = A.world_of("Gate", lx, ly)
    A.glow(f"GateGlow{i}", x, y, scale=0.6, energy=2.2, color=LANTERN)
x, y = A.world_of("HouseA1", *ha_h[1]); A.glow("HouseA1Glow", x, y, scale=0.6, energy=2.4, color=LANTERN)
x, y = A.world_of("HallDoor" if False else "Hall", 47, 60); A.glow("HallGlow", x, y, scale=0.8, energy=3.0)

# ---- 回主街 ----
A.door("ToMainStreet", 19, "res://levels/rust_arena/rust_city.tscn", 2)

# ---- 前景:头顶垂下的灯笼串剪影 ----
for i, (x, w) in enumerate([(90, 110), (470, 90), (820, 100)]):
    k = f"front_lanterns{i}"
    A.save(k, M.lantern_line(w, seed=700 + i)[0])
    A.front_item(k, x, -9)
A.write()
