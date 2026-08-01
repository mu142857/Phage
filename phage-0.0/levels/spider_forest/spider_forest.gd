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

const SPAWN_START_Y: float = -25.0
const SILK_ANCHOR_Y: float = -30.0
const LANDING_Y: float = 79.0
# 垂降总时长：嗖的一下坠到地面（缓出，落地前微减速）
const DESCEND_TIME: float = 0.55

const CHECK_INTERVAL: float = 2.0
const SPAWN_CHANCE_EMPTY: float = 0.5
const SPAWN_CHANCE_ONE: float = 0.18
const MAX_ALIVE: int = 8
const HALF_SCREEN: float = 80.0
# 平台中心 x（跨度±22），垂降落点严禁在平台正上方（会穿到平台底下）
const PLATFORM_XS: Array[float] = [360.0, 435.0, 515.0, 1150.0, 1225.0, 1300.0, 1240.0]

var _spiders: Array = []
var _rng := RandomNumberGenerator.new()
var _check_accum: float = 0.0

func _ready() -> void:
	add_to_group("camera_follow")
	_rng.randomize()

func _process(delta: float) -> void:
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
