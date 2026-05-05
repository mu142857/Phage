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

const CAMERA_FOLLOW_GROUP: StringName = &"camera_follow"
const CAMERA_FIXED_GROUP: StringName = &"camera_fixed"

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
var zoom_tween: Tween = null
var position_override: Vector2 = Vector2.ZERO
var position_override_enabled: bool = false

func _ready() -> void:
	make_current()
	default_zoom = zoom
	screen_shake.connect(_on_screen_shake)
	screen_flash.connect(_on_screen_flash)
	screen_filter.connect(_on_screen_filter)
	if is_instance_valid(colour_rect1):
		colour_rect1.color = Color(rect1_colour.r, rect1_colour.g, rect1_colour.b, 0.0)
		colour_rect1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(colour_rect2):
		colour_rect2.color = Color(rect2_colour.r, rect2_colour.g, rect2_colour.b, 0.0)
		colour_rect2.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_update_camera_mode()
	_update_follow_target()
	if position_override_enabled:
		global_position = position_override
	elif follow_player and is_instance_valid(follow_target):
		global_position = follow_target.global_position
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

func _update_camera_mode() -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	if position_override_enabled:
		follow_player = false
		follow_target = null
		return
	if scene.is_in_group(CAMERA_FIXED_GROUP):
		follow_player = false
		follow_target = null
		global_position = Vector2.ZERO
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
	position_override = position
	position_override_enabled = true

func clear_position_override() -> void:
	position_override_enabled = false
