# =============================================================================
# penitent_ground_fire.gd  —  地火（危险物）
# =============================================================================
# 照抄 cursed_stone_big_fire 的做法（frame_changed 判伤害 + 播完自毁），
# 唯一区别：两段动画——先播 Ready(预警) → 播完自动播 GroundFire(喷发)。
# GroundFire 动画期间为伤害判定（扫到玩家结算一次），播完消失。
# =============================================================================
extends Area2D

@export var damage_amount: int = 10
@export var glow: float = 1.0        # >1 做泛光（需场景开 glow）；默认 1 不改色

var _damage_applied: bool = false

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	collision_mask = 2  # 只检测玩家层
	monitoring = true
	z_index = 10
	if is_instance_valid(ani_2d):
		if glow != 1.0:
			ani_2d.modulate = Color(glow, glow, glow, 1.0)
		if not ani_2d.frame_changed.is_connected(_on_frame_changed):
			ani_2d.frame_changed.connect(_on_frame_changed)
		if not ani_2d.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
			ani_2d.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
		ani_2d.play(&"Ready")
		ani_2d.set_frame_and_progress(0, 0.0)  # 强制从 Ready 第 0 帧起（tscn 存成了别的帧）


func _on_frame_changed() -> void:
	if _damage_applied or not is_instance_valid(ani_2d):
		return
	if ani_2d.animation != &"GroundFire":
		return  # 只有喷发动画期间判定；GroundFire 全程都是判定帧
	_apply_damage()


func _apply_damage() -> void:
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
			_damage_applied = true  # 命中才算数，没命中就继续等下一帧
		break


func _on_animated_sprite_2d_animation_finished() -> void:
	if not is_instance_valid(ani_2d):
		return
	if ani_2d.animation == &"Ready":
		ani_2d.play(&"GroundFire")   # 预警结束 → 喷发
	else:
		queue_free()                  # 喷发结束 → 消失
