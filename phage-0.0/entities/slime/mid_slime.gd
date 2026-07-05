#MidSlime —— 中等，跳跃高度居中。数值写死在脚本里（避免编辑器重存时被清掉）。
extends Slime

func _ready() -> void:
	max_health = 80
	health = 80
	contact_damage = 6
	gravity = 850.0
	jump_speed_y_min = 185.0
	jump_speed_y_max = 245.0
	jump_speed_x_min = 48.0
	jump_speed_x_max = 85.0
	if death_effect_scene == null:
		death_effect_scene = preload("res://entities/slime/mid_slime_death.tscn")
	super._ready()
