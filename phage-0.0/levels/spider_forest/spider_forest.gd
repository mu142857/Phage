extends Node2D

@export var camera_limit_top: int = 0
@export var camera_limit_bottom: int = 90
@export var camera_limit_left: int = -80
@export var camera_limit_right: int = 1600

const SPIDER_SCENES: Array[PackedScene] = [
	preload("res://entities/spider/spider_1.tscn"),
	preload("res://entities/spider/spider_2.tscn"),
	preload("res://entities/spider/spider_3.tscn"),
]
const SILK_LINE_TEXTURE: Texture2D = preload("res://levels/spider_forest/web_silk_line.png")
const LURE_TEXTURE: Texture2D = preload("res://levels/spider_forest/spider_queen.png")
const WEB_WALL_SCRIPT: GDScript = preload("res://levels/spider_forest/web_wall.gd")

# ---- 诱饵女孩 + 右→左封锁网 ----
const LURE_X: float = 1560.0
const LURE_Y: float = 73.0          # 地面80 - 半身高7
const LURE_TRIGGER_DIST: float = 22.0
const LURE_HOIST_TIME: float = 1.3
const WALL_START_X: float = 1640.0
const WALL_SPEED: float = 48.0      # 步行(70)被追上，冲刺(220)能逃
const WALL_MIN_X: float = -60.0     # 封到最左侧留的极限，按需调
const ESCAPE_SPAWN_INTERVAL: float = 2.4
const ESCAPE_MAX_ALIVE: int = 5
# 逃亡期只刷轻量蜘蛛(绿橙/蓝眼)，不刷肉墙狼蛛
const ESCAPE_SPIDER_INDICES: Array[int] = [0, 2]
# 逃亡期地面拦路蜘蛛：直接站在玩家逃跑方向前方的距离范围
const ESCAPE_BLOCKER_AHEAD_MIN: float = 55.0
const ESCAPE_BLOCKER_AHEAD_MAX: float = 90.0

const SPAWN_START_Y: float = -25.0
const SILK_ANCHOR_Y: float = -30.0
const LANDING_Y: float = 79.0
# 垂降总时长：嗖的一下坠到地面（缓出，落地前微减速）
const DESCEND_TIME: float = 0.55

const CHECK_INTERVAL: float = 2.0
const SPAWN_CHANCE_EMPTY: float = 0.5
const SPAWN_CHANCE_ONE: float = 0.18
const MAX_ALIVE: int = 14
const HALF_SCREEN: float = 80.0
# 平台中心 x（跨度±22），垂降落点严禁在平台正上方（会穿到平台底下）
const PLATFORM_XS: Array[float] = [360.0, 435.0, 515.0, 1150.0, 1225.0, 1300.0, 1240.0]
# 开局就站在地上的蜘蛛（去程一路都有阻拦），全部避开平台正上方
const GROUND_SPAWN_XS: Array[float] = [190.0, 320.0, 480.0, 640.0, 800.0, 990.0, 1120.0, 1330.0, 1470.0]
const GROUND_SPAWN_Y: float = 74.0

var _spiders: Array = []
var _rng := RandomNumberGenerator.new()
var _check_accum: float = 0.0
var _lure: Sprite2D = null
var _lure_line: Sprite2D = null
var _lure_triggered: bool = false
var _escape_active: bool = false
var _wall_x: float = 0.0
var _wall: Node2D = null
var _escape_accum: float = 0.0

func _ready() -> void:
	add_to_group("camera_follow")
	_rng.randomize()
	_spawn_lure()
	for gx in GROUND_SPAWN_XS:
		var scene: PackedScene = SPIDER_SCENES[_rng.randi_range(0, SPIDER_SCENES.size() - 1)]
		_spawn_ground_spider(scene, gx)

func _process(delta: float) -> void:
	if _escape_active:
		_update_escape(delta)
		return
	if not _lure_triggered:
		_check_lure_trigger()
	_check_accum += delta
	if _check_accum < CHECK_INTERVAL:
		return
	_check_accum = 0.0
	_try_screen_spawn()

func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}

