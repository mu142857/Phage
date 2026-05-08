extends GPUParticles2D

func _on_timer_timeout() -> void:
	queue_free()


func _on_gpu_particles_2d_finished() -> void:
	pass # Replace with function body.
