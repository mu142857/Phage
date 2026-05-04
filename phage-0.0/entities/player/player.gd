# res://entities/player/player.gd
class_name Player
extends CharacterBody2D

# ============================================================
# Constants - tweak here, applies to all states
# ============================================================
const GRAVITY: float = 1000.0
const MAX_HEALTH: int = 100
const IDLE_TO_CONTRACT_TIME: float = 2.0  # seconds before auto-contract
const INVINCIBLE_DURATION: float = 0.3
const RUN_SPEED: float = 100.0
const JUMP_SPEED: float = -200.0
const MAX_JUMP_HOLD_TIME: float = 0.14
const JUMP_HOLD_GRAVITY_MULTIPLIER: float = 0.35

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_RUN: int = 2
const STATE_FALL: int = 3
const STATE_JUMP: int = 4
const STATE_SPRINT: int = 5

# ============================================================
# State (read by states, written by player or specific states)
# ============================================================
var health: int = MAX_HEALTH
var facing_direction: int = 1  # 1 = right, -1 = left
var is_invincible: bool = false
var is_in_ball_form: bool = false  # true when contracted; modifies hitbox + buffs

# ============================================================
# Node references
# ============================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_normal: CollisionShape2D = $CollisionNormal
@onready var collision_ball: CollisionShape2D = $CollisionBall
@onready var state_machine: StateManager = $StateMachine

# ============================================================
# Signals
# ============================================================
signal health_changed(new_health: int)
signal died

func _ready() -> void:
	add_to_group("player")
	set_ball_form(false)

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
