# res://systems/game.tscn
extends Camera2D

signal screen_shake(amount: float)
signal screen_flash(amount: float, colour: Color)
signal screen_filter(amount: float, colour: Color)

@export var recovery_speed: float = 32.0
@export var blink_duration_1: float = 0.2
@export var max_blink_alpha_1: float = 1.0
@export var blink_duration_2: float = 0.2
@export var max_blink_alpha_2: float = 1.0
@export var hit_stop_duration: float = 0.035
@export var hit_recover_duration: float = 0.18
@export var hit_flash_duration: float = 0.4
@export var hit_flash_color: Color = Color(1.0, 0.1, 0.1, 0.16)

@export var follow_offset: Vector2 = Vector2(0, -20)

const CAMERA_FOLLOW_GROUP: StringName = &"camera_follow"
const CAMERA_FIXED_GROUP: StringName = &"camera_fixed"
const ANCHOR_FOLLOW: int = Camera2D.ANCHOR_MODE_DRAG_CENTER
const ANCHOR_FIXED: int = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT

@onready var flash_layer: CanvasLayer = $CanvasLayer
@onready var colour_rect1: ColorRect = $CanvasLayer/ColorRect1
@onready var colour_rect2: ColorRect = $CanvasLayer/ColorRect2

var shake_strength: float = 0.0
var blink_time_1: float = 0.0
var blink_time_2: float = 0.0
var rect1_colour: Color = Color(1, 1, 1, 1)
var rect2_colour: Color = Color(1, 1, 1, 1)
var follow_target: Node2D = null
var follow_player: bool = true
var default_zoom: Vector2 = Vector2.ONE
var default_limit_left: int = 0
var default_limit_right: int = 0
var default_limit_top: int = 0
var default_limit_bottom: int = 0
var zoom_tween: Tween = null
var position_override: Vector2 = Vector2.ZERO
var position_override_enabled: bool = false
var position_override_tween: Tween = null
var slowmo_token: int = 0

func _ready() -> void:
	make_current()
	default_zoom = zoom
	default_limit_left = limit_left
	default_limit_right = limit_right
	default_limit_top = limit_top
	default_limit_bottom = limit_bottom
	screen_shake.connect(_on_screen_shake)
	screen_flash.connect(_on_screen_flash)
	screen_filter.connect(_on_screen_filter)
	if is_instance_valid(colour_rect1):
		colour_rect1.color = Color(rect1_colour.r, rect1_colour.g, rect1_colour.b, 0.0)
		colour_rect1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(colour_rect2):
		colour_rect2.color = Color(rect2_colour.r, rect2_colour.g, rect2_colour.b, 0.0)
		colour_rect2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(flash_layer) and not flash_layer.visible:
		flash_layer.visible = true

func _process(delta: float) -> void:
	_update_camera_mode()
	_update_follow_target()
	if position_override_enabled:
		global_position = position_override
	elif follow_player and is_instance_valid(follow_target):
		global_position = follow_target.global_position + follow_offset
	elif not follow_player:
		global_position = Vector2.ZERO

	if shake_strength > 0.0:
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_strength = move_toward(shake_strength, 0.0, recovery_speed * delta)
	else:
		offset = Vector2.ZERO


	if is_instance_valid(colour_rect1):
		if blink_time_1 > 0.0:
			var alpha_1 := (blink_time_1 / blink_duration_1) * max_blink_alpha_1
			colour_rect1.color = Color(rect1_colour.r, rect1_colour.g, rect1_colour.b, alpha_1)
			blink_time_1 = max(blink_time_1 - delta, 0.0)
		else:
			colour_rect1.color = Color(rect1_colour.r, rect1_colour.g, rect1_colour.b, 0.0)

	if is_instance_valid(colour_rect2):
		if blink_time_2 > 0.0:
			var alpha_2 := (blink_time_2 / blink_duration_2) * max_blink_alpha_2
			colour_rect2.color = Color(rect2_colour.r, rect2_colour.g, rect2_colour.b, alpha_2)
			blink_time_2 = max(blink_time_2 - delta, 0.0)
		else:
			colour_rect2.color = Color(rect2_colour.r, rect2_colour.g, rect2_colour.b, 0.0)

func shake_camera(amount: float) -> void:
	screen_shake.emit(amount)

func stop_shake() -> void:
	shake_strength = 0.0

func flash(amount: float, colour: Color) -> void:
	screen_flash.emit(amount, colour)

func filter(amount: float, colour: Color) -> void:
	screen_filter.emit(amount, colour)

func play_hit_feedback() -> void:
	_play_hit_flash()
	_apply_hit_stop(hit_stop_duration, hit_recover_duration)

func zoom_to(target_zoom: Vector2, duration: float = 0.2) -> void:
	if is_instance_valid(zoom_tween):
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", target_zoom, duration)

