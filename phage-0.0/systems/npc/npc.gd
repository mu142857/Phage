# res://systems/npc/npc.gd
# 会说话的 NPC 通用节点(铁锈城起用)。节点原点 = 脚底中点,贴图朝右画。
# - 主角走到 talk_radius 以内:头顶冒"…"提示,按 Q(触屏:攻击键)搭话。
#   搭话时调用 on_talk(关卡剧情脚本给的协程);没设就只发 talked 信号。
# - bark(text):头顶冒一句小字(叫住你、自言自语),几秒后淡掉,不打断操作。
# - walk_to(x):横着走过去(只有一帧贴图,走路用上下颠代替);hop():原地小跳一下。
# - 有帧动画(梧桐画的)就填 frames(SpriteFrames),优先于 texture;play()/play_once() 切动画。
#   脚底按动画内容自动找(画布下面留空也没关系);画的时候朝左的勾 art_faces_left。
# 摆位:实例 npc.tscn,在检查器里填 texture 或 frames、display_name;想让他朝左就勾 flip。
class_name Npc
extends Node2D

signal talked

const HINT_TEX: Texture2D = preload("res://systems/npc/talk_hint.png")
const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const BARK_COLOR := Color(0.95, 0.92, 0.84)
const BOB_PERIOD := 0.3   # 走路一颠一颠的周期(秒)
# ---- 防泛光 ----
# 项目开了全局泛光(阈值 1.0)。场景被 CanvasModulate 压暗,主角身上挂着灯:NPC 贴脸时
# 最终颜色 = 贴图色 ×(压暗 + 主角灯),浅色(皮肤、白头发、白衣服)会冲过 1 发光。
const BLOOM_SAFE := 0.95         # 贴图最亮那批颜色在最亮光照下压到这个值
const PLAYER_LIGHT_PEAK := 1.0   # 主角的灯贴脸时最多加亮多少
const HIGHLIGHT_PERCENTILE := 0.95  # 取贴图亮度的这个分位当"最亮那批"(灯芯、高光这种几个像素的点允许发一点光)
const UI_BRIGHTNESS := 0.9       # 头顶"…"和冒的话:不吃灯光,补偿压暗后显示到这个亮度
static var _highlight_cache: Dictionary = {}
const BARK_LINE := 12.0          # 冒的话一行占多高(互相让位时按这个往上叠)
static var _bark_counter := 0    # 冒话的先后(后冒的给先冒的让位)

## 对话里显示的名字。
@export var display_name := ""
@export var texture: Texture2D:
	set(value):
		texture = value
		if is_instance_valid(sprite):
			_apply_texture()
## 帧动画(有就用它,不用 texture)。
@export var frames: SpriteFrames
## 默认播哪段动画。
@export var animation := &"idle"
## 原画是朝左画的(羊、龙、狼):勾上,朝向按这个反过来算。
@export var art_faces_left := false
## 朝左站。
@export var flip := false
## 能不能按 Q 搭话。
@export var talkable := true
## 主角离多近(水平距离)能搭话。
@export var talk_radius := 14.0
## 贴图亮度(只调贴图,不影响头顶提示)。< 0 = 自动:按场景压暗 + 主角的灯算,
## 保证浅色贴脸也不过泛光阈值;想手动定就填 0~1。
@export var brightness := -1.0

## 搭话时执行的协程,由关卡剧情脚本设置:npc.on_talk = func() -> void: await ...
var on_talk: Callable
## 走路中(上下颠)。
var walking := false

var sprite = null            # Sprite2D(单张图)或 AnimatedSprite2D(帧动画)
var _anchor_x := 0.0          # 画布里脚底中点的 x(翻面时用来保持站位不跳)
var _canvas_w := 0.0
var _facing_left := false
var _head := 8.0              # 头顶离脚底多高
var _hint: Sprite2D = null
var _bark: Label = null
var _bark_tween: Tween = null
var _bob_time := 0.0
var _hop_tween: Tween = null
var _bark_seq := 0


