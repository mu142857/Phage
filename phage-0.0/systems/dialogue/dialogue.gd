# res://systems/dialogue/dialogue.gd
# 全屏自言自语对话 autoload(参考 eight-minutes 的 Dialogue 思路,去掉立绘/对话框,
# 文字直接打在画面上)。场景压暗由调用方负责(房间只留物品和主角亮着)。
# 用法:
#   await Dialogue.say(["第一句。", "第二句。"])
#   var pick: int = await Dialogue.ask(["要睡了吗。"], ["钻进被窝", "再待一会儿"])
# 打字中任意键/点击 = 整段显示;显示完 = 下一句。选项只认鼠标点击。
extends CanvasLayer

signal _picked(index: int)

const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const TYPE_CPS := 18.0
const TEXT_COLOR := Color(0.93, 0.91, 0.86)
const OPTION_COLOR := Color(0.93, 0.91, 0.86)          # 默认就是亮的
const OPTION_HOVER_COLOR := Color(0.6, 0.95, 0.68)     # 选中浅绿
const OPTION_ROW_HEIGHT := 13.0
const OPTION_PANEL_PAD := 3.0

var is_open := false

var _advance := false
var _root: Control = null
var _label: Label = null
var _options_panel: ColorRect = null
var _options_box: VBoxContainer = null


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 正文永远固定在上半区,弹选项时不动(问题被选项往上顶很难受)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 10.0
	_label.offset_right = -10.0
	_label.offset_top = 6.0
	_label.offset_bottom = -56.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 居中+逐字显示必须用 CHARS_AFTER_SHAPING,否则整行随出字抖动(DreamIntro 同款坑)
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)

	# 选项区:半透明黑底 + 左对齐的选项列
	_options_panel = ColorRect.new()
	_options_panel.color = Color(0.0, 0.0, 0.0, 0.65)
	_options_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_options_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_panel.visible = false
	_root.add_child(_options_panel)

	_options_box = VBoxContainer.new()
	_options_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_box.offset_left = 10.0
	_options_box.offset_right = -10.0
	_options_box.offset_top = OPTION_PANEL_PAD
	_options_box.offset_bottom = -OPTION_PANEL_PAD
	_options_box.add_theme_constant_override("separation", 0)
	_options_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_panel.add_child(_options_box)

	visible = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			_advance = true


## 顺序打出每一句,每句等一次按键。播完自动收起。
func say(lines: Array) -> void:
	_open()
	for line: String in lines:
		await _type_line(line)
		await _wait_advance()
	close()


## 打完 lines(可为空,则保留上一句)后弹出选项,返回点中的下标。收起由调用方决定何时发生
## (返回时已自动收起)。
func ask(lines: Array, options: Array) -> int:
	_open()
	for i in lines.size():
		await _type_line(lines[i])
		if i < lines.size() - 1:  # 最后一句不等按键,直接带着它弹选项
			await _wait_advance()
	_show_options(options)
	var index: int = await _picked
	_clear_options()
	close()
	return index


func close() -> void:
	is_open = false
	visible = false
	_label.text = ""
	_clear_options()


func _open() -> void:
	is_open = true
	visible = true
	_clear_options()


func _type_line(text: String) -> void:
	_advance = false
	_label.text = text
	_label.visible_characters = 0
	var acc := 0.0
	while _label.visible_characters < text.length():
		if _advance:
			break
		acc += get_process_delta_time() * TYPE_CPS
		while acc >= 1.0 and _label.visible_characters < text.length():
			_label.visible_characters += 1
			acc -= 1.0
		await get_tree().process_frame
	_label.visible_characters = -1
	_advance = false


func _wait_advance() -> void:
	_advance = false
	while not _advance:
		await get_tree().process_frame
	_advance = false


func _show_options(options: Array) -> void:
	_clear_options()
	# 底板按选项数定高,贴着屏幕底
	var panel_height := options.size() * OPTION_ROW_HEIGHT + OPTION_PANEL_PAD * 2.0
	_options_panel.offset_top = -2.0 - panel_height
	_options_panel.offset_bottom = -2.0
	_options_panel.visible = true
	for i in options.size():
		var option := Label.new()
		option.text = "· " + str(options[i])
		option.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.add_theme_font_override("font", FONT)
		option.add_theme_font_size_override("font_size", 11)
		option.add_theme_color_override("font_color", OPTION_COLOR)
		option.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		option.add_theme_constant_override("shadow_offset_x", 1)
		option.add_theme_constant_override("shadow_offset_y", 1)
		option.mouse_filter = Control.MOUSE_FILTER_STOP
		var index := i
		option.mouse_entered.connect(func() -> void:
			option.add_theme_color_override("font_color", OPTION_HOVER_COLOR))
		option.mouse_exited.connect(func() -> void:
			option.add_theme_color_override("font_color", OPTION_COLOR))
		option.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_picked.emit(index))
		_options_box.add_child(option)


func _clear_options() -> void:
	_options_panel.visible = false
	for child in _options_box.get_children():
		child.queue_free()