func reset_zoom(duration: float = 0.2) -> void:
	zoom_to(default_zoom, duration)

func _on_screen_shake(amount: float) -> void:
	shake_strength = max(shake_strength, amount)

func _on_screen_flash(amount: float, colour: Color) -> void:
	blink_time_1 = blink_duration_1 * amount
	rect1_colour = colour
	max_blink_alpha_1 = colour.a

func _on_screen_filter(amount: float, colour: Color) -> void:
	blink_time_2 = blink_duration_2 * amount
	rect2_colour = colour
	max_blink_alpha_2 = colour.a

func _play_hit_flash() -> void:
	blink_time_2 = maxf(hit_flash_duration, 0.0)
	rect2_colour = hit_flash_color
	max_blink_alpha_2 = hit_flash_color.a

func _apply_hit_stop(stop_duration: float, recover_duration: float) -> void:
	if stop_duration <= 0.0 or recover_duration <= 0.0:
		return
	slowmo_token += 1
	var token := slowmo_token
	Engine.time_scale = 0.0
	await get_tree().create_timer(stop_duration, false, false, true).timeout
	if token != slowmo_token:
		return
	var elapsed := 0.0
	while elapsed < recover_duration:
		await get_tree().create_timer(0.01, false, false, true).timeout
		if token != slowmo_token:
			return
		elapsed = minf(elapsed + 0.01, recover_duration)
		var t := elapsed / recover_duration
		var eased := 1.0 - pow(1.0 - t, 3.0)
		Engine.time_scale = eased
	Engine.time_scale = 1.0

func _update_camera_mode() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	_apply_scene_camera_limits(scene)
	if scene.is_in_group(CAMERA_FIXED_GROUP):
		anchor_mode = ANCHOR_FIXED
	else:
		anchor_mode = ANCHOR_FOLLOW
	if position_override_enabled:
		follow_player = false
		follow_target = null
		return
	if scene.is_in_group(CAMERA_FIXED_GROUP):
		follow_player = false
		follow_target = null
		# Allow scenes to specify their own fixed camera origin by
		# implementing `func get_camera_fixed_position() -> Vector2` on
		# the scene root. If not present, default to top-left (0,0).
		var fixed_pos: Vector2 = Vector2.ZERO
		if is_instance_valid(scene) and scene.has_method("get_camera_fixed_position"):
			fixed_pos = scene.call("get_camera_fixed_position")
		global_position = fixed_pos
		return
	if scene.is_in_group(CAMERA_FOLLOW_GROUP):
		follow_player = true
		return
	follow_player = true

func _update_follow_target() -> void:
	if not follow_player:
		return
	if is_instance_valid(follow_target):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var candidate := players[0]
	if candidate is Node2D:
		follow_target = candidate

func set_position_override(position: Vector2) -> void:
	if is_instance_valid(position_override_tween):
		position_override_tween.kill()
	position_override = position
	position_override_enabled = true

func set_position_override_smooth(position: Vector2, duration: float = 0.2) -> void:
	if duration <= 0.0:
		set_position_override(position)
		return
	if is_instance_valid(position_override_tween):
		position_override_tween.kill()
	position_override_enabled = true
	position_override = global_position
	position_override_tween = create_tween()
	position_override_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	position_override_tween.tween_property(self, "position_override", position, duration)

func clear_position_override() -> void:
	if is_instance_valid(position_override_tween):
		position_override_tween.kill()
	position_override_enabled = false

func clear_position_override_smooth(duration: float = 0.2) -> void:
	if not position_override_enabled:
		return
	if duration <= 0.0:
		clear_position_override()
		return
	if is_instance_valid(position_override_tween):
		position_override_tween.kill()
	var target_position := position_override
	if follow_player and is_instance_valid(follow_target):
		target_position = follow_target.global_position + follow_offset
	elif not follow_player:
		target_position = Vector2.ZERO
	var tween := create_tween()
	position_override_tween = tween
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position_override", target_position, duration)
	await tween.finished
	if position_override_tween != tween:
		return
	position_override_tween = null
	position_override_enabled = false

func set_camera_limits(left: int, right: int, top: int, bottom: int) -> void:
	limit_left = left
	limit_right = right
	limit_top = top
	limit_bottom = bottom
	limit_enabled = true

func _apply_scene_camera_limits(scene: Node) -> void:
	if scene.has_method("get_camera_limits"):
		var limits = scene.call("get_camera_limits")
		if limits is Dictionary:
			set_camera_limits(
				int((limits as Dictionary).get("left", default_limit_left)),
				int((limits as Dictionary).get("right", default_limit_right)),
				int((limits as Dictionary).get("top", default_limit_top)),
				int((limits as Dictionary).get("bottom", default_limit_bottom))
			)
			return
	set_camera_limits(default_limit_left, default_limit_right, default_limit_top, default_limit_bottom)
