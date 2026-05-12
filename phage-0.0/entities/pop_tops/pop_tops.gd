extends CharacterBody2D

@export var max_health: int = 400
@export var health: int = 400
@export var spin_distance: float = 10.0

func take_damage(value: int) -> void:
	health -= value
	health = clampi(health, 0, max_health)
	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")
	if health <= 0:
		queue_free()

func get_next_attack_state() -> int:
	if _is_player_close(spin_distance):
		return 3
	return 2

func _is_player_close(distance_limit: float) -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var player := players[0]
	if not (player is Node2D):
		return false
	return (player as Node2D).global_position.distance_to(global_position) <= distance_limit
