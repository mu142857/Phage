#BigSlime —— 最大，跳得最低。数值写死在脚本里（避免编辑器重存时被清掉）。
extends Slime

func _ready() -> void:
	max_health = 170
	health = 170
	contact_damage = 10
	gravity = 850.0
	jump_speed_y_min = 162.0
	jump_speed_y_max = 212.0
	jump_speed_x_min = 35.0
	jump_speed_x_max = 70.0
	if death_effect_scene == null:
		death_effect_scene = preload("res://entities/slime/big_slime_death.tscn")
	super._ready()
