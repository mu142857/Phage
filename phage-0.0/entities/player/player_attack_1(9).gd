extends BasicState

const ATTACK_MOVE_MULTIPLIER: float = 0.75
const ATTACK1_1_DAMAGE: int = 100
const ATTACK1_2_DAMAGE: int = 30

@onready var attack_hitbox_1: Area2D = $"../../HitBox/Attack1_1"
@onready var attack_hitbox_2: Area2D = $"../../HitBox/Attack1_2"

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player.set_walking_effect(false)
	player.clear_attack_hitboxes()
	if is_instance_valid(player.sprite):
		player.sprite.play(&"Attack1")

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	var move_input := Input.get_axis(&"move_left", &"move_right")
	player.velocity.x = move_input * player.RUN_SPEED * ATTACK_MOVE_MULTIPLIER

	if move_input > 0.0:
		player.set_facing_direction(1)
	elif move_input < 0.0:
		player.set_facing_direction(-1)

	if not player.is_on_floor():
		player.velocity.y += player.GRAVITY * delta
	elif player.velocity.y > 0.0:
		player.velocity.y = 0.0
	player.move_and_slide()

func attack1_1_check() -> void:
	_check_attack_hitbox(attack_hitbox_1, ATTACK1_1_DAMAGE)

func attack1_2_check() -> void:
	_check_attack_hitbox(attack_hitbox_2, ATTACK1_2_DAMAGE)

func _check_attack_hitbox(hitbox: Area2D, damage: int) -> void:
	if not is_instance_valid(hitbox):
		return

	for body in hitbox.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("monster"):
			continue
		if body.has_method("take_hit"):
			body.call("take_hit", damage)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)

func _on_animated_sprite_2d_animation_finished() -> void:
	var player := host as Player
	if player == null:
		return
	if not is_instance_valid(player.sprite):
		return
	if player.sprite.animation != &"Attack1":
		return
	player.finish_attack()

func exit() -> void:
	var player := host as Player
	if player == null:
		return
	player.clear_attack_hitboxes()