# 屏内无蜘蛛时高概率、有一只时低概率，在玩家视野内垂降一只（三种等概率）
func _try_screen_spawn() -> void:
	_spiders = _spiders.filter(func(s: Object) -> bool: return is_instance_valid(s))
	if _spiders.size() >= MAX_ALIVE:
		return
	var player := get_node_or_null("Player") as Node2D
	if player == null:
		return
	var center: float = clampf(player.global_position.x,
		float(camera_limit_left) + HALF_SCREEN, float(camera_limit_right) - HALF_SCREEN)
	var on_screen: int = 0
	for s in _spiders:
		var sp := s as Node2D
		if sp != null and absf(sp.global_position.x - center) <= HALF_SCREEN + 8.0:
			on_screen += 1
	if on_screen >= 2:
		return
	var chance: float = SPAWN_CHANCE_EMPTY if on_screen == 0 else SPAWN_CHANCE_ONE
	if _rng.randf() > chance:
		return
	for attempt in 8:
		var x: float = center + _rng.randf_range(-HALF_SCREEN + 12.0, HALF_SCREEN - 12.0)
		if absf(x - player.global_position.x) < 18.0:
			continue
		if _x_over_platform(x):
			continue
		var scene: PackedScene = SPIDER_SCENES[_rng.randi_range(0, SPIDER_SCENES.size() - 1)]
		_spawn_descending_spider(scene, x)
		return

func _x_over_platform(x: float) -> bool:
	for px in PLATFORM_XS:
		if absf(x - px) < 22.0:
			return true
	return false

# 直接站在地上的蜘蛛（无垂降），用于开局布防和逃亡期拦路
func _spawn_ground_spider(scene: PackedScene, x: float) -> void:
	var spider := scene.instantiate() as CharacterBody2D
	if spider == null:
		return
	_spiders.append(spider)
	spider.z_index = 10
	spider.position = Vector2(x, GROUND_SPAWN_Y)
	add_child(spider)

