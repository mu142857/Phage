# res://entities/player/player_jump(4).gd
extends BasicState

var jump_hold_elapsed: float = 0.0
var apex_hang_elapsed: float = 0.0

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	jump_hold_elapsed = 0.0
	apex_hang_elapsed = 0.0
	player.coyote_timer = 0.0
	player.set_walking_effect(true)
	player.velocity.y = player.JUMP_SPEED
	player.reached_terminal = false
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

	if Input.is_action_just_pressed(&"Attack1"):
		change_state(player.STATE_ATTACK_1)
		return

	if Input.is_action_just_pressed(&"sprint") and player.can_sprint:
		change_state(player.STATE_SPRINT)
		return

	var gravity_multiplier := 1.0
	if Input.is_action_pressed(&"jump") and jump_hold_elapsed < player.MAX_JUMP_HOLD_TIME and player.velocity.y < 0.0:
		jump_hold_elapsed += delta
		gravity_multiplier = player.JUMP_HOLD_GRAVITY_MULTIPLIER

	if player.velocity.y < 0.0 and absf(player.velocity.y) <= player.JUMP_APEX_VELOCITY_THRESHOLD and apex_hang_elapsed < player.MAX_JUMP_APEX_HANG_TIME:
		apex_hang_elapsed += delta
		gravity_multiplier = minf(gravity_multiplier, player.JUMP_APEX_GRAVITY_MULTIPLIER)

	player.apply_gravity(delta, gravity_multiplier)

	if player.velocity.y >= 0.0:
		change_state(player.STATE_FALL)
		return

	player.move_and_slide()
