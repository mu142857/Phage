extends CharacterBody2D

signal died

@export var max_health: int = 400
@export var health: int = 400
@export var attack_distance: float = 100.0
@export var spin_distance: float = 20.0

func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)

func take_damage(value: int) -> void:
	health -= value
	health = clampi(health, 0, max_health)
	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")
	if health <= 0:
		died.emit()
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
