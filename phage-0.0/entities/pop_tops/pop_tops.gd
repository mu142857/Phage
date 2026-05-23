extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/pop_tops/pop_tops_death.tscn")

@export var max_health: int = 400
@export var health: int = 400
@export var attack_distance: float = 70.0
@export var spin_distance: float = 25.0

func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.material != null:
		sprite.material = sprite.material.duplicate()
	if sprite != null and sprite.material is ShaderMaterial:
		var shader_mat := sprite.material as ShaderMaterial
		shader_mat.set_shader_parameter("Enabled", false)

func take_damage(value: int) -> void:
	health -= value
	health = clampi(health, 0, max_health)
	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")
	if health <= 0:
		_spawn_death_effect()
		queue_free()

func get_next_attack_state() -> int:
	if _is_player_close(spin_distance):
		return 3
	if _is_player_close(attack_distance):
		return 2
	return 1

func is_player_close(distance_limit: float) -> bool:
	return _is_player_close(distance_limit)

func _is_player_close(distance_limit: float) -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var player := players[0]
	if not (player is Node2D):
		return false
	return absf((player as Node2D).global_position.x - global_position.x) <= distance_limit

func _spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null:
		return
	if get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true
