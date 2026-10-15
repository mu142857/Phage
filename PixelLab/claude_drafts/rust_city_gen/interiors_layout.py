# 铁锈城室内(第一批):三间穿堂屋把巷子连成环 + 主街三间奥斯卡帮占着的屋。
#   python3 interiors_layout.py            全部
#   python3 interiors_layout.py gang_den   只生成一间
# 每间屋:levels/rust_city/interiors/<屋>/<屋>.tscn(kit 室内模式)+ <屋>_people.tscn(帮派 + 藏的铜板,RoomPeople)。
# 门 id 登记在 Phage/Story/rust_city_interiors.md 第六节。
import sys
from pxlib import BRICK
from kit import *
import props as P
import rooms as R
import market as M
import boiler as B
import scrap as SC
import stairs as ST

ROOT = "levels/rust_city/interiors/"
MAIN = "res://levels/rust_arena/rust_city.tscn"
# 灯别太橙太亮(用户:室内对比度饱和度太高):偏灰的暖白,亮度低、范围大,洗出一片柔光而不是亮斑
WARM = "Color(0.82, 0.73, 0.6, 1)"
FIRE = "Color(0.9, 0.58, 0.36, 1)"
MUTE = (0.7, 0.85, 0.36, 0.5)   # 贴图压色:饱和度×0.7(封顶0.5)、明暗往 0.36 收 15%
G = GROUND


def res(name):
    return f"res://{ROOT}{name}/{name}.tscn"


def alley(name):
    return f"res://levels/rust_city/{name}/{name}.tscn"


class Room:
    def __init__(self, name, root, W, player_x=30, brightness=0.7, cm=0.5):
        self.name, self.W = name, W
        self.A = Alley(ROOT + name, name, root, W, interior=True, canvas_modulate=cm, brightness=brightness, player_x=player_x)
        self.A.mute = MUTE
        self.A.soft_lights = False   # 屋里的灯已经按室内调好了
        self.gang, self.stash = [], []
        self.bag = 0
        self.k = 0

    def shell(self, **kw):
        self.A.save("shell", R.room_shell(self.W, **kw))
        self.A.building("Shell", "shell", 0, 90)

    def deco(self, key, canvas, left, bottom, parent="Buildings", **extra):
        """贴在墙上/地上不挡路的东西。"""
        self.A.save(key, canvas)
        self.k += 1
        return self.A.sprite(parent, f"{key.capitalize()}{self.k}", key, left, bottom, **extra)

    def solid(self, key, canvas, left, bottom):
        """实心家具(柜子、箱子):能站在顶上。"""
        self.A.save(key, canvas)
        self.k += 1
        return self.A.prop(f"{key.capitalize()}{self.k}", key, left, bottom)

    def bulb(self, x, cord=8, energy=1.4, scale=1.3):
        c, (bx, by) = R.bulb(cord=cord)
        self.A.save("bulb%d" % cord, c)
        self.k += 1
        self.A.sprite("Buildings", f"Bulb{self.k}", "bulb%d" % cord, x - 1, 8 + cord + 4)
        self.A.glow(f"BulbGlow{self.k}", x, 8 + by, scale=scale, energy=energy, color=WARM)

    def stairs_up(self, x0, run, rise, base=G, key="stairs"):
        """左低右高的木楼梯,碰撞是斜坡。"""
        self.A.save(key, R.stairs(run, rise))
        self.k += 1
        self.A.sprite("Props", f"Stairs{self.k}", key, x0, base)
        self.A.poly(f"Stairs{self.k}Col", [(x0, base), (x0 + run, base - rise), (x0 + run, base)])

    def loft(self, x0, x1, y, key="loft", support=(G, G)):
        """一段阁楼/走廊楼板(单向平台,从下面能跳穿上去)。两头各一根竖柱,落到 support(左, 右)的高度
        (地面,或者下面那层阁楼的顶面)——不悬空。"""
        W = x1 - x0 + 1
        posts = [(2, support[0] - y - 2), (W - 4, support[1] - y - 2)]
        c = R.loft(W, posts=posts)
        self.A.save(key, c)
        self.k += 1
        self.A.sprite("Props", f"Loft{self.k}", key, x0, y - 6 + c.h)
        self.A.platform(x0, x1, y, f"Loft{self.k}")

    def mob(self, name, kind, x, y=G, leash=60, aggro=200, coins=2):
        self.gang.append((name, kind, x, y, leash, aggro, coins))

    def coin(self, x, y):
        """藏一枚铜板;y = 站的表面。"""
        self.stash.append((x, y))

    def write(self):
        self.A.people()
        self.A.write()
        write_people(self)


