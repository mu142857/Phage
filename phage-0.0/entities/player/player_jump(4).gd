# res://entities/player/player_jump(4).gd
extends BasicState

var jump_hold_elapsed: float = 0.0

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	jump_hold_elapsed = 0.0
	player.velocity.y = player.JUMP_SPEED
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Jump")

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	var move_input := Input.get_axis(&"move_left", &"move_right")
	player.velocity.x = move_input * player.RUN_SPEED

	if move_input > 0.0:
		player.set_facing_direction(1)
	elif move_input < 0.0:
		player.set_facing_direction(-1)

	if Input.is_action_pressed(&"jump") and jump_hold_elapsed < player.MAX_JUMP_HOLD_TIME and player.velocity.y < 0.0:
		jump_hold_elapsed += delta
		player.velocity.y += player.GRAVITY * player.JUMP_HOLD_GRAVITY_MULTIPLIER * delta
	else:
		player.velocity.y += player.GRAVITY * delta

	if player.velocity.y >= 0.0:
		change_state(player.STATE_FALL)
		return

	player.move_and_slide()
