# =============================================================================
# Null(0)  —  空状态：什么都不做（被打断/等待外部驱动时停这里，不碰动画）
# =============================================================================
extends BasicState


func enter() -> void:
	# 开场停在这里等玩家进场，先摆待机
	var ani := $"../../AnimatedSprite2D" as AnimatedSprite2D
	if is_instance_valid(ani):
		ani.play(&"Idle")


func process(_delta: float) -> void:
	pass


func exit() -> void:
	pass
