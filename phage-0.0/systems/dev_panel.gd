# res://systems/dev_panel.gd
# 开发者面板 autoload(Dev):F8 开关,Esc 关闭。仅 debug 构建存在,导出正式版自动移除。
# 管:天数进度(决定下一夜进哪个场景)/昼夜/直接入梦跳转(可选字卡·回顾模式)/
#     房间物品显隐覆盖(remi_room 读 item_visible)/携带 buff 增删(可超上限测试)。
# 打开时整棵树暂停;所有会切场景的操作先关面板恢复运行再执行。
# 160×90 放不下这么多控件:面板挂在 scale=0.2 的 CanvasLayer 上按 800×450 设计,
# 调试 UI 不受巨像素渲染铁律约束。
extends CanvasLayer

const DreamIntroScript := preload("res://systems/dream_intro/dream_intro.gd")
const FONT := preload("res://asstes/fonts/PixelFont.ttf")

const DESIGN := Vector2(800, 450)
const NIGHT_TITLES: Array[String] = [
	"周一《伤口》", "周二《珊瑚摇篮》", "周三《铁锈城》", "周四《盐做的山》",
	"周五《网》", "周六《森林的谢礼》", "周日《礼拜日》",
]
## 房间收集品 → 归属的夜(与 remi_room.COLLECT_BY_NIGHT 对应,顺序即面板顺序)
const ITEM_NIGHTS: Dictionary = {
	"Table": 1, "Watertank": 2, "CopperLamp": 3, "SaltLight": 4,
	"SpiderQueenDoll": 5, "Plant": 6, "Flower": 6, "BlueCrystal": 6,
	"YunwuPaint": 7, "RedCrystal": 7,
}

## 房间物品显隐覆盖:节点名 -> bool。没有键 = 跟随进度。remi_room 经 item_visible 读。
var item_override: Dictionary = {}

var _status: Label = null
var _next_label: Label = null
var _night_check: CheckBox = null
var _intro_check: CheckBox = null
var _replay_check: CheckBox = null
var _item_checks: Dictionary = {}  # 节点名 -> CheckBox
var _buff_checks: Dictionary = {}  # buff id(StringName) -> CheckBox
var _was_paused := false


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 4000  # 压过 DreamIntro 的 3001
	scale = Vector2(0.2, 0.2)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## remi_room 的物品显隐都从这儿过一道:有覆盖用覆盖,没有就用默认(进度)。
func item_visible(item_name: String, default_visible: bool) -> bool:
	return bool(item_override.get(item_name, default_visible))


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F8:
		_close() if visible else _open()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and visible:
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	_refresh()


func _close() -> void:
	visible = false
	get_tree().paused = _was_paused


## 切场景的操作统一走这儿:先关面板恢复运行,下一帧再动手,别在暂停里换场景。
func _run_after_close(action: Callable) -> void:
	_close()
	await get_tree().process_frame
	action.call()


# ============================================================
# 面板状态同步
# ============================================================
func _refresh() -> void:
	var time_text := "夜晚" if Story.is_night else "白天"
	var where := "梦中(第 %d 夜)" % Story.current_dream_night if Story.in_dream else "房间"
	if Story.replay_mode:
		where += "·回顾"
	_status.text = "已完成 %d 夜 · %s\n当前:%s\nBuff:%d/%d" % [
		Story.nights_completed, time_text, where,
		Story.buffs_owned.size(), Story.MAX_BUFFS]
	if Story.nights_completed >= 7:
		_next_label.text = "下一夜:已全部做完"
	else:
		_next_label.text = "下一夜:" + NIGHT_TITLES[Story.nights_completed]
	_night_check.set_pressed_no_signal(Story.is_night)
	for item_name: String in _item_checks:
		var default_owned: bool = ITEM_NIGHTS[item_name] <= Story.nights_completed
		var check: CheckBox = _item_checks[item_name]
		check.set_pressed_no_signal(item_visible(item_name, default_owned))
	for id: StringName in _buff_checks:
		var check: CheckBox = _buff_checks[id]
		check.set_pressed_no_signal(Story.has_buff(id))


## 人在房间时让物品/昼夜立即生效(房间私有方法,面板是调试工具直接借用)
func _refresh_room() -> void:
	var room := get_tree().current_scene
	if room != null and room.has_method("_apply_collected"):
		room._apply_collected()
		room._apply_time(Story.is_night)


# ============================================================
# 操作
# ============================================================
func _set_day(n: int) -> void:
	Story.nights_completed = n
	Story.save_game()
	_refresh_room()
	_refresh()


func _on_night_toggled(on: bool) -> void:
	Story.is_night = on
	Story.save_game()
	_refresh_room()
	_refresh()


func _jump_dream(night: int) -> void:
	var path: String = Story.DREAM_SCENES[night - 1]
	# 字卡记录按勾选定死:勾了必播,没勾必跳过
	if _intro_check.button_pressed:
		DreamIntroScript._played.erase(path)
	else:
		DreamIntroScript._played[path] = true
	var replay: bool = _replay_check.button_pressed
	_run_after_close(func() -> void:
		Story.in_dream = false  # 允许从梦里直接跳下一个梦
		Story.start_dream(night, replay))


func _complete_dream() -> void:
	if not Story.in_dream:
		return
	_run_after_close(func() -> void: Story.complete_dream())


func _goto_room() -> void:
	_run_after_close(func() -> void:
		Story.in_dream = false
		Story.replay_mode = false
		Story.current_dream_night = 0
		Story.wake_kind = ""
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file(Story.ROOM_SCENE))


