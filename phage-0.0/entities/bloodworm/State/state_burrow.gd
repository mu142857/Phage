# 红丝虫 钻地(4 号)：沉入血肉(无敌) → 鼓包贴地追玩家 → 到脚下猛地顶出来。
# 鼓包就是预警——玩家看到地皮鼓起来要跑。
# 动画：Burrow(钻入) → Mound(鼓包爬行循环) → Emerge(顶出)。全靠计时器推进。
extends BasicState

@export var burrow_in_time: float = 0.5    # 钻入耗时
@export var mound_speed: float = 55.0      # 鼓包追踪速度(比玩家略慢才躲得掉)
@export var mound_min_time: float = 0.4    # 至少钻这么久才允许顶出
@export var mound_max_time: float = 2.5    # 追不上也要顶出来
@export var emerge_time: float = 0.5       # 顶出动画时长
@export var emerge_hit_window: float = 0.25 # 顶出后的伤害判定窗口
@export var damage: int = 15
@export var emerge_shake: float = 3.0
@export var hitbox_path: NodePath = ^"../../EmergeHitBox"

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)

enum Phase { DIG_IN, MOUND, EMERGE }

var _phase: Phase = Phase.DIG_IN
var _phase_elapsed: float = 0.0
var _hit_registered: bool = false


func enter() -> void:
	_phase = Phase.DIG_IN
	_phase_elapsed = 0.0
	_hit_registered = false
	monster.velocity = Vector2.ZERO
	_set_hitbox_active(false)
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(true)
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Burrow")


func process(delta: float) -> void:
	_phase_elapsed += delta
	match _phase:
		Phase.DIG_IN:
			if _phase_elapsed >= burrow_in_time:
				_switch_phase(Phase.MOUND)
				if is_instance_valid(ani_2d):
					ani_2d.play(&"Mound")
		Phase.MOUND:
			_process_mound(delta)
		Phase.EMERGE:
			if _phase_elapsed <= emerge_hit_window:
				_check_hit()
			if _phase_elapsed >= emerge_time:
				change_state(1)  # 回 Idle


func exit() -> void:
	# 无论怎么退出都要恢复可打+碰撞，别把无敌带出去
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(false)
	_set_hitbox_active(false)


func _process_mound(delta: float) -> void:
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	var dx: float = 0.0
	if player != null:
		dx = player.global_position.x - monster.global_position.x
		var step: float = mound_speed * delta
		monster.global_position.x += clampf(dx, -step, step)
		if is_instance_valid(ani_2d):
			ani_2d.flip_h = dx < 0.0
	# 追到脚下(且钻够了最短时间) 或 超时 → 顶出
	var arrived: bool = _phase_elapsed >= mound_min_time and absf(dx) < 3.0
	if arrived or _phase_elapsed >= mound_max_time:
		_emerge()


func _emerge() -> void:
	_switch_phase(Phase.EMERGE)
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(false)
	_set_hitbox_active(true)
	Game.shake_camera(emerge_shake)
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Emerge")


func _switch_phase(next_phase: Phase) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0


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
