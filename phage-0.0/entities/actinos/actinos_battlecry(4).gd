extends BasicState

@export var duration: float = 3.0
@export var shake_amount: float = 6.0
@export var zoom_amount: float = 0.85
@export var zoom_duration: float = 0.2

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"

var is_active: bool = false

func enter() -> void:
	is_active = true
	_play_battlecry_animation()
	_set_player_lock(true)
	Game.zoom_to(Vector2(zoom_amount, zoom_amount), zoom_duration)
	_start_timer()

func process(_delta: float) -> void:
	if is_active:
		Game.shake_camera(shake_amount)

func exit() -> void:
	is_active = false
	_set_player_lock(false)
	Game.stop_shake()
	Game.reset_zoom(zoom_duration)

func _start_timer() -> void:
	var timer := get_tree().create_timer(duration)
	await timer.timeout
	if is_active:
		Game.stop_shake()
		change_state(1)

func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	if player.has_method("set_lock"):
		player.call("set_lock", locked)

func _play_battlecry_animation() -> void:
	if not is_instance_valid(ani_2D):
		return
	ani_2D.play(&"Battlecry")
