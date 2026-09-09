# =============================================================================
# puppeteer.gd  —  木偶师「台上那只手」：Boss 的大脑(血/阶段/决策/刷东西都在这)
# =============================================================================
# 画面里永远只看得到手，手是人偶贴图的一部分(见 wooden_man.gd)。
# 木偶师本身是个 Node2D 控制器，没有身体、打不到；玩家打的是它派下来的木头人，
# 木头人 take_damage 转给这里扣血。血条挂在这(BossHealthUI + CanvasLayer)。
#
# 战斗循环：
#   一阶段  1 只木头人在屏幕中间吊着 → 随机变刀哥/激光眼打一套 → 化开 → 再放一只
#   二阶段(血 ≤ phase_two_ratio) 战吼一下，左右各吊一只(两只手都上了)；
#            同一时刻只许一只动手(next_attack_for 里排队)，另一只吊着晃
#   期间手会往下扔惊喜盒子(jack_box)：砸到主角 = 硬控不掉血；落地弹出小丑头(接 pop_scene)
#   还可以用线把随机小怪吊下来(minion_scenes 留空 = 不刷)
# 死亡：所有木头人线断掉地 → 等它们摔完 → queue_free(关卡 DreamEnd.watch_path 盯这里)
#
# 对外接口(BossIntro / boss_rush 都靠这些)：
#   change_state(0)=停 / change_state(1)=开打 / change_state(2)=死
#   take_damage(v) / show_health_ui() / hide_health_ui() / initial_battlecry_shown
# =============================================================================
extends Node2D

const WOODEN_MAN_SCENE: PackedScene = preload("res://entities/wooden_man/wooden_man.tscn")
const JACK_BOX_SCENE: PackedScene = preload("res://entities/wooden_man/jack_box.tscn")

const PHASE_ONE: int = 0
const PHASE_TWO: int = 1

# --- 基础数值 ----------------------------------------------------------------
@export var max_health: int = 6000
@export var health: int = 6000
@export var phase_two_ratio: float = 0.5
@export var idle_only: bool = false            # 调试：人偶只吊着晃不攻击

# --- 槽位：各阶段木头人吊在哪些 x --------------------------------------------
@export var slots_phase_one: Array[float] = [80.0]
@export var slots_phase_two: Array[float] = [44.0, 116.0]

# --- 节奏 --------------------------------------------------------------------
@export var idle_time_full_health: float = 2.4  # 吊着晃多久才出手(满血)
@export var idle_time_low_health: float = 1.2   # (残血)
@export var respawn_delay: float = 0.8          # 化开后多久放新的下来
@export var battlecry_duration: float = 2.0     # 二阶段战吼(锁玩家+震屏)
@export var battlecry_shake: float = 3.0

# --- 惊喜盒子 ----------------------------------------------------------------
@export var box_enabled: bool = true
@export var box_interval_phase_one: float = 7.0
@export var box_interval_phase_two: float = 4.5
@export var box_stun_time: float = 0.9          # 砸中主角的硬控时长(不掉血)
@export var box_pop_scene: PackedScene = null   # 盒子落地弹出来的东西(小丑头小怪)，空=只弹不出怪

# --- 随机小怪(用线吊下来) -----------------------------------------------------
@export var minion_scenes: Array[PackedScene] = []
@export var minion_interval: float = 12.0
@export var minion_max_alive: int = 2
@export var minion_floor_y: float = 80.0

# --- 运行时 ------------------------------------------------------------------
var phase: int = PHASE_ONE
var fighting: bool = false
var initial_battlecry_shown: bool = false   # BossIntro/boss rush 会预设 true
var puppets: Array = []                     # 场上的木头人
var attacking_puppet: Node = null           # 正在动手的那只(同一时刻只许一只)
var _pending_phase_two: bool = false
var _phase_two_done: bool = false
var _battlecry_active: bool = false
var _last_attack: int = -1
var _dead: bool = false
var _loop_ticket: int = 0
var rng := RandomNumberGenerator.new()

@onready var boss_health_ui = get_node_or_null("BossHealthUI")


func _ready() -> void:
	rng.randomize()
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.hide_ui(false)
	# tscn 里预放的木头人(字卡期间就是它吊在场上)
	for child in get_children():
		if child is CharacterBody2D and child.has_method("respawn"):
			register_puppet(child)
	for p in puppets:
		p.slot_x = p.global_position.x
		p.change_state(p.STATE_NULL)


