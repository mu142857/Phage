# 修车废料巷的人。剧本 #12 轮胎(瘪了 → 扫地机给气门芯 → 打足气)、#7 扫地机(在车库门口转悠)。
# 打足气以后可以赛跑(tire_race.gd,三场一场比一场难,能押铜板,三场全赢有奖)。
# 扫地机的尘盒是全城失物招领:气门芯(→轮胎)、油壶(→楼梯坡巷的剑中石)。
# 扫地机的电池/没电推回充电窝、旧电脑(修车铺里屋),之后接。
# 角落:仓库门口的链子小弟 + 滚桶的。
extends AlleyPeople

const RACE_SCRIPT := preload("res://levels/rust_city/scrap_alley/tire_race.gd")
const CHAMPION_PRIZE := 15
const VAC_LEFT := 78.0
const VAC_RIGHT := 126.0

var _tire: Npc
var _vac: Npc
var _vac_dir := 1.0
var _vac_sulk := 0.0
var _race: TireRace = null


func _setup() -> void:
	_tire = npc("Tire")
	_vac = npc("Vacuum")
	_tire.on_talk = _talk_tire
	_vac.on_talk = _talk_vac
	if not Story.flag("tire_inflated", false):
		_tire.sprite.scale = Vector2(1.3, 0.5)   # 瘪的
		call_out(_tire, "……瘪了。", 40.0)
	call_out(_vac, "对不起！", 22.0, "", "我不是人机！")


# 扫地机在车库门口来回扫
func _process(delta: float) -> void:
	super._process(delta)
	if _vac == null or Talk.busy():
		return
	if _vac_sulk > 0.0:
		# 生气:原地转圈
		_vac_sulk -= delta
		if fmod(_vac_sulk, 0.25) < delta:
			_vac.face(1.0 if randf() < 0.5 else -1.0)
		return
	_vac.global_position.x += _vac_dir * 14.0 * delta
	if _vac.global_position.x > VAC_RIGHT:
		_vac_dir = -1.0
	elif _vac.global_position.x < VAC_LEFT:
		_vac_dir = 1.0
	_vac.face(_vac_dir)


func _talk_tire() -> void:
	stop_call_out(_tire)
	if not Story.flag("tire_inflated", false):
		if Story.flag("has_valve", false):
			await Dialogue.say(["（你把气门芯装上。）"])
			Story.set_flag("tire_inflated", true)
			var tw := create_tween()
			tw.tween_property(_tire.sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await tw.finished
			_tire.hop(4.0, 0.3)
			await wait(0.3)
		else:
			Story.set_flag("tire_met", true)
			await Dialogue.say(["……瘪了。", "气门芯丢了。"], "轮胎")
			return
	var wins: int = int(Story.flag("tire_wins", 0))
	var lines := ["我是这条街最快的！", "比一场？"] if wins < 3 else ["……你比我快。", "再来一场？"]
	var pick := await Dialogue.ask(lines, ["比！", "你以前是干嘛的？", "下次"], "轮胎")
	if pick == 1:
		await Dialogue.say(["我以前是一辆车的前轮。", "车停在路那边的码头。", "路断那天，", "我正好滚到这边来了。"], "轮胎")
		return
	if pick != 0:
		return
	var bet := 0
	if Story.coins >= 1:
		var opts: Array = []
		var vals: Array = []
		if Story.coins >= 5:
			opts.append("押 5")
			vals.append(5)
		opts.append("押 1")
		vals.append(1)
		opts.append("不押")
		vals.append(0)
		bet = vals[await Dialogue.ask(["押几个铜板？", "赢了翻倍。"], opts, "轮胎")]
	var round_no := mini(wins + 1, 3)
	var intro: Array = [
		["从这盏路灯，", "跑到那盏路灯。"],
		["这回我可不让你了。"],
		["这回废车场那帮野轮胎", "也要来凑热闹。", "跳过去，别被撞上。"],
	][round_no - 1]
	await Dialogue.say(intro, "轮胎")
	if bet > 0:
		Story.add_coins(-bet)
	_start_race.call_deferred(round_no, bet)


func _start_race(round_no: int, bet: int) -> void:
	if _race != null:
		return
	pause_talk(true)
	_tire.visible = false
	_race = RACE_SCRIPT.new()
	_race.setup(player as CharacterBody2D, round_no, bet)
	_race.finished.connect(_on_race_finished.bind(round_no))
	_race.reset_done.connect(func() -> void:
		_tire.visible = true
		pause_talk(false))
	_race.tree_exited.connect(_on_race_gone)
	add_child(_race)


func _on_race_finished(result: int, round_no: int) -> void:
	if result == 1:
		var wins: int = int(Story.flag("tire_wins", 0))
		if round_no > wins:
			Story.set_flag("tire_wins", round_no)
	_race_result = result


var _race_result := -2


# 比完了(黑屏那一下):轮胎回原位,说一句
func _on_race_gone() -> void:
	_race = null
	if not is_inside_tree():
		return
	_tire.visible = true
	pause_talk(false)
	await wait(0.2)
	if _race_result == 1:
		if int(Story.flag("tire_wins", 0)) >= 3 and not Story.flag("tire_champion", false):
			Story.set_flag("tire_champion", true)
			_tire.bark("……", 1.2)
			await wait(1.0)
			Talk.begin()
			await Dialogue.say(["……你比我快。", "这条街最快的，", "是你。"], "轮胎")
			pay(CHAMPION_PRIZE)
			MiniHud.float_text(get_parent(), player.global_position + Vector2(0, -10), "+%d" % CHAMPION_PRIZE)
			Talk.end()
		else:
			_tire.bark("……漏气了。", 2.0)
	elif _race_result == 0:
		_tire.bark("最快的！", 2.0)
	_race_result = -2


func _talk_vac() -> void:
	stop_call_out(_vac)
	_vac.face_x(player.global_position.x)
	var item := ""
	if Story.flag("tire_met", false) and not Story.flag("has_valve", false):
		item = "has_valve"
	elif Story.flag("sword_needs_oil", false) and not Story.flag("has_oil", false):
		item = "has_oil"
	if item != "":
		await Dialogue.say(["等等。"], "扫地机")
		await Dialogue.ask(["你是人机吗？"], ["不是"], "扫地机")
		await Dialogue.say(["人机都这么说。", "……算了，给你。"], "扫地机")
		Story.set_flag(item, true)
		await Dialogue.say(["（拿到了气门芯。）" if item == "has_valve" else "（拿到了一个油壶。）"])
		return
	if not Story.flag("vac_met", false):
		Story.set_flag("vac_met", true)
		await Dialogue.say(["对不起！", "我不是人机！"], "扫地机")
	var pick := await Dialogue.ask(["我是扫地的。", "但我不是人机。"], ["你当然不是", "你就是个机器人"], "扫地机")
	if pick == 0:
		await Dialogue.say(["对吧！"], "扫地机")
	else:
		await Dialogue.say(["…………"], "扫地机")
		_vac_sulk = 3.0   # 气得原地转圈
