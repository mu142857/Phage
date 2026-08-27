# 红丝虫爆体特效 — wowen 式方形粒子爆炸(boss 体型，粒子加量)
extends GPUParticles2D


func _on_timer_timeout() -> void:
	queue_free()
