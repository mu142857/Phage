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
@export var teleport_fade_duration: float = 0.08
@export var teleport_fade_in_duration: float = 0.35

@export var follow_offset: Vector2 = Vector2(0, -20)
@export var follow_horizontal_speed: float = 18.0
@export var follow_vertical_down_speed: float = 18.0
@export var follow_vertical_up_speed: float = 4.0
@export var follow_vertical_up_deadzone: float = 12.0

const CAMERA_FOLLOW_GROUP: StringName = &"camera_follow"
const CAMERA_FIXED_GROUP: StringName = &"camera_fixed"
const TELEPORT_GROUP: StringName = &"teleport"
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const PLAYER_LIGHT_SCENE: PackedScene = preload("res://entities/player/player_light.tscn")
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
var teleport_transition_tween: Tween = null
var teleport_transition_layer: CanvasLayer = null
var teleport_transition_rect: ColorRect = null
var teleport_transition_active: bool = false

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
		var target_position := follow_target.global_position + follow_offset
		var follow_position := global_position
		var x_alpha := clampf(delta * follow_horizontal_speed, 0.0, 1.0)
		follow_position.x = lerpf(follow_position.x, target_position.x, x_alpha)
		var y_delta := target_position.y - follow_position.y
		if y_delta > 0.0:
			var down_alpha := clampf(delta * follow_vertical_down_speed, 0.0, 1.0)
			follow_position.y = lerpf(follow_position.y, target_position.y, down_alpha)
		elif y_delta < -follow_vertical_up_deadzone:
			var up_alpha := clampf(delta * follow_vertical_up_speed, 0.0, 1.0)
			follow_position.y = lerpf(follow_position.y, target_position.y, up_alpha)
		global_position = follow_position
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


func change_scene(scene_path: String, teleport_id: int, player_light: bool) -> void:
	if teleport_transition_active:
		return
	if scene_path.is_empty():
		return
	teleport_transition_active = true
	await _play_teleport_fade(1.0, teleport_fade_duration)
	var tree := get_tree()
	if tree == null:
		teleport_transition_active = false
		return
	tree.change_scene_to_file(scene_path)
	await tree.process_frame
	await tree.process_frame
	var current_scene := tree.current_scene
	if not is_instance_valid(current_scene):
		teleport_transition_active = false
		await _play_teleport_fade(0.0, teleport_fade_in_duration)
		return
	var target_teleport := _find_teleport_by_id(current_scene, teleport_id)
	var target_position := Vector2.ZERO
	if is_instance_valid(target_teleport):
		target_position = target_teleport.global_position
	var player := _find_player_in_current_scene(current_scene)
	if not is_instance_valid(player):
		player = PLAYER_SCENE.instantiate() as Player
		current_scene.add_child(player)
	if is_instance_valid(player):
		player.global_position = target_position
		# Ensure player's sprite modulate is normalized so adding/removing lights
		# does not inadvertently change perceived brightness.
		if player is Player:
			if is_instance_valid(player.sprite):
				player.sprite.modulate = Color(1, 1, 1, 1)
		_ensure_player_light(player, player_light)
		_set_player_lock(true)
	await _play_teleport_fade(0.0, teleport_fade_in_duration)
	_set_player_lock(false)
	teleport_transition_active = false


func _find_teleport_by_id(root: Node, teleport_id: int) -> Node2D:
	if not is_instance_valid(root):
		return null
	if root is Node2D and root.get("teleport_id") == teleport_id:
		return root
	for child in root.get_children():
		var match := _find_teleport_by_id(child, teleport_id)
		if is_instance_valid(match):
			return match
	return null


func _find_player_in_current_scene(root: Node) -> Player:
	if not is_instance_valid(root):
		return null
	if root is Player:
		return root
	for child in root.get_children():
		var player := _find_player_in_current_scene(child)
		if is_instance_valid(player):
			return player
	return null


func _ensure_player_light(player: Player, enabled: bool) -> void:
	if not enabled:
		return
	if player.find_child("PlayerLight", true, false) != null:
		return
	if PLAYER_LIGHT_SCENE == null:
		return
	var light := PLAYER_LIGHT_SCENE.instantiate()
	player.add_child(light)
	if light is Node2D:
		(light as Node2D).position = Vector2.ZERO


func _play_teleport_fade(target_alpha: float, duration: float) -> void:
	var rect := _get_teleport_transition_rect()
	if rect == null:
		return
	if is_instance_valid(teleport_transition_tween):
		teleport_transition_tween.kill()
	rect.visible = true
	teleport_transition_tween = create_tween()
	teleport_transition_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	teleport_transition_tween.tween_property(rect, "color:a", target_alpha, duration)
	await teleport_transition_tween.finished
	if target_alpha <= 0.0 and is_instance_valid(rect):
		rect.visible = false


func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	if player.has_method("set_lock"):
		player.call("set_lock", locked)


func _get_teleport_transition_rect() -> ColorRect:
	if is_instance_valid(teleport_transition_rect):
		return teleport_transition_rect
	if not is_instance_valid(teleport_transition_layer):
		teleport_transition_layer = CanvasLayer.new()
		teleport_transition_layer.name = "TeleportTransitionLayer"
		teleport_transition_layer.layer = 1000
		add_child(teleport_transition_layer)
	teleport_transition_rect = ColorRect.new()
	teleport_transition_rect.name = "TeleportTransitionRect"
	teleport_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	teleport_transition_rect.offset_left = 0.0
	teleport_transition_rect.offset_top = 0.0
	teleport_transition_rect.offset_right = 0.0
	teleport_transition_rect.offset_bottom = 0.0
	teleport_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	teleport_transition_rect.color = Color(0, 0, 0, 0)
	teleport_transition_layer.add_child(teleport_transition_rect)
	return teleport_transition_rect
