# 小游戏共用的屏幕提示(铁锈城的赛跑/陪练/拔剑/举重都用这一个)。
# 160×90 上字只有 11 号,所以每样东西都放在固定的位置、不叠在一起:
#   顶上正中  banner:第几场/第几回合 + 小赛道或血点
#   屏幕中间  big:倒计时、"跑!"、"赢了!"(弹一下再淡掉)
#   底下正中  prompt:按键帽 + 一句话(比如 [←] 连按) 和 meter 力量条
# 用法:var hud := MiniHud.open(self)  …  hud.close()
class_name MiniHud
extends CanvasLayer

const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const TEXT := Color(0.96, 0.92, 0.84)
const SHADOW := Color(0, 0, 0, 0.9)
const GOOD := Color(0.62, 0.9, 0.5)
const BAD := Color(0.95, 0.45, 0.4)
const GOLD := Color(1.0, 0.84, 0.42)
const W := 160.0
const H := 90.0

var _root: Control
var _banner: Label
var _big: Label
var _big_tween: Tween
var _prompt_row: Control
var _prompt_label: Label
var _keycap: KeyCap
var _meter_back: ColorRect
var _meter_fill: ColorRect
var _meter_mark: ColorRect
var _track: Control
var _track_dots: Array = []   # [ColorRect, 颜色]
var _pips: Array = []
var _pulse_t := 0.0


static func open(owner_node: Node) -> MiniHud:
	var hud := MiniHud.new()
	owner_node.add_child(hud)
	return hud


func _ready() -> void:
	layer = 110   # 盖过铜板/护盾 HUD(100),在对话框(150)底下
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_banner = _label(Vector2(0, 3), Vector2(W, 12))
	_big = _label(Vector2(0, 28), Vector2(W, 24))
	_big.add_theme_font_size_override("font_size", 24)
	_big.pivot_offset = Vector2(W / 2.0, 12)
	_big.visible = false
	# 底下:按键帽 + 提示
	_prompt_row = Control.new()
	_prompt_row.position = Vector2(0, 76)
	_prompt_row.size = Vector2(W, 12)
	_prompt_row.visible = false
	_root.add_child(_prompt_row)
	_keycap = KeyCap.new()
	_prompt_row.add_child(_keycap)
	_prompt_label = _label(Vector2.ZERO, Vector2(W, 12), _prompt_row)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 力量条(在提示上面)
	_meter_back = _rect(Vector2(50, 70), Vector2(60, 4), Color(0.08, 0.07, 0.07, 0.85))
	_meter_fill = _rect(Vector2(51, 71), Vector2(0, 2), GOOD)
	_meter_mark = _rect(Vector2(50, 69), Vector2(1, 6), TEXT)
	for n in [_meter_back, _meter_fill, _meter_mark]:
		n.visible = false
	_track = Control.new()
	_track.position = Vector2(50, 15)
	_track.visible = false
	_root.add_child(_track)


func close() -> void:
	queue_free()


# ------------------------------------------------------------------ 顶上
func banner(text: String, color := TEXT) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = text != ""


