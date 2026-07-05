# =============================================================================
# Prominence(6)  —  从地里升起：在场地边缘（由 Skill 传送好）播升起动画 → SprintAttack
# =============================================================================
# 旧邪帽这里会先重力砸落地面再升起；新竞技场直接贴地播升起动画即可。
# =============================================================================
extends BasicState

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.global_position.y = monster.floor_y
	monster.show()
	monster.apply_facing()
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Prominence")


func process(_delta: float) -> void:
	pass


func exit() -> void:
	pass


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == &"Prominence":
		change_state(monster.STATE_SPRINT_ATTACK)
