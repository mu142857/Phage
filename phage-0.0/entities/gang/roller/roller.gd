# 滚桶的:扛着一只锈油桶。离你不远不近的时候放下来,抬脚(前摇)一脚踹过去,
# 桶贴着地面滚过来(跳过去,或者一刀砍碎)。然后从身后再摸一只扛上肩。
extends GangMob

const BARREL: PackedScene = preload("res://entities/gang/roller/rolling_barrel.tscn")

@export var kick_frame: int = 6
@export var min_range: float = 26.0
@export var max_range: float = 150.0
@export var barrel_speed: float = 85.0

var _kicked := false


func _engage(_delta: float) -> void:
	var p := player()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	var dist := absf(dx)
	face(signf(dx))
	if dist > max_range:
		walk(facing, move_speed)
		return
	if cooldown <= 0.0 and dist >= min_range:
		start_attack(&"Kick")
		return
	if dist < min_range and floor_ahead(-facing):
		# 太近了踹不开:往后挪两步
		velocity.x = -facing * move_speed
		play(&"Walk")
		return
	velocity.x = _separation()
	play(&"Idle")


func _on_attack_started() -> void:
	_kicked = false


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation == &"Kick" and sprite.frame >= kick_frame and not _kicked:
		_kicked = true
		var scene := get_tree().current_scene
		if scene != null:
			var b := BARREL.instantiate() as Node2D
			b.position = global_position + Vector2(facing * 16.0, 0.0)
			scene.add_child(b)
			b.call("roll", facing * barrel_speed)


func _end_attack() -> void:
	state = S.CUSTOM
	play_once(&"Fetch", func() -> void:
		cooldown = attack_cooldown
		state = S.ENGAGE)
