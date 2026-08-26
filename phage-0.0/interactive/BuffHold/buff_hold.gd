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

# ---- 护盾进度条(素材 ShieldBar.png:三条 19×4,行距5,中间两行=进度填充) ----
# 槽0=第一条(棕框,基础盾);槽1/2=第二三条(绿框,森林的谢礼附加的两层)。
# 就绪=满条,充能中=遮罩从右盖住未充部分逐渐揭开(排队制,同时只有一条在涨),
# 拿着的那条微亮。条数=盾数(默认1/树3)。只在梦里(有主角)显示。
const SHIELD_BAR: Texture2D = preload("res://entities/player/ShieldBar.png")
const BAR_SIZE := Vector2(19, 4)
const BAR_PITCH := 5.0            # 素材里条与条的行距(4px条+1px空)
const BAR_FILL_X := 1.0           # 填充区:x 1..17,中间两行
const BAR_FILL_W := 17.0
const BAR_FILL_Y := 1.0
const BAR_FILL_H := 2.0
const BAR_TOP := 14.0             # 整组条贴在 buff 框下方
const BAR_MASK_COLOR := Color(0.12, 0.13, 0.12, 1.0)  # 未充部分的暗色(近框色)
const BAR_GUARD_MODULATE := Color(1.25, 1.25, 1.25)

var _root: Control = null
var _fade_tween: Tween = null
var _bars_root: Control = null
var _bars: Array[TextureRect] = []
var _masks: Array[ColorRect] = []
var _player: Player = null

func _ready() -> void:
	layer = 100  # 盖在游戏画面上,躲在 Dialogue(150) 底下
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# 护盾条挂在 _root 下,转场淡入淡出跟着一起走
	_bars_root = Control.new()
	_bars_root.position = Vector2(MARGIN.x, BAR_TOP)
	_bars_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bars_root)
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
		if child != _bars_root:
			child.queue_free()
	_built_display = _current_display()
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


# 显示用 id:按运行状态换脸——碎掉的守望/冷却中的云雾/燃烧中的铜灯。
func _display_id(id: StringName) -> StringName:
	if id == &"MuziPaint" and Story.muzi_broken:
		return &"MuziPaint_Broke"
	if id == &"YunwuPaint" and is_instance_valid(_player) and _player.mist_cooldown_left > 0.0:
		return &"YunwuPaintInactive"
	if id == &"CopperLamp" and is_instance_valid(_player) and _player._lamp_fire_left > 0.0:
		return &"CopperLampActive"
	return id


# 运行状态变了(冷却开始/结束、点燃/熄灭)就重建图标,数组随 _rebuild 记录。
var _built_display: Array = []

func _current_display() -> Array:
	var owned: Array = Story.buffs_owned
	var result: Array = []
	for i in mini(owned.size(), Story.MAX_BUFFS):
		result.append(String(_display_id(StringName(String(owned[i])))))
	return result


# ---- 护盾进度条 ----

## 主角出生时来登记(player._ready 调用);死亡/换场景自动解绑,房间里不显示。
func bind_player(player: Player) -> void:
	_player = player
	player.shield_changed.connect(_rebuild_bars)
	player.tree_exited.connect(_on_player_gone)
	_rebuild_bars()


func _on_player_gone() -> void:
	_player = null
	_rebuild_bars()


## 条的数量随护盾层数(花1/默认2/树3);素材第 i 条对应第 i 个盾位。
func _rebuild_bars() -> void:
	for child in _bars_root.get_children():
		child.queue_free()
	_bars.clear()
	_masks.clear()
	if not is_instance_valid(_player):
		return
	for i in _player.shield_ready.size():
		var atlas := AtlasTexture.new()
		atlas.atlas = SHIELD_BAR
		# 槽0=棕框条,槽1/2=绿框条(素材第二三行)
		atlas.region = Rect2(0.0, float(mini(i, 2)) * BAR_PITCH, BAR_SIZE.x, BAR_SIZE.y)
		var bar := TextureRect.new()
		bar.texture = atlas
		bar.position = Vector2(0.0, float(i) * BAR_PITCH)
		bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars_root.add_child(bar)
		_bars.append(bar)
		var mask := ColorRect.new()
		mask.color = BAR_MASK_COLOR
		mask.position = Vector2(BAR_FILL_X, BAR_FILL_Y)
		mask.size = Vector2(0.0, BAR_FILL_H)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(mask)
		_masks.append(mask)
	_update_bars()


## 每帧更新充能进度(遮罩从右往左盖住未充部分)、"拿着"的微亮和状态图标。
func _process(_delta: float) -> void:
	_update_bars()
	if _current_display() != _built_display:
		_rebuild()


func _update_bars() -> void:
	if not is_instance_valid(_player) or _bars.is_empty():
		return
	for i in _bars.size():
		if i >= _player.shield_ready.size():
			break
		var total: float = maxf(_player.shield_recharge_time(i), 0.01)
		var progress := 1.0
		if not _player.shield_ready[i]:
			progress = clampf(1.0 - _player.shield_recharge[i] / total, 0.0, 1.0)
		var filled := roundf(BAR_FILL_W * progress)
		_masks[i].position.x = BAR_FILL_X + filled
		_masks[i].size.x = BAR_FILL_W - filled
		_bars[i].modulate = BAR_GUARD_MODULATE if i == _player.guard_slot else Color.WHITE
