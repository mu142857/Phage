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
var _inline_icon: TextureRect = null


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

	# 行内小图标(获得 buff 用):打完字后贴在文字末尾
	_inline_icon = TextureRect.new()
	_inline_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_inline_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_inline_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inline_icon.visible = false
	_root.add_child(_inline_icon)

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


## 获得 buff 演出:打出 line 后把图标贴进 "{icon}" 占位符的位置(文字里预留了
## 等宽空隙);line 里没有占位符就贴在整行末尾。按键后再打一行介绍。
## 用法: await Dialogue.say_gain("获得 buff「{icon}森林的谢礼」", BuffDefs.icon(&"Plant"), "……")
const ICON_MARK := "{icon}"

func say_gain(line: String, icon: Texture2D, desc: String) -> void:
	_open()
	var shown := line
	var prefix := line      # 图标插槽左侧的文字;无占位符时=整行(图标贴末尾)
	var gap := ""
	if icon != null and line.contains(ICON_MARK):
		var parts := line.split(ICON_MARK, true, 1)
		prefix = parts[0]
		var suffix: String = parts[1] if parts.size() > 1 else ""
		gap = _icon_gap_text(icon)
		shown = prefix + gap + suffix
	# 图标位置先定好但不显示;打字机扫到插槽时它像被"打出来"一样弹出。
	_prepare_inline_icon(shown, prefix, gap, icon)
	await _type_line(shown, prefix.length() if icon != null else -1)
	await _wait_advance()
	_inline_icon.visible = false
	await _type_line(desc)
	await _wait_advance()
	close()


# 宽度足够塞下图标的空格串(占位符换成它,文字排版就给图标留了缝)。
func _icon_gap_text(icon: Texture2D) -> String:
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var space_width := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var count := maxi(1, ceili((icon.get_width() + 2.0) / maxf(space_width, 1.0)))
	return " ".repeat(count)


# 图标定位到空隙正中(先不显示,由打字机进度揭示);gap 为空表示贴在末行末尾。
# 支持手动 \n 换行(带图标的行要保证自身不触发自动换行,调用方控制行宽)。
func _prepare_inline_icon(shown: String, prefix: String, gap: String, icon: Texture2D) -> void:
	if icon == null:
		return
	_inline_icon.texture = icon
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var center := _label.get_global_rect().get_center()
	var lines := shown.split("\n")
	var x: float
	var icon_line: int
	if gap.is_empty():
		icon_line = lines.size() - 1
		var last_width := font.get_string_size(
			lines[icon_line], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		x = center.x + last_width / 2.0 + 3.0
	else:
		icon_line = prefix.count("\n")
		var newline_at := prefix.rfind("\n")
		var prefix_in_line := prefix.substr(newline_at + 1) if newline_at >= 0 else prefix
		var line_width := font.get_string_size(
			lines[icon_line], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var prefix_width := font.get_string_size(
			prefix_in_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var gap_width := font.get_string_size(gap, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		x = center.x - line_width / 2.0 + prefix_width + (gap_width - icon.get_width()) / 2.0
	var y := _line_center_y(center.y, lines.size(), icon_line, font, font_size) \
		- icon.get_height() / 2.0
	_inline_icon.position = Vector2(roundf(x), roundf(y))
	_inline_icon.visible = false


# 垂直居中的多行文本里,第 line_index 行的中心 y。
func _line_center_y(center_y: float, line_count: int, line_index: int,
		font: Font, font_size: int) -> float:
	var line_height := font.get_height(font_size)
	var spacing := float(_label.get_theme_constant("line_spacing"))
	var total := line_height * float(line_count) + spacing * float(line_count - 1)
	return center_y - total / 2.0 + (line_height + spacing) * float(line_index) + line_height / 2.0


func close() -> void:
	is_open = false
	visible = false
	_label.text = ""
	_inline_icon.visible = false
	_clear_options()


func _open() -> void:
	is_open = true
	visible = true
	_clear_options()


# reveal_icon_at >= 0 时:打字进度扫过该字符数就让行内图标现身(按键跳过也会带出来)。
func _type_line(text: String, reveal_icon_at: int = -1) -> void:
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
		if reveal_icon_at >= 0 and _label.visible_characters >= reveal_icon_at:
			_inline_icon.visible = true
			reveal_icon_at = -1
		await get_tree().process_frame
	_label.visible_characters = -1
	if reveal_icon_at >= 0:
		_inline_icon.visible = true
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
