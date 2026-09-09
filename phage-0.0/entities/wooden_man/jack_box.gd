# =============================================================================
# jack_box.gd  —  惊喜盒子：木偶师的手从屏幕顶扔出来的盒子
# =============================================================================
# 抛物线砸向主角；空中砸到主角 = 硬控 stun_time 秒(不掉血，player.apply_stun)；
# 落到地上播 Land → 停 pop_delay → 播 Pop 弹出小丑头(pop_scene，空=只弹不出怪)
# → 自删。不许凭空消失：飞出屏幕靠 VisibleOnScreenNotifier2D 删，兜底寿命到点淡出。
# 动画名(用户导帧)：Fly(循环) / Land / Pop
# =============================================================================
extends Area2D

@export var flight_time: float = 0.9
@export var fall_gravity: float = 500.0
@export var target_jitter: float = 6.0
@export var stun_time: float = 0.9
@export var floor_y: float = 80.0
@export var pop_delay: float = 0.7
@export var pop_fallback_time: float = 0.5   # 没有 Pop 动画时的弹出时长
@export var pop_scene: PackedScene = null
@export var lifetime: float = 8.0

var _velocity: Vector2 = Vector2.ZERO
var _flying: bool = false
var _landed: bool = false
var _stunned_once: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	z_index = 12
	add_to_group("puppeteer_spawn")
	collision_layer = 0
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	var notifier := get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
	if notifier != null and not notifier.screen_exited.is_connected(_on_screen_exited):
		notifier.screen_exited.connect(_on_screen_exited)
	_play(&"Fly")
	_lifetime_guard()


func launch(from: Vector2, target: Vector2) -> void:
	global_position = from
	target.x += randf_range(-target_jitter, target_jitter)
	target.y = floor_y
	_velocity.x = (target.x - from.x) / flight_time
	_velocity.y = (target.y - from.y - 0.5 * fall_gravity * flight_time * flight_time) / flight_time
	_flying = true


func _physics_process(delta: float) -> void:
	if not _flying or _landed:
		return
	_velocity.y += fall_gravity * delta
	global_position += _velocity * delta
	if _velocity.y > 0.0 and global_position.y >= floor_y:
		_land()


func _land() -> void:
	_landed = true
	_flying = false
	global_position.y = floor_y
	set_deferred("monitoring", false)
	Game.shake_camera(1.2)
	_play(&"Land")
	_pop_sequence()


func _pop_sequence() -> void:
	await get_tree().create_timer(pop_delay).timeout
	if not is_inside_tree():
		return
	if _has(&"Pop"):
		_play(&"Pop")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(pop_fallback_time).timeout
	if not is_inside_tree():
		return
	_spawn_pop()
	queue_free()


func _spawn_pop() -> void:
	if pop_scene == null or get_tree().current_scene == null:
		return
	var m := pop_scene.instantiate() as Node2D
	if m == null:
		return
	m.add_to_group("puppeteer_minion")
	m.global_position = global_position
	get_tree().current_scene.add_child(m)


func _on_body_entered(body: Node2D) -> void:
	if _landed or _stunned_once or body == null or not body.is_in_group("player"):
		return
	_stunned_once = true
	if body.has_method("apply_stun"):
		body.call("apply_stun", stun_time)
	Game.shake_camera(1.5)


func cancel() -> void:
	# 木偶师死了：还在飞的盒子淡出
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _on_screen_exited() -> void:
	if not _landed:
		queue_free()


func _lifetime_guard() -> void:
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		cancel()


func _has(anim: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) \
			and sprite.sprite_frames.get_frame_count(anim) > 0


func _play(anim: StringName) -> void:
	if _has(anim):
		sprite.play(anim)
