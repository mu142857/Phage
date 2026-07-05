# =============================================================================
# Death(2)  —  死亡：放死亡特效后移除本体（与 cursed_stone 同款做法）
# =============================================================================
extends BasicState

@onready var monster: CharacterBody2D = $"../.."


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.spawn_death_effect()
	monster.queue_free()


func process(_delta: float) -> void:
	pass


func exit() -> void:
	pass
