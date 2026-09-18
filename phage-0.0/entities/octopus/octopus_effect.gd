# 大章鱼的一次性粒子(子弹落地 / 死亡炸开):Timer 到点把自己删掉
extends GPUParticles2D


func _on_timer_timeout() -> void:
	queue_free()
