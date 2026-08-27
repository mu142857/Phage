# =============================================================================
# calendula_web_shot(4).gd  —  吐网弹（4 号）：朝面对的方向吐一发抛物线网弹
# =============================================================================
# 行为：播 WebShot 动画 → 【第 release_frame(5) 帧，含 0】从 CalendulaWebBoltPoint
#       吐出网弹：初速只有横向（vy=0），随重力下坠成抛物线，方向 = 面对方向
#       （-side：side=1 在玩家右上朝左吐，side=-1 在玩家左上朝右吐）→
#       动画播完问大脑。不转向、不镜像——释放点跟着整个角色的 scale 自动镜像。
# 全程保持轻微上下浮动（金盏一刻不停），吐弹瞬间震屏。
#
# WebShot 动画必须【不循环】；动画不存在时兜底：播 Idle + 计时器，绝不卡死。
# =============================================================================

extends BasicState

@export var shot_animation: StringName = &"WebShot"
@export var release_frame: int = 5          # 第几帧出弹（含 0）
@export var bolt_vx: float = 80.0           # 网弹横向初速（固定，不瞄准）
@export var finish_delay: float = 0.1       # 播完到切状态的停顿
@export var fallback_windup: float = 0.45   # 没有动画时的前摇计时
@export var spit_shake: float = 2.0         # 吐弹瞬间的震屏（压迫感）
@export var bob_amplitude: float = 2.5      # 攻击中轻微浮动幅度
@export var bob_speed: float = 2.5          # 浮动角速度
@export var bob_y_max: float = 45.0         # 高度铁律：root y ≤ 45（贴图下探 35，不进地面）

const BOLT_SCENE: PackedScene = preload("res://entities/calendula/calendula_web_bolt.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var ticket: int = 0         # 防过期 await
var _spat: bool = false     # 本轮是否已出弹（release_frame 只出一次）
var _base_y: float = 0.0
var _time: float = 0.0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	ticket += 1
	_spat = false
	_base_y = monster.global_position.y
	_time = 0.0

	if _has_animation(shot_animation):
		ani_2d.play(shot_animation)
		if not ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.connect(_on_frame_changed)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)
	else:
		# 兜底：没切 WebShot 帧时播 Idle，计时器顶替
		if is_instance_valid(ani_2d):
			ani_2d.play(&"Idle")
		_fallback_windup(ticket)


func process(delta: float) -> void:
	# 轻微上下浮动：金盏没有真正的静止
	_time += delta
	monster.global_position.y = minf(_base_y + sin(_time * bob_speed) * bob_amplitude, bob_y_max)


func exit() -> void:
	ticket += 1  # 作废未完成的 await
	if is_instance_valid(ani_2d):
		if ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.disconnect(_on_frame_changed)
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _on_frame_changed() -> void:
	if _spat or not is_instance_valid(ani_2d) or ani_2d.animation != shot_animation:
		return
	if ani_2d.frame >= release_frame:
		_spat = true
		_spit()


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != shot_animation:
		return
	if not _spat:  # 动画帧数不够 release_frame 的兜底：播完补吐
		_spat = true
		_spit()
	_finish(ticket)


func _fallback_windup(t: int) -> void:
	await get_tree().create_timer(fallback_windup).timeout
	if t != ticket:
		return
	_spit()
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


# 从嘴（CalendulaWebBoltPoint，随整个角色镜像，全局坐标直接用）吐一发抛物线弹
func _spit() -> void:
	if BOLT_SCENE == null or get_tree().current_scene == null:
		return

	var start: Vector2 = monster.global_position
	var release := monster.get_node_or_null("CalendulaWebBoltPoint") as Node2D
	if release == null:
		release = monster.get_node_or_null("BulletReleasePoint") as Node2D
	if release != null:
		start = release.global_position

	var side: int = monster.side if "side" in monster else 1
	var cx: float = monster.center_x if "center_x" in monster else 0.0
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	# 出界删除线跟着场地中心走：boss rush 的房间中心是 80，
	# 用默认 [-110,110] 会把飞进房间右半的弹当出界删掉（=子弹凭空消失）
	bolt.set("bound_left", cx - 110.0)
	bolt.set("bound_right", cx + 110.0)
	if bolt.has_method("setup_arc"):
		bolt.setup_arc(start, Vector2(-float(side) * bolt_vx, 0.0))
	else:
		bolt.global_position = start
	if spit_shake > 0.0:
		Game.shake_camera(spit_shake)


func _has_animation(anim: StringName) -> bool:
	return is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(anim)
