# =============================================================================
# cursed_stone_small_fire.gd  —  小地火（CursedStoneSmallFire）
# =============================================================================
# 地面型危险物，不是发射的子弹。召唤在玩家脚下，播一遍 default 动画后消失。
# 伤害判定：动画 8.0 FPS，第 3 帧（索引 2）为伤害帧 —— 那一帧对身上的玩家
# 造成一次伤害（只结算一次）。动画播完自动移除。
# =============================================================================
extends Area2D

@export var damage_amount: int = 6
@export var damage_frame: int = 2   # 从 0 开始：第 3 帧
@export var glow: float = 1.8       # modulate 提到 1 以上做泛光（需场景开 glow）

var _damage_applied: bool = false

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	collision_mask = 2  # 只检测玩家层
	monitoring = true
	z_index = 10  # 画在 boss（默认 z=0）前面，别被石头挡住
	if is_instance_valid(ani_2d):
		ani_2d.modulate = Color(glow, glow, glow, 1.0)
		if not ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.connect(_on_frame_changed)
		ani_2d.play(&"default")
		ani_2d.set_frame_and_progress(0, 0.0)  # 强制从第 0 帧起播，保留前摇（tscn 存成了 frame=3）


func _on_frame_changed() -> void:
	if _damage_applied or not is_instance_valid(ani_2d):
		return
	if ani_2d.frame >= damage_frame:
		_apply_damage()


func _apply_damage() -> void:
	_damage_applied = true
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
		break


func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()
