# res://systems/ui/coin_hud.gd
# 右上角铜板数(铁锈城起用)。捡到第一枚铜板(Story.flag "coins_seen")后才出现;
# 知道了目标(Story.flag "coin_goal" > 0,比如过路费一百)就显示成 "12/100"。
# 由关卡剧情脚本 add_child 进场景,跟着场景走。
class_name CoinHud
extends CanvasLayer

const ICON: Texture2D = preload("res://entities/rust_npcs/talking_coin.png")
const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const TEXT_COLOR := Color(0.95, 0.88, 0.7)
const RIGHT_MARGIN := 3.0
const TOP := 2.0

var _icon: TextureRect = null
var _label: Label = null
var _root: Control = null
var _shown_coins := -1


func _ready() -> void:
	layer = 100  # 和 buff HUD 同层,在对话(150)底下
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -60.0
	_label.offset_right = -RIGHT_MARGIN
	_label.offset_top = TOP
	_label.offset_bottom = TOP + 11.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	_icon = TextureRect.new()
	_icon.texture = ICON
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_icon)
	Story.coins_changed.connect(refresh)
	refresh()


## 铜板数或目标变了就调(Story.coins_changed 会自动调;改 coin_goal 后手动调一次)。
func refresh() -> void:
	var seen: bool = Story.flag("coins_seen", false)
	_root.visible = seen
	if not seen:
		return
	var goal: int = int(Story.flag("coin_goal", 0))
	_label.text = "%d/%d" % [Story.coins, goal] if goal > 0 else str(Story.coins)
	# 图标贴在数字左边
	var width := FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var vp := get_viewport().get_visible_rect().size
	_icon.position = Vector2(roundf(vp.x - RIGHT_MARGIN - width - ICON.get_width() - 2.0), TOP + 3.0)
	if _shown_coins >= 0 and Story.coins != _shown_coins:
		_pulse()
	_shown_coins = Story.coins


func _pulse() -> void:
	_root.modulate = Color(1.6, 1.4, 1.0)
	create_tween().tween_property(_root, "modulate", Color.WHITE, 0.4)
