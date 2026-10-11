# res://systems/npc/npc.gd
# 会说话的 NPC 通用节点(铁锈城起用)。节点原点 = 脚底中点,贴图朝右画。
# - 主角走到 talk_radius 以内:头顶冒"…"提示,按 Q(触屏:攻击键)搭话。
#   搭话时调用 on_talk(关卡剧情脚本给的协程);没设就只发 talked 信号。
# - bark(text):头顶冒一句小字(叫住你、自言自语),几秒后淡掉,不打断操作。
# - walk_to(x):横着走过去(只有一帧贴图,走路用上下颠代替);hop():原地小跳一下。
# 摆位:实例 npc.tscn,在检查器里填 texture/display_name;想让他朝左就勾 flip。
class_name Npc
extends Node2D

signal talked

const HINT_TEX: Texture2D = preload("res://systems/npc/talk_hint.png")
const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const BARK_COLOR := Color(0.95, 0.92, 0.84)
const BOB_PERIOD := 0.3   # 走路一颠一颠的周期(秒)

## 对话里显示的名字。
@export var display_name := ""
@export var texture: Texture2D:
	set(value):
		texture = value
		if is_instance_valid(sprite):
			_apply_texture()
## 朝左(贴图默认朝右)。
@export var flip := false
## 能不能按 Q 搭话。
@export var talkable := true
## 主角离多近(水平距离)能搭话。
@export var talk_radius := 14.0

## 搭话时执行的协程,由关卡剧情脚本设置:npc.on_talk = func() -> void: await ...
var on_talk: Callable
## 走路中(上下颠)。
var walking := false

var sprite: Sprite2D = null
var _hint: Sprite2D = null
var _bark: Label = null
var _bark_tween: Tween = null
var _bob_time := 0.0
var _hop_tween: Tween = null


func _ready() -> void:
	add_to_group("npc")
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	_hint = Sprite2D.new()
	_hint.texture = HINT_TEX
	_hint.centered = false
	_hint.visible = false
	add_child(_hint)
	_bark = Label.new()
	_bark.add_theme_font_override("font", FONT)
	_bark.add_theme_font_size_override("font_size", 11)
	_bark.add_theme_color_override("font_color", BARK_COLOR)
	_bark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_bark.add_theme_constant_override("shadow_offset_x", 1)
	_bark.add_theme_constant_override("shadow_offset_y", 1)
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark.size = Vector2(120, 12)
	_bark.visible = false
	_bark.z_index = 20
	add_child(_bark)
	_apply_texture()
	face(-1 if flip else 1)


func _apply_texture() -> void:
	sprite.texture = texture
	var size := texture.get_size() if texture != null else Vector2(8, 8)
	# 脚底中点对齐节点原点;奇数宽的贴图往左多让半格,保证像素落在整数格上
	sprite.offset = Vector2(-floorf(size.x / 2.0), -size.y)
	_hint.position = Vector2(-3, -size.y - 8)
	_bark.position = Vector2(-60, -size.y - 14)


## 头顶高度(贴图高)。
func height() -> float:
	return texture.get_size().y if texture != null else 8.0


func _process(delta: float) -> void:
	if walking:
		_bob_time += delta
		sprite.position.y = -1.0 if fmod(_bob_time, BOB_PERIOD) < BOB_PERIOD * 0.5 else 0.0
	elif not is_instance_valid(_hop_tween) or not _hop_tween.is_running():
		sprite.position.y = 0.0
		_bob_time = 0.0
	var can_talk := _can_talk_now()
	_hint.visible = can_talk
	if can_talk and _confirm_pressed():
		_start_talk()


func _can_talk_now() -> bool:
	if not talkable or Talk.busy() or Dialogue.is_open:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.get("input_locked"):
		return false
	if absf(player.global_position.y - global_position.y) > 24.0:
		return false
	var dist := absf(player.global_position.x - global_position.x)
	if dist > talk_radius:
		return false
	# 几个 NPC 挨着站时,只有最近的那个冒提示、接这次按键
	for other in get_tree().get_nodes_in_group("npc"):
		if other == self or not (other is Npc) or not other.talkable:
			continue
		var d := absf(player.global_position.x - (other as Node2D).global_position.x)
		if d < dist or (d == dist and other.get_instance_id() < get_instance_id()):
			if d <= (other as Npc).talk_radius:
				return false
	return true


func _confirm_pressed() -> bool:
	# 触屏模式没有 Q,攻击键也能搭话(和传送点一致)
	return Input.is_action_just_pressed("Select") \
		or (TouchControls.enabled and Input.is_action_just_pressed("Attack1"))


func _start_talk() -> void:
	Talk.begin()
	_hint.visible = false
	hide_bark()
	if on_talk.is_valid():
		await on_talk.call()
	else:
		talked.emit()
	Talk.end()


## 朝向:dir > 0 朝右,< 0 朝左。
func face(dir: float) -> void:
	if dir != 0.0:
		sprite.flip_h = dir < 0.0


## 面朝某个世界坐标 x。
func face_x(x: float) -> void:
	face(x - global_position.x)


## 头顶冒一句小字,duration 秒后淡掉(0 = 一直挂着,直到 hide_bark)。
## 世界里的字是 11px,160 宽的屏幕上很大:头顶的话控制在五六个字以内,长的放进对话框。
func bark(text: String, duration := 2.0) -> void:
	if is_instance_valid(_bark_tween):
		_bark_tween.kill()
	_bark.text = text
	_bark.modulate.a = 1.0
	_bark.visible = true
	if duration > 0.0:
		_bark_tween = create_tween()
		_bark_tween.tween_interval(duration)
		_bark_tween.tween_property(_bark, "modulate:a", 0.0, 0.3)
		_bark_tween.tween_callback(func() -> void: _bark.visible = false)


func hide_bark() -> void:
	if is_instance_valid(_bark_tween):
		_bark_tween.kill()
	_bark.visible = false


## 横着走到世界坐标 x(像素/秒)。走完停下,朝向保持行进方向。
func walk_to(x: float, speed := 40.0) -> void:
	var dir := signf(x - global_position.x)
	if dir == 0.0:
		return
	face(dir)
	walking = true
	while is_inside_tree() and signf(x - global_position.x) == dir:
		global_position.x += dir * speed * get_process_delta_time()
		await get_tree().process_frame
	if is_inside_tree():
		global_position.x = x
	walking = false


## 原地小跳一下(拧灯、吓一跳、高兴)。
func hop(height_px := 2.0, duration := 0.16) -> void:
	if is_instance_valid(_hop_tween):
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_property(sprite, "position:y", -height_px, duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(sprite, "position:y", 0.0, duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _hop_tween.finished
