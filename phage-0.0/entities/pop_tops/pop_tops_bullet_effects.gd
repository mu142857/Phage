extends GPUParticles2D

func _ready() -> void:
	emitting = true
	Game.shake_camera(1)

func _on_timer_timeout() -> void:
	queue_free()
