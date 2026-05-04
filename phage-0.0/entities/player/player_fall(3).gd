# res://entities/player/player_fall(3).gd
extends BasicState

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Fall")

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	var move_input := Input.get_axis(&"move_left", &"move_right")
	player.velocity.x = move_input * player.RUN_SPEED
	player.velocity.y += player.GRAVITY * delta

	if move_input > 0.0:
		player.set_facing_direction(1)
	elif move_input < 0.0:
		player.set_facing_direction(-1)

	player.move_and_slide()

	if player.is_on_floor():
		if abs(move_input) > 0.0:
			change_state(player.STATE_RUN)
		else:
			change_state(player.STATE_IDLE)
