# 竞技场街布局:修路工地那头。路灯全灭,只有竞技场顶上一盏灯(照剧本)。
from kit import *
import props as P
import arena as R

A = Alley("levels/rust_city/arena_street", "arena_street", "ArenaStreet", 640, back_key="far_backs", player_x=30,
          back_modulate="Color(0.45, 0.45, 0.5, 1)", canvas_modulate=0.42)
A.tex("far_backs", "res://levels/rust_city/laundry_alley/alley_back.png")
A.tex("arena", "res://levels/rust_city/rust_arena_building.png")
A.tex("black2", "res://levels/rust_city/black_building_2.png")
A.tex("yellow1", "res://levels/rust_city/yellow_building_1.png")
A.tex("house_brick", "res://levels/rust_city/laundry_alley/house_brick.png")
A.tex("house_ochre", "res://levels/rust_city/laundry_alley/house_ochre.png")
A.tex("dead_end", "res://levels/rust_city/laundry_alley/dead_end.png")
A.tex("manhole", "res://entities/rust_npcs/manhole.png")
for i in range(5):
    A.save(f"poster{i}", R.poster(i, 401 + i, torn=(i % 2 == 1)))
A.save("banner_red", R.banner(410, (110, 40, 36)))
A.save("banner_blue", R.banner(411, (44, 66, 96)))
A.save("ticket_booth", R.ticket_booth())
A.save("rubble", R.rubble())
A.save("crate_slat", P.crate_slat(seed=420))
A.save("crate_dark", P.crate_panel(seed=421, paint=(60, 54, 50)))
G = GROUND

# 井盖:从下水道爬上来的地方(暂时从主街井盖直通过来)
A.sprite(".", "Manhole", "manhole", 24, G + 2, z_index="11")
A.door("FromSewer", 30, "res://levels/rust_arena/rust_city.tscn", 6)

A.building("Black2", "black2", -6, G)
A.building("Brick", "house_brick", 52, G)
A.platform(56, 91, G - 86 + 60, "BrickBalcony")
A.building("Booth", "ticket_booth", 196, G)
A.building("Arena", "arena", 228, G)
A.building("Ochre", "house_ochre", 352, G, flip=True)
for ly, lab in [(34, "a"), (54, "b"), (74, "c")]:
    A.platform(352, 352 + 31, G - 96 + ly, f"Ochre{lab}")
A.building("Yellow1", "yellow1", 418, G)
A.building("DeadEnd", "dead_end", 560, G)
A.platform(560, 639, G - 112 + 66, "BigPipe")
A.platform(560, 590, G - 112 + 44, "SmallPipe")
# 竞技场大门 → 竞技场
A.door("ToArena", 228 + 59, "res://levels/rust_arena/rust_arena.tscn", 7, preserve=False)
# 竞技场顶上那盏灯(整条街唯一亮着的灯)
A.glow("ArenaTopLight", 228 + 59, G - 71 + 6, scale=1.6, energy=3.2, color="Color(1, 0.75, 0.45, 1)")
A.glow("ArenaGateLight", 228 + 59, G - 16, scale=0.8, energy=1.6, color="Color(1, 0.6, 0.3, 1)")
# 灭着的路灯(只有灯杆,没有光)+ 挂的拳赛旗
for i, x in enumerate([150, 214, 368, 520]):
    A.node(f"DeadLamp{i}", "Sprite2D", "Buildings", z_index="7", position=V(x, G - 16), texture=A.E("lamp"), modulate="Color(0.55, 0.55, 0.6, 1)")
for i, (x, k) in enumerate([(206, "banner_red"), (360, "banner_blue")]):
    A.sprite("Buildings", f"Banner{i}", k, x, G - 30)
# 墙上的海报
for i, (x, y, k) in enumerate([(14, 70, 0), (30, 66, 1), (66, 76, 2), (86, 72, 3), (190, 66, 4), (430, 74, 0), (446, 70, 2), (470, 76, 1), (580, 74, 3), (600, 70, 4)]):
    A.sprite("Buildings", f"Poster{i}", f"poster{k}", x, y)
A.prop("Rubble1", "rubble", 120, G + 1, solid=False)
A.prop("Rubble2", "rubble", 500, G + 1, solid=False, flip=True)
A.prop("CrateA", "crate_slat", 536, G)
A.prop("CrateB", "crate_dark", 546, G - 11)
A.prop("CrateC", "crate_dark", 548, G)
# 巷子里的人(NPC + 角落里的帮派),见 people.py
A.people()
A.write()
