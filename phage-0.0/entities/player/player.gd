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

# ============================================================
# State (read by states, written by player or specific states)
# ============================================================
var health: int = MAX_HEALTH
var facing_direction: int = 1  # 1 = right, -1 = left
var can_sprint: bool = true
var is_invincible: bool = false
var is_in_ball_form: bool = false  # true when contracted; modifies hitbox + buffs

# ============================================================
# Node references
# ============================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_normal: CollisionShape2D = $CollisionNormal
@onready var collision_ball: CollisionShape2D = $CollisionBall
@onready var walking_effect: GPUParticles2D = $PlayerWalkingEffect
@onready var attack_hitbox_1: Area2D = $HitBox/Attack1_1
@onready var attack_hitbox_2: Area2D = $HitBox/Attack1_2
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

func take_damage(amount: int) -> void:
	if is_invincible:
		return
	health = max(0, health - amount)
	health_changed.emit(health)
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

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = sign(direction)
	var scale_x := absf(sprite.scale.x)
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * float(facing_direction)

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
