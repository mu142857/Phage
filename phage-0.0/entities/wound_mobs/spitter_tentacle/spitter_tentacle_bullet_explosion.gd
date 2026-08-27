# 喷吐触手子弹的爆炸粒子 — wowen 式方形粒子(配色=子弹主色，alpha 头尾渐变)
extends GPUParticles2D


func _on_timer_timeout() -> void:
	queue_free()