func _ready() -> void:
	add_to_group("npc")
	add_to_group(InteractFocus.GROUP)
	if frames != null:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		if frames.has_animation(animation):
			sprite.play(animation)
	else:
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
	_bark.add_theme_font_size_override("font_size", 12)
	_bark.add_theme_color_override("font_color", BARK_COLOR)
	_bark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_bark.add_theme_constant_override("shadow_offset_x", 1)
	_bark.add_theme_constant_override("shadow_offset_y", 1)
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark.size = Vector2(120, 12)
	_bark.visible = false
	_bark.z_index = 20
	add_child(_bark)
	# 提示气泡和冒的话是给玩家看的字,不吃主角的灯(否则白字一靠近就发光),
	# 只受场景压暗,再按压暗程度补亮回来
	var ambient := _scene_ambient()
	_hint.light_mask = 0
	_hint.modulate = _ui_compensation(_texture_highlight(HINT_TEX), ambient)
	_bark.light_mask = 0
	_bark.modulate = _ui_compensation(maxf(BARK_COLOR.r, maxf(BARK_COLOR.g, BARK_COLOR.b)), ambient)
	_apply_texture()
	face(-1 if flip else 1)


func _apply_texture() -> void:
	var head := 8.0
	if frames != null:
		# 帧动画:画布可能比人大(四周留空),按默认动画所有帧的不透明范围找脚底和头顶
		var bounds := _frames_bounds()
		_canvas_w = _frame_size().x
		_anchor_x = bounds.position.x + bounds.size.x / 2.0
		sprite.offset.y = -(bounds.position.y + bounds.size.y)
		head = bounds.size.y
	else:
		sprite.texture = texture
		var size := texture.get_size() if texture != null else Vector2(8, 8)
		_canvas_w = size.x
		_anchor_x = size.x / 2.0
		sprite.offset.y = -size.y
		head = size.y
	_head = head
	_update_offset_x()
	_hint.position = Vector2(-3, -head - 8)
	_bark.position = Vector2(-60, -head - 14)
	_apply_brightness()


# 脚底中点对齐节点原点;翻面时画面以画布中线镜像,站位要跟着换算,不然人会横跳。
# 奇数宽往左多让半格,保证像素落在整数格上。
func _update_offset_x() -> void:
	var anchor := _canvas_w - _anchor_x if sprite.flip_h else _anchor_x
	sprite.offset.x = -floorf(anchor)


func _frame_size() -> Vector2:
	var tex: Texture2D = null
	if frames.has_animation(animation):
		tex = frames.get_frame_texture(animation, 0)
	return tex.get_size() if tex != null else Vector2(8, 8)


# 默认动画所有帧不透明像素的外接框(画布坐标)。
func _frames_bounds() -> Rect2:
	var size := _frame_size()
	if not frames.has_animation(animation):
		return Rect2(Vector2.ZERO, size)
	var box := Rect2i()
	var first := true
	for i in frames.get_frame_count(animation):
		var tex: Texture2D = frames.get_frame_texture(animation, i)
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		box = used if first else box.merge(used)
		first = false
	return Rect2(Vector2.ZERO, size) if first else Rect2(box)


## 切动画(没有这段就不动)。
func play(anim: StringName) -> void:
	if frames != null and frames.has_animation(anim):
		sprite.play(anim)


## 播一段不循环的动画,播完再切到 then(空=停在最后一帧)。带超时兜底,不会卡死。
func play_once(anim: StringName, then: StringName = &"") -> void:
	if frames == null or not frames.has_animation(anim):
		return
	sprite.play(anim)
	var fps: float = maxf(frames.get_animation_speed(anim), 0.1)
	var limit := float(frames.get_frame_count(anim)) / fps + 0.3
	var elapsed := 0.0
	while is_inside_tree() and elapsed < limit and sprite.animation == anim and sprite.is_playing():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if then != &"" and is_inside_tree():
		play(then)


func _apply_brightness() -> void:
	var m := brightness
	if m < 0.0:
		var peak := _scene_ambient() + PLAYER_LIGHT_PEAK
		var art: Texture2D = texture
		if frames != null and frames.has_animation(animation):
			art = frames.get_frame_texture(animation, 0)
		m = clampf(BLOOM_SAFE / maxf(_texture_highlight(art) * peak, 0.01), 0.5, 1.0)
	sprite.self_modulate = Color(m, m, m)


func _ui_compensation(highlight: float, ambient: float) -> Color:
	var k := clampf(UI_BRIGHTNESS / maxf(highlight * ambient, 0.01), 1.0, 3.0)
	return Color(k, k, k)


