# 木头人 化开状态(4 号)：变身后的形态打完一套就散掉(淡出 + 方块粒子)，
# 然后告诉木偶师「我没了」，木偶师隔一会儿再放一只新的下来(respawn → Descend)。
# 散开期间打不到、没判定。
extends BasicState

@export var fade_time: float = 0.35
@export var particles: bool = true

@onready var monster: CharacterBody2D = $"../.."

var _tween: Tween = null


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.hittable = false
	monster.slash_hitbox.monitoring = false
	if particles:
		monster.spawn_death_effect()
	_tween = create_tween()
	_tween.tween_property(monster, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(_on_faded)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_faded() -> void:
	monster.change_state(monster.STATE_NULL)
	monster.on_vanished()
