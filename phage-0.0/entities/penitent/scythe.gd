# =============================================================================
# scythe.gd  —  长镰：冲刺时挂在 boss 身上的贴身横扫（旧「长镰.gd」重置版）
# =============================================================================
# 由 SprintAttack 生成并挂在 boss 精灵上，播一遍 default 动画即消失。
# 单次结算：扫到玩家造成一次伤害，避免逐帧多段。
# =============================================================================
extends Area2D

@export var damage: int = 12

var _hit: bool = false


func _ready() -> void:
	z_index = 1
	collision_mask = 2
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	$AnimatedSprite2D.play(&"default")


func _process(_delta: float) -> void:
	if _hit:
		return
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_hit = true
			return


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"default":
		queue_free()
