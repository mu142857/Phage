# 巷子里的人:按下面的表生成每条巷子的 <巷名>_people.tscn(NPC + 角落里的帮派怪)。
# 剧情/对话写在同目录的 <巷名>_people.gd(手写,这里不生成)。改站位就改表重跑:
#   python3 people.py            全部
#   python3 people.py scrap_alley 只生成一条
# 坐标都是脚底;平台上的怪 y 写平台表面。
import sys

PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
N = "res://entities/rust_npcs/"
T = "res://entities/talktive_npc/"

# NPC:(节点名, 显示名, 贴图或帧, x, y, 其它属性)
#   贴图 = .png → texture;.tres → frames
# 帮派:(节点名, 种类, x, y, leash, aggro_range, coins, 其它属性)
ALLEYS = {
    "laundry_alley": dict(
        npcs=[
            ("PaperBox", "", N + "paper_box.png", 96, 80, {}),
            ("Lazy", "摆烂仔", N + "lazy.png", 300, 66, {"talk_radius": 18.0}),
            ("FoxTail", "", N + "fox_graffiti.png", 505, 72, {}),
        ],
        gang=[
            ("Thug", "thug", 640, 80, 30, 80, 2, {}),
            ("Lookout", "lookout", 670, 80, 20, 60, 1, {}),
        ],
        goose=[(50, 80), (430, 80), (580, 80)],
    ),
    "night_market": dict(
        npcs=[
            ("Warrior", "老板", N + "old_warrior.png", 560, 80, {"flip": True}),
            ("Sheep", "羊", N + "sheep/sheep.tres", 372, 68, {"art_faces_left": True, "flip": True}),
            ("Bird", "", N + "sheep/bird_dreamcatcher.tres", 398, 51, {"talkable": False}),
            ("BowlingPin", "球瓶", N + "bowling_pin.png", 724, 80, {"talkable": False}),
            ("Bowler", "保龄球先生", N + "bowler.png", 736, 80, {"flip": True}),
            ("FoxTail", "", N + "fox_graffiti.png", 70, 72, {}),
        ],
        gang=[
            ("Knife", "knife", 250, 80, 35, 70, 2, {}),
            ("Thrower", "thrower", 241, 32, 6, 120, 2, {}),
        ],
        goose=[(40, 80), (420, 68), (660, 80)],
    ),
    "scrap_alley": dict(
        npcs=[
            ("Tire", "轮胎", N + "tire.png", 392, 80, {}),
            ("Vacuum", "扫地机", N + "vacuum.png", 100, 80, {"talk_radius": 16.0}),
            ("FoxTail", "", N + "fox_graffiti.png", 622, 72, {}),
        ],
        gang=[
            ("Chain", "chain", 728, 80, 25, 100, 2, {}),
            ("Roller", "roller", 762, 80, 25, 110, 3, {}),
        ],
        goose=[(40, 80), (110, 80), (370, 80)],
    ),
    "boiler_alley": dict(
        npcs=[
            ("Slime", "蓝史莱姆", N + "blue_slime/blue_slime.tres", 250, 80, {}),
            ("Dragon", "", T + "blue_dragon/blue_dragon.tres", 704, 34, {"art_faces_left": True, "talkable": False}),
            ("FoxTail", "", N + "fox_graffiti.png", 80, 72, {}),
        ],
        gang=[
            ("ShieldGuy", "shield", 378, 80, 25, 100, 3, {}),
            ("Thrower", "thrower", 372, 44, 25, 110, 2, {}),
        ],
        goose=[(40, 80), (470, 80), (630, 80)],
    ),
    "stair_alley": dict(
        npcs=[
            ("Pirate", "海盗船长", N + "pirate.png", 652, 44, {}),
            ("Sword", "剑", N + "sword_stone.png", 700, 44, {"talk_radius": 18.0}),
            ("Wolf", "", T + "xinglang_wolf/xinglang_wolf.tres", 206, 68, {"art_faces_left": True, "talkable": False}),
            ("FoxTail", "", N + "fox_graffiti.png", 150, 62, {}),
        ],
        gang=[
            ("Thug", "thug", 300, 56, 30, 80, 2, {}),
            ("Crossbow", "crossbow", 430, 44, 25, 130, 3, {}),
        ],
        goose=[(60, 80), (330, 56), (540, 44)],
    ),
    "arena_street": dict(
        npcs=[
            ("Muscle", "肌肉哥", N + "muscle.png", 470, 80, {"flip": True}),
            ("FoxTail", "", N + "fox_graffiti.png", 432, 72, {}),
        ],
        gang=[
            ("Brute", "brute", 604, 80, 20, 80, 6, {}),
        ],
        goose=[(100, 80), (400, 80)],
    ),
}


def v(x):
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, float):
        return str(int(x)) + ".0" if x.is_integer() else str(x)
    if isinstance(x, str):
        return '"%s"' % x
    return str(x)


def build(alley, spec):
    ext = {}

    def E(path, typ):
        if path not in ext:
            ext[path] = (typ, f"{len(ext) + 1}")
        return f'ExtResource("{ext[path][1]}")'

    script = E(f"res://levels/rust_city/{alley}/{alley}_people.gd", "Script")
    npc_scene = E("res://systems/npc/npc.tscn", "PackedScene")
    nodes = []
    goose = ", ".join(f"{x}, {y}" for x, y in spec["goose"])
    nodes.append(f'[node name="People" type="Node2D"]\nscript = {script}\ngoose_spots = PackedVector2Array({goose})')
    for name, disp, art, x, y, extra in spec["npcs"]:
        props = [f'position = Vector2({x}, {y})']
        if disp:
            props.append(f'display_name = "{disp}"')
        if art.endswith(".tres"):
            props.append(f'frames = {E(art, "SpriteFrames")}')
        else:
            props.append(f'texture = {E(art, "Texture2D")}')
        for k, val in extra.items():
            props.append(f"{k} = {v(val)}")
        nodes.append(f'[node name="{name}" parent="." instance={npc_scene}]\n' + "\n".join(props))
    if spec["gang"]:
        nodes.append('[node name="Gang" type="Node2D" parent="."]')
        for name, kind, x, y, leash, aggro, coins, extra in spec["gang"]:
            sc = E(f"res://entities/gang/{kind}/{kind}.tscn", "PackedScene")
            props = [f"position = Vector2({x}, {y - 1})", f"leash = {v(float(leash))}", f"aggro_range = {v(float(aggro))}",
                     f"coins = {coins}"]
            for k, val in extra.items():
                props.append(f"{k} = {v(val)}")
            nodes.append(f'[node name="{name}" parent="Gang" instance={sc}]\n' + "\n".join(props))
    out = ["[gd_scene format=3]", ""]
    for path, (typ, i) in ext.items():
        out.append(f'[ext_resource type="{typ}" path="{path}" id="{i}"]')
    out.append("")
    for nd in nodes:
        out += [nd, ""]
    path = f"{PROJ}levels/rust_city/{alley}/{alley}_people.tscn"
    open(path, "w").write("\n".join(out))
    print("wrote", path)


if __name__ == "__main__":
    for a in (sys.argv[1:] or ALLEYS):
        build(a, ALLEYS[a])
