# =============================================================================
# state_move.gd  —  移动待机（rust_goat 的 8 号状态，「会走路的 Idle」）
# =============================================================================
# 行为：播 7 帧 Move 动画（帧编号 0~6）→ 进入第 2 帧时启动 Tween 位移，
#       位移时长 = 第 2~4 帧的播放时长（3 帧 / fps）→ 动画播完问大脑要下一个状态。
# 帧对齐用 AnimatedSprite2D 的 frame_changed 信号，比猜时间准。
#
# 注意：动画 Move 必须是【不循环】的（SpriteFrames 里关掉 loop），
#       循环动画不会发 animation_finished 信号，状态会卡死。
# =============================================================================

extends BasicState

@export var move_animation: StringName = &"Move"
@export var move_start_frame: int = 2      # 从这帧开始位移（含）
@export var move_end_frame: int = 4        # 到这帧位移结束（含）
@export var move_distance: float = 30.0    # 位移距离（160 宽屏参考 20~40）

# 位移方向：0=朝向玩家走, 1=远离玩家走, 2=随机
@export_enum("toward_player", "away_from_player", "random") var move_dir_mode: int = 0

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var move_tween: Tween = null
var move_started: bool = false


func enter() -> void:
	move_started = false
	monster.velocity = Vector2.ZERO

	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()

	if is_instance_valid(ani_2d):
		ani_2d.play(move_animation)
		if not ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.connect(_on_frame_changed)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	# ★ 必须杀掉 Tween：闪避可能在位移途中打断本状态，
	#   Tween 不会随状态退出自动停，不杀会把 boss 拖到旧目标点
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = null
	if is_instance_valid(ani_2d):
		if ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.disconnect(_on_frame_changed)
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _on_frame_changed() -> void:
	if move_started or not is_instance_valid(ani_2d):
		return
	if ani_2d.animation != move_animation:
		return
	if ani_2d.frame < move_start_frame:
		return
	move_started = true
	_start_move()


func _start_move() -> void:
	# 位移时长 = 移动帧数 / 动画帧率（帧率从 SpriteFrames 里读，改动画不用改代码）
	var fps := 10.0
	if ani_2d.sprite_frames != null:
		fps = ani_2d.sprite_frames.get_animation_speed(move_animation)
	var duration := float(move_end_frame - move_start_frame + 1) / maxf(fps, 0.01)

	# 算目标点并夹在场地边界内
	var dir := _pick_direction()
	var min_x: float = monster.bound_min_x if "bound_min_x" in monster else 10.0
	var max_x: float = monster.bound_max_x if "bound_max_x" in monster else 150.0
	var target_x := clampf(monster.global_position.x + dir * move_distance, min_x, max_x)

	move_tween = get_tree().create_tween()
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(monster, "global_position:x", target_x, duration)


func _pick_direction() -> float:
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	match move_dir_mode:
		0:  # 朝玩家
			if player != null:
				return signf(player.global_position.x - monster.global_position.x)
			return float(monster.direct)
		1:  # 远离玩家
			if player != null:
				var away := signf(monster.global_position.x - player.global_position.x)
				return away if away != 0.0 else 1.0
			return float(-monster.direct)
		_:  # 随机
			return 1.0 if randf() < 0.5 else -1.0


func _on_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == move_animation:
		# 演完问大脑（剧本制统一规则）
		if monster.has_method("get_next_attack_state"):
			change_state(int(monster.get_next_attack_state()))
		else:
			change_state(1)


func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var d: int = monster.direct if "direct" in monster else 1
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if d > 0 else s  # 翻转方向按你素材改