# 场景的压暗程度(CanvasModulate 最亮的通道;没有压暗就是 1)。
func _scene_ambient() -> float:
	var root: Node = owner if owner != null else get_tree().current_scene
	if root == null:
		return 1.0
	var found := root.find_children("*", "CanvasModulate", true, false)
	# NPC 放在单独的子场景里(巷子的 *_people.tscn)时 owner 是那个子场景,往上找整个关卡
	if found.is_empty():
		var top: Node = self
		while top.get_parent() != null and top.get_parent() != get_tree().root:
			top = top.get_parent()
		if top != root:
			found = top.find_children("*", "CanvasModulate", true, false)
	if found.is_empty():
		return 1.0
	var c: Color = (found[0] as CanvasModulate).color
	return maxf(c.r, maxf(c.g, c.b))


# 贴图里"最亮那批颜色"的亮度(不透明像素 RGB 最大通道的 95 分位),按贴图缓存。
static func _texture_highlight(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var key := tex.resource_path if not tex.resource_path.is_empty() else str(tex.get_instance_id())
	if _highlight_cache.has(key):
		return _highlight_cache[key]
	var img := tex.get_image()
	if img == null:
		return 1.0
	if img.is_compressed():
		img.decompress()
	var values: PackedFloat32Array = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				values.append(maxf(c.r, maxf(c.g, c.b)))
	var result := 1.0
	if not values.is_empty():
		values.sort()
		result = values[int(floor(HIGHLIGHT_PERCENTILE * float(values.size() - 1)))]
	_highlight_cache[key] = result
	return result


## 头顶高度(贴图高)。
func height() -> float:
	return _head


func _process(delta: float) -> void:
	if walking:
		_bob_time += delta
		sprite.position.y = -1.0 if fmod(_bob_time, BOB_PERIOD) < BOB_PERIOD * 0.5 else 0.0
	elif not is_instance_valid(_hop_tween) or not _hop_tween.is_running():
		sprite.position.y = 0.0
		_bob_time = 0.0
	var can_talk := _can_talk_now()
	_hint.visible = can_talk
	if _bark.visible:
		_layout_bark()
	if can_talk and _confirm_pressed():
		_start_talk()


# 能不能按 Q:够得着,而且是所有可交互的东西(别的 NPC、按 Q 的门)里离主角最近的那个
func _can_talk_now() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and InteractFocus.is_focused(self, player)


## InteractFocus 用:够得着返回水平距离,够不着返回 INF。
func interact_distance(player: Node2D) -> float:
	if not talkable or Talk.busy() or Dialogue.is_open or not is_visible_in_tree():
		return INF
	if player.get("input_locked"):
		return INF
	if absf(player.global_position.y - global_position.y) > 24.0:
		return INF
	var dist := absf(player.global_position.x - global_position.x)
	return dist if dist <= talk_radius else INF


## InteractFocus 用:头顶"…"提示的框(世界坐标)。
func prompt_rect() -> Rect2:
	if not _hint.visible:
		return Rect2()
	return Rect2(_hint.global_position, HINT_TEX.get_size())


## 正在冒的话的框(世界坐标),没在冒返回空 Rect2。
func bark_rect() -> Rect2:
	if not _bark.visible or _bark.modulate.a <= 0.01:
		return Rect2()
	var w := _bark_width()
	return Rect2(global_position.x - w / 2.0, _bark.global_position.y, w, BARK_LINE)


func _bark_width() -> float:
	return FONT.get_string_size(_bark.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 2.0


# 冒的话不和别的字叠:自己头顶有"…"就先抬一行;再躲开所有可交互提示和比自己先冒的话,
# 撞上了就叠到它上面一行。
func _layout_bark() -> void:
	var top := global_position.y - _head - (20.0 if _hint.visible else 14.0)
	var w := _bark_width()
	var x0 := global_position.x - w / 2.0
	var blockers := InteractFocus.prompt_rects(get_tree())
	for other in get_tree().get_nodes_in_group("npc"):
		if other != self and other is Npc and (other as Npc)._bark_seq < _bark_seq:
			var r := (other as Npc).bark_rect()
			if r.has_area():
				blockers.append(r)
	for _i in 8:
		var mine := Rect2(x0, top, w, BARK_LINE)
		var hit := false
		for r in blockers:
			if mine.intersects(r):
				top = minf(top, r.position.y - BARK_LINE)
				hit = true
		if not hit:
			break
	_bark.position.y = top - global_position.y


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
	if dir == 0.0:
		return
	_facing_left = dir < 0.0
	sprite.flip_h = _facing_left != art_faces_left
	_update_offset_x()


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
	_bark_counter += 1
	_bark_seq = _bark_counter
	_layout_bark()
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
