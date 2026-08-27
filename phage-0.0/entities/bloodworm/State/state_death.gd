# 红丝虫 死亡状态(2 号)：关掉一切碰撞/交互 → 藏血条 → 挣扎+死亡动画 → 爆体粒子。
extends BasicState

@export var pre_death_duration: float = 0.9
@export var death_duration: float = 1.1
@export var death_shake_light: float = 2.0
@export var death_shake_heavy: float = 6.0

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/bloodworm/bloodworm_death.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false


func enter() -> void:
	is_active = true
	if not is_instance_valid(monster):
		return
	monster.velocity = Vector2.ZERO
	monster.set_physics_process(false)
	_disable_all_interactions()
	_play_sequence()


func process(_delta: float) -> void:
	pass


func exit() -> void:
	is_active = false


func _play_sequence() -> void:
	if is_instance_valid(monster) and monster.has_method("hide_health_ui"):
		monster.hide_health_ui()

	if not is_instance_valid(ani_2d):
		_free_boss()
		return

	# --- 死前挣扎段 ---
	if ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(&"Battlecry"):
		ani_2d.play(&"Battlecry")
		await get_tree().create_timer(pre_death_duration).timeout
		if not is_active or not is_instance_valid(ani_2d):
			return

	# --- Death 动画段 ---
	if ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(&"Death"):
		ani_2d.play(&"Death")
	Game.shake_camera(death_shake_light)
	await get_tree().create_timer(death_duration).timeout
	if not is_active:
		return

	# --- 爆体：粒子 + 重震 + 删除 ---
	if DEATH_EFFECT_SCENE != null and is_instance_valid(monster):
		var eff := DEATH_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		eff.global_position = monster.global_position
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true
	Game.shake_camera(death_shake_heavy)
	_free_boss()


func _disable_all_interactions() -> void:
	if is_instance_valid(monster):
		monster.collision_layer = 0
		monster.collision_mask = 0
	_disable_shape("../../CollisionShape2D")
	_disable_area("../../PlayerCheck")
	_disable_area("../../EmergeHitBox")
	_disable_area("../../LungeHitBox")
	_disable_area("../../DiveHitBox")
	var dive_sprite := get_node_or_null("../../DiveSprite") as AnimatedSprite2D
	if is_instance_valid(dive_sprite):
		dive_sprite.visible = false


func _disable_shape(path: String) -> void:
	var shape := get_node_or_null(path) as CollisionShape2D
	if is_instance_valid(shape):
		shape.disabled = true


func _disable_area(path: String) -> void:
	var area := get_node_or_null(path) as Area2D
	if is_instance_valid(area):
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0


func _free_boss() -> void:
	if is_instance_valid(monster):
		monster.queue_free()
