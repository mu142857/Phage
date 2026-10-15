# 修车废料巷布局
from kit import *
import props as P
import scrap as S

A = Alley("levels/rust_city/scrap_alley", "scrap_alley", "ScrapAlley", 800, back_key="scrap_back", player_x=24,
          back_modulate="Color(0.7, 0.7, 0.72, 1)")
A.save("scrap_back", S.scrap_back())
A.save("garage_rust", S.garage(102, S.TIN_RUST))
A.save("garage_blue", S.garage(112, S.TIN_BLUE))
A.save("shed_blue", S.shed_tall(103, S.TIN_BLUE))
A.save("shed_rust", S.shed_tall(113, S.TIN_RUST))
A.save("car_teal", S.car_wreck("teal", 104))
A.save("car_red", S.car_wreck("red", 114))
A.save("car_stack4", S.car_stack(4, 105))
A.save("car_stack4b", S.car_stack(4, 115))
heap1, peak1 = S.scrap_heap(72, 28, 106); A.save("heap1", heap1)
heap2, peak2 = S.scrap_heap(84, 34, 116); A.save("heap2", heap2)
A.save("crane", S.crane())
A.save("fence", S.fence())
A.save("warehouse", S.warehouse())
for n in (2, 3, 4):
    A.save(f"tires{n}", S.tire_stack(n, seed=120 + n))
A.save("barrel_red", P.barrel(seed=130, col=(120, 50, 38)))
A.save("barrel_blue", P.barrel(seed=131, col=(60, 76, 110)))
G = GROUND


def car(name, key, left):
    A.prop(name, key, left, G, solid=False)
    A.solid(name + "Body", left + 1, G - 12, 44, 12)       # 车身顶 y=68
    A.solid(name + "Cabin", left + 15, G - 19, 14, 7)      # 车顶 y=61


def stack(name, key, left):
    l, t, w, h = A.prop(name, key, left, G)


def heap(name, key, left, peak, W, H):
    A.sprite("Props", name, key, left, G)
    A.poly(name + "Col", [(left, G), (left + peak, G - H + 2), (left + W, G)])
    pass


def shed(name, key, left, flip=False):
    A.building(name, key, left, G, flip)
    A.platform(left + 1, left + 54, G - 72 + 6, name + "Roof")
    ax0, ax1 = (6, 21) if not flip else (56 - 1 - 21, 56 - 1 - 6)
    A.platform(left + ax0, left + ax1, G - 72 + 56, name + "Awning")


# 栏杆在最后面
A.building("Fence1", "fence", 232, G)
A.building("Fence2", "fence", 656, G)
A.building("Crane", "crane", 300, G)
A.building("Garage", "garage_rust", -4, G)           # 回主街的门
A.prop("Tires1", "tires3", 60, G)
shed("ShedBlue", "shed_blue", 74)
stack("CarStack1", "car_stack4", 132)
car("CarTeal", "car_teal", 182)
heap("Heap1", "heap1", 232, peak1, 72, 28)
car("CarRed", "car_red", 312)
A.building("Workshop", "garage_blue", 362, G, flip=True)
A.prop("Tires2", "tires2", 426, G)
A.prop("BarrelR", "barrel_red", 440, G)
heap("Heap2", "heap2", 450, peak2, 84, 34)
A.prop("Tires3", "tires4", 536, G)
stack("CarStack2", "car_stack4b", 550)
shed("ShedRust", "shed_rust", 598, flip=True)
A.prop("Tires4", "tires3", 658, G)
A.prop("BarrelB", "barrel_blue", 672, G)
A.prop("BarrelB2", "barrel_blue", 682, G, flip=True)
A.prop("Tires5", "tires2", 692, G)
A.building("Warehouse", "warehouse", 704, G)

# 灯:主街同款路灯 + 车库里吊灯 + 仓库探照灯
A.lamp("Lamp1", 66)
A.lamp("Lamp2", 300 + 2)
A.lamp("Lamp3", 594)
x, y = A.world_of("Garage", 28, 33); A.glow("GarageBulb", x, y, scale=0.6, energy=3.0)
x, y = A.world_of("Workshop", A.flip_x("Workshop", 28), 33); A.glow("WorkshopBulb", x, y, scale=0.6, energy=3.0)
x, y = A.world_of("Warehouse", 6, 52); A.glow("Floodlight", x, y + 6, scale=1.1, energy=2.2, color="Color(0.9, 0.85, 0.7, 1)")
x, y = A.world_of("Warehouse", 49, 70); A.glow("WarehouseCrack", x, y, scale=0.7, energy=2.4)
x, y = A.world_of("Crane", 8, 11); A.glow("CraneCab", x, y, scale=0.4, energy=2.0)
# 绳子:棚子之间拉一根工作灯串,一根晾的工作服
A.line_between("ShedBlue", "Crane", 30, kind="bulbs", lights=1) if False else None
A.line_at(A.edge("Workshop", 40, "right"), A.edge("ShedRust", 40, "left"), 40, kind="bulbs", lights=1) if A.edge("Workshop", 40, "right") < A.edge("ShedRust", 40, "left") else None

A.door("ToMainStreet", 24, "res://levels/rust_arena/rust_city.tscn", 3)

# 前景:头顶垂下来的吊链/吊钩剪影
for i, (x, ln) in enumerate([(70, 30), (118, 44), (330, 26), (520, 50), (560, 34), (760, 40), (900, 30)]):
    k = f"front_chain{i}"
    A.save(k, S.chain(ln, seed=150 + i, hook=(i % 2 == 0)))
    A.front_item(k, x, -4)
# 巷子里的人(NPC + 角落里的帮派),见 people.py
A.people()
A.write()
