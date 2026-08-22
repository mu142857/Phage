# =============================================================================
# calendula_web_shot(4).gd  —  吐网弹（4 号）：朝玩家吐一发
# =============================================================================
# 行为：面向玩家 → 播一遍 WebShot 动画 → 播完从 BulletReleasePoint
#       朝玩家【当前位置】吐一发网弹（直线飞行，不追踪）→ 问大脑要下一个状态。
# 全程保持轻微上下浮动（金盏一刻不停）。
#
# WebShot 动画必须【不循环】，靠 animation_finished 收尾；
# 动画不存在时兜底：播 Idle + 计时器代替，绝不卡死。
# =============================================================================

extends BasicState

@export var shot_animation: StringName = &"WebShot"
@export var finish_delay: float = 0.1       # 吐完到切状态的停顿
@export var fallback_windup: float = 0.45   # 没有动画时的前摇计时
@export var bob_amplitude: float = 2.5      # 攻击中轻微浮动幅度
@export var bob_speed: float = 2.5          # 浮动角速度

const BOLT_SCENE: PackedScene = preload("res://entities/calendula/calendula_web_bolt.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var ticket: int = 0         # 防过期 await
var _base_y: float = 0.0
var _time: float = 0.0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	ticket += 1
	_base_y = monster.global_position.y
	_time = 0.0

	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()

	if _has_animation(shot_animation):
		ani_2d.play(shot_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)
	else:
		# 兜底：没切 WebShot 帧时播 Idle，计时器顶替 animation_finished
		if is_instance_valid(ani_2d):
			ani_2d.play(&"Idle")
		_fallback_windup(ticket)


func process(delta: float) -> void:
	# 轻微上下浮动：金盏没有真正的静止
	_time += delta
	monster.global_position.y = _base_y + sin(_time * bob_speed) * bob_amplitude


func exit() -> void:
	ticket += 1  # 作废未完成的 await
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)
		ani_2d.scale.x = maxf(absf(ani_2d.scale.x), 1.0)


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != shot_animation:
		return
	_spit_at_player()
	_finish(ticket)


func _fallback_windup(t: int) -> void:
	await get_tree().create_timer(fallback_windup).timeout
	if t != ticket:
		return
	_spit_at_player()
	_finish(t)


func _finish(t: int) -> void:
	await get_tree().create_timer(finish_delay).timeout
	if t != ticket:
		return  # 状态已退出，作废
	# 演完问大脑
	if monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))
	else:
		change_state(1)


# 朝玩家当前位置直线吐一发
func _spit_at_player() -> void:
	if BOLT_SCENE == null or get_tree().current_scene == null:
		return
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	if player == null:
		return

	var start: Vector2 = monster.global_position
	var release := monster.get_node_or_null("BulletReleasePoint") as Node2D
	if release != null:
		start = release.global_position

	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	if bolt.has_method("setup"):
		bolt.setup(start, player.global_position)
	else:
		bolt.global_position = start


func _has_animation(anim: StringName) -> bool:
	return is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(anim)


func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var d: int = monster.direct if "direct" in monster else 1
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if d > 0 else s  # 翻转方向按你素材改
