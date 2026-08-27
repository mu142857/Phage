# 红丝虫激光(通用一根)。分两步由外部指挥：
#   show_aim()  摆好预警细线：渐显后呼吸脉动，一直亮着等命令；
#   fire()      真正发射：主束砸出(过曝颜色吃泛光+白热芯+方形粒子+震屏/闪屏)
#               → 快速收拢(不许凭空消失) → 粒子飘完自删。
#   cancel()    没开火就要撤(状态被打断时)：预警线淡出自删。
# 「预警线慢慢织成网、开火密集连发」的节奏在钻地状态里控制。
# 横竖斜任意方向都行(判定箱和粒子盒跟着束的角度转)；表演束不带伤害，
# 威胁束整根 3px 宽判定、命中一次就停。参考《骑士山城》栗子劫念，
# 斜线在 160×90 原生分辨率下自带大颗粒锯齿，正合巨像素风。
extends Node2D

@export var damage: int = 6
@export var beam_hold: float = 0.18     # 主束全宽维持时长
@export var beam_width: float = 3.0
@export var core_width: float = 1.0
@export var retract_time: float = 0.1   # 收束时长(渐窄收拢，不硬删)

var _vec := Vector2.RIGHT
var _deals_damage: bool = false
var _damage_done: bool = false
var _firing: bool = false
var _fired: bool = false
var _fire_shake: float = 0.0
var _fire_flash: float = 0.0
var _pulse: Tween = null

@onready var aim_line: Line2D = $AimLine
@onready var beam: Line2D = $Beam
@onready var core: Line2D = $Core
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var beam_particles: GPUParticles2D = $BeamParticles
@onready var impact_particles: GPUParticles2D = $ImpactParticles


func _ready() -> void:
	set_physics_process(false)


# 摆出预警线。from/to 用世界坐标；亮起后就一直呼吸脉动，等 fire()/cancel()
func show_aim(from: Vector2, to: Vector2, deals_damage: bool,
		shake: float, flash_amount: float) -> void:
	global_position = from
	_vec = to - from
	_deals_damage = deals_damage
	_fire_shake = shake
	_fire_flash = flash_amount

	var pts := PackedVector2Array([Vector2.ZERO, _vec])
	aim_line.points = pts
	beam.points = pts
	core.points = pts
	_setup_hit_shape()
	_setup_particles()

	aim_line.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(aim_line, "modulate:a", 0.7, 0.45)
	fade.finished.connect(_start_pulse)


func _start_pulse() -> void:
	if _fired or not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(aim_line, "modulate:a", 0.35, 0.5)
	_pulse.tween_property(aim_line, "modulate:a", 0.85, 0.5)


# 开火：整根光的后半生自己演完自己删，外部一根根快速点名即可
func fire() -> void:
	if _fired:
		return
	_fired = true
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	aim_line.visible = false
	Game.shake_camera(_fire_shake)
	if _fire_flash > 0.0:
		Game.flash(_fire_flash, Color(1.5, 0.45, 0.45, 0.4))
	_firing = true
	_damage_done = false
	if _deals_damage:
		hit_area.set_deferred("monitoring", true)
		set_physics_process(true)
	beam_particles.emitting = true
	if _deals_damage:
		impact_particles.emitting = true
	var open := create_tween().set_parallel(true)
	open.tween_property(beam, "width", beam_width, 0.04)
	open.tween_property(core, "width", core_width, 0.04)
	await open.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(beam_hold).timeout
	if not is_inside_tree():
		return

	# 收束：渐窄收拢，粒子停发后飘完再删(不凭空消失)
	_firing = false
	set_physics_process(false)
	hit_area.set_deferred("monitoring", false)
	beam_particles.emitting = false
	var close := create_tween().set_parallel(true)
	close.tween_property(beam, "width", 0.0, retract_time)
	close.tween_property(core, "width", 0.0, retract_time)
	await close.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.6).timeout
	queue_free()


# 没轮到开火就被打断：预警线淡出走人，别悬在场上
func cancel() -> void:
	if _fired:
		return
	_fired = true
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	var tw := create_tween()
	tw.tween_property(aim_line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _physics_process(_delta: float) -> void:
	if not _firing or not _deals_damage or _damage_done:
		return
	for body in hit_area.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_damage_done = true
			return


# 判定箱铺满整根(束宽)，跟着束的角度转——斜束也能用。
# RectangleShape2D 现场 new，避免多根激光共享同一份资源
func _setup_hit_shape() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(_vec.length(), beam_width), beam_width)
	hit_shape.shape = rect
	hit_shape.position = _vec * 0.5
	hit_shape.rotation = _vec.angle()
	hit_area.monitoring = false


func _setup_particles() -> void:
	# 沿束漂浮的小方粒：发射盒拉成整根束的长度、转到束的角度
	# (材质复制一份再改，防实例间串)
	var mat := beam_particles.process_material as ParticleProcessMaterial
	if mat != null:
		mat = mat.duplicate() as ParticleProcessMaterial
		mat.emission_box_extents = Vector3(maxf(_vec.length() * 0.5, 1.0), 1.0, 1.0)
		beam_particles.process_material = mat
	beam_particles.position = _vec * 0.5
	beam_particles.rotation = _vec.angle()
	# 远端命中火花(帘幕激光=打在地面上)
	impact_particles.position = _vec
