class_name AzureWarlord
extends CharacterBody2D

@export var max_health: int = 8000
@export var health: int = 8000
@export var idle_full: float = 1.0 # Idle 时长（满血）
@export var idle_empty: float = 0.5 # Idle 时长（0 血）
@export var idle_min_limit: float = 0.15 # Idle 最小下限，防止太短
@export var crystallization_wait_time: float = 5.0

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_SPRINT: int = 2
const STATE_ATTACK: int = 3
const STATE_CRYSTALLIZATION: int = 4
const STATE_TRAMPLING: int = 5
const STATE_DIVE_DOWN: int = 6
const STATE_DEATH: int = 7

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var punch_hitbox: Area2D = get_node_or_null("PunchHitBox") as Area2D
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitBox") as Area2D
@onready var trampling_hitbox: Area2D = get_node_or_null("TramplingHitBox") as Area2D
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var boss_health_ui := get_node_or_null("BossHealthUI")

var direct: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var attack_batch_index: int = 0
var attacks_left_in_batch: int = 0
var crystallization_active: bool = false
var intro_shown: bool = false

func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	rng.randomize()
	if health <= 0:
		health = max_health
	health = int(clamp(float(health), 0.0, float(max_health)))
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.show_ui(false)
	var sprite := animated_sprite
	if sprite != null and sprite.material is ShaderMaterial:
		var shader_mat := sprite.material as ShaderMaterial
		shader_mat.set_shader_parameter("Enabled", false)
	if has_node("StateMachine"):
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)
	set_facing_direction(1)

func get_idle_time() -> float:
	if max_health <= 0:
		return idle_full
	var ratio := float(health) / float(max_health)
	ratio = clampf(ratio, 0.0, 1.0)
	var t := idle_empty + ratio * (idle_full - idle_empty)
	return maxf(t, idle_min_limit)

func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return
	direct = sign(direction)
	if is_instance_valid(animated_sprite):
		var sprite_scale_x := maxf(absf(animated_sprite.scale.x), 1.0)
		animated_sprite.scale.x = sprite_scale_x * float(direct)
	for node in [punch_hitbox, attack_hitbox, trampling_hitbox, player_check]:
		if is_instance_valid(node) and node is Node2D:
			var node_2d := node as Node2D
			var node_scale_x := maxf(absf(node_2d.scale.x), 1.0)
			node_2d.scale.x = node_scale_x * float(direct)

func set_facing_from_player() -> void:
	if not is_instance_valid(player_check):
		var fallback_players := get_tree().get_nodes_in_group("player")
		if fallback_players.is_empty():
			return
		var fallback_player := fallback_players[0]
		if fallback_player is Node2D:
			set_facing_direction(sign((fallback_player as Node2D).global_position.x - global_position.x))
		return
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			set_facing_direction(sign(body.global_position.x - global_position.x))
			return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	if player is Node2D:
		set_facing_direction(sign((player as Node2D).global_position.x - global_position.x))

func begin_attack_batch() -> void:
	attacks_left_in_batch = rng.randi_range(1, 3)

func consume_attack_followup() -> int:
	if attacks_left_in_batch > 0:
		attacks_left_in_batch -= 1
	if attacks_left_in_batch > 0:
		return STATE_ATTACK
	if attack_batch_index == 0:
		attack_batch_index = 1
		return STATE_SPRINT
	attack_batch_index = 0
	return STATE_CRYSTALLIZATION

func reset_cycle() -> void:
	attack_batch_index = 0
	attacks_left_in_batch = 0
	crystallization_active = false

func finish_null() -> void:
	change_state(STATE_IDLE)

func finish_trampling() -> void:
	reset_cycle()
	change_state(STATE_IDLE)

func take_damage(value: int) -> void:
	if crystallization_active:
		return
	health -= value
	health = clampi(health, 0, max_health)
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)
	if has_node("HitEffectPlayer"):
		$HitEffectPlayer.play("HitFlash")
	if health <= 0:
		change_state(STATE_DEATH)

func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)

func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)
