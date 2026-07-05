# =============================================================================
# Disappear(5)  —  传送中枢：播 Disappear 动画，演完按标志分流
# =============================================================================
#   · 若已排队地火 → UndergroundFire(地火横扫)
#   · 否则 → 隐身、传送到施法悬浮点(场地 1/3 或 2/3, 高度 hover_y) → Appear
# =============================================================================
extends BasicState

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."


func enter() -> void:
	monster.velocity = Vector2.ZERO
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Disappear")


func process(_delta: float) -> void:
	pass


func exit() -> void:
	pass


func _on_animated_sprite_2d_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != &"Disappear":
		return
	if monster.ready_to_underground_fire:
		change_state(monster.STATE_UNDERGROUND_FIRE)
		return
	# 传送到施法悬浮点
	monster.hide()
	var span: float = monster.bound_max_x - monster.bound_min_x
	if monster.rng.randi_range(0, 1) == 0:
		monster.global_position.x = monster.bound_min_x + span / 3.0
	else:
		monster.global_position.x = monster.bound_min_x + 2.0 * span / 3.0
	monster.global_position.y = monster.hover_y
	monster.face_player()
	change_state(monster.STATE_APPEAR)
