# res://levels/boss_rush_test/boss_rush_test.gd
# Boss Rush 测试场:160×90 固定镜头,ROSTER 里的 boss 一个接一个出场,专门测强度。
# 每个 boss 出场都播头衔+名字字卡;玩家死亡走正常重载 = 从头再来;按 N 跳过当前 boss。
# 每个 boss 的击杀用时实时显示在右上角,全打完后控制台输出一份总表。
extends Node2D

const BOSS_INTRO_SCENE: PackedScene = preload("res://systems/boss_intro/boss_intro.tscn")
const BossIntroScript := preload("res://systems/boss_intro/boss_intro.gd")

const ROSTER: Array[Dictionary] = [
	{"name": "球克", "title": "羸弱之翼", "scene": "res://entities/cox/week_cox.tscn",
		"pos": Vector2(80, 40)},
	{"name": "阿克缇诺斯", "title": "摇篮里的心跳", "scene": "res://entities/actinos/actinos.tscn",
		"pos": Vector2(80, 80), "card_animation": &"Battlecry"},
	{"name": "老大史莱姆", "title": "锈都拳王", "scene": "res://entities/rust_goat/rust_goat.tscn",
		"pos": Vector2(86, 80)},
	# 金盏的状态机以 center_x 为场地原点(蛛网森林=0),这间 0~160 的房覆写成 80
	{"name": "金盏", "title": "顶级捕猎者", "scene": "res://entities/calendula/calendula.tscn",
		"pos": Vector2(116, 33),
		"overrides": {"center_x": 80.0, "bound_min_x": 10.0, "bound_max_x": 150.0}},
	{"name": "蓝晶", "title": "森林的创口", "scene": "res://entities/azure_warlord/azure_warlord.tscn",
		"pos": Vector2(118, 80)},
	{"name": "忏悔者", "title": "礼拜日的狂信徒", "scene": "res://entities/penitent/penitent.tscn",
		"pos": Vector2(83, 25), "card_animation": &"Battlecry"},
]

@export var start_index := 0    # 从第几个 boss 开打(0 起),想单练后期 boss 改这里
@export var gap_seconds := 1.0  # 上一个死掉到下一个出场的间隔
@export var fight_state := 1    # 状态机开打状态号(全项目 boss 都是 1)

@onready var _hud: Label = $HUD/InfoLabel

var _boss: Node2D = null
var _index := -1
var _fight_start_ms := 0
var _fighting := false
var _skip_used := false
var _total_seconds := 0.0
var _results: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	for i in range(start_index, ROSTER.size()):
		if not is_inside_tree():
			return
		_index = i
		var entry := ROSTER[i]
		_restore_player_shields()
		_hud.text = "下一个:%s (N=跳过)" % entry["name"]
		await _sleep(gap_seconds)
		if not is_inside_tree():
			return
		_boss = _spawn(entry)
		if _boss == null:
			_results.append("%s 生成失败" % entry["name"])
			continue
		await _play_intro(entry, _boss)
		if not is_inside_tree():
			return
		_fight_start_ms = Time.get_ticks_msec()
		_fighting = true
		_skip_used = false
		await _boss.tree_exited
		if not is_inside_tree():
			return
		_fighting = false
		var seconds := (Time.get_ticks_msec() - _fight_start_ms) / 1000.0
		_total_seconds += seconds
		_results.append("%s %.1fs%s" % [entry["name"], seconds, "(跳过)" if _skip_used else ""])
		Game.stop_shake()
	_finish()


func _spawn(entry: Dictionary) -> Node2D:
	var packed: PackedScene = load(entry["scene"])
	if packed == null:
		return null
	var boss := packed.instantiate() as Node2D
	if boss == null:
		return null
	# 掐掉各 boss 自带的出场演出(同 BossIntro._prepare_boss)
	if "initial_battlecry_shown" in boss:
		boss.set("initial_battlecry_shown", true)
	if "intro_shown" in boss:
		boss.set("intro_shown", true)
	if "fighting" in boss:
		boss.set("fighting", true)
	var overrides: Dictionary = entry.get("overrides", {})
	for key: String in overrides:
		boss.set(key, overrides[key])
	boss.position = entry["pos"]
	add_child(boss)
	# 状态机按回 Null:_ready 里 Idle 可能已入场并排了攻击计时
	_change_boss_state(boss, 0)
	Game.flash(0.25, Color(1.0, 1.0, 1.0))
	return boss


# 每个 boss 都播完整的头衔+名字字卡(BossIntro 手动模式),播完自动开打。
# BossIntro 的字卡记录按场景 key 去重,先擦掉才能每个 boss 都完整演一遍。
func _play_intro(entry: Dictionary, boss: Node2D) -> void:
	var intro := BOSS_INTRO_SCENE.instantiate()
	intro.title_text = entry["title"]
	intro.boss_name_text = entry["name"]
	intro.card_animation = entry.get("card_animation", &"")
	intro.fight_state = fight_state
	add_child(intro)
	BossIntroScript._played.erase(get_tree().current_scene.scene_file_path)
	await intro.play_for(boss)
	if is_instance_valid(intro):
		intro.queue_free()


func _change_boss_state(boss: Node2D, id: int) -> void:
	if id < 0:
		return
	if boss.has_method("change_state"):
		boss.call("change_state", id)
		return
	var sm := boss.get_node_or_null("StateMachine")
	if sm != null and sm.has_method("change_state"):
		sm.call("change_state", id)


# 每个 boss 之间把玩家的盾全部回满(等价于回满状态,主角没有血池)
func _restore_player_shields() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Node = players[0]
	if not "shield_ready" in p:
		return
	var ready_list: Array = p.get("shield_ready")
	var recharge_list: Array = p.get("shield_recharge")
	for i in ready_list.size():
		ready_list[i] = true
	for i in recharge_list.size():
		recharge_list[i] = 0.0
	if p.has_method("_refresh_shield_visual"):
		p.call("_refresh_shield_visual")
	p.emit_signal("shield_changed")


func _finish() -> void:
	for line in _results:
		print("[BossRush] ", line)
	print("[BossRush] 总计 %.1fs" % _total_seconds)
	_hud.text = "通关! 总计 %.1fs\n" % _total_seconds + "\n".join(_results)


func _process(_delta: float) -> void:
	if _fighting and is_instance_valid(_boss):
		var seconds := (Time.get_ticks_msec() - _fight_start_ms) / 1000.0
		_hud.text = "%d/%d %s %.1fs" % [_index + 1, ROSTER.size(), ROSTER[_index]["name"], seconds]


func _unhandled_input(event: InputEvent) -> void:
	# N:跳过当前 boss,直接进下一个
	if _fighting and is_instance_valid(_boss) and event is InputEventKey \
			and event.pressed and not event.is_echo() and event.keycode == KEY_N:
		_skip_used = true
		_boss.queue_free()


func _sleep(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
