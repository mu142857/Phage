# res://interactive/BuffHold/buff_hold.gd
# 左上角持有 buff 展示(上限 Story.MAX_BUFFS=2):
# 1 个 = 单格框 BuffHold1,2 个 = 双格框 BuffHold2,8×8 图标嵌在格洞里。
# 左键格子 → 先看名字和介绍,再问要不要放下(期间暂停游戏,Dialogue 不受暂停影响)。
# 由 Game 常驻实例化,跟随存档变化自动刷新。
extends CanvasLayer

const FRAME_SINGLE: Texture2D = preload("res://interactive/BuffHold/BuffHold1.png")
const FRAME_DOUBLE: Texture2D = preload("res://interactive/BuffHold/BuffHold2.png")
const MARGIN := Vector2(2.0, 2.0)                      # 距屏幕左上角
const SLOT_OFFSETS: Array[Vector2] = [Vector2(1, 1), Vector2(10, 1)]  # 格洞位置(8×8)

var _root: Control = null
var _fade_tween: Tween = null

func _ready() -> void:
	layer = 100  # 盖在游戏画面上,躲在 Dialogue(150) 底下
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	Story.buff_gained.connect(_on_buffs_changed)
	Story.buff_removed.connect(_on_buffs_changed)
	Story.muzi_broken_changed.connect(_rebuild)  # 守望破碎/复原时换图标
	# Game 这个 autoload 排在 Story 前面:此刻存档(load_save)还没跑,直接
	# _rebuild 会读到空列表且事后没有信号。延迟到全部 autoload 就绪后再建。
	_rebuild.call_deferred()


func _on_buffs_changed(_id: StringName) -> void:
	_rebuild()


# ---- 转场演出用:入梦时随画面隐去,字卡结束后再回来 ----
func fade_out(duration: float) -> void:
	_start_fade(0.0, duration)


func fade_in(duration: float) -> void:
	_start_fade(1.0, duration)


## 立即恢复显示(房间 _ready 的兜底,防演出中断把 HUD 永久黑掉)。
func show_now() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_root.modulate.a = 1.0


func _start_fade(target_alpha: float, duration: float) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_root, "modulate:a", target_alpha, duration)


func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	var owned: Array = Story.buffs_owned
	if owned.is_empty():
		return
	var count := mini(owned.size(), Story.MAX_BUFFS)
	var frame := TextureRect.new()
	frame.texture = FRAME_DOUBLE if count >= 2 else FRAME_SINGLE
	frame.position = MARGIN
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	for i in count:
		var id := StringName(String(owned[i]))
		var icon := TextureRect.new()
		icon.texture = BuffDefs.icon(_display_id(id))
		icon.position = MARGIN + SLOT_OFFSETS[i]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(icon)
		# 透明点击区盖住格洞,左键查看
		var click := Control.new()
		click.position = MARGIN + SLOT_OFFSETS[i]
		click.size = Vector2(8, 8)
		click.mouse_filter = Control.MOUSE_FILTER_STOP
		click.gui_input.connect(_on_slot_input.bind(id))
		_root.add_child(click)


func _on_slot_input(event: InputEvent, id: StringName) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_inspect(id)


## 先报名字,按键后带着介绍弹选项:放下 / 留着。
func _inspect(id: StringName) -> void:
	if Dialogue.is_open:
		return
	var shown := _display_id(id)  # 破碎的守望显示变体名/介绍,放下仍操作真身
	var tree := get_tree()
	tree.paused = true
	var pick := await Dialogue.ask(
		["「%s」" % BuffDefs.display_name(shown), BuffDefs.desc(shown)],
		["放下", "留着"])
	tree.paused = false
	if pick == 0:
		Story.remove_buff(id)


# 显示用 id:沐子的守望在本场尝试里用掉后,换成"破碎的守望"的图标和文案。
func _display_id(id: StringName) -> StringName:
	if id == &"MuziPaint" and Story.muzi_broken:
		return &"MuziPaint_Broke"
	return id
