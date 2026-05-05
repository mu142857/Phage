# res://entities/player/player_idle(1).gd
extends BasicState

@onready var idle_timer: Timer = $Timer

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player.set_walking_effect(false)
	if is_instance_valid(idle_timer):
		idle_timer.stop()
		idle_timer.wait_time = player.IDLE_TO_CONTRACT_TIME
		idle_timer.start()
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Idle")

func exit() -> void:
	if is_instance_valid(idle_timer):
		idle_timer.stop()

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	if not player.is_on_floor():
		change_state(player.STATE_FALL)
		return

	if Input.is_action_just_pressed(&"Attack1"):
		change_state(player.STATE_ATTACK_1)
		return

	if Input.is_action_just_pressed(&"sprint") and player.can_sprint:
		change_state(player.STATE_SPRINT)
		return

	if Input.is_action_just_pressed(&"jump"):
		change_state(player.STATE_JUMP)
		return

	var horizontal := Input.get_axis(&"move_left", &"move_right")
	if abs(horizontal) > 0.0:
		change_state(player.STATE_RUN)
		return

	player.velocity.x = move_toward(player.velocity.x, 0.0, player.RUN_SPEED * 8.0 * delta)
	player.velocity.y += player.GRAVITY * delta
	player.move_and_slide()


func _on_timer_timeout() -> void:
	var player := host as Player
	if player == null:
		return
	if not player.is_on_floor():
		return
	change_state(player.STATE_CONTRACT)
