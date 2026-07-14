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
	player.set_jump_trail(true)
	player.velocity.y = player.JUMP_SPEED
	player.reached_terminal = false
	# 起跳瞬间就给速度(手感不变),动画先播一次性的 StartJump,
	# 播完后由 _on_animated_sprite_2d_animation_finished 切到循环的 Jump。
	player.play_anim(&"StartJump")

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


func _on_animated_sprite_2d_animation_finished() -> void:
	var player := host as Player
	if player == null or not is_instance_valid(player.sprite):
		return
	# StartJump 播完后,若还在上升(仍处于跳跃状态),切到循环 Jump。
	# 若已到顶点转入 Fall,此时动画已是 Fall,下面的判断会自然跳过。
	if player._strip_shield(player.sprite.animation) != &"StartJump":
		return
	if player.velocity.y < 0.0:
		player.play_anim(&"Jump")
