# =============================================================================
# state_melee.gd  —  近战攻击样板（原地挥击 / 肘击类）
# =============================================================================
# 最小积木：朝向玩家 → 播攻击动画 → 在「生效窗口」内开 hitbox 查命中 → 动画完回 Idle。
# 适用：近身肘击、原地拍地、挥爪……一切「不位移、靠贴脸的 Area2D 判定」的招。
# 要位移的招（冲到玩家身边再打）用 state_dash_attack.gd 拼。
#
# 命中时机用「计时器猜帧」：trigger_frame / attack_fps 算出开窗时刻。
#   例：动画 10fps，第 3 帧出手 → 0.3 秒时开 hitbox。
#
# 节点要求：
#   - 主体下有本招专用的 HitBox (Area2D)，路径填到 hitbox_path
#   - hitbox 的 collision_mask 要能扫到玩家所在层
#   - AnimatedSprite2D 有本招的动画（动画名填 attack_animation）
# =============================================================================

extends BasicState

@export var attack_animation: StringName = &"Attack"  # 本招动画名
@export var hitbox_path: NodePath = ^"../../AttackHitBox"  # 本招 hitbox 路径

# --- 命中窗口（计时器猜帧）---
@export var attack_fps: float = 10.0          # 动画帧率（和 SpriteFrames 里设的一致！）
@export var hit_open_frame: int = 3           # 第几帧开始有判定（Actinos SpikeAttack: 第3帧出手）
@export var hit_close_frame: int = 5          # 第几帧判定结束（-1 = 一直开到动画结束）

# --- 伤害与受击反馈 ---
@export var damage: int = 20                              # Actinos JumpAttack: 20
@export var hit_filter_amount: float = 0.45               # 玩家被打时的全屏滤镜强度（Actinos: 0.45）
@export var hit_filter_color: Color = Color(0.9, 0.1, 0.1, 0.6)  # 滤镜颜色（Actinos 红）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var hitbox: Area2D = get_node_or_null(hitbox_path)

var elapsed: float = 0.0
var hit_registered: bool = false  # 一招只打一次


func enter() -> void:
	elapsed = 0.0
	hit_registered = false
	monster.velocity = Vector2.ZERO

	# 朝向玩家 + 翻转 hitbox（boss_base 提供 face_player / direct）
	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()

	_set_hitbox_active(false)  # 先关，到帧再开

	if is_instance_valid(ani_2d):
		ani_2d.play(attack_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(delta: float) -> void:
	elapsed += delta
	var open_t := _frame_time(hit_open_frame)
	var close_t := _frame_time(hit_close_frame) if hit_close_frame >= 0 else INF

	# 在窗口内：开 hitbox 并持续查命中
	if elapsed >= open_t and elapsed < close_t:
		if is_instance_valid(hitbox) and not hitbox.monitoring:
			_set_hitbox_active(true)
		_check_hit()
	elif elapsed >= close_t:
		_set_hitbox_active(false)


func exit() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation_finished.is_connected(_on_animation_finished):
		ani_2d.animation_finished.disconnect(_on_animation_finished)
	_set_hitbox_active(false)
	_reset_facing_scale()


func _on_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == attack_animation:
		change_state(1)  # 回 Idle，由主体决定下一招


# --- 工具 ---

func _frame_time(frame: int) -> float:
	if attack_fps <= 0.0:
		return 0.0
	return float(frame) / attack_fps


func _check_hit() -> void:
	if hit_registered or not is_instance_valid(hitbox):
		return
	for body in hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
			Game.filter(hit_filter_amount, hit_filter_color)
		hit_registered = true
		break


func _set_hitbox_active(active: bool) -> void:
	if is_instance_valid(hitbox):
		hitbox.monitoring = active
		hitbox.monitorable = active


# 按朝向翻转贴图和 hitbox（参考 Actinos：direct=1 朝右；贴图原始朝左则取反，按你素材改）
func _apply_facing() -> void:
	var d: int = monster.direct if "direct" in monster else 1
	if is_instance_valid(ani_2d):
		ani_2d.scale.x = -absf(ani_2d.scale.x) if d > 0 else absf(ani_2d.scale.x)
	if is_instance_valid(hitbox):
		hitbox.scale.x = -absf(hitbox.scale.x) if d > 0 else absf(hitbox.scale.x)


func _reset_facing_scale() -> void:
	if is_instance_valid(ani_2d):
		ani_2d.scale.x = maxf(absf(ani_2d.scale.x), 1.0)
	if is_instance_valid(hitbox):
		hitbox.scale.x = maxf(absf(hitbox.scale.x), 1.0)
