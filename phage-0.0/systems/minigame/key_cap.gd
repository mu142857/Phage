# 小游戏提示里的按键帽:一个小方块,上面写这个动作现在绑的键(← → 空格 Q…)。
# 触屏模式没有键盘,写成按钮的名字(攻击/跳)。键改了绑定也跟着变,不写死。
class_name KeyCap
extends Control

const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const FACE := Color(0.9, 0.86, 0.78)
const SIDE := Color(0.52, 0.48, 0.44)
const INK := Color(0.16, 0.13, 0.12)
const TOUCH_NAMES := {&"Attack1": "攻击", &"jump": "跳", &"Select": "Q", &"sprint": "冲"}

var label := ""
var _down := 0.0


func set_action(action: StringName) -> void:
	label = _label_for(action)
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	size = Vector2(maxf(9.0, w + 4.0), 11.0)
	queue_redraw()


func press() -> void:
	_down = 0.08
	queue_redraw()


func _process(delta: float) -> void:
	if _down > 0.0:
		_down -= delta
		if _down <= 0.0:
			queue_redraw()


func _draw() -> void:
	var dy := 1.0 if _down > 0.0 else 0.0
	draw_rect(Rect2(0, 1, size.x, size.y - 1), SIDE)
	draw_rect(Rect2(0, dy, size.x, size.y - 2), FACE)
	draw_string(FONT, Vector2(2, 9 + dy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)


static func _label_for(action: StringName) -> String:
	if TouchControls.enabled:
		return TOUCH_NAMES.get(action, String(action))
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = (ev as InputEventKey).physical_keycode
			if code == 0:
				code = (ev as InputEventKey).keycode
			match code:
				KEY_LEFT: return "←"
				KEY_RIGHT: return "→"
				KEY_UP: return "↑"
				KEY_DOWN: return "↓"
				KEY_SPACE: return "空格"
				KEY_SHIFT: return "Shift"
				KEY_ENTER: return "回车"
			return OS.get_keycode_string(code)
	return String(action)
