# =============================================================================
# state_heal.gd  —  rust_goat 冰红茶回血（5 号）
# =============================================================================
# 行为：播 Heal 动画 → 到 heal_frame 帧时一口气回 heal_amount 血 → 播完问大脑。
# 设计要点：喝水期间【可被打、且不会触发反应闪避】——
#   · 可被打：本状态不动 hittable，take_damage 正常结算
#   · 不闪避：主体的 _try_reactive_dodge 只认 Idle/Move 状态，Heal 中天然不触发
#   这是玩家唯一的回血惩罚窗口，是这招的反制点，别"优化"掉。
#
# 注意：Heal 动画必须【不循环】。
# =============================================================================

extends BasicState

@export var heal_animation: StringName = &"Heal"
@export var heal_amount: int = 500
@export var heal_frame: int = 6   # 第几帧生效（默认第 6 帧，按你的动画手感调）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var healed: bool = false


func enter() -> void:
	healed = false
	monster.velocity = Vector2.ZERO

	if is_instance_valid(ani_2d):
		ani_2d.play(heal_animation)
		if not ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.connect(_on_frame_changed)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	if is_instance_valid(ani_2d):
		if ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.disconnect(_on_frame_changed)
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _on_frame_changed() -> void:
	if healed or not is_instance_valid(ani_2d):
		return
	if ani_2d.animation != heal_animation:
		return
	if ani_2d.frame >= heal_frame:
		healed = true
		if monster.has_method("heal"):
			monster.heal(heal_amount)


func _on_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == heal_animation:
		# 演完问大脑
		if monster.has_method("get_next_attack_state"):
			change_state(int(monster.get_next_attack_state()))
		else:
			change_state(1)
