# =============================================================================
# scythe.gd  —  长镰：冲刺时挂在 boss 身上的贴身横扫（旧「长镰.gd」重置版）
# =============================================================================
# 由 SprintAttack 生成并挂在 boss 精灵上。完整播 default（前摇 0~6 帧 + 挥砍），
# 伤害判定从第 7 帧（0 起，即第 8 帧）开始生效，扫到玩家结算一次伤害。播完即消失。
# =============================================================================
extends Area2D

@export var damage: int = 12
@export var damage_frame: int = 7   # 从这一帧起判定（0 起）

var _hit: bool = false


func _ready() -> void:
	z_index = 1
	collision_mask = 2
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	$AnimatedSprite2D.play(&"default")
	# tscn 把默认帧存成了最后一帧(10)，直接 play 会瞬间"播完"，强制从第 0 帧起播出前摇
	$AnimatedSprite2D.set_frame_and_progress(0, 0.0)


func _process(_delta: float) -> void:
	if _hit or $AnimatedSprite2D.animation != &"default":
		return
	if $AnimatedSprite2D.frame < damage_frame:
		return  # 前摇阶段不判定
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_hit = true
			return


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"default":
		queue_free()