func _spawn_descending_spider(scene: PackedScene, x: float) -> void:
	var spider := scene.instantiate() as CharacterBody2D
	if spider == null:
		return
	_spiders.append(spider)
	spider.z_index = 10
	# 必须先设位置再入树：腿部脚本在 _ready 里以当前位置为锚，晚了会拉出残影
	spider.position = Vector2(x, SPAWN_START_Y)
	add_child(spider)
	# 垂降期间整体冻结（含状态机/物理子节点），只由 tween 控制位置
	spider.process_mode = Node.PROCESS_MODE_DISABLED

	var line := Sprite2D.new()
	line.texture = SILK_LINE_TEXTURE
	line.centered = false
	line.z_index = 9
	line.position = Vector2(x - 1.0, SILK_ANCHOR_Y)
	line.scale = Vector2(1.0, 0.125)
	add_child(line)

	var tween := create_tween()
	tween.tween_method(_descend_step.bind(spider, line, x), SPAWN_START_Y, LANDING_Y, DESCEND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	if is_instance_valid(spider):
		spider.process_mode = Node.PROCESS_MODE_INHERIT
		for child in spider.get_children():
			if child.has_method("reset_feet"):
				child.call("reset_feet")
	if is_instance_valid(line):
		var fade := create_tween()
		fade.tween_property(line, "modulate:a", 0.0, 0.5)
		fade.tween_callback(line.queue_free)

func _descend_step(y: float, spider: CharacterBody2D, line: Sprite2D, x: float) -> void:
	if is_instance_valid(spider):
		spider.global_position = Vector2(x, y)
	if is_instance_valid(line):
		# 基础贴图 8px 高，拉伸到锚点→蜘蛛身体的长度（纯色直线，拉伸无失真）
		line.scale = Vector2(1.0, maxf(1.0, y - 5.0 - SILK_ANCHOR_Y) / 8.0)

# ============================================================
# 诱饵女孩：站在关卡最右端，玩家靠近 -> 被蛛丝吊起 -> 封锁网启动
# ============================================================

func _spawn_lure() -> void:
	_lure = Sprite2D.new()
	_lure.texture = LURE_TEXTURE
	_lure.position = Vector2(LURE_X, LURE_Y)
	_lure.z_index = 10
	add_child(_lure)

func _check_lure_trigger() -> void:
	var player := get_node_or_null("Player") as Node2D
	if player == null or _lure == null:
		return
	if absf(player.global_position.x - LURE_X) > LURE_TRIGGER_DIST:
		return
	_lure_triggered = true
	_hoist_lure()

func _hoist_lure() -> void:
	# 丝线锚在屏幕上方，女孩被拽上去时丝线跟着缩短
	_lure_line = Sprite2D.new()
	_lure_line.texture = SILK_LINE_TEXTURE
	_lure_line.centered = false
	_lure_line.z_index = 9
	_lure_line.position = Vector2(LURE_X - 1.0, SILK_ANCHOR_Y)
	_lure_line.scale = Vector2(1.0, maxf(1.0, LURE_Y - SILK_ANCHOR_Y) / 8.0)
	add_child(_lure_line)

	var tween := create_tween()
	tween.tween_method(_hoist_step, LURE_Y, SILK_ANCHOR_Y - 12.0, LURE_HOIST_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(_lure):
		_lure.queue_free()
	if is_instance_valid(_lure_line):
		_lure_line.queue_free()
	_start_escape()

func _hoist_step(y: float) -> void:
	if is_instance_valid(_lure):
		_lure.position.y = y
	if is_instance_valid(_lure_line):
		_lure_line.scale = Vector2(1.0, maxf(0.1, y - 7.0 - SILK_ANCHOR_Y) / 8.0)

# ============================================================
# 封锁网：从右往左推进的死亡墙，碰到即死；逃亡期蜘蛛只刷在屏幕左侧
# ============================================================

func _start_escape() -> void:
	_escape_active = true
	_wall_x = WALL_START_X
	_wall = WEB_WALL_SCRIPT.new() as Node2D
	_wall.z_index = 20
	add_child(_wall)
	_wall.call("setup", WALL_START_X)

func _update_escape(delta: float) -> void:
	_wall_x = maxf(_wall_x - WALL_SPEED * delta, WALL_MIN_X)
	if is_instance_valid(_wall):
		_wall.set("front_x", _wall_x)

	var player := get_node_or_null("Player") as Node2D
	if player != null and player.global_position.x >= _wall_x - 1.0:
		if player.has_method("_die"):
			player.call("_die")

	# 被网吞掉的蜘蛛直接清掉
	_spiders = _spiders.filter(func(s: Object) -> bool: return is_instance_valid(s))
	for s in _spiders:
		var sp := s as Node2D
		if sp != null and sp.global_position.x >= _wall_x:
			sp.queue_free()

	_escape_accum += delta
	if _escape_accum < ESCAPE_SPAWN_INTERVAL:
		return
	_escape_accum = 0.0
	_try_escape_spawn(player)

# 逃亡期生成：每拍两路夹击——视野左缘垂降一只 + 逃跑路线正前方地面拦一只
func _try_escape_spawn(player: Node2D) -> void:
	if player == null:
		return
	var center: float = clampf(player.global_position.x,
		float(camera_limit_left) + HALF_SCREEN, float(camera_limit_right) - HALF_SCREEN)
	# 上限只数玩家附近的蜘蛛，远处没清掉的残兵不占逃亡期配额
	var nearby: int = 0
	for s in _spiders:
		var sp := s as Node2D
		if sp != null and absf(sp.global_position.x - player.global_position.x) <= 180.0:
			nearby += 1
	# 1) 地面拦路：直接站在玩家前方（左侧）挡道
	if nearby < ESCAPE_MAX_ALIVE:
		for attempt in 6:
			var bx: float = player.global_position.x - _rng.randf_range(ESCAPE_BLOCKER_AHEAD_MIN, ESCAPE_BLOCKER_AHEAD_MAX)
			if bx <= float(camera_limit_left) + 10.0 or bx >= _wall_x - 30.0:
				break
			if _x_over_platform(bx):
				continue
			var bi: int = ESCAPE_SPIDER_INDICES[_rng.randi_range(0, ESCAPE_SPIDER_INDICES.size() - 1)]
			_spawn_ground_spider(SPIDER_SCENES[bi], bx)
			nearby += 1
			break
	# 2) 垂降：刷在视野左缘（逃跑方向）
	if nearby >= ESCAPE_MAX_ALIVE:
		return
	for attempt in 6:
		var x: float = center - HALF_SCREEN + _rng.randf_range(8.0, 26.0)
		if x <= float(camera_limit_left) + 6.0 or x >= _wall_x - 12.0:
			continue
		if absf(x - player.global_position.x) < 18.0:
			continue
		if _x_over_platform(x):
			continue
		var index: int = ESCAPE_SPIDER_INDICES[_rng.randi_range(0, ESCAPE_SPIDER_INDICES.size() - 1)]
		_spawn_descending_spider(SPIDER_SCENES[index], x)
		return
