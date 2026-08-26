# res://systems/buff_defs.gd
# Buff 静态定义表:id = 雷米房间物品的节点名(也是图标文件名)。
# 获得/持有状态在 Story(存档),这里只有数据。
# tags 里带 "crystal" 的是水晶系,集齐全部水晶另有隐藏效果(待做,水晶后续会加)。
class_name BuffDefs

const ICON_DIR := "res://entities/player/BuffIcon/"

const DEFS: Dictionary = {
	&"Table": {
		"name": "愈合的伤口",
		"desc": "破盾后的无敌时间,延长到两秒。",
		"tags": [],
	},
	&"Watertank": {
		"name": "珊瑚潮汐",
		"desc": "冲刺后的下一击更重;开盾和破盾时激起水刺。",
		"tags": [],
	},
	&"CopperLamp": {
		"name": "城市的心跳",
		"desc": "攻击积攒心跳,攒满时燃起火光,出手更快。",
		"tags": [],
	},
	# 火光燃烧中的显示变体(判定见 player._lamp_fire_left)
	&"CopperLampActive": {
		"name": "城市的心跳",
		"desc": "心跳攒满了——火光燃烧中,出手更快。",
		"tags": [],
		"variant": true,
	},
	&"SaltLight": {
		"name": "山的重量",
		"desc": "跳劈的伤害提高三成。",
		"tags": [],
	},
	&"SpiderQueenDoll": {
		"name": "蜘蛛的伪装",
		"desc": "一枚漂浮的卵陪着你,自动攻击身边的怪。",
		"tags": [],
	},
	&"Plant": {
		"name": "森林的谢礼",
		"desc": "多出第三层护盾,充能也更快。",
		"tags": [],
	},
	&"Flower": {
		"name": "绽放的代价",
		"desc": "每一击都全力绽放,但护盾恢复变得很慢。",
		"tags": [],
	},
	&"BlueCrystal": {
		"name": "蓝水晶的力量",
		"desc": "冲刺时被水晶包裹,无懈可击。",
		"tags": ["crystal"],
	},
	&"RedCrystal": {
		"name": "红水晶的力量",
		"desc": "连击第二段不再减弱;破盾后更加凶狠。",
		"tags": ["crystal"],
	},
	&"YunwuPaint": {
		"name": "礼拜日的云雾",
		"desc": "按 F 隐入云雾,无懈可击;出手或冲刺便会破雾。",
		"tags": [],
	},
	# 云雾冷却中的显示变体(不是可持有 buff,判定见 player.mist_cooldown_left)
	&"YunwuPaintInactive": {
		"name": "礼拜日的云雾",
		"desc": "云雾散尽,正在重新聚拢。(冷却中)",
		"tags": [],
		"variant": true,
	},
	&"MuziPaint": {
		"name": "沐子的守望",
		"desc": "倒下时,带着护盾重新站起来一次。",
		"tags": [],
	},
	# 沐子的守望用掉后的显示变体(不是可持有的 buff,只给 HUD 换脸用,
	# 判定见 Story.muzi_broken)
	&"MuziPaint_Broke": {
		"name": "破碎的守望",
		"desc": "已经替你站起来过一次。这场梦里,不会再有了。",
		"tags": [],
		"variant": true,
	},
	&"Window": {
		"name": "窗边的晨光",
		"desc": "护盾在身时,出手越来越快。",
		"tags": [],
	},
}


static func has_buff_def(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	return DEFS[id]["name"] if DEFS.has(id) else String(id)


static func desc(id: StringName) -> String:
	return DEFS[id]["desc"] if DEFS.has(id) else ""


static func icon(id: StringName) -> Texture2D:
	return load(ICON_DIR + String(id) + ".png") as Texture2D


static func has_tag(id: StringName, tag: String) -> bool:
	return DEFS.has(id) and tag in (DEFS[id]["tags"] as Array)


## 显示用状态变体(破碎守望/冷却云雾/燃烧铜灯):不是可持有的技能,列表要跳过。
static func is_variant(id: StringName) -> bool:
	return DEFS.has(id) and bool(DEFS[id].get("variant", false))
