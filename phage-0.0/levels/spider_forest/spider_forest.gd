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
const CALENDULA_SCENE: PackedScene = preload("res://entities/calendula/calendula.tscn")
const BOSS_INTRO_SCENE: PackedScene = preload("res://systems/boss_intro/boss_intro.tscn")

# ---- 诱饵女孩 + 右→左封锁网 ----
const LURE_X: float = 1560.0
const LURE_Y: float = 73.0          # 地面80 - 半身高7
const LURE_TRIGGER_DIST: float = 22.0
const LURE_HOIST_TIME: float = 1.3
const WALL_START_X: float = 1640.0
const WALL_SPEED: float = 48.0      # 步行(70)被追上，冲刺(220)能逃
const WALL_MIN_X: float = 80.0      # 蔓延到这就停：凝固成 boss 房右墙
const ESCAPE_SPAWN_INTERVAL: float = 3.4
const ESCAPE_MAX_ALIVE: int = 3
# 逃亡期只刷轻量蜘蛛(绿橙/蓝眼)，不刷肉墙狼蛛
const ESCAPE_SPIDER_INDICES: Array[int] = [0, 2]
# 逃亡期地面拦路蜘蛛：直接站在玩家逃跑方向前方的距离范围
const ESCAPE_BLOCKER_AHEAD_MIN: float = 55.0
const ESCAPE_BLOCKER_AHEAD_MAX: float = 90.0

# ---- Boss 房（[-80,80] 正好一屏，相机中心锁死 (0,45) = 真 fixed）----
const ARENA_RIGHT_FACE_X: float = 80.0  # 右侧硬网内壁（= 网墙停点）
const LEFT_CURTAIN_X: float = -72.0     # 左缘网帘（纯视觉，实体墙是关卡的 -80）
const ARENA_MIN_X: float = -80.0
const ARENA_MAX_X: float = 80.0
const EARLY_TRIGGER_X: float = 0.0      # 逃亡中玩家过这条线 → 网墙加速封死，提前开打
const WALL_RUSH_SPEED: float = 900.0    # 提前触发后网墙的封死速度
const BOSS_BOUND_MIN_X: float = -70.0   # 金盏在这间房里的活动边界
const BOSS_BOUND_MAX_X: float = 70.0
const SUMMON_LEFT_X: float = -55.0      # 召唤点位（房间左/右/中）
const SUMMON_RIGHT_X: float = 55.0
const SUMMON_CENTER_X: float = 0.0
const BOSS_SPAWN_X: float = 36.0
const BOSS_SPAWN_Y: float = 42.0

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
var _escape_beat_blocker: bool = false  # 逃亡刷怪：拦路/垂降轮着来（减半密度）
var _wall_rush: bool = false            # 玩家提前过线，网墙加速封死中
var _arena_started: bool = false
var _left_curtain: Node2D = null
var _arena_right_body: StaticBody2D = null
var _boss: CharacterBody2D = null

func _ready() -> void:
	add_to_group("camera_follow")
	_rng.randomize()
	_spawn_lure()
	for gx in GROUND_SPAWN_XS:
		var scene: PackedScene = SPIDER_SCENES[_rng.randi_range(0, SPIDER_SCENES.size() - 1)]
		_spawn_ground_spider(scene, gx)

func _process(delta: float) -> void:
	if _arena_started:
		return  # boss 房：不再刷小怪、不再管诱饵
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
# 诱饵女孩：站在关卡最右端，玩家靠近 -> 对话「快跑」-> 被蛛丝吊起 -> 封锁网启动
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
	_lure_sequence()

# 靠近诱饵：全局暂停（和 boss 字卡一个待遇）-> 「她一动不动」「看起来像一个诱饵」
# -> 唯一选项「快跑」-> 恢复时间 -> 吊起。
# 必须真暂停：光冻结现有蜘蛛不够，刷怪和垂降 tween 还在跑，小蜘蛛会趁机围殴锁住的玩家。
# Dialogue 是 PROCESS_MODE_ALWAYS，暂停中照常打字/收输入。
func _lure_sequence() -> void:
	get_tree().paused = true
	await Dialogue.ask(["她一动不动", "看起来像一个诱饵"], ["快跑"])
	get_tree().paused = false
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
# 封锁网：从右往左推进的死亡墙，碰到即死；蔓延到 160 凝固成 boss 房右墙
# ============================================================

func _start_escape() -> void:
	_escape_active = true
	_wall_x = WALL_START_X
	_wall = WEB_WALL_SCRIPT.new() as Node2D
	_wall.z_index = 20
	add_child(_wall)
	_wall.call("setup", WALL_START_X)

func _update_escape(delta: float) -> void:
	var wall_speed: float = WALL_RUSH_SPEED if _wall_rush else WALL_SPEED
	_wall_x = maxf(_wall_x - wall_speed * delta, WALL_MIN_X)
	if is_instance_valid(_wall):
		_wall.set("front_x", _wall_x)

	var player := get_node_or_null("Player") as Node2D
	# 玩家提前跑过触发线：不等网慢慢爬，加速把路封死直接开打
	if not _wall_rush and player != null and player.global_position.x <= EARLY_TRIGGER_X:
		_wall_rush = true
	if player != null and player.global_position.x >= _wall_x - 1.0:
		if player.has_method("_die"):
			player.call("_die")

	# 被网吞掉的蜘蛛直接清掉
	_spiders = _spiders.filter(func(s: Object) -> bool: return is_instance_valid(s))
	for s in _spiders:
		var sp := s as Node2D
		if sp != null and sp.global_position.x >= _wall_x:
			sp.queue_free()

	# 网墙到位：凝固成实体墙，逃脱战结束，boss 房启动
	if _wall_x <= WALL_MIN_X + 0.01:
		_escape_active = false
		_arena_started = true
		_begin_boss_arena()
		return

	_escape_accum += delta
	if _escape_accum < ESCAPE_SPAWN_INTERVAL:
		return
	_escape_accum = 0.0
	_try_escape_spawn(player)

