extends BasicState

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player.set_walking_effect(false)
	player.velocity = Vector2.ZERO
	if is_instance_valid(player.sprite):
		player.play_anim(&"Uncontract")

func process(_delta: float) -> void:
	var player := host as Player
	if player == null:
		return
	player.velocity = Vector2.ZERO

func _on_animated_sprite_2d_animation_finished() -> void:
	var player := host as Player
	if player == null:
		return
	if not is_instance_valid(player.sprite):
		return
	if player._strip_shield(player.sprite.animation) != &"Uncontract":
		return
	player.exit_ball_form()
	change_state(player.STATE_IDLE)
