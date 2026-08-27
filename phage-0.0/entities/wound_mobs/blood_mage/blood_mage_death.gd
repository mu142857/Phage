# 血法师死亡特效 — wowen 式方形粒子爆炸(红袍+金饰配色)
extends GPUParticles2D


func _on_timer_timeout() -> void:
	queue_free()
