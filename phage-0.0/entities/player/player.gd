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
const RUN_SPEED: float = 70.0 #(100.0)
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
const JUMP_ATTACK_EFFECT_SCENE: PackedScene = preload("res://entities/player/jump_attack_effect.tscn")

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
const FALL_GRAVITY_MULTIPLIER: float = 1.6
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.10
# 在地面上连续站稳这么久,当前位置才算"安全点"(避免擦着地刺滑过时被误记)。
const SAFE_RECORD_SETTLE_TIME: float = 0.12
# 安全点离平台左右边缘至少留这么多像素(主角半宽),免得复活在边缘直接滑落。
const SAFE_EDGE_MARGIN: float = 2.0
# 侧向探针在地面接触点上下各探这么多像素(够覆盖落差,又不会探到下层平台)。
const SAFE_GROUND_PROBE_HEIGHT: float = 6.0

var _grounded_time: float = 0.0

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

# 像素对齐:物理体停在浮点坐标(保证移动/相机插值丝滑),
# 只把渲染用的 sprite 节点局部偏移到整数像素,消除脚底与地板间的亚像素缝隙。
# 只吸附 Y 轴 —— 缝隙是垂直方向的,横向不碰,避免水平移动出现像素跳动。
# 在 _process(渲染帧)里做,不污染物理状态。
func _process(_delta: float) -> void:
	if not is_instance_valid(sprite):
		return
	# 让 sprite.global_position.y 落到整数:补偿父级(物理体)的小数残差。
	sprite.position.y = roundf(global_position.y) - global_position.y

func _physics_process(_delta: float) -> void:
	# 持续记录最后的安全落脚点,供地刺等危险物弹回使用。
	# 站稳一小会儿才记录;受伤无敌期间不记录(刚被弹回时别立刻覆盖);
	# 脚下是陷阱平台(unsafe_ground 组)时不记录,免得重生在陷阱上。
	# 只在"平台内侧"记录:脚下左右各 SAFE_EDGE_MARGIN 处都得有地面。
	# 这样贴地走下平台时(土狼时间内中心已越过边缘的那几帧)不会被记录,
	# 自动保留上一个内侧安全点,避免复活在悬空边缘后直接滑落。
	if is_on_floor() and not _is_on_unsafe_ground():
		_grounded_time += _delta
		if _grounded_time >= SAFE_RECORD_SETTLE_TIME and not is_invincible and _is_interior_floor_spot():
			Game.record_safe_position(global_position)
	else:
		_grounded_time = 0.0

# 脚下左右两侧 SAFE_EDGE_MARGIN 处都有地面 → 站在平台内侧(非边缘悬空)。
func _is_interior_floor_spot() -> bool:
	var ground_y := _floor_contact_y()
	if is_inf(ground_y):
		return true  # 拿不到接触点时不阻止记录(退回原行为)
	return _has_ground_below(global_position.x - SAFE_EDGE_MARGIN, ground_y) \
		and _has_ground_below(global_position.x + SAFE_EDGE_MARGIN, ground_y)

# 脚下地面接触点的 Y(全局),取不到返回 INF。
func _floor_contact_y() -> float:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.5:  # 只看脚下(法线朝上)的接触面
			return collision.get_position().y
	return INF

# 在 (x, ground_y) 附近上下各探一小段,判断该处脚下是否有地面。
func _has_ground_below(x: float, ground_y: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := Vector2(x, ground_y - SAFE_GROUND_PROBE_HEIGHT)
	var to := Vector2(x, ground_y + SAFE_GROUND_PROBE_HEIGHT)
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	return not space.intersect_ray(query).is_empty()

# 检查脚下踩着的碰撞体是否属于 "unsafe_ground" 组(陷阱平台)。
func _is_on_unsafe_ground() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		# 只看脚下(法线朝上)的接触面
		if collision.get_normal().y < -0.5:
			var collider := collision.get_collider()
			if collider is Node and (collider as Node).is_in_group("unsafe_ground"):
				return true
	return false

# 被地刺等危险物击中时调用:弹回上一个安全点,清零速度并给无敌帧。
func respawn_to_safe() -> void:
	if not Game.has_safe_position:
		return
	global_position = Game.last_safe_position
	velocity = Vector2.ZERO
	_grounded_time = 0.0
	change_state(STATE_IDLE)
	_start_invincibility()

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
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

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

func spawn_jump_attack_effect(posx: float) -> void:
	if not is_inside_tree() or JUMP_ATTACK_EFFECT_SCENE == null:
		return
	var effect := JUMP_ATTACK_EFFECT_SCENE.instantiate() as GPUParticles2D
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
