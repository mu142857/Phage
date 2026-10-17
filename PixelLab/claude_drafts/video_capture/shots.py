# 铁锈城第一期 · 我录的过渡镜头。x 都是场景坐标,主角放在 y=70(地面 80)。
CITY = "res://levels/rust_arena/rust_city.tscn"
A = "res://levels/rust_city/"
LIT = {"coin_found": True, "coins_seen": True, "talking_coin_in_wallet": True,
       "lamp_intro": True, "lamp_at_site": True, "road_seen": True,
       "lit_lamps": ["Light%d" % i for i in range(1, 13)]}
COIN = {"coin_found": True, "coins_seen": True, "talking_coin_in_wallet": True}


def walk_through(scene, x0, x1, sec):
    return {"max_sec": sec, "flags": LIT, "steps": [
        ["scene", A + scene, x0, 70], ["wait", 0.8], ["walk", x1], ["wait", 1.2], ["end"]]}


def mont(scene, x0, x1):
    return {"max_sec": 7, "flags": LIT, "steps": [
        ["scene", scene, x0, 70], ["god"], ["wait", 0.4], ["walk", x1], ["end"]]}


SHOTS = {
    # ---- 逛街:每条街从头走到尾 ----
    "01_主街_全程": {"flags": LIT, "max_sec": 26, "steps": [
        ["scene", CITY, -40, 70], ["wait", 1.0], ["walk", 1480], ["wait", 1.5], ["end"]]},
    "02_主街进晾衣巷_过门": {"flags": LIT, "max_sec": 16, "steps": [
        ["scene", CITY, 640, 70], ["wait", 0.5], ["walk", 753], ["wait", 0.6], ["tap", "Select"],
        ["wait", 2.5], ["walk", 260], ["wait", 1.0], ["end"]]},
    "03_晾衣巷_全程": walk_through("laundry_alley/laundry_alley.tscn", 22, 780, 18),
    "04_夜市_全程": walk_through("night_market/night_market.tscn", 19, 780, 18),
    # 废料巷两摞叠车要踩轮胎→雨棚→棚顶翻过去(跳跃路线,用户自己录),这里只录两段平路
    "05a_废料巷_前段": walk_through("scrap_alley/scrap_alley.tscn", 186, 535, 9),
    "05b_废料巷_后段": walk_through("scrap_alley/scrap_alley.tscn", 610, 785, 6),
    "06_锅炉巷_全程": walk_through("boiler_alley/boiler_alley.tscn", 24, 780, 18),
    "07_楼梯坡巷_爬坡": walk_through("stair_alley/stair_alley.tscn", 24, 700, 18),
    "08_竞技场街_到大门": walk_through("arena_street/arena_street.tscn", 30, 600, 15),

    # ---- 分镜里的具体段落 ----
    # 开头:掀开纸壳 →「妈妈？」→ 选「……嗯」→「妈妈！」
    "09_纸壳_妈妈": {"flags": LIT, "max_sec": 16, "allow_still": True, "steps": [
        ["scene", A + "laundry_alley/laundry_alley.tscn", 30, 70], ["move", "Goose", 0, -100],
        ["wait", 0.6], ["walk", 80], ["wait", 1.2], ["tap", "Select"], ["talk", 1.4, [0, 1]],
        ["wait", 1.5], ["end"]]},
    # 扫地机撞脚:「对不起！」「我不是人机！」→ 搭话 → 选「你就是个机器人」气得转圈撞墙
    "10_扫地机_不是人机": {"flags": LIT, "max_sec": 22, "allow_still": True, "steps": [
        ["scene", A + "scrap_alley/scrap_alley.tscn", 60, 70], ["move", "Goose", 0, -100],
        ["wait", 0.5], ["walk", 100], ["wait", 3.0], ["talkto", 6], ["talk", 1.4, [1]],
        ["wait", 4.0], ["end"]]},
    # 羊在台子上数羊
    "11_羊_数羊": {"flags": LIT, "max_sec": 20, "allow_still": True, "steps": [
        ["scene", A + "night_market/night_market.tscn", 300, 70], ["move", "Goose", 0, -100],
        ["wait", 0.5], ["walk", 360], ["wait", 2.0], ["tap", "Select"], ["talk", 1.4, [0]],
        ["wait", 1.5], ["end"]]},
    # 肌肉哥登场:「兄弟！」「你的肌肉在哭泣！」
    "12_肌肉哥_登场": {"flags": LIT, "max_sec": 18, "allow_still": True, "steps": [
        ["scene", A + "arena_street/arena_street.tscn", 330, 70], ["move", "Goose", 0, -100],
        ["wait", 0.5], ["walk", 458], ["wait", 2.5], ["talkto", 3], ["talk", 1.4, [0]],
        ["wait", 1.5], ["end"]]},
    # 坡顶:剑中石 + 海盗
    "13_剑中石_坡顶": {"flags": LIT, "max_sec": 16, "allow_still": True, "steps": [
        ["scene", A + "stair_alley/stair_alley.tscn", 560, 30], ["move", "Goose", 0, -100],
        ["wait", 0.5], ["walk", 680], ["wait", 1.0], ["tap", "Select"], ["talk", 1.4, [1]],
        ["wait", 1.5], ["end"]]},
    # 大白鹅:「我又来了。」
    "14_大白鹅_我又来了": {"flags": LIT, "max_sec": 14, "allow_still": True, "steps": [
        ["scene", A + "laundry_alley/laundry_alley.tscn", 360, 70], ["move", "Goose", 430, 80],
        ["wait", 0.5], ["walk", 418], ["wait", 2.5], ["talkto", 3], ["talk", 1.4, [0]],
        ["wait", 1.5], ["end"]]},
    # 收尾:点灯人出场 + 一路点灯带路(主角跟在后面)
    "15_点灯人_带路点灯": {"flags": COIN, "max_sec": 75, "allow_still": True, "steps": [
        ["scene", CITY, 150, 70], ["wait", 1.0], ["talk", 1.3, [0]],
        ["follow", "Lamplighter", 22, 55], ["end"]]},

    # ---- 开场混剪:每条 3 秒左右,剪的时候各取 0.5 秒 ----
    "M01_主街_路灯": mont(CITY, 180, 400),
    "M02_主街_路障工地": mont(CITY, 1330, 1490),
    "M03_晾衣巷": mont(A + "laundry_alley/laundry_alley.tscn", 330, 560),
    "M04_夜市": mont(A + "night_market/night_market.tscn", 120, 340),
    "M05_废料巷": mont(A + "scrap_alley/scrap_alley.tscn", 240, 470),
    "M06_锅炉巷": mont(A + "boiler_alley/boiler_alley.tscn", 90, 320),
    "M07_楼梯坡巷": mont(A + "stair_alley/stair_alley.tscn", 180, 420),
    "M08_竞技场街": mont(A + "arena_street/arena_street.tscn", 380, 600),
    "M09_后巷": mont(A + "back_alley/back_alley.tscn", 60, 290),
    "M10_筒子楼穿堂": mont(A + "interiors/tenement_passage/tenement_passage.tscn", 30, 290),
    "M11_市场后仓": mont(A + "interiors/market_storage/market_storage.tscn", 30, 290),
    "M12_帮派屋": mont(A + "interiors/gang_den/gang_den.tscn", 14, 220),
    "M13_下水道一段": mont(A + "sewer/sewer_1.tscn", 30, 250),
    "M14_下水道二段_金甲队": mont(A + "sewer/sewer_2.tscn", 140, 360),
    "M15_下水道三段": mont(A + "sewer/sewer_3.tscn", 30, 250),
    "M16_点灯人点灯": {"flags": COIN, "max_sec": 10, "allow_still": True, "steps": [
        ["scene", CITY, 150, 70], ["wait", 9.0], ["end"]]},
}
