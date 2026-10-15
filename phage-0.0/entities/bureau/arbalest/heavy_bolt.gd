# 管道局的重弩箭:又快又直。打主角(射出去那会儿主角算敌人才打)、打奥斯卡帮;穿过自己人不伤。
# 扎到墙/地上钉一会儿再淡掉。
extends Area2D

@export var stick_time: float = 0.6
@export var max_life: float = 2.0
@export var damage: int = 90

var shooter: Node = null
var hits_player := true

var _v := Vector2.ZERO
var _life := 0.0
var _stuck := false


func launch(v: Vector2) -> void:
	_v = v
	rotation = v.angle()


func _ready() -> void:
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	_life += delta
	if _stuck:
		if _life > max_life - stick_time:
			modulate.a = clampf(1.0 - (_life - (max_life - stick_time)) / stick_time, 0.0, 1.0)
		if _life > max_life:
			queue_free()
		return
	var step := _v * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + _v.normalized() * 2.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider as Node).has_method("_drop"):
		global_position = hit.position - _v.normalized() * 2.0
		_stuck = true
		_life = max_life - stick_time - 0.4
		return
	global_position += step
	if _life > max_life:
		queue_free()


func _on_body(body: Node2D) -> void:
	if _stuck:
		return
	if body is GangMob:
		var m := body as GangMob
		if m.faction() == &"bureau" or m.health <= 0:
			return
		m.take_hit(damage, global_position.x - signf(_v.x) * 4.0, shooter if is_instance_valid(shooter) else null)
		queue_free()
		return
	if body.is_in_group("player") and hits_player and body.has_method("take_damage"):
		body.call("take_damage", 1)
		queue_free()
