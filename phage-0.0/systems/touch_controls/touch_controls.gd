extends CanvasLayer
## 手机触屏按键(临时方案,给网页版手机玩家用)。
## 触屏设备自动显示;网页版可在网址后加 ?touch=1 强制显示(电脑调试用)、?touch=0 强制隐藏。
## 贴图全部运行时点阵生成,不占素材目录。

## 触屏模式是否生效(teleport.gd 靠它判断"攻击键确认传送"是否开放)。
var enabled: bool = false

## 按钮判定区(160×90 坐标),用于拦截点击穿透。
var _button_rects: Array[Rect2] = []

## 压在 HUD 之上、对话框(150)之下,入梦字卡(3001)和转场(1000)都能盖住它。
const BUTTON_LAYER: int = 140

# --- 图标点阵 ---
const GLYPH_LEFT: PackedStringArray = [
	".....#",
	"...###",
	".#####",
	"######",
	".#####",
	"...###",
	".....#",
]
const GLYPH_RIGHT: PackedStringArray = [
	"#.....",
	"###...",
	"#####.",
	"######",
	"#####.",
	"###...",
	"#.....",
]
const GLYPH_DOWN: PackedStringArray = [
	"#######",
	".#####.",
	"..###..",
	"...#...",
]
const GLYPH_JUMP: PackedStringArray = [
	"...#...",
	"..###..",
	".#####.",
	"#######",
	"..###..",
	"..###..",
	"..###..",
]
const GLYPH_ATTACK: PackedStringArray = [
	"...#...",
	".#.#.#.",
	"..###..",
	"###.###",
	"..###..",
	".#.#.#.",
	"...#...",
]
const GLYPH_SPRINT: PackedStringArray = [
	"#...#...",
	"##..##..",
	".##..##.",
	"..##..##",
	".##..##.",
	"##..##..",
	"#...#...",
]
const GLYPH_SHIELD: PackedStringArray = [
	"#######",
	"#.....#",
	"#.....#",
	"#.....#",
	".#...#.",
	".#...#.",
	"..#.#..",
	"...#...",
]


func _ready() -> void:
	layer = BUTTON_LAYER
	enabled = _detect_touch()
	if enabled:
		_build_buttons()


## 按钮不吞事件,点按会穿透到场景里的物理拾取(比如房间的可点物品)。
## 对话/字卡都在 _input 阶段、TouchScreenButton 也在 _input 阶段,
## 这里在 _unhandled_input 阶段把落在按钮上的点按标记为已处理,只拦住物理拾取。
func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var pos: Vector2
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton:
		pos = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion:
		# 悬停也会触发物品聚焦压暗,一并拦掉
		pos = (event as InputEventMouseMotion).position
	else:
		return
	if covers(pos):
		get_viewport().set_input_as_handled()


## 该位置(160×90 坐标)是否落在某个触屏按钮上。
## 物理拾取的悬停是每物理帧用最后鼠标位置合成的,拦事件拦不住,
## 所以 clickable_item.gd 还会主动调这个来忽略按钮下的悬停/点击。
func covers(pos: Vector2) -> bool:
	if not enabled:
		return false
	for rect in _button_rects:
		if rect.has_point(pos):
			return true
	return false


func _detect_touch() -> bool:
	if OS.has_feature("web"):
		var override: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('touch')", true)
		if override is String:
			if override == "1":
				return true
			if override == "0":
				return false
		return OS.has_feature("web_android") or OS.has_feature("web_ios")
	return DisplayServer.is_touchscreen_available()


func _build_buttons() -> void:
	var defs: Array[Dictionary] = [
		{"action": "move_left", "pos": Vector2(2, 71), "size": 16, "glyph": GLYPH_LEFT, "passby": true},
		{"action": "move_right", "pos": Vector2(21, 71), "size": 16, "glyph": GLYPH_RIGHT, "passby": true},
		{"action": "move_down", "pos": Vector2(13, 56), "size": 12, "glyph": GLYPH_DOWN, "passby": false},
		{"action": "jump", "pos": Vector2(141, 70), "size": 17, "glyph": GLYPH_JUMP, "passby": false},
		{"action": "Attack1", "pos": Vector2(122, 72), "size": 15, "glyph": GLYPH_ATTACK, "passby": false},
		{"action": "sprint", "pos": Vector2(124, 56), "size": 12, "glyph": GLYPH_SPRINT, "passby": false},
		{"action": "Backpack", "pos": Vector2(145, 55), "size": 12, "glyph": GLYPH_SHIELD, "passby": false},
	]
	for def in defs:
		var btn := TouchScreenButton.new()
		var side: int = def["size"]
		btn.texture_normal = _make_texture(side, def["glyph"], false)
		btn.texture_pressed = _make_texture(side, def["glyph"], true)
		btn.action = def["action"]
		btn.position = def["pos"]
		btn.passby_press = def["passby"]
		btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		# 判定框比贴图大一圈,手指好按
		var shape := RectangleShape2D.new()
		shape.size = Vector2.ONE * (side + 5)
		btn.shape = shape
		btn.shape_centered = true
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(btn)
		_button_rects.append(Rect2(btn.position - Vector2.ONE * 2.5, shape.size))


@warning_ignore("integer_division")
func _make_texture(size_px: int, glyph: PackedStringArray, pressed: bool) -> ImageTexture:
	var fill := Color(0.08, 0.09, 0.13, 0.55)
	var edge_colour := Color(0.93, 0.91, 0.82, 0.85)
	var ink := Color(0.93, 0.91, 0.82, 0.95)
	if pressed:
		fill = Color(0.93, 0.91, 0.82, 0.85)
		edge_colour = Color(0.15, 0.13, 0.10, 0.9)
		ink = Color(0.15, 0.13, 0.10, 0.95)
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	for y in size_px:
		for x in size_px:
			var on_x_edge := x == 0 or x == size_px - 1
			var on_y_edge := y == 0 or y == size_px - 1
			if on_x_edge and on_y_edge:
				continue  # 切掉四角,圆润一点
			img.set_pixel(x, y, edge_colour if (on_x_edge or on_y_edge) else fill)
	var gw := glyph[0].length()
	var gh := glyph.size()
	var ox := (size_px - gw) / 2
	var oy := (size_px - gh) / 2
	for gy in gh:
		var row := glyph[gy]
		for gx in gw:
			if row[gx] == "#":
				img.set_pixel(ox + gx, oy + gy, ink)
	return ImageTexture.create_from_image(img)
