extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

const BULLET_SCENE: PackedScene = preload("res://entities/azure_warlord/azure_bullet.tscn")

var spawn_complete: bool = false

func _get_player_x() -> float:
	# prefer using the boss's PlayerCheck Area2D to find the player
	if boss == null:
		return 0.0
	var pc := boss.player_check
	if not is_instance_valid(pc):
		return boss.global_position.x
	for body in pc.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return (body as Node2D).global_position.x
	return boss.global_position.x

func enter() -> void:
	boss.set_collision_layer_value(3, false) 
	spawn_complete = false
	if is_instance_valid(ani_2D):
		if boss != null:
			boss.velocity = Vector2.ZERO
			boss.crystallization_active = true
		ani_2D.play("Crystallization")
		# start spawn loop (deferred so enter() finishes quickly)
		call_deferred("_crystallization_spawn_loop")

func exit() -> void:
	if boss != null:
		boss.crystallization_active = false
		boss.set_collision_layer_value(3, true) 

func _on_animated_sprite_2d_animation_finished() -> void:
	if ani_2D.animation != &"Crystallization":
		return
	if not spawn_complete:
		return
	var frame_count := 0
	if is_instance_valid(ani_2D.sprite_frames):
		frame_count = ani_2D.sprite_frames.get_frame_count(&"Crystallization")
	if frame_count > 0 and ani_2D.frame < frame_count - 1:
		return
	if boss != null:
		boss.crystallization_active = false
	change_state(6)

func _crystallization_spawn_loop() -> void:
	if boss == null:
		return
	if BULLET_SCENE == null:
		return
	var ratio: float = 0.0
	if boss.max_health > 0:
		ratio = float(boss.health) / float(boss.max_health)
	var wave_count: int = int(round(lerp(3.0, 10.0, ratio)))
	wave_count = clamp(wave_count, 3, 10)
	for i in range(wave_count):
		if boss == null or not boss.crystallization_active:
			break
		# 2/3 single, 1/3 pair
		var is_pair: bool = (randi() % 3) == 0
		var px: float = _get_player_x()
		if not is_pair:
			var sx: float = clamp(px, 10.0, 150.0)
			var bullet = BULLET_SCENE.instantiate()
			if bullet != null and get_tree().current_scene != null:
				get_tree().current_scene.add_child(bullet)
				if bullet.has_method("setup"):
					bullet.call("setup", Vector2(sx, -20.0))
				else:
					bullet.global_position = Vector2(sx, -20.0)
		else:
			var span: float = 40.0
			var left: float = px - 20.0
			left = clamp(left, 10.0, 150.0 - span)
			var right: float = left + span
			var b1 = BULLET_SCENE.instantiate()
			var b2 = BULLET_SCENE.instantiate()
			if get_tree().current_scene != null:
				if b1 != null:
					get_tree().current_scene.add_child(b1)
					if b1.has_method("setup"):
						b1.call("setup", Vector2(left, -20.0))
					else:
						b1.global_position = Vector2(left, -20.0)
				if b2 != null:
					get_tree().current_scene.add_child(b2)
					if b2.has_method("setup"):
						b2.call("setup", Vector2(right, -20.0))
					else:
						b2.global_position = Vector2(right, -20.0)
		# wait 0.5s between waves, but abort early if crystallization ends
		var t = get_tree().create_timer(0.5)
		await t.timeout
		if boss == null or not boss.crystallization_active:
			break
	if boss == null:
		return
	await get_tree().create_timer(1.5).timeout
	if boss == null or not boss.crystallization_active:
		return
	boss.global_position.x = 80.0
	boss.velocity = Vector2.ZERO
	spawn_complete = true
	change_state(6)
