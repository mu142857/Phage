# 红丝虫 巨虫穿场(6 号)：二阶段大招。小虫钻进血肉深处 → 短暂预警 →
# 巨大的成体虫身斜穿整个画面(素材里那几帧 145×90 的全屏大图)。
# 全屏帧是原地播放的，所以 DiveSprite 固定摆在场地中心播 Dive 动画即可，
# 伤害判定用 DiveHitBox(斜带状，形状你在编辑器里画)。
# 动画：本体 Burrow(钻入) / Emerge(钻回来)；DiveSprite 上是 Dive(单次全屏)。
extends BasicState

@export var telegraph_time: float = 0.8    # 钻入后的预警间隔(震屏渐强)
@export var dive_time: float = 1.5         # 巨虫穿场总时长(和 Dive 动画对齐)
@export var hit_start: float = 0.3         # 判定窗口(相对穿场开始)
@export var hit_end: float = 1.0
@export var damage: int = 25
@export var dive_shake: float = 4.0
@export var emerge_time: float = 0.5       # 钻回来的后摇
## 全屏大帧的摆放位置(场地中心；场地不在原点就在检查器里改)
@export var dive_center: Vector2 = Vector2(80.0, 45.0)
@export var hitbox_path: NodePath = ^"../../DiveHitBox"

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var dive_sprite: AnimatedSprite2D = get_node_or_null("../../DiveSprite") as AnimatedSprite2D
@onready var monster: CharacterBody2D = $"../.."
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)

enum Phase { DIG_IN, DIVE, EMERGE }

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
			# 预警：震屏由弱渐强，告诉玩家有大的要来了
			Game.shake_camera(lerpf(0.5, dive_shake, clampf(_phase_elapsed / telegraph_time, 0.0, 1.0)))
			if _phase_elapsed >= telegraph_time:
				_start_dive()
		Phase.DIVE:
			Game.shake_camera(dive_shake)
			if _phase_elapsed >= hit_start and _phase_elapsed <= hit_end:
				_check_hit()
			if _phase_elapsed >= dive_time:
				_start_emerge()
		Phase.EMERGE:
			if _phase_elapsed >= emerge_time:
				change_state(1)  # 回 Idle


func exit() -> void:
	Game.stop_shake()
	_set_hitbox_active(false)
	if is_instance_valid(dive_sprite):
		dive_sprite.visible = false
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(false)


func _start_dive() -> void:
	_phase = Phase.DIVE
	_phase_elapsed = 0.0
	if is_instance_valid(dive_sprite):
		dive_sprite.global_position = dive_center
		dive_sprite.visible = true
		if dive_sprite.sprite_frames != null and dive_sprite.sprite_frames.has_animation(&"Dive"):
			dive_sprite.play(&"Dive")
	if is_instance_valid(hitbox):
		hitbox.global_position = dive_center
	_set_hitbox_active(true)


func _start_emerge() -> void:
	_phase = Phase.EMERGE
	_phase_elapsed = 0.0
	_set_hitbox_active(false)
	if is_instance_valid(dive_sprite):
		dive_sprite.visible = false
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(false)
	Game.stop_shake()
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Emerge")


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
