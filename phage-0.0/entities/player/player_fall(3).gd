# res://entities/player/player_fall(3).gd
extends BasicState

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player.set_walking_effect(true)
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Fall")

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	player.coyote_timer = maxf(player.coyote_timer - delta, 0.0)
	player.jump_buffer_timer = maxf(player.jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_pressed(&"jump"):
		if player.coyote_timer > 0.0:
			player.coyote_timer = 0.0
			player.jump_buffer_timer = 0.0
			change_state(player.STATE_JUMP)
			return
		player.jump_buffer_timer = player.JUMP_BUFFER_TIME

	var move_input := Input.get_axis(&"move_left", &"move_right")
	player.velocity.x = move_input * player.RUN_SPEED
	player.apply_gravity(delta, player.FALL_GRAVITY_MULTIPLIER)

	if move_input > 0.0:
		player.set_facing_direction(1)
	elif move_input < 0.0:
		player.set_facing_direction(-1)

	if Input.is_action_just_pressed(&"Attack1"):
		change_state(player.STATE_ATTACK_1)
		return

	if Input.is_action_just_pressed(&"sprint") and player.can_sprint:
		change_state(player.STATE_SPRINT)
		return

	player.move_and_slide()

	if player.is_on_floor():
		var impact_speed := player.velocity.y
		player.velocity.y = 0.0
		if player.reached_terminal or impact_speed >= player.MAX_FALL_SPEED:
			Game.shake_camera(2)
		player.reached_terminal = false
		player.spawn_landing_effect()

		if player.jump_buffer_timer > 0.0:
			player.jump_buffer_timer = 0.0
			change_state(player.STATE_JUMP)
			return

		if abs(move_input) > 0.0:
			change_state(player.STATE_RUN)
		else:
			change_state(player.STATE_IDLE)
