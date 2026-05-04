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

func change_state(state_id: StringName) -> void:
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
		# or you can change_state(&"null") directly here

func _start_invincibility() -> void:
	is_invincible = true
	await get_tree().create_timer(INVINCIBLE_DURATION).timeout
	is_invincible = false

func set_ball_form(enabled: bool) -> void:
	is_in_ball_form = enabled
	collision_normal.disabled = enabled
	collision_ball.disabled = not enabled

func enter_ball_form() -> void:
	set_ball_form(true)

func exit_ball_form() -> void:
	set_ball_form(false)
