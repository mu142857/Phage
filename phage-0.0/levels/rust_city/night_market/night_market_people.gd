# 夜市的人。剧本 #6 退役勇士(三段话分三次来才听得完)、#8 羊 + 捕梦网里的小鸟、#9 保龄球先生。
# 卖装备/卖好梦/保龄球馆、羊的隐藏战,等商店和室内做好再接。
# 角落:面摊边上的刀仔,楼上阳台的扔瓶子的。
extends AlleyPeople

const WARRIOR_PARTS := [
	["这里以前很和平。", "直到它们来了。"],
	["我和我朋友，想把它们赶走。", "……没成功。", "你是我们唯一的希望了。"],
	["什么，你问我的朋友在哪……", "你到底需要些什么！？"],
]

var _warrior: Npc
var _sheep: Npc
var _bowler: Npc
var _warrior_advanced := false   # 这一趟来已经往下讲过一段了


func _setup() -> void:
	_warrior = npc("Warrior")
	_sheep = npc("Sheep")
	_bowler = npc("Bowler")
	_warrior.on_talk = _talk_warrior
	_sheep.on_talk = _talk_sheep
	_bowler.on_talk = _talk_bowler
	call_out(_sheep, "哈——欠——", 50.0)
	call_out(_bowler, "全中！", 56.0, "", "……不是说你。")


func _talk_warrior() -> void:
	var n: int = int(Story.flag("warrior_part", 0))
	await Dialogue.say(WARRIOR_PARTS[n % WARRIOR_PARTS.size()], "老板")
	# 一趟只往下讲一段:下次再来才听下一段
	if not _warrior_advanced:
		_warrior_advanced = true
		Story.set_flag("warrior_part", n + 1)


func _talk_sheep() -> void:
	stop_call_out(_sheep)
	if not Story.flag("sheep_met", false):
		Story.set_flag("sheep_met", true)
		await Dialogue.talk([
			["羊", "一只羊……"],
			["羊", "两只羊……"],
			["羊", "……"],
			["", "（数的是它自己）"],
			["羊", "欢迎光临。"],
			["羊", "本店只卖好梦。"],
		])
	else:
		await Dialogue.say(["本店只卖好梦。"], "羊")


func _talk_bowler() -> void:
	stop_call_out(_bowler)
	await Dialogue.say(["这是我最好的朋友。", "我把它打倒过一万次。"], "保龄球先生")
