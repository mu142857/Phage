# 木头人 死亡状态(2 号)：木偶师血空 → 线断了 → 人偶软掉砸到地上 → 方块粒子炸开
# → 淡出 → queue_free。木偶师自己等所有人偶掉完再收场(DreamEnd 盯的是木偶师)。
extends BasicState

@export var fall_gravity: float = 700.0
@export var land_shake: float = 3.0
@export var fade_time: float = 0.6

@onready var monster: CharacterBody2D = $"../.."

var _landed: bool = false
var is_active: bool = false


func enter() -> void:
	is_active = true
	_landed = false
	monster.hittable = false
	monster.velocity = Vector2.ZERO
	monster.slash_hitbox.monitoring = false
	monster.set_deferred("collision_layer", 0)
	monster.play_anim(&"Idle")
	if monster.global_position.y >= monster.floor_y - 0.5:
		_on_land()


func process(delta: float) -> void:
	if not is_active or _landed:
		return
	monster.velocity.y += fall_gravity * delta
	monster.global_position.y += monster.velocity.y * delta
	if monster.global_position.y >= monster.floor_y:
		monster.global_position.y = monster.floor_y
		_on_land()


func exit() -> void:
	is_active = false


func _on_land() -> void:
	_landed = true
	monster.velocity = Vector2.ZERO
	Game.shake_camera(land_shake)
	monster.spawn_death_effect()
	var tw := create_tween()
	tw.tween_property(monster, "modulate:a", 0.0, fade_time)
	tw.tween_callback(monster.queue_free)