# ------------------------------------------------------------------ 中间大字
## 弹出一句大字,hold 秒后淡掉(hold <= 0 就一直挂着,直到下一句或 clear_big)
func big(text: String, color := TEXT, hold := 0.7) -> void:
	if is_instance_valid(_big_tween):
		_big_tween.kill()
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_big.visible = true
	_big.modulate.a = 1.0
	_big.scale = Vector2(1.5, 1.5)
	_big_tween = create_tween()
	_big_tween.tween_property(_big, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_big_tween.tween_interval(hold)
		_big_tween.tween_property(_big, "modulate:a", 0.0, 0.2)
		_big_tween.tween_callback(func() -> void: _big.visible = false)


func clear_big() -> void:
	if is_instance_valid(_big_tween):
		_big_tween.kill()
	_big.visible = false


## 3、2、1、开始的倒计时(调用的地方 await 它)
func countdown(go_text: String) -> void:
	for n in ["3", "2", "1"]:
		big(n, TEXT, 0.45)
		await get_tree().create_timer(0.62).timeout
	big(go_text, GOLD, 0.5)


# ------------------------------------------------------------------ 底下:按键提示
## action = InputMap 里的动作名(按键帽上画它绑的键,触屏模式写"攻击"之类)
func prompt(action: StringName, text: String) -> void:
	_keycap.set_action(action)
	_prompt_label.text = text
	var font_w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var total := _keycap.size.x + 3.0 + font_w
	var x0 := floorf((W - total) / 2.0)
	_keycap.position = Vector2(x0, 0)
	_prompt_label.position = Vector2(x0 + _keycap.size.x + 3.0, -1)
	_prompt_row.visible = true


func clear_prompt() -> void:
	_prompt_row.visible = false


## 按了一下:键帽往下按一格(给连按一个手感)
func press_flash() -> void:
	_keycap.press()


# ------------------------------------------------------------------ 力量条
## value 0~1;mark >= 0 在那个位置画一根竖线(举重的"甜区"用 zone)
func meter(value: float, color := GOOD) -> void:
	for n in [_meter_back, _meter_fill]:
		n.visible = true
	_meter_fill.size.x = roundf(58.0 * clampf(value, 0.0, 1.0))
	_meter_fill.color = color


## 甜区:从 a 到 b(0~1)画一段亮色底;cursor 是正在扫的那根线
func meter_zone(a: float, b: float, cursor: float, zone_color := Color(0.35, 0.6, 0.3)) -> void:
	_meter_back.visible = true
	_meter_fill.visible = true
	_meter_fill.position.x = 51.0 + roundf(58.0 * a)
	_meter_fill.size.x = maxf(1.0, roundf(58.0 * (b - a)))
	_meter_fill.color = zone_color
	_meter_mark.visible = true
	_meter_mark.position.x = 50.0 + roundf(59.0 * clampf(cursor, 0.0, 1.0))


func clear_meter() -> void:
	for n in [_meter_back, _meter_fill, _meter_mark]:
		n.visible = false
	_meter_fill.position.x = 51.0


# ------------------------------------------------------------------ 小赛道(顶上,banner 底下)
## 两个(或几个)小点在一根 60 格的线上跑;colors 决定点的颜色,progress 0~1
func track(progress: Array, colors: Array) -> void:
	_track.visible = true
	if _track.get_child_count() == 0:
		var line := ColorRect.new()
		line.color = Color(0.5, 0.46, 0.42, 0.9)
		line.position = Vector2(0, 2)
		line.size = Vector2(60, 1)
		_track.add_child(line)
		var flag := ColorRect.new()
		flag.color = GOLD
		flag.position = Vector2(60, 0)
		flag.size = Vector2(1, 5)
		_track.add_child(flag)
	while _track_dots.size() < progress.size():
		var d := ColorRect.new()
		d.size = Vector2(2, 3)
		_track.add_child(d)
		_track_dots.append(d)
	for i in progress.size():
		var d: ColorRect = _track_dots[i]
		d.color = colors[i]
		d.position = Vector2(roundf(clampf(progress[i], 0.0, 1.0) * 59.0), 1 - i)


func clear_track() -> void:
	_track.visible = false


# ------------------------------------------------------------------ 血点(陪练:还能挨几拳)
func pips(left: int, total: int, color := BAD) -> void:
	while _pips.size() < total:
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		_root.add_child(p)
		_pips.append(p)
	var x0 := floorf((W - (total * 5 - 2)) / 2.0)
	for i in _pips.size():
		var p: ColorRect = _pips[i]
		p.visible = i < total
		p.position = Vector2(x0 + i * 5, 16)
		p.color = color if i < left else Color(0.25, 0.22, 0.22)


func clear_pips() -> void:
	for p in _pips:
		p.visible = false


# ------------------------------------------------------------------ 世界里飘的字(+5 之类)
## 在世界坐标 pos 冒一句,往上飘一点再淡掉。挂在 parent(一般是关卡)下面。
static func float_text(parent: Node, pos: Vector2, text: String, color := GOLD) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(60, 12)
	l.z_index = 40
	l.light_mask = 0
	parent.add_child(l)
	l.global_position = pos + Vector2(-30, -12)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 10.0, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ 挨了一下(不扣血)
## 小游戏里被撞/被打中:主角往 dir 那边滑开 dist 格(撞墙就停)+ 定身 stun 秒 + 闪一下。
## 不走 take_damage,不破盾——比赛输了不该丢命。
static func knock(player: Node2D, dir: float, dist := 14.0, stun := 0.4) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_stun"):
		player.call("apply_stun", stun)
	var body := player as CharacterBody2D
	var moved := [0.0]
	var tw := player.create_tween()
	tw.tween_method(func(v: float) -> void:
		var step: float = v - moved[0]
		moved[0] = v
		if is_instance_valid(body):
			body.move_and_collide(Vector2(dir * step, 0.0)), 0.0, dist, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Game.flash(0.12, Color(1, 1, 1))
	Game.shake_camera(2.0)


# ------------------------------------------------------------------ 小工具
func _label(pos: Vector2, size: Vector2, parent: Control = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _root).add_child(l)
	return l


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r
