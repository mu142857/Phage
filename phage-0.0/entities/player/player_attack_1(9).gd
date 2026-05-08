extends BasicState

const ATTACK_BURST_SPEED: float = 180.0
const ATTACK_BRAKE_ACCEL: float = 800.0
const ATTACK_BURST_SPEED_AIR: float = 240.0
const ATTACK_BRAKE_ACCEL_AIR: float = 380.0
const ATTACK1_1_DAMAGE: int = 100
const ATTACK1_2_DAMAGE: int = 30
const ATTACK1_1_TRIGGER_FRAME: int = 1
const ATTACK1_2_TRIGGER_FRAME: int = 1
const ATTACK1_1_TRIGGER_TIME: float = 2.0 / 12.0
const ATTACK1_2_TRIGGER_TIME: float = 2.0 / 12.0
const COMBO_QUEUE_OPEN_TIME: float = 2.0 / 12.0
const HIT_RECOIL_SPEED: float = 110.0
const HIT_RECOIL_DURATION: float = 0.08
const HIT_RECOIL_INPUT_SCALE: float = 0.6
const LUNGE_SUPPRESS_DURATION: float = 0.12

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
var attack_glow_tween: Tween = null
var base_sprite_modulate: Color = Color(1, 1, 1, 1)
var player_ref: Player = null
var recoil_time_left: float = 0.0
var lunge_suppress_left: float = 0.0
var suppress_next_lunge: bool = false

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player_ref = player
	recoil_time_left = 0.0
	phase_1_done = false
	phase_2_done = false
	attack_elapsed = 0.0
	phase_2_requested = false
	current_phase = 1
	attack_locked_facing = player.facing_direction
	if attack_locked_facing == 0:
		attack_locked_facing = 1
	base_sprite_modulate = player.sprite.modulate if is_instance_valid(player.sprite) else Color(1, 1, 1, 1)
	player.set_facing_direction(attack_locked_facing)
	player.set_walking_effect(false)
	player.clear_attack_hitboxes()
	player.set_attack_hitbox(1, true)
	if suppress_next_lunge:
		suppress_next_lunge = false
	else:
		_apply_attack_surge(player)
	_play_attack_glow(player)
	_play_attack_animation(player, ANIM_ATTACK1_1, ANIM_ATTACK_LEGACY)

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	# Ignore horizontal move input during attack: do a forward lunge then decay.
	var brake_accel := ATTACK_BRAKE_ACCEL if player.is_on_floor() else ATTACK_BRAKE_ACCEL_AIR
	if recoil_time_left > 0.0:
		recoil_time_left = maxf(recoil_time_left - delta, 0.0)
		var move_input := Input.get_axis(&"move_left", &"move_right")
		var recoil_target := -float(attack_locked_facing) * HIT_RECOIL_SPEED
		var input_target := move_input * player.RUN_SPEED * HIT_RECOIL_INPUT_SCALE
		var target_x := recoil_target + input_target
		player.velocity.x = move_toward(player.velocity.x, target_x, brake_accel * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, brake_accel * delta)
	player.set_facing_direction(attack_locked_facing)

	if not player.is_on_floor():
		player.velocity.y += player.GRAVITY * delta
	elif player.velocity.y > 0.0:
		player.velocity.y = 0.0
	player.move_and_slide()
	attack_elapsed += delta
	if lunge_suppress_left > 0.0:
		lunge_suppress_left = maxf(lunge_suppress_left - delta, 0.0)

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
	var burst_speed := ATTACK_BURST_SPEED if player.is_on_floor() else ATTACK_BURST_SPEED_AIR
	player.velocity.x = float(attack_locked_facing) * burst_speed

func _play_attack_glow(player: Player) -> void:
	if not is_instance_valid(player.sprite):
		return
	if is_instance_valid(attack_glow_tween):
		attack_glow_tween.kill()
	attack_glow_tween = create_tween()
	attack_glow_tween.tween_property(player.sprite, "modulate", Color(1.6, 1.6, 1.6, base_sprite_modulate.a), 0.05)
	attack_glow_tween.tween_property(player.sprite, "modulate", base_sprite_modulate, 0.10)

func _check_attack_hitbox(hitbox: Area2D, damage: int) -> void:
	if not is_instance_valid(hitbox):
		return

	for body in hitbox.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("monster"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", damage)
			$"../..".spawn_hit_effect(body.global_position.x)
			Game.flash(0.1, Color(0.815, 0.908, 0.915, 1.0))
			Game.shake_camera(2)
		_apply_hit_recoil()
		break

func _apply_hit_recoil() -> void:
	if player_ref == null:
		return
	# Push player slightly backward to counter the lunge
	player_ref.velocity.x = -float(attack_locked_facing) * HIT_RECOIL_SPEED
	recoil_time_left = HIT_RECOIL_DURATION
	lunge_suppress_left = LUNGE_SUPPRESS_DURATION
	suppress_next_lunge = true

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
			player.set_attack_hitbox(2, true)
			if suppress_next_lunge:
				suppress_next_lunge = false
			else:
				_apply_attack_surge(player)
			_play_attack_glow(player)
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
	if is_instance_valid(attack_glow_tween):
		attack_glow_tween.kill()
		attack_glow_tween = null
	if is_instance_valid(player.sprite):
		player.sprite.modulate = base_sprite_modulate
	player.clear_attack_hitboxes()
	player_ref = null
	recoil_time_left = 0.0
