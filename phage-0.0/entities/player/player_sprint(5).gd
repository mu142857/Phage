# res://entities/player/player_sprint(5).gd
extends BasicState

@onready var cooldown_timer: Timer = $Timer

var dash_direction: int = 1

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	var move_input := Input.get_axis(&"move_left", &"move_right")
	if abs(move_input) > 0.0:
		dash_direction = signi(move_input)
	else:
		dash_direction = player.facing_direction
	if dash_direction == 0:
		dash_direction = 1
	player.can_sprint = false
	player.set_walking_effect(true)
	player.set_facing_direction(dash_direction)
	player.velocity.y = 0.0
	player.velocity.x = float(dash_direction) * player.SPRINT_SPEED
	if is_instance_valid(cooldown_timer):
		cooldown_timer.stop()
		cooldown_timer.wait_time = player.SPRINT_COOLDOWN
		cooldown_timer.start()
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Sprint")

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	player.velocity.x = float(dash_direction) * player.SPRINT_SPEED
	player.velocity.y = 0.0

	player.move_and_slide()

func _on_animated_sprite_2d_animation_finished() -> void:
	var player := host as Player
	if player == null:
		return
	if not is_instance_valid(player.sprite):
		return
	if player.sprite.animation != &"Sprint":
		return

	var move_input := Input.get_axis(&"move_left", &"move_right")
	if player.is_on_floor():
		if abs(move_input) > 0.0:
			change_state(player.STATE_RUN)
		else:
			change_state(player.STATE_IDLE)
	else:
		change_state(player.STATE_FALL)


func _on_timer_timeout() -> void:
	var player := host as Player
	if player == null:
		return
	player.can_sprint = true
