# =============================================================================
# penitent_ground_fire.gd  —  地火（旧「地火.gd」重置版）
# =============================================================================
# 地面危险物：Ready(预警闪烁) → Fire(喷发·结算伤害) → 消失。
# 由 UndergroundFire 沿地板成排生成。单次结算，避免逐帧多段。
# =============================================================================
extends Area2D

@export var damage: int = 10

var _hit: bool = false


func _ready() -> void:
	z_index = 1
	collision_mask = 2
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	$AnimatedSprite2D.play(&"Ready")


func _process(_delta: float) -> void:
	if _hit or $AnimatedSprite2D.animation != &"Fire":
		return
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_hit = true
			return


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"Ready":
		$AnimatedSprite2D.play(&"Fire")     # 预警结束 → 喷发
	elif $AnimatedSprite2D.animation == &"Fire":
		queue_free()
