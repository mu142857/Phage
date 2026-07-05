# =============================================================================
# small_sickle.gd  —  小镰刀：先绕椭圆炫转，再追踪玩家（Start→Spin→落地 Stop）
# =============================================================================
# 移植自旧「小镰刀.gd」。成对生成(_direction 左右)，先绕一小圈椭圆当前摇，
# 然后转为追踪飞向玩家，落地炸开。
# =============================================================================
extends Area2D

enum Phase { INITIAL, TRACKING }

@export var ellipse_width: float = 26.0
@export var ellipse_height: float = -26.0
@export var base_ang_speed: float = 10.0
@export var ang_accel: float = 1.2
@export var initial_lifetime: float = 0.6   # 椭圆阶段时长
@export var track_speed: float = 95.0
@export var track_speed_cap: float = 130.0
@export var track_turn_rate: float = 0.12
@export var land_y: float = 82.0
@export var damage: int = 9
@export var lifetime: float = 8.0
@export var shake_amount: float = 2.0

var _direction: int = 1        # 由 boss 设置：1=顺时针 / -1=逆时针
var _phase: int = Phase.INITIAL
var _a: float = 0.0
var _b: float = 0.0
var _theta: float = 0.0
var _ang_vel: float = 0.0
var _timer: float = 0.0
var _center: Vector2 = Vector2.ZERO
var _landed: bool = false


func _ready() -> void:
	z_index = 1
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not $AnimatedSprite2D.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		$AnimatedSprite2D.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	$AnimatedSprite2D.play(&"Start")
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	if _landed:
		return
	if global_position.y >= land_y and _phase == Phase.TRACKING:
		_land()
		return
	if $AnimatedSprite2D.animation != &"Spin":
		return
	if _phase == Phase.INITIAL:
		_initial_phase(delta)
	else:
		_tracking_phase(delta)


func _initial_phase(delta: float) -> void:
	_timer += delta
	if _timer >= initial_lifetime:
		var player := _find_player()
		if player != null:
			rotation = (player.global_position - global_position).angle()
		_phase = Phase.TRACKING
		return
	_ang_vel += ang_accel * delta
	_theta += float(_direction) * _ang_vel * delta
	global_position = _center + Vector2(_a * cos(_theta), _b * sin(_theta))
	rotation += float(_direction) * PI * 2.0 * delta


func _tracking_phase(delta: float) -> void:
	var player := _find_player()
	if player != null:
		var target_angle := (player.global_position - global_position).angle()
		rotation = lerp_angle(rotation, target_angle, track_turn_rate)
	global_position += Vector2(cos(rotation), sin(rotation)) * track_speed * delta
	track_speed = minf(track_speed + 12.0 * delta, track_speed_cap)


func _land() -> void:
	_landed = true
	global_position.y = land_y
	rotation = 0.0
	Game.shake_camera(shake_amount)
	Game.flash(0.12, Color(1.6, 0.5, 0.9, 0.4))
	$AnimatedSprite2D.play(&"Stop")


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == &"Start":
		$AnimatedSprite2D.play(&"Spin")
		_a = ellipse_width / 2.0
		_b = ellipse_height / 2.0
		_theta = 3.0 * PI / 2.0            # 从椭圆底部起转
		_center = global_position + Vector2(0, _b)
		_ang_vel = base_ang_speed
	elif $AnimatedSprite2D.animation == &"Stop":
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _landed or $AnimatedSprite2D.animation != &"Spin":
		return
	if body != null and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
