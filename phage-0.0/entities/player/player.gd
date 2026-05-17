# res://entities/player/player.gd
class_name Player
extends CharacterBody2D

# ============================================================
# Constants - tweak here, applies to all states
# ============================================================
const GRAVITY: float = 1000.0
const MAX_HEALTH: int = 100
const IDLE_TO_CONTRACT_TIME: float = 3.0
const INVINCIBLE_DURATION: float = 0.3
const RUN_SPEED: float = 100.0
const SPRINT_SPEED: float = 220.0
const SPRINT_COOLDOWN: float = 0.75
const JUMP_SPEED: float = -200.0
const MAX_JUMP_HOLD_TIME: float = 0.14
const JUMP_HOLD_GRAVITY_MULTIPLIER: float = 0.35
const MAX_JUMP_APEX_HANG_TIME: float = 0.08
const JUMP_APEX_VELOCITY_THRESHOLD: float = 24.0
const JUMP_APEX_GRAVITY_MULTIPLIER: float = 0.18
const LANDING_EFFECT_SCENE: PackedScene = preload("res://entities/player/player_jumping_effect.tscn")
const HIT_EFFECT_SCENE: PackedScene = preload("res://entities/player/attack_effect.tscn")

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_RUN: int = 2
const STATE_FALL: int = 3
const STATE_JUMP: int = 4
const STATE_SPRINT: int = 5
const STATE_CONTRACT: int = 6
const STATE_BALL: int = 7
const STATE_UNCONTRACT: int = 8
const STATE_ATTACK_1: int = 9

# Maximum downward speed (terminal velocity). Normal jumps shouldn't hit this.
const MAX_FALL_SPEED: float = 600.0

# ============================================================
# State (read by states, written by player or specific states)
# ============================================================
var health: int = MAX_HEALTH
var facing_direction: int = 1  # 1 = right, -1 = left
var can_sprint: bool = true
var is_invincible: bool = false
var is_in_ball_form: bool = false  # true when contracted; modifies hitbox + buffs
var input_locked: bool = false

# ============================================================
# Node references
# ============================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_normal: CollisionShape2D = $CollisionNormal
@onready var collision_ball: CollisionShape2D = $CollisionBall
@onready var walking_effect: GPUParticles2D = $PlayerWalkingEffect
@onready var attack_hitbox_1: Area2D = $HitBox/Attack1_1
@onready var attack_hitbox_2: Area2D = $HitBox/Attack1_2
@onready var hitbox_root: Node2D = $HitBox
@onready var state_machine: StateManager = $StateMachine

# ============================================================
# Signals
# ============================================================
signal health_changed(new_health: int)
signal died

func _ready() -> void:
	add_to_group("player")
	set_ball_form(false)
	clear_attack_hitboxes()
	can_sprint = true

func change_state(state_id: int) -> void:
	state_machine.change_state(state_id)

func set_lock(locked: bool) -> void:
	input_locked = locked
	if locked:
		set_ball_form(false)
		change_state(STATE_IDLE)
		velocity = Vector2.ZERO
		clear_attack_hitboxes()
	if is_instance_valid(state_machine):
		state_machine.set_process(not locked)
		state_machine.set_physics_process(not locked)

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	var previous_health := health
	health = max(0, health - amount)
	health_changed.emit(health)
	if health < previous_health:
		Game.play_hit_feedback()
	# Trigger flash shader here later (no hurt state by design)
	_start_invincibility()
	if health <= 0:
		died.emit()
		# Death state transition: handled by whoever listens to `died`
		# or you can change_state(STATE_NULL) directly here

func _start_invincibility() -> void:
	is_invincible = true
	await get_tree().create_timer(INVINCIBLE_DURATION).timeout
	is_invincible = false

var reached_terminal: bool = false

func apply_gravity(delta: float, multiplier: float = 1.0) -> void:
	# Apply gravity and clamp to terminal velocity. Mark if terminal reached.
	velocity.y += GRAVITY * multiplier * delta
	if velocity.y > MAX_FALL_SPEED:
		velocity.y = MAX_FALL_SPEED
		reached_terminal = true

func set_ball_form(enabled: bool) -> void:
	is_in_ball_form = enabled
	collision_normal.disabled = enabled
	collision_ball.disabled = not enabled

func set_walking_effect(enabled: bool) -> void:
	if is_instance_valid(walking_effect):
		walking_effect.emitting = enabled

func spawn_landing_effect() -> void:
	if not is_inside_tree() or LANDING_EFFECT_SCENE == null:
		return
	var effect := LANDING_EFFECT_SCENE.instantiate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	if get_tree().current_scene == null:
		effect.queue_free()
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	await get_tree().create_timer(effect.lifetime).timeout
	if is_instance_valid(effect):
		effect.queue_free()

func spawn_hit_effect(posx: float) -> void:
	if not is_inside_tree() or HIT_EFFECT_SCENE == null:
		return
	var effect := HIT_EFFECT_SCENE.instantiate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	if get_tree().current_scene == null:
		effect.queue_free()
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = Vector2(posx, $HitBox/HitEffectPosition.global_position.y)
	await get_tree().create_timer(effect.lifetime).timeout
	if is_instance_valid(effect):
		effect.queue_free()

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = sign(direction)
	var scale_x := absf(sprite.scale.x)
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * float(facing_direction)
	if is_instance_valid(hitbox_root):
		var hitbox_scale_x := absf(hitbox_root.scale.x)
		if hitbox_scale_x == 0.0:
			hitbox_scale_x = 1.0
		hitbox_root.scale.x = hitbox_scale_x * float(facing_direction)

func enter_ball_form() -> void:
	set_ball_form(true)

func exit_ball_form() -> void:
	set_ball_form(false)

func start_attack() -> void:
	clear_attack_hitboxes()
	change_state(STATE_ATTACK_1)

func set_attack_hitbox(stage: int, enabled: bool = true) -> void:
	if stage == 1:
		if is_instance_valid(attack_hitbox_1):
			attack_hitbox_1.monitoring = enabled
		if is_instance_valid(attack_hitbox_2):
			attack_hitbox_2.monitoring = false
		return

	if stage == 2:
		if is_instance_valid(attack_hitbox_1):
			attack_hitbox_1.monitoring = false
		if is_instance_valid(attack_hitbox_2):
			attack_hitbox_2.monitoring = enabled
		return

	clear_attack_hitboxes()

func clear_attack_hitboxes() -> void:
	if is_instance_valid(attack_hitbox_1):
		attack_hitbox_1.monitoring = false
	if is_instance_valid(attack_hitbox_2):
		attack_hitbox_2.monitoring = false

func finish_attack() -> void:
	clear_attack_hitboxes()
	if is_in_ball_form:
		change_state(STATE_BALL)
		return
	if not is_on_floor():
		change_state(STATE_FALL)
		return
	var move_input := Input.get_axis(&"move_left", &"move_right")
	if abs(move_input) > 0.0:
		change_state(STATE_RUN)
	else:
		change_state(STATE_IDLE)
