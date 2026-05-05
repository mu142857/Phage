extends BasicState

const ATTACK_BURST_SPEED: float = 180.0
const ATTACK_BRAKE_ACCEL: float = 800.0
const ATTACK1_1_DAMAGE: int = 100
const ATTACK1_2_DAMAGE: int = 30
const ATTACK1_1_TRIGGER_FRAME: int = 2
const ATTACK1_2_TRIGGER_FRAME: int = 2
const ATTACK1_1_TRIGGER_TIME: float = 2.0 / 12.0
const ATTACK1_2_TRIGGER_TIME: float = 2.0 / 12.0
const COMBO_QUEUE_OPEN_TIME: float = 2.0 / 12.0

const ANIM_ATTACK1_1: StringName = &"Attack1_1"
const ANIM_ATTACK1_2: StringName = &"Attack1_2"
const ANIM_ATTACK_LEGACY: StringName = &"Attack1"

@onready var attack_hitbox_1: Area2D = $"../../HitBox/Attack1_1"
@onready var attack_hitbox_2: Area2D = $"../../HitBox/Attack1_2"

var phase_1_done: bool = false
var phase_2_done: bool = false
var attack_elapsed: float = 0.0
var attack_locked_facing: int = 1
var phase_2_requested: bool = false
var current_phase: int = 1

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	phase_1_done = false
	phase_2_done = false
	attack_elapsed = 0.0
	phase_2_requested = false
	current_phase = 1
	attack_locked_facing = player.facing_direction
	if attack_locked_facing == 0:
		attack_locked_facing = 1
	player.set_facing_direction(attack_locked_facing)
	player.set_walking_effect(false)
	player.clear_attack_hitboxes()
	_apply_attack_surge(player)
	_play_attack_animation(player, ANIM_ATTACK1_1, ANIM_ATTACK_LEGACY)

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	# Ignore horizontal move input during attack: do a forward lunge then decay.
	player.velocity.x = move_toward(player.velocity.x, 0.0, ATTACK_BRAKE_ACCEL * delta)
	player.set_facing_direction(attack_locked_facing)

	if not player.is_on_floor():
		player.velocity.y += player.GRAVITY * delta
	elif player.velocity.y > 0.0:
		player.velocity.y = 0.0
	player.move_and_slide()
	attack_elapsed += delta

	# Queue phase 2 only in phase 1 and after combo window opens.
	if current_phase == 1 and phase_1_done and not phase_2_done and attack_elapsed >= COMBO_QUEUE_OPEN_TIME:
		if Input.is_action_pressed(&"Attack1") or Input.is_action_just_pressed(&"Attack1"):
			phase_2_requested = true

	_try_auto_attack_phases(player)

func attack1_1_check() -> void:
	if phase_1_done:
		return
	phase_1_done = true
	_check_attack_hitbox(attack_hitbox_1, ATTACK1_1_DAMAGE)

func attack1_2_check() -> void:
	if not phase_2_requested:
		return
	if phase_2_done:
		return
	phase_2_done = true
	_check_attack_hitbox(attack_hitbox_2, ATTACK1_2_DAMAGE)

func _try_auto_attack_phases(player: Player) -> void:
	if not is_instance_valid(player.sprite):
		return
	var anim := player.sprite.animation

	if anim == ANIM_ATTACK1_1 or (anim == ANIM_ATTACK_LEGACY and current_phase == 1):
		var phase_1_frame := player.sprite.frame
		if phase_1_frame >= ATTACK1_1_TRIGGER_FRAME or attack_elapsed >= ATTACK1_1_TRIGGER_TIME:
			attack1_1_check()
		return

	if anim == ANIM_ATTACK1_2 or (anim == ANIM_ATTACK_LEGACY and current_phase == 2):
		var phase_2_frame := player.sprite.frame
		if phase_2_frame >= ATTACK1_2_TRIGGER_FRAME or attack_elapsed >= ATTACK1_2_TRIGGER_TIME:
			attack1_2_check()
		return

func _play_attack_animation(player: Player, primary: StringName, fallback: StringName = &"") -> void:
	if not is_instance_valid(player.sprite):
		return
	var frames := player.sprite.sprite_frames
	if frames != null and frames.has_animation(primary):
		player.sprite.play(primary)
		return
	if fallback != &"" and frames != null and frames.has_animation(fallback):
		player.sprite.play(fallback)

func _apply_attack_surge(player: Player) -> void:
	player.velocity.x = float(attack_locked_facing) * ATTACK_BURST_SPEED

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

	var anim := player.sprite.animation
	if anim == ANIM_ATTACK1_1 or (anim == ANIM_ATTACK_LEGACY and current_phase == 1):
		attack1_1_check()
		if phase_2_requested:
			current_phase = 2
			attack_elapsed = 0.0
			player.clear_attack_hitboxes()
			_apply_attack_surge(player)
			_play_attack_animation(player, ANIM_ATTACK1_2, ANIM_ATTACK_LEGACY)
			return
		player.finish_attack()
		return

	if anim == ANIM_ATTACK1_2 or (anim == ANIM_ATTACK_LEGACY and current_phase == 2):
		attack1_2_check()
		player.finish_attack()

func exit() -> void:
	var player := host as Player
	if player == null:
		return
	player.clear_attack_hitboxes()
