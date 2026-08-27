# 红丝虫 突进撕咬(5 号)：抬头蓄力(闪烁预警) → 贴地猛冲过去咬一口 → 缓一下。
# 动画：Windup(蓄力) → Lunge(冲刺) → Idle(后摇)。全靠计时器推进。
extends BasicState

@export var windup_time: float = 0.5
@export var lunge_speed: float = 90.0
@export var max_lunge_time: float = 1.2    # 冲刺最长时长(兜底)
@export var overshoot: float = 8.0         # 冲过玩家一点，别正好停脸上
@export var recover_time: float = 0.4
@export var damage: int = 12
@export var hitbox_path: NodePath = ^"../../LungeHitBox"

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)

enum Phase { WINDUP, LUNGE, RECOVER }

var _phase: Phase = Phase.WINDUP
var _phase_elapsed: float = 0.0
var _hit_registered: bool = false
var _target_x: float = 0.0
var _lunge_dir: float = 1.0
var _base_modulate: Color = Color.WHITE


func enter() -> void:
	_phase = Phase.WINDUP
	_phase_elapsed = 0.0
	_hit_registered = false
	monster.velocity = Vector2.ZERO
	_set_hitbox_active(false)

	# 瞄准玩家当前位置，冲过头一点
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	if player != null:
		_lunge_dir = signf(player.global_position.x - monster.global_position.x)
		if _lunge_dir == 0.0:
			_lunge_dir = 1.0
		_target_x = player.global_position.x + _lunge_dir * overshoot
	else:
		_lunge_dir = 1.0
		_target_x = monster.global_position.x
	if "bound_min_x" in monster and "bound_max_x" in monster:
		_target_x = clampf(_target_x, monster.bound_min_x, monster.bound_max_x)

	if is_instance_valid(ani_2d):
		_base_modulate = ani_2d.modulate
		ani_2d.flip_h = _lunge_dir < 0.0
		ani_2d.play(&"Windup")


func process(delta: float) -> void:
	_phase_elapsed += delta
	match _phase:
		Phase.WINDUP:
			# 蓄力闪烁预警(与杂兵同款)
			if is_instance_valid(ani_2d):
				var blink_on: bool = fmod(_phase_elapsed, 0.12) < 0.06
				ani_2d.modulate = Color(1.6, 1.6, 1.6, _base_modulate.a) if blink_on else _base_modulate
			if _phase_elapsed >= windup_time:
				_start_lunge()
		Phase.LUNGE:
			monster.velocity.x = _lunge_dir * lunge_speed
			monster.velocity.y = 0.0
			monster.move_and_slide()
			_check_hit()
			var reached: bool = (_lunge_dir > 0.0 and monster.global_position.x >= _target_x) \
				or (_lunge_dir < 0.0 and monster.global_position.x <= _target_x)
			if reached or _phase_elapsed >= max_lunge_time:
				_start_recover()
		Phase.RECOVER:
			if _phase_elapsed >= recover_time:
				change_state(1)  # 回 Idle


func exit() -> void:
	monster.velocity = Vector2.ZERO
	_set_hitbox_active(false)
	if is_instance_valid(ani_2d):
		ani_2d.modulate = _base_modulate


func _start_lunge() -> void:
	_phase = Phase.LUNGE
	_phase_elapsed = 0.0
	if is_instance_valid(ani_2d):
		ani_2d.modulate = _base_modulate
		ani_2d.play(&"Lunge")
	_set_hitbox_active(true)


func _start_recover() -> void:
	_phase = Phase.RECOVER
	_phase_elapsed = 0.0
	monster.velocity = Vector2.ZERO
	_set_hitbox_active(false)
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")


func _check_hit() -> void:
	if _hit_registered or not is_instance_valid(hitbox):
		return
	for body in hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_hit_registered = true
		return


func _set_hitbox_active(active: bool) -> void:
	if is_instance_valid(hitbox):
		hitbox.set_deferred("monitoring", active)
		hitbox.set_deferred("monitorable", active)
