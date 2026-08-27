# 血蛛死亡特效 — wowen 式方形粒子爆炸(配色=贴图主色)
extends GPUParticles2D


func _on_timer_timeout() -> void:
	queue_free()