func register_puppet(p: Node) -> void:
	if p in puppets:
		return
	puppets.append(p)
	p.puppeteer = self


# =============================================================================
# 对外：状态切换(0 停 / 1 开打 / 2 死)
# =============================================================================
func change_state(id: int) -> void:
	match id:
		0:
			_stop()
		1:
			_start_fight()
		2:
			_die()


func _stop() -> void:
	fighting = false
	_loop_ticket += 1
	attacking_puppet = null
	for p in puppets:
		if is_instance_valid(p):
			p.change_state(p.STATE_NULL)


func _start_fight() -> void:
	if fighting or _dead:
		return
	fighting = true
	initial_battlecry_shown = true
	_loop_ticket += 1
	var slots := _slots()
	for i in puppets.size():
		var p = puppets[i]
		if not is_instance_valid(p):
			continue
		p.slot_x = slots[i % slots.size()]
		p.change_state(p.STATE_IDLE)
	_box_loop(_loop_ticket)
	_minion_loop(_loop_ticket)


# =============================================================================
# 受伤 / 阶段 / 死亡
# =============================================================================
func take_damage(value: int) -> void:
	if _dead:
		return
	health = clampi(health - value, 0, max_health)
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)
	if not _phase_two_done and float(health) / float(max_health) <= phase_two_ratio:
		_phase_two_done = true
		_pending_phase_two = true
	if health <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	fighting = false
	_loop_ticket += 1
	hide_health_ui()
	Game.shake_camera(2.5)
	for n in get_tree().get_nodes_in_group("puppeteer_spawn"):
		if is_instance_valid(n):
			if n.has_method("cancel"):
				n.call("cancel")
			else:
				(n as Node).queue_free()
	for p in puppets:
		if is_instance_valid(p):
			p.change_state(p.STATE_DEATH)
	_wait_puppets_gone()


func _wait_puppets_gone() -> void:
	var t := 0.0
	while t < 4.0:
		var alive := false
		for p in puppets:
			if is_instance_valid(p):
				alive = true
		if not alive:
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_inside_tree():
		queue_free()


# =============================================================================
# 决策：木头人 Idle 到点来问「我能出手吗，出什么」
# =============================================================================
func next_attack_for(p: Node) -> int:
	if not fighting or idle_only:
		return p.STATE_IDLE
	# 二阶段：先战吼、放第二只下来，这一轮谁都别动
	if _pending_phase_two:
		_pending_phase_two = false
		_enter_phase_two()
		return p.STATE_IDLE
	if _battlecry_active:
		return p.STATE_IDLE  # 战吼中谁都别动
	if attacking_puppet != null and is_instance_valid(attacking_puppet) and attacking_puppet != p:
		return p.STATE_IDLE  # 别人在打，排队
	var pool: Array[int] = [p.STATE_TO_BLADE, p.STATE_TO_EYE]
	if pool.size() > 1 and _last_attack in pool:
		pool.erase(_last_attack)
	var pick: int = pool[rng.randi() % pool.size()]
	_last_attack = pick
	attacking_puppet = p
	return pick


func idle_time_for(_p: Node) -> float:
	var ratio: float = float(health) / float(max_health) if max_health > 0 else 1.0
	return lerpf(idle_time_low_health, idle_time_full_health, ratio)


func on_puppet_attack_finished(p: Node) -> void:
	if attacking_puppet == p:
		attacking_puppet = null


# 化开了：隔一会儿在自己的槽位放一只新的下来(同一节点复用)
func on_puppet_vanished(p: Node) -> void:
	if attacking_puppet == p:
		attacking_puppet = null
	var ticket := _loop_ticket
	await get_tree().create_timer(respawn_delay).timeout
	if ticket != _loop_ticket or not fighting or not is_instance_valid(p):
		return
	p.respawn(p.slot_x)


# 二阶段：战吼(锁玩家+震屏) + 第一只挪到左槽、第二只从右槽放下来
func _enter_phase_two() -> void:
	phase = PHASE_TWO
	_battlecry_active = true
	var ticket := _loop_ticket
	_set_player_lock(true)
	var slots := _slots()
	# 现有的那只挪到自己的新槽位(Idle 会自己平滑滑过去)
	for i in puppets.size():
		if is_instance_valid(puppets[i]):
			puppets[i].slot_x = slots[i % slots.size()]
	# 第二只
	var second := WOODEN_MAN_SCENE.instantiate()
	add_child(second)
	register_puppet(second)
	second.respawn(slots[1 % slots.size()])
	var t := 0.0
	while t < battlecry_duration:
		if ticket != _loop_ticket or not is_inside_tree():
			_battlecry_active = false
			_set_player_lock(false)
			return
		Game.shake_camera(battlecry_shake)
		await get_tree().process_frame
		t += get_process_delta_time()
	Game.stop_shake()
	_battlecry_active = false
	_set_player_lock(false)


