extends BasicState

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player.set_walking_effect(false)
	player.set_ball_form(true)
	player.velocity = Vector2.ZERO
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Ball")

func process(_delta: float) -> void:
	var player := host as Player
	if player == null:
		return
	player.velocity = Vector2.ZERO
	if Input.is_anything_pressed():
		change_state(player.STATE_UNCONTRACT)