# 逃亡期生成：每拍只来一路，拦路/垂降轮着上（数量比初版减半）
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
	if nearby >= ESCAPE_MAX_ALIVE:
		return
	_escape_beat_blocker = not _escape_beat_blocker
	if _escape_beat_blocker:
		# 地面拦路：直接站在玩家前方（左侧）挡道
		for attempt in 6:
			var bx: float = player.global_position.x - _rng.randf_range(ESCAPE_BLOCKER_AHEAD_MIN, ESCAPE_BLOCKER_AHEAD_MAX)
			if bx <= float(camera_limit_left) + 10.0 or bx >= _wall_x - 30.0:
				return
			if _x_over_platform(bx):
				continue
			var bi: int = ESCAPE_SPIDER_INDICES[_rng.randi_range(0, ESCAPE_SPIDER_INDICES.size() - 1)]
			_spawn_ground_spider(SPIDER_SCENES[bi], bx)
			return
	else:
		# 垂降：刷在视野左缘（逃跑方向）
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

# ============================================================
# Boss 房：硬网封场 -> 相机收 [-80,160] -> 杂兵四散 -> 金盏登场 -> 字卡开打
# ============================================================

func _begin_boss_arena() -> void:
	_spawn_arena_walls()
	_kill_spiders()

	# 相机平滑推到 (0,45) 后把右限收到 80：[-80,80] 正好一屏，
	# 跟随相机被夹死在唯一合法中心 = 真正的 fixed camera，交接无跳变
	Game.set_position_override_smooth(Vector2(0.0, 45.0), 0.6)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	camera_limit_right = 80
	Game.clear_position_override()

	await _summon_boss()
	if not is_inside_tree() or _boss == null:
		return

	var intro := BOSS_INTRO_SCENE.instantiate()
	intro.set("auto_start", false)
	intro.set("title_text", "顶级捕猎者")
	intro.set("boss_name_text", "金盏")
	add_child(intro)
	_boss.tree_exited.connect(_on_boss_defeated)
	await intro.call("play_for", _boss)

# 右侧硬墙（layer 1，玩家撞得上；视觉就是停下的封锁网）
# 左边界用关卡自带的 LeftWall(-80)，只贴一道网帘视觉，不再加实体墙（防把玩家关外面）
func _spawn_arena_walls() -> void:
	_arena_right_body = _make_wall_body(Vector2(ARENA_RIGHT_FACE_X + 6.0, 45.0))

	_left_curtain = WEB_WALL_SCRIPT.new() as Node2D
	_left_curtain.z_index = 20
	add_child(_left_curtain)
	_left_curtain.call("setup", LEFT_CURTAIN_X)
	_left_curtain.set("front_x", ARENA_MIN_X)

func _make_wall_body(pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12.0, 220.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = pos
	add_child(body)
	return body

# 金盏一登场，场上残余小蜘蛛全部当场死亡（顶级捕猎者的威压）
func _kill_spiders() -> void:
	_spiders = _spiders.filter(func(s: Object) -> bool: return is_instance_valid(s))
	for s in _spiders:
		var sp := s as Node
		if sp != null and sp.has_method("take_damage"):
			sp.call("take_damage", 99999)
	# 盾蛛开盾时免伤还回血，缓一拍后补刀强制清场
	await get_tree().create_timer(0.6).timeout
	for s in _spiders:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_spiders.clear()

# 金盏从屏幕上方缓缓飘落入场（冻结本体，只让贴图动）
func _summon_boss() -> void:
	_boss = CALENDULA_SCENE.instantiate() as CharacterBody2D
	if _boss == null:
		return
	_boss.position = Vector2(BOSS_SPAWN_X, -60.0)
	add_child(_boss)
	# 场地几何是关卡的知识：活动边界和召唤点位按这间 [-80,160] 房间覆写
	_boss.set("bound_min_x", BOSS_BOUND_MIN_X)
	_boss.set("bound_max_x", BOSS_BOUND_MAX_X)
	var summon_state := _boss.get_node_or_null("StateMachine/Summon(5)")
	if summon_state != null:
		summon_state.set("left_x", SUMMON_LEFT_X)
		summon_state.set("right_x", SUMMON_RIGHT_X)
		summon_state.set("center_x", SUMMON_CENTER_X)
	if _boss.has_method("change_state"):
		_boss.call("change_state", 0)
	_boss.process_mode = Node.PROCESS_MODE_DISABLED
	var ani := _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if ani != null:
		ani.process_mode = Node.PROCESS_MODE_ALWAYS
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_boss, "position", Vector2(BOSS_SPAWN_X, BOSS_SPAWN_Y), 1.2)
	await tw.finished

# Boss 冲出屏幕（Death 状态 queue_free）→ 蛛网解除 → 梦结束
func _on_boss_defeated() -> void:
	if not is_inside_tree():
		return
	_dissolve_webs()

func _dissolve_webs() -> void:
	if is_instance_valid(_arena_right_body):
		_arena_right_body.queue_free()
	var last_tween: Tween = null
	for node: Node2D in [_wall, _left_curtain]:
		if is_instance_valid(node):
			var tw := create_tween()
			tw.tween_property(node, "modulate:a", 0.0, 1.2)
			tw.tween_callback(node.queue_free)
			last_tween = tw
	if last_tween != null:
		await last_tween.finished
	if not is_inside_tree():
		return
	Story.complete_dream()
