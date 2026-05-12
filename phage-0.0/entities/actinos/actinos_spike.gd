extends Area2D

func _on_animated_sprite_2d_animation_finished() -> void:
	queue_free()

func _ready() -> void:
	$AnimatedSprite2D.play("Attack")

func attack_check():
	pass
