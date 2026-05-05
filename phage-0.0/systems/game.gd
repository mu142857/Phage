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

@onready var colour_rect1: ColorRect = $CanvasLayer/ColorRect1
@onready var colour_rect2: ColorRect = $CanvasLayer/ColorRect2

var shake_strength: float = 0.0
var blink_time_1: float = 0.0
var blink_time_2: float = 0.0
var rect1_colour: Color = Color(1, 1, 1, 1)
var rect2_colour: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	make_current()
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

func flash(amount: float, colour: Color) -> void:
	screen_flash.emit(amount, colour)

func filter(amount: float, colour: Color) -> void:
	screen_filter.emit(amount, colour)

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
