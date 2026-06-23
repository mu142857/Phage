extends Node2D

## 带陷阱的跳跳乐平台。
## 玩家踩上去(进入 PlayerDetector)0.1 秒后随机触发一种陷阱动画,
## 动画播完冷却 0.8 秒,只要玩家还在范围内就循环触发。
## 12 种陷阱完全随机,但不会连续触发同一种。
## 除 MachineLeft 外的 11 种在第 2 帧(编号从 0 起,即第三帧)造成伤害;
## MachineLeft 不造成伤害,而是在第 2、3 帧把平台碰撞箱切短,之后切回 Normal。

@export var damage: int = 10            # 统一伤害值
@export var trigger_delay: float = 0.2  # 踩上去到首次触发的延迟
@export var cooldown: float = 1.8       # 一次陷阱播完到下一次的冷却
@export var shake_strength: float = 4.0 # 陷阱在伤害帧释放时的屏幕震动强度

const DAMAGE_FRAME: int = 2             # 伤害帧(从 0 起计,即第三帧)
const MACHINE_LEFT: StringName = &"MachineLeft"

# 全部 12 种陷阱动画
const TRAP_ANIMS: Array[StringName] = [
	&"FireTop", &"FireBottom", &"FireLeft", &"FireRight",
	&"MachineTop", &"MachineBottom", &"MachineLeft", &"MachineRight",
	&"SpikeTop", &"SpikeBottom", &"SpikeLeft", &"SpikeRight",
]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_root: Node2D = $HitBox
@onready var wall_normal: CollisionShape2D = $Wall/Normal
@onready var wall_machine_left: CollisionShape2D = $Wall/MachineLeft

var _player_inside: bool = false
var _running: bool = false
var _current_trap: StringName = &""
var _last_trap: StringName = &""

func _ready() -> void:
	sprite.frame_changed.connect(_on_frame_changed)
	_set_machine_left_collision(false)  # 默认使用 Normal 碰撞箱
	# 把玩家真正踩的 Wall 标记为"不安全地面",这样玩家不会把陷阱平台记成重生点。
	# (解绑本脚本后这行不执行,平台即自动变为安全地面。)
	$Wall.add_to_group("unsafe_ground")


func _on_player_detector_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if not _running:
		_run_traps()


func _on_player_detector_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false


## 陷阱主循环:进入后等 trigger_delay,首次触发不可取消(即使此时已离开也照触发);
## 之后进入冷却(冷却中绝不触发),冷却结束时只要玩家还在范围内就继续强制触发。
func _run_traps() -> void:
	_running = true
	await get_tree().create_timer(trigger_delay).timeout
	while true:
		_current_trap = _pick_trap()
		_last_trap = _current_trap
		sprite.play(_current_trap)
		await sprite.animation_finished  # 播放期间伤害/碰撞切换由 _on_frame_changed 处理
		_current_trap = &""
		await get_tree().create_timer(cooldown).timeout
		if not _player_inside:  # 冷却结束后才判定是否继续
			break
	_running = false


## 随机选一种,且不与上一次相同。
func _pick_trap() -> StringName:
	var choice: StringName = _last_trap
	while choice == _last_trap:
		choice = TRAP_ANIMS[randi() % TRAP_ANIMS.size()]
	return choice


func _on_frame_changed() -> void:
	if _current_trap == &"":
		return
	# 所有陷阱在释放帧(第2帧)都来一下屏幕震动
	if sprite.frame == DAMAGE_FRAME:
		Game.shake_camera(shake_strength)
	if _current_trap == MACHINE_LEFT:
		# MachineLeft:第 2、3 帧用缩短碰撞箱,其余帧用 Normal
		_set_machine_left_collision(sprite.frame == 2 or sprite.frame == 3)
		return
	# 其余 11 种:到伤害帧时,检查对应 Hitbox 内是否有玩家
	if sprite.frame == DAMAGE_FRAME:
		_apply_damage(_current_trap)


## 检查 "Hitbox" + 动画名 对应的 Area2D 是否压到玩家,有则扣血。
func _apply_damage(trap: StringName) -> void:
	var hitbox := hitbox_root.get_node_or_null("Hitbox" + String(trap)) as Area2D
	if hitbox == null:
		return
	for body in hitbox.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", damage)
			# 击退留作以后扩展:玩家目前无受击状态,直接改 velocity 会被状态机覆盖。
			break


func _set_machine_left_collision(use_machine_left: bool) -> void:
	# 用 set_deferred 避免在物理回调/信号里直接改碰撞体导致报错
	wall_machine_left.set_deferred("disabled", not use_machine_left)
	wall_normal.set_deferred("disabled", use_machine_left)


func _on_animated_sprite_2d_animation_finished() -> void:
	_set_machine_left_collision(false)  # 确保 MachineLeft 结束后恢复 Normal 碰撞箱
	sprite.play(&"Idle")