def write_people(room):
    ext, nodes = {}, []

    def E(path, typ):
        if path not in ext:
            ext[path] = (typ, str(len(ext) + 1))
        return f'ExtResource("{ext[path][1]}")'
    sc = E(f"res://{ROOT}room_people.gd", "Script")
    nodes.append(f'[node name="People" type="Node2D"]\nscript = {sc}\nbag_coins = {room.bag}\n'
                 f'room_left = 16.0\nroom_right = {float(room.W - 16)}')
    if room.gang:
        nodes.append('[node name="Gang" type="Node2D" parent="."]')
        for name, kind, x, y, leash, aggro, coins in room.gang:
            s = E(f"res://entities/gang/{kind}/{kind}.tscn", "PackedScene")
            nodes.append(f'[node name="{name}" parent="Gang" instance={s}]\nposition = Vector2({x}, {y - 1})\n'
                         f'leash = {float(leash)}\naggro_range = {float(aggro)}\ncoins = {coins}')
    if room.stash:
        nodes.append('[node name="Stash" type="Node2D" parent="."]')
        for i, (x, y) in enumerate(room.stash):
            nodes.append(f'[node name="Coin{i + 1}" type="Marker2D" parent="Stash"]\nposition = Vector2({x}, {y})')
    out = ["[gd_scene format=3]", ""]
    for path, (typ, i) in ext.items():
        out.append(f'[ext_resource type="{typ}" path="{path}" id="{i}"]')
    out.append("")
    for nd in nodes:
        out += [nd, ""]
    path = PROJ + ROOT + f"{room.name}/{room.name}_people.tscn"
    open(path, "w").write("\n".join(out))
    print("wrote", path)


# ============================================================
# 穿堂 1:筒子楼(晾衣巷红砖楼的门 → 夜市牌楼底下)
# ============================================================
def tenement_passage():
    r = Room("tenement_passage", "TenementPassage", 320)
    A = r.A
    r.shell(wall=R.WALLPAPER_GREEN, stripes=True, doors=[(6, "out"), (56, "room"), (150, "room"), (246, "room"), (303, "out")],
            windows=[(206, 20, 12, 14)])
    r.deco("notice", R.notice_board(), 82, 52)
    r.deco("picture", R.picture(533), 188, 38)
    r.deco("clock", R.clock(), 128, 32)
    r.stairs_up(64, 36, 32)
    r.loft(100, 189, 48)
    r.loft(178, 249, 22, key="loft2", support=(48, G))   # 左柱落在下层走廊上
    r.solid("wardrobe", R.wardrobe(534), 266, G)
    r.deco("sacks", R.sacks(535), 22, G, parent="Props")
    r.deco("potted", ST.potted(536, big=True), 296, G, parent="Props")
    r.deco("rug", R.rug(537, 40, (60, 96, 100)), 190, G + 1, parent="Props")
    # 屋里也晾衣服:绳子拴在房梁上
    A.line_at(24, 64, 8, density=0.8)       # 两头钉在房梁上(梁 18~23、64~69,伸到 y=10)
    A.line_at(208, 248, 8, density=0.7)
    r.bulb(40); r.bulb(140, cord=10); r.bulb(290)
    r.mob("Thug", "thug", 228)
    r.mob("Lookout", "lookout", 284, leash=20, aggro=90, coins=1)
    r.bag = 5
    r.coin(200, 22); r.coin(236, 22); r.coin(274, 50); r.coin(120, 48)
    A.door("ToLaundry", 11, alley("laundry_alley"), 20)
    A.door("ToMarket", 308, alley("night_market"), 21)
    r.write()