func _slots() -> Array[float]:
	var s := slots_phase_two if phase == PHASE_TWO else slots_phase_one
	if s.is_empty():
		return [80.0]
	return s


# =============================================================================
# 惊喜盒子：手从屏幕顶往主角那边扔，砸中 = 硬控不掉血，落地弹小丑头
# =============================================================================
func _box_loop(ticket: int) -> void:
	while fighting and ticket == _loop_ticket and is_inside_tree():
		var interval := box_interval_phase_two if phase == PHASE_TWO else box_interval_phase_one
		await get_tree().create_timer(interval).timeout
		if ticket != _loop_ticket or not fighting or not is_inside_tree():
			return
		if box_enabled and not idle_only:
			_throw_box()


func _throw_box() -> void:
	if JACK_BOX_SCENE == null or get_tree().current_scene == null:
		return
	var player := _get_player()
	if player == null:
		return
	# 从最近的那只手(木头人头顶的屏幕顶)扔出去
	var from_x: float = 80.0
	var best := INF
	for p in puppets:
		if is_instance_valid(p) and absf(p.global_position.x - player.global_position.x) < best:
			best = absf(p.global_position.x - player.global_position.x)
			from_x = p.global_position.x
	var box := JACK_BOX_SCENE.instantiate()
	box.set("stun_time", box_stun_time)
	box.set("pop_scene", box_pop_scene)
	box.set("floor_y", minion_floor_y)
	get_tree().current_scene.add_child(box)
	box.call("launch", Vector2(from_x, -8.0), player.global_position)


# =============================================================================
# 随机小怪：用一根线从屏幕顶吊下来
# =============================================================================
func _minion_loop(ticket: int) -> void:
	while fighting and ticket == _loop_ticket and is_inside_tree():
		await get_tree().create_timer(minion_interval).timeout
		if ticket != _loop_ticket or not fighting or not is_inside_tree():
			return
		if minion_scenes.is_empty() or idle_only:
			continue
		if get_tree().get_nodes_in_group("puppeteer_minion").size() >= minion_max_alive:
			continue
		_lower_minion()


func _lower_minion() -> void:
	var scene: PackedScene = minion_scenes[rng.randi() % minion_scenes.size()]
	if scene == null or get_tree().current_scene == null:
		return
	var player := _get_player()
	var x := rng.randf_range(24.0, 136.0)
	if player != null and absf(x - player.global_position.x) < 18.0:
		x = clampf(player.global_position.x + (24.0 if x >= player.global_position.x else -24.0), 24.0, 136.0)
	var m := scene.instantiate() as Node2D
	if m == null:
		return
	m.add_to_group("puppeteer_minion")
	m.global_position = Vector2(x, -20.0)  # 位置必须在 add_child 之前设好
	get_tree().current_scene.add_child(m)
	m.process_mode = Node.PROCESS_MODE_DISABLED  # 吊着的时候整体冻结
	# 线：一根 1 格宽的竖线(横平竖直，合铁律)，随人偶下降拉长
	var line := ColorRect.new()
	line.color = Color(0.55, 0.8, 1.0, 0.9)
	line.size = Vector2(1.0, 1.0)
	line.z_index = 9
	get_tree().current_scene.add_child(line)
	line.global_position = Vector2(x, -20.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(m, "global_position:y", minion_floor_y, 0.55)
	tw.tween_property(line, "size:y", minion_floor_y + 20.0, 0.55)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		if is_instance_valid(m):
			m.process_mode = Node.PROCESS_MODE_INHERIT
			if m.has_method("reset_feet"):
				m.call("reset_feet")
	)
	tw.tween_property(line, "modulate:a", 0.0, 0.3)
	tw.tween_callback(line.queue_free)


# =============================================================================
# 血条 / 工具
# =============================================================================
func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)


func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)


func _set_player_lock(locked: bool) -> void:
	var player := _get_player()
	if player == null:
		return
	if player.has_method("set_battlecry_lock"):
		player.call("set_battlecry_lock", locked)
	elif player.has_method("set_lock"):
		player.call("set_lock", locked)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null