func _reload_scene() -> void:
	_run_after_close(func() -> void: get_tree().reload_current_scene())


# Boss Rush 测试场:不进剧情,in_dream 关掉让死亡走"重载重打"而不是惊醒回房间
func _goto_boss_rush() -> void:
	_run_after_close(func() -> void:
		Story.in_dream = false
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://levels/boss_rush_test/boss_rush_test.tscn"))


## 等价 F12:清空进度回第一夜白天,顺带清掉面板自己的物品覆盖。
func _reset_progress() -> void:
	item_override.clear()
	_run_after_close(func() -> void:
		Story.nights_completed = 0
		Story.is_night = false
		for id: String in Story.buffs_owned.duplicate():
			Story.buffs_owned.erase(id)
			Story.buff_removed.emit(StringName(id))
		Story.in_dream = false
		Story.replay_mode = false
		Story.current_dream_night = 0
		Story.wake_kind = ""
		Engine.time_scale = 1.0
		Story.save_game()
		get_tree().change_scene_to_file(Story.ROOM_SCENE))


func _on_item_toggled(on: bool, item_name: String) -> void:
	item_override[item_name] = on
	_refresh_room()


func _clear_item_override() -> void:
	item_override.clear()
	_refresh_room()
	_refresh()


## 绕过 grant_buff 的 MAX_BUFFS 上限,方便一次挂一堆测试;信号照发,玩家/HUD 即时刷新。
func _on_buff_toggled(on: bool, id: StringName) -> void:
	if on and not Story.has_buff(id):
		Story.buffs_owned.append(String(id))
		Story.save_game()
		Story.buff_gained.emit(id)
	elif not on and Story.has_buff(id):
		Story.buffs_owned.erase(String(id))
		Story.save_game()
		Story.buff_removed.emit(id)
	_refresh()


func _clear_buffs() -> void:
	for id: String in Story.buffs_owned.duplicate():
		Story.buffs_owned.erase(id)
		Story.buff_removed.emit(StringName(id))
	Story.save_game()
	_refresh()


# ============================================================
# 纯代码建 UI
# ============================================================
func _build_ui() -> void:
	var panel := Control.new()
	panel.size = DESIGN
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 14
	panel.theme = theme
	add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.85)
	bg.size = DESIGN  # 默认 MOUSE_FILTER_STOP,顺带挡住往游戏里漏的点击
	panel.add_child(bg)

	var margin := MarginContainer.new()
	margin.size = DESIGN
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "开发者面板"
	title.modulate = Color(1.0, 0.85, 0.4)
	head.add_child(title)
	var hint := Label.new()
	hint.text = "   F8 开关 · Esc 关闭 · 打开时游戏暂停"
	hint.modulate = Color(1, 1, 1, 0.5)
	head.add_child(hint)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	_build_progress_column(_column(cols, "进度 / 天数"))
	_build_jump_column(_column(cols, "直接入梦"))
	_build_items_column(_column(cols, "房间物品(覆盖显隐)"))
	_build_buffs_column(_column(cols, "携带 Buff(可超上限)"))


func _build_progress_column(col: VBoxContainer) -> void:
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(170, 0)
	col.add_child(_status)

	var day_label := Label.new()
	day_label.text = "设已完成夜数:"
	day_label.modulate = Color(1, 1, 1, 0.6)
	col.add_child(day_label)
	var grid := GridContainer.new()
	grid.columns = 4
	col.add_child(grid)
	for n in 8:
		var b := Button.new()
		b.text = str(n)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_day.bind(n))
		grid.add_child(b)

	_next_label = Label.new()
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.custom_minimum_size = Vector2(170, 0)
	col.add_child(_next_label)
	_night_check = _check(col, "夜晚(惊醒后)", _on_night_toggled)

	_button(col, "通关当前梦 (F9)", _complete_dream)
	_button(col, "回到房间", _goto_room)
	_button(col, "重载当前场景", _reload_scene)
	_button(col, "清空进度 (F12)", _reset_progress)


func _build_jump_column(col: VBoxContainer) -> void:
	_intro_check = _check(col, "播放入梦字卡", func(_on: bool) -> void: pass)
	_replay_check = _check(col, "回顾模式(不推进度)", func(_on: bool) -> void: pass)
	for night in range(1, 8):
		_button(col, NIGHT_TITLES[night - 1], _jump_dream.bind(night))
	_button(col, "Boss Rush 测试场", _goto_boss_rush)


func _build_items_column(col: VBoxContainer) -> void:
	for item_name: String in ITEM_NIGHTS:
		var text := "%d %s" % [ITEM_NIGHTS[item_name], BuffDefs.display_name(StringName(item_name))]
		var check := _check(col, text, _on_item_toggled.bind(item_name))
		_item_checks[item_name] = check
	_button(col, "清除覆盖(跟随进度)", _clear_item_override)


func _build_buffs_column(col: VBoxContainer) -> void:
	# 技能会越来越多:列表放进滚动区,往下划;"清空"按钮固定在滚动区外。
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for id: StringName in BuffDefs.DEFS:
		if BuffDefs.is_variant(id):
			continue  # 状态显示变体不是可持有技能,别列出来
		var check := _check(list, BuffDefs.display_name(id), _on_buff_toggled.bind(id))
		_buff_checks[id] = check
	_button(col, "清空 Buff", _clear_buffs)


func _column(parent: Control, title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var lab := Label.new()
	lab.text = title_text
	lab.modulate = Color(0.65, 0.85, 1.0)
	box.add_child(lab)
	return box


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(parent: Control, text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(cb)
	parent.add_child(c)
	return c
