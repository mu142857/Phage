# 一袋"保护费":从天上掉下来,落地弹一下,主角碰到就进钱包,头顶冒"+12"。
extends Area2D

const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")

@export var coins: int = 10
@export var gravity_px: float = 500.0

var _vy := 0.0
var _landed := false
var _t := 0.0
var _taken := false

@onready var sprite: Sprite2D = $Sprite2D


var _skip: Array[RID] = []


func _ready() -> void:
	body_entered.connect(_on_body)
	# 穿过消防梯那种单向平台,一直落到地面(不然挂在半空够不着)
	var scene := get_tree().current_scene
	if scene != null:
		for n in scene.find_children("*", "StaticBody2D", true, false):
			if n.has_method("_drop"):
				_skip.append((n as StaticBody2D).get_rid())


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		_vy += gravity_px * delta
		var step := _vy * delta
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, step + 1.0), 1)
		q.exclude = _skip
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and _vy > 0.0:
			global_position.y = hit.position.y
			if _vy > 120.0:
				_vy = -_vy * 0.3   # 弹一下
				Game.shake_camera(1.0)
			else:
				_vy = 0.0
				_landed = true
		else:
			global_position.y += step
	else:
		sprite.position.y = -4.0 - round(sin(_t * 4.0))


func _on_body(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Story.set_flag("coins_seen", true)
	Story.add_coins(coins)
	var label := Label.new()
	label.text = "+%d" % coins
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.5))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 12)
	label.z_index = 30
	label.light_mask = 0
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-20, -24)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 10.0, 0.9)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(label.queue_free)
	queue_free()