# ============================================================
# 穿堂 2:市场后仓(夜市水泥楼的门 → 修车废料巷的车库)
# ============================================================
def market_storage():
    r = Room("market_storage", "MarketStorage", 320)
    A = r.A
    r.shell(wall=BRICK, wain=None, brick=True, doors=[(6, "out"), (303, "out")], windows=[(160, 16, 10, 8)])
    r.solid("shelf_tall", R.shelf(540, 22, 4, H=34), 34, G)
    r.solid("baskets", R.fish_baskets(541), 64, G)
    r.solid("baskets2", R.fish_baskets(542), 82, G)
    r.deco("sacks", R.sacks(543, 4), 186, G, parent="Props")
    r.stairs_up(98, 42, 36)
    r.loft(140, 239, 44)
    r.solid("shelf_tall2", R.shelf(544, 22, 4, H=34), 250, G)
    r.solid("crate_a", P.crate_slat(seed=545), 280, G)
    r.solid("crate_b", P.crate_panel(seed=546, paint=(120, 60, 46)), 280, G - 12)
    # 收起来的灯笼,一串串挂在房梁上
    for i, (x0, x1) in enumerate([(24, 64), (116, 156), (208, 248)]):
        c, centers = M.lantern_line(x1 - x0, seed=547 + i)
        A.save(f"lanterns{i}", c)
        A.node(f"Lanterns{i}", "Sprite2D", "Laundry", position=V(x0, 6), texture=A.E(f"lanterns{i}"), centered="false",
               light_mask="2", material='SubResource("ClothSwing")')
        if i == 1:
            bx, by = centers[len(centers) // 2]
            A.glow(f"LanternGlow{i}", x0 + bx, 6 + by, scale=1.0, energy=1.1, color="Color(0.85, 0.55, 0.42, 1)")
    r.bulb(296)
    r.mob("Knife", "knife", 180)
    r.mob("Thrower", "thrower", 212, y=44, leash=20, aggro=200, coins=2)
    r.bag = 6
    r.coin(45, 47); r.coin(232, 44); r.coin(73, 66); r.coin(287, 57)
    A.door("ToMarket", 11, alley("night_market"), 22)
    A.door("ToScrap", 308, alley("scrap_alley"), 23)
    r.write()


# ============================================================
# 穿堂 3:废料场仓库(废料巷尽头 → 锅炉巷;这扇是捷径门,只能从仓库里拉开门闩)
# ============================================================
def scrap_warehouse():
    r = Room("scrap_warehouse", "ScrapWarehouse", 320, brightness=0.65)
    A = r.A
    sh = R.room_shell(320, wall=R.WALL_DIRTY, wain=None, floor="concrete", doors=[(6, "out"), (303, "heavy")])
    SC.tin(sh, 4, 12, 315, 74, SC.TIN_GREEN, rust=0.5)      # 墙内衬一整面瓦楞铁皮
    for (dx, kind) in [(6, "out"), (303, "heavy")]:
        R.doorway(sh, dx, kind)
    for y in range(90):                                      # 两侧墙厚重新压一下
        for x in range(4):
            sh.darken(x, y, 0.5 + x * 0.12); sh.darken(319 - x, y, 0.5 + x * 0.12)
    A.save("shell", sh)
    A.building("Shell", "shell", 0, 90)
    # 军火箱一级级垒上去
    for i, (x, n) in enumerate([(80, 1), (96, 2), (112, 3), (262, 2), (278, 1)]):
        for j in range(n):
            r.solid(f"army{(i + j) % 3}", R.army_crate(550 + (i + j) % 3), x, G - 12 * j)
    c = B.catwalk(112, 48)
    A.save("catwalk", c)
    A.sprite("Props", "Catwalk", "catwalk", 128, G)
    A.platform(128, 239, G - 48 + 4, "Catwalk")
    for x, ln in [(155, 34), (293, 26)]:      # 链子(图里 x=2~4)对准梁中线
        A.save(f"hoist{ln}", R.hoist(length=ln))
        A.sprite("Props", f"Hoist{x}", f"hoist{ln}", x, 10 + ln + 8)
    r.solid("drum", P.barrel(seed=553, col=(120, 50, 38)), 246, G)
    r.solid("drum2", P.barrel(seed=554, col=(50, 50, 52)), 254, G)
    r.bulb(60); r.bulb(200, cord=6); r.bulb(286, cord=12)
    r.mob("Brute", "brute", 196, leash=70, aggro=200, coins=4)
    r.mob("Crossbow", "crossbow", 222, y=36, leash=15, aggro=220, coins=3)
    r.mob("Thug", "thug", 60)
    r.bag = 10
    r.coin(150, 36); r.coin(119, 44); r.coin(270, 56)
    A.door("ToScrap", 11, alley("scrap_alley"), 24)
    A.door("ToBoiler", 308, alley("boiler_alley"), 25, set_flag="shortcut_warehouse_boiler")
    r.write()


# ============================================================
# 主街 3 号:被洗劫的住户(卧室)
# ============================================================
def home_robbed_a():
    r = Room("home_robbed_a", "HomeRobbedA", 160, player_x=14)
    A = r.A
    r.shell(wall=R.WALLPAPER_ROSE, stripes=True, doors=[(6, "out")], windows=[(66, 22, 14, 16)])
    r.deco("rug", R.rug(560, 40), 60, G + 1, parent="Props")
    r.deco("picture", R.picture(561, broken=True), 34, 40)
    r.deco("clock", R.clock(), 104, 30)
    r.solid("drawers", R.drawers(562), 26, G)
    r.deco("table_flipped", R.table_flipped(563), 58, G, parent="Props")
    r.deco("chair_down", R.chair(564, toppled=True), 82, G, parent="Props")
    r.solid("wardrobe", R.wardrobe(565, open_door=True), 98, G)
    r.deco("bed", R.bed(566), 122, G, parent="Props")
    r.deco("clutter", R.clutter(567, 40), 40, G, parent="Props")
    r.deco("clutter2", R.clutter(568, 24), 114, G, parent="Props")
    r.bulb(80)
    r.mob("Thug", "thug", 92)
    r.mob("Chain", "chain", 132)
    r.bag = 10
    r.coin(106, 50)
    A.door("ToMainStreet", 11, MAIN, 27)
    r.write()


# ============================================================
# 主街 9 号:被洗劫的住户(厨房)
# ============================================================
def home_robbed_b():
    r = Room("home_robbed_b", "HomeRobbedB", 160, player_x=146)
    A = r.A
    r.shell(wall=R.WALLPAPER_GREEN, doors=[(143, "out")], windows=[(40, 22, 12, 14)])
    c, fire = R.stove(570)
    A.save("stove", c)
    A.sprite("Props", "Stove", "stove", 14, G)
    A.solid("StoveCol", 15, G - 15, 12, 15)
    A.glow("StoveFire", 14 + fire[0], G - 70 + fire[1], scale=1.0, energy=1.3, color=FIRE)
    r.deco("shelf_wall", R.shelf(571, 24, 2, H=18), 60, 56)
    A.platform(60, 83, 56 - 18 + 1, "WallShelf")
    r.deco("table", R.table(572), 92, G, parent="Props")
    A.platform(92, 111, G - 9, "Table")
    r.deco("chair_down", R.chair(573, toppled=True), 70, G, parent="Props")
    r.deco("chair", R.chair(574), 114, G, parent="Props")
    r.deco("clutter", R.clutter(575, 50), 30, G, parent="Props")
    r.deco("picture", R.picture(576, 10, 7), 100, 38)
    r.bulb(102)
    r.mob("Knife", "knife", 56)
    r.mob("Thrower", "thrower", 30)
    r.bag = 10
    r.coin(72, 39)
    A.door("ToMainStreet", 148, MAIN, 28)
    r.write()


# ============================================================
# 主街 6 号:奥斯卡帮的分赃窝
# ============================================================
def gang_den():
    r = Room("gang_den", "GangDen", 240, player_x=14, brightness=0.74)
    A = r.A
    r.shell(wall=R.WALL_DIRTY, doors=[(6, "out")], windows=[])
    A.tex("scarf_flag", "res://levels/rust_city/back_alley/scarf_flag.png")
    for i, x in enumerate((52, 120)):
        A.sprite("Buildings", f"ScarfFlag{i}", "scarf_flag", x, 40)
    r.deco("table_big", R.table(580, 40), 60, G, parent="Props")
    A.platform(60, 99, G - 9, "BigTable")
    r.deco("coins_a", R.coin_pile(581), 64, G - 9, parent="Props")
    r.deco("coins_b", R.coin_pile(582, 9), 86, G - 9, parent="Props")
    r.deco("cards", R.cards(), 77, G - 9, parent="Props")
    r.deco("ledger", R.ledger(), 96, G - 9, parent="Props")
    r.deco("chair_l", R.chair(583), 52, G, parent="Props")
    r.deco("chair_r", R.chair(584, toppled=True), 102, G, parent="Props")
    r.deco("sacks", R.sacks(585, 3), 24, G, parent="Props")
    r.stairs_up(140, 40, 34)
    r.loft(180, 236, 46)
    r.solid("army0", R.army_crate(586), 196, G)
    r.solid("army1", R.army_crate(587), 212, G)
    r.solid("army2", R.army_crate(588), 204, G - 12)
    r.bulb(80, cord=14, energy=1.8, scale=1.6)
    r.bulb(210, cord=6)
    r.mob("Lookout", "lookout", 30, leash=15, aggro=90, coins=1)
    r.mob("Thug", "thug", 112)
    r.mob("Shield", "shield", 128, coins=3)
    r.mob("Knife", "knife", 166)
    r.mob("Crossbow", "crossbow", 226, y=46, leash=10, aggro=220, coins=3)
    r.bag = 20
    r.coin(186, 46); r.coin(209, 44)
    A.door("ToMainStreet", 11, MAIN, 29)
    r.write()


ROOMS = {"tenement_passage": tenement_passage, "market_storage": market_storage, "scrap_warehouse": scrap_warehouse,
         "home_robbed_a": home_robbed_a, "home_robbed_b": home_robbed_b, "gang_den": gang_den}

if __name__ == "__main__":
    for n in (sys.argv[1:] or ROOMS):
        ROOMS[n]()
