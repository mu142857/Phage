#MiniSlime —— 最小，跳得最高。数值写死在脚本里（避免编辑器重存时被清掉）。
extends Slime

func _ready() -> void:
	max_health = 5
	health = 5
	contact_damage = 3
	gravity = 850.0
	jump_speed_y_min = 235.0
	jump_speed_y_max = 290.0
	jump_speed_x_min = 55.0
	jump_speed_x_max = 95.0
	if death_effect_scene == null:
		death_effect_scene = preload("res://entities/slime/mini_slime_death.tscn")
	super._ready()
