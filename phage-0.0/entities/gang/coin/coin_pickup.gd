# 掉在地上的一个铜板:蹦出来、落地弹一下,过 0.35 秒才能捡(不然一出来就被站在旁边的主角吸走,看不见)。
# 主角走近就往他身上飞,碰到 +1。不会消失,离开巷子才没了。
extends Area2D

const PICK_DELAY := 0.35
const MAGNET := 14.0

var velocity := Vector2.ZERO
var _t := 0.0
var _landed := false
var _taken := false
var _skip: Array[RID] = []

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body)
	var scene := get_tree().current_scene
	if scene != null:
		for n in scene.find_children("*", "StaticBody2D", true, false):
			if n.has_method("_drop"):
				_skip.append((n as StaticBody2D).get_rid())


func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if _t > PICK_DELAY and p != null:
		var to := p.global_position + Vector2(0, -5) - global_position
		if to.length() < MAGNET:
			global_position += to.normalized() * minf(to.length(), 160.0 * delta)
			_check_overlap()
			return
	if _landed:
		sprite.position.y = -1.0 if fmod(_t, 0.9) < 0.45 else 0.0
		_check_overlap()
		return
	velocity.y += 420.0 * delta
	var step := velocity * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + Vector2(0, 1), 1)
	q.exclude = _skip
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position - Vector2(0, 0.1)
		if absf(hit.normal.y) > 0.5 and velocity.y > 60.0:
			velocity = Vector2(velocity.x * 0.5, -velocity.y * 0.35)
		elif absf(hit.normal.y) > 0.5:
			_landed = true
			velocity = Vector2.ZERO
		else:
			velocity.x = -velocity.x * 0.4
	else:
		global_position += step
	_check_overlap()


func _check_overlap() -> void:
	if _t <= PICK_DELAY or _taken:
		return
	for b in get_overlapping_bodies():
		_on_body(b)


func _on_body(body: Node2D) -> void:
	if _taken or _t <= PICK_DELAY or not body.is_in_group("player"):
		return
	_taken = true
	Story.set_flag("coins_seen", true)
	Story.add_coins(1)
	queue_free()
