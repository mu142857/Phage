extends Area2D

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()

func _ready() -> void:
	$AnimatedSprite2D.play("Attack")

func attack_check():
	var arr = $CollisionPolygon2D.get_overlapping_bodies()
	for i in arr:
		if i.is_in_group("player"):
			i.take_damage(5)
