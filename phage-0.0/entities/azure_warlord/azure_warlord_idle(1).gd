extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

@export var intro_zoom_amount: float = 1.15
@export var intro_zoom_duration: float = 0.20
@export var intro_camera_focus_position: Vector2 = Vector2(16.0, 9.0)
@export var intro_camera_move_duration: float = 0.25

var idle_ticket: int = 0
var intro_active: bool = false

func enter() -> void:
	idle_ticket += 1
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Idle")
	intro_active = false
	if boss != null and not boss.intro_shown:
		boss.intro_shown = true
		intro_active = true
		if boss.has_method("show_health_ui"):
			boss.call("show_health_ui")
		_set_front_visible(true)
		Game.set_position_override_smooth(intro_camera_focus_position, intro_camera_move_duration)
		Game.zoom_to(Vector2(intro_zoom_amount, intro_zoom_amount), intro_zoom_duration)
	var duration := 1.0
	if boss != null:
		duration = boss.get_idle_time()
	_start_idle_timer(duration, idle_ticket)

func exit() -> void:
	idle_ticket += 1
	if intro_active:
		_set_front_visible(false)
		Game.clear_position_override_smooth(intro_camera_move_duration)
		Game.reset_zoom(intro_zoom_duration)
		intro_active = false

func _start_idle_timer(duration: float, ticket: int) -> void:
	await get_tree().create_timer(duration).timeout
	if ticket != idle_ticket:
		return
	change_state(2)

func _set_front_visible(visible: bool) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var front := scene.get_node_or_null("Front") as CanvasLayer
	if front == null:
		return
	front.visible = visible
