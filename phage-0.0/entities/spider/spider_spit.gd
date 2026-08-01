#SpiderSpit 蜘蛛毒球：抛物线飞行，碰到玩家或地形(1层)才消失，落点释放特效；绘制取整到像素格
extends Area2D

@export var damage_amount: int = 6
@export var projectile_gravity: float = 300.0
@export var flight_time: float = 0.9
@export var max_lifetime: float = 6.0
@export var size_px: int = 2
@export var core_color: Color = Color(0.94902, 0.403922, 0.164706)
@export var rim_color: Color = Color(0.207843, 0.788235, 0.552941)

const IMPACT_EFFECT_SCENE: PackedScene = preload("res://entities/spider/spider_spit_effect.tscn")

var velocity: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var active: bool = false

func setup(start_pos: Vector2, target_pos: Vector2, time_override: float = -1.0) -> void:
	global_position = start_pos
	if time_override > 0.0:
		flight_time = time_override
	var t: float = maxf(flight_time, 0.01)
	velocity.x = (target_pos.x - start_pos.x) / t
	velocity.y = (target_pos.y - start_pos.y - 0.5 * projectile_gravity * t * t) / t
	elapsed = 0.0
	active = true

func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	velocity.y += projectile_gravity * delta
	global_position += velocity * delta
	queue_redraw()
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.call("take_damage", damage_amount)
			_explode()
			return
		# 非玩家(mask 里只剩 1 层地形) -> 落地
		_explode()
		return
	# 保险丝：太久没落地(飞出地图)就静默消失
	if elapsed >= max_lifetime:
		queue_free()

func _draw() -> void:
	var s: float = float(size_px)
	var cell: Vector2 = Vector2(floorf(global_position.x), floorf(global_position.y)) - global_position
	draw_rect(Rect2(cell - Vector2(s, s) * 0.5, Vector2(s, s) + Vector2(2.0, 2.0)), rim_color)
	draw_rect(Rect2(cell - Vector2(s, s) * 0.5 + Vector2(1.0, 1.0), Vector2(s, s)), core_color)

func _explode() -> void:
	active = false
	if IMPACT_EFFECT_SCENE != null and get_tree().current_scene != null:
		var effect := IMPACT_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(effect)
		if effect is Node2D:
			(effect as Node2D).global_position = global_position
		if effect is GPUParticles2D:
			(effect as GPUParticles2D).emitting = true
	queue_free()
