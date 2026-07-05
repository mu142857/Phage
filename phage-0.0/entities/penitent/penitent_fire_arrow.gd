# =============================================================================
# penitent_fire_arrow.gd  —  天降长矛（旧「火矢.gd」重置版）
# =============================================================================
# Ready(悬在高处淡入·预警) → Loop(加速下落) → 落地 End(淡出)。
# 下落途中碰到玩家 → 伤害并消失。落地(进 End 动画前)放粒子，和中镰刀共用 MidSickleEffect。
# 由 penitent.gd 在玩家成功攻击 boss 时成批生成。
# =============================================================================
extends Area2D

const LAND_EFFECT: PackedScene = preload("res://entities/penitent/mid_sickle_effect.tscn")

@export var land_y: float = 80.0
@export var fall_speed: float = 40.0     # 起始下落速度 px/s
@export var fall_accel: float = 180.0    # 下落加速度 px/s²
@export var fade_in_speed: float = 1.6   # 预警阶段淡入速度
@export var fade_out_speed: float = 3.0  # 落地淡出速度
@export var damage: int = 8
@export var shake_amount: float = 2.0

var _speed: float = 0.0
var _landed: bool = false


func _ready() -> void:
	z_index = 1
	collision_mask = 2
	modulate.a = 0.0
	_speed = fall_speed
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	$AnimatedSprite2D.play(&"Ready")


func _physics_process(delta: float) -> void:
	match $AnimatedSprite2D.animation:
		&"Ready":
			modulate.a = minf(modulate.a + fade_in_speed * delta, 1.0)
		&"Loop":
			modulate.a = 1.0
			global_position.y += _speed * delta
			_speed += fall_accel * delta
			if global_position.y >= land_y:
				global_position.y = land_y
				_impact()
		&"End":
			modulate.a = maxf(modulate.a - fade_out_speed * delta, 0.0)


func _impact() -> void:
	if _landed:
		return
	_landed = true
	Game.shake_camera(shake_amount)
	Game.flash(0.12, Color(1.5, 0.4, 0.4, 0.4))
	spawn_land_effect(LAND_EFFECT)   # 落地(进 End 动画前)放粒子
	$AnimatedSprite2D.play(&"End")


func spawn_land_effect(scene: PackedScene) -> void:
	if scene == null or get_tree().current_scene == null:
		return
	var fx := scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx is Node2D:
		(fx as Node2D).global_position = global_position
	if fx is GPUParticles2D:
		(fx as GPUParticles2D).emitting = true


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"Ready":
		$AnimatedSprite2D.play(&"Loop")   # 预警结束，开始下落
	elif $AnimatedSprite2D.animation == &"End":
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _landed or $AnimatedSprite2D.animation != &"Loop":
		return
	if body != null and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_impact()   # 命中也放落地特效再消失
