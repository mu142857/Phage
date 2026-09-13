# 珊瑚摇篮杂兵共用的死亡/破碎特效 — wowen 式方形粒子爆炸(配色在各自 tscn 里按贴图主色调)
extends GPUParticles2D


func _on_timer_timeout() -> void:
	queue_free()
