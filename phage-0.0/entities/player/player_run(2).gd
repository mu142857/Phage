# res://entities/player/player_run(2).gd
extends BasicState

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player.set_walking_effect(true)
	player.set_jump_trail(false)
	if is_instance_valid(player.sprite):
		player.play_anim(&"Run")

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	if not player.is_on_floor():
		player.coyote_timer = player.COYOTE_TIME
		change_state(player.STATE_FALL)
		return

	if Input.is_action_just_pressed(&"Attack1"):
		change_state(player.STATE_ATTACK_1)
		return

	if Input.is_action_just_pressed(&"sprint") and player.can_sprint and not player.web_snared:
		change_state(player.STATE_SPRINT)
		return

	if (Input.is_action_just_pressed(&"jump") or player.jump_buffer_timer > 0.0) and not player.web_snared:
		player.jump_buffer_timer = 0.0
		change_state(player.STATE_JUMP)
		return

	var move_input := Input.get_axis(&"move_left", &"move_right")
	if abs(move_input) <= 0.0:
		change_state(player.STATE_IDLE)
		return

	player.velocity.x = move_input * player.run_speed()
	player.apply_gravity(delta)

	if move_input > 0.0:
		player.set_facing_direction(1)
	elif move_input < 0.0:
		player.set_facing_direction(-1)

	player.move_and_slide()
