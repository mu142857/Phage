# =============================================================================
# eye_laser.gd  —  激光眼的横向光束(纯程序，无贴图)
# =============================================================================
# 铁律：禁斜线，所以光束永远水平；「扫」= 整根往下平移。
#   show_aim(origin, dir, length)  预警细线渐显 + 呼吸
#   fire(shake, flash)             主束砸出(过曝色+白芯) 开判定
#   sweep_to(y, time)              整根往下压到 y
#   retract()                      收束自删(不许凭空消失)
#   cancel()                       中断：预警线/光束淡出自删
# 判定：开火期间每物理帧查重叠的玩家调 take_damage，重复命中靠玩家自己的无敌帧挡。
# =============================================================================
extends Node2D

@export var damage: int = 10
@export var beam_width: float = 3.0
@export var core_width: float = 1.0
@export var retract_time: float = 0.12

var _length: float = 160.0
var _dir: int = 1
var _firing: bool = false
var _done: bool = false
var _pulse: Tween = null

@onready var aim_line: Line2D = $AimLine
@onready var beam: Line2D = $Beam
@onready var core: Line2D = $Core
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D


func _ready() -> void:
	z_index = 12
	add_to_group("puppeteer_spawn")
	set_physics_process(false)
	beam.visible = false
	core.visible = false
	hit_area.monitoring = false


func show_aim(origin: Vector2, dir: int, length: float) -> void:
	global_position = origin
	_dir = 1 if dir >= 0 else -1
	_length = length
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(_length * float(_dir), 0.0)])
	aim_line.points = pts
	beam.points = pts
	core.points = pts
	beam.width = beam_width
	core.width = core_width
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_length, beam_width)
	hit_shape.shape = rect
	hit_shape.position = Vector2(_length * 0.5 * float(_dir), 0.0)
	aim_line.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(aim_line, "modulate:a", 0.7, 0.3)
	fade.finished.connect(_start_pulse)


func _start_pulse() -> void:
	if _firing or _done or not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(aim_line, "modulate:a", 0.35, 0.25)
	_pulse.tween_property(aim_line, "modulate:a", 0.85, 0.25)


func fire(shake: float = 2.0, flash_amount: float = 0.1) -> void:
	if _firing or _done:
		return
	_firing = true
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	aim_line.visible = false
	beam.visible = true
	core.visible = true
	hit_area.monitoring = true
	set_physics_process(true)
	Game.shake_camera(shake)
	if flash_amount > 0.0:
		Game.flash(flash_amount, Color(0.6, 0.9, 1.5, 0.5))


func sweep_to(y: float, time: float) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:y", y, time)


func retract() -> void:
	if _done:
		return
	_done = true
	hit_area.monitoring = false
	set_physics_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(beam, "width", 0.0, retract_time)
	tw.tween_property(core, "width", 0.0, retract_time)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


func cancel() -> void:
	if _done:
		return
	_done = true
	hit_area.monitoring = false
	set_physics_process(false)
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _physics_process(_delta: float) -> void:
	if not _firing or _done:
		return
	for body in hit_area.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
