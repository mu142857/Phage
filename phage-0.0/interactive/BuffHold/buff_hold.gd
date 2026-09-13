# res://interactive/BuffHold/buff_hold.gd
# 左上角 buff 展示:格子数随内容往右无限拼(框从 BuffHold2 切边框/格洞/隔条拼出来),
# 最左是强制 buff(浅浅的梦/水下:环境挂的,不占上限、不能放下),右边是持有的 buff
# (上限 Story.MAX_BUFFS=2)。8×8 图标嵌在格洞里。
# 左键格子 → 持有的:看名字介绍再问放不放下;水下:只看说明;浅浅的梦:问继续做梦还是醒来
# (期间暂停游戏,Dialogue 不受暂停影响)。由 Game 常驻实例化,跟随存档/环境变化自动刷新。
# 右侧竖着一根氧气条(素材 OxygenBar.png 4×36):在水下时显示,从上往下流逝,
# 顶到底下的红格 = 死;握着珊瑚潮汐时满着不动。
extends CanvasLayer

const FRAME_SHEET: Texture2D = preload("res://interactive/BuffHold/BuffHold2.png")
const MARGIN := Vector2(2.0, 2.0)                      # 距屏幕左上角
# BuffHold2 的切法:x0 左边框 | x1..8 格洞 | x9 隔条 | x10..17 格洞 | x18 右边框,高 10
const FRAME_H := 10.0
const CELL_PITCH := 9.0                                # 一格 8 + 隔条 1
const FRAME_LEFT := Rect2(0, 0, 1, 10)
const FRAME_CELL := Rect2(1, 0, 8, 10)
const FRAME_DIVIDER := Rect2(9, 0, 1, 10)
const FRAME_RIGHT := Rect2(18, 0, 1, 10)

# ---- 氧气条(OxygenBar.png 4×36):x1..2 是柱子,y1..31 可流逝区,y33..34 红格=死线 ----
const OXYGEN_BAR: Texture2D = preload("res://entities/player/OxygenBar.png")
const OXYGEN_POS := Vector2(154.0, 27.0)               # 屏幕右缘,竖向居中
const OXYGEN_FILL := Rect2(1.0, 1.0, 2.0, 31.0)
const OXYGEN_EMPTY_COLOR := Color(93.0 / 255.0, 62.0 / 255.0, 54.0 / 255.0, 1.0)  # 流走的部分=框色

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
	Story.forced_buffs_changed.connect(_rebuild)  # 入水/排干/回笼觉/回房间
	_build_oxygen_bar()
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


## 立即藏起(开机加载屏切房间前调用,HUD 随房间一起从黑里浮现)。
func hide_now() -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_root.modulate.a = 0.0


func _start_fade(target_alpha: float, duration: float) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_root, "modulate:a", target_alpha, duration)


func _rebuild() -> void:
	for child in _root.get_children():
		if child != _bars_root and child != _oxygen_root:
			child.queue_free()
	_built_display = _current_display()
	var ids := _slot_ids()
	if ids.is_empty():
		return
	# 框:左边框 + (格洞 + 隔条)×(n-1) + 格洞 + 右边框,总宽 9n+1
	var n := ids.size()
	_add_frame_piece(FRAME_LEFT, 0.0)
	for i in n:
		_add_frame_piece(FRAME_CELL, 1.0 + CELL_PITCH * float(i))
		if i < n - 1:
			_add_frame_piece(FRAME_DIVIDER, 9.0 + CELL_PITCH * float(i))
	_add_frame_piece(FRAME_RIGHT, 1.0 + CELL_PITCH * float(n) - 1.0)
	for i in n:
		var id: StringName = ids[i]
		var slot := MARGIN + Vector2(1.0 + CELL_PITCH * float(i), 1.0)
		var icon := TextureRect.new()
		icon.texture = BuffDefs.icon(_display_id(id))
		icon.position = slot
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(icon)
		# 透明点击区盖住格洞,左键查看
		var click := Control.new()
		click.position = slot
		click.size = Vector2(8, 8)
		click.mouse_filter = Control.MOUSE_FILTER_STOP
		click.gui_input.connect(_on_slot_input.bind(id))
		_root.add_child(click)


func _add_frame_piece(region: Rect2, x: float) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = FRAME_SHEET
	atlas.region = region
	var piece := TextureRect.new()
	piece.texture = atlas
	piece.position = MARGIN + Vector2(x, 0.0)
	piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(piece)


# 格子顺序:强制 buff 在左,持有的在右(截到上限)。
func _slot_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for f in Story.forced_buffs():
		ids.append(f)
	var owned: Array = Story.buffs_owned
	for i in mini(owned.size(), Story.MAX_BUFFS):
		ids.append(StringName(String(owned[i])))
	return ids


func _on_slot_input(event: InputEvent, id: StringName) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_inspect(id)


## 先报名字,按键后带着介绍弹选项:放下 / 留着。
## 强制 buff 没有"放下":水下只看说明;浅浅的梦报回来的次数,问继续做梦还是醒来。
func _inspect(id: StringName) -> void:
	if Dialogue.is_open:
		return
	var shown := _display_id(id)  # 破碎的守望显示变体名/介绍,放下仍操作真身
	var tree := get_tree()
	tree.paused = true
	if id == &"ALightDream":
		var times := Story.revisit_count(Story.current_dream_night)
		var pick := await Dialogue.ask(
			["「%s」" % BuffDefs.display_name(id), "这是第 %d 次回到这个梦了。" % times],
			["继续做梦", "醒来"])
		tree.paused = false
		if pick == 1:
			Story.wake_early()
		return
	if BuffDefs.is_forced(id):
		await Dialogue.say(["「%s」" % BuffDefs.display_name(shown), BuffDefs.desc(shown)])
		tree.paused = false
		return
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
	var result: Array = []
	for id in _slot_ids():
		result.append(String(_display_id(id)))
	return result


# ---- 氧气条 ----
var _oxygen_root: TextureRect = null
var _oxygen_mask: ColorRect = null


func _build_oxygen_bar() -> void:
	_oxygen_root = TextureRect.new()
	_oxygen_root.texture = OXYGEN_BAR
	_oxygen_root.position = OXYGEN_POS
	_oxygen_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_oxygen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oxygen_root.visible = false
	_root.add_child(_oxygen_root)
	# 流走的部分:从顶上盖下来的一块框色
	_oxygen_mask = ColorRect.new()
	_oxygen_mask.color = OXYGEN_EMPTY_COLOR
	_oxygen_mask.position = OXYGEN_FILL.position
	_oxygen_mask.size = Vector2(OXYGEN_FILL.size.x, 0.0)
	_oxygen_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oxygen_root.add_child(_oxygen_mask)


func _update_oxygen_bar() -> void:
	if _oxygen_root == null:
		return
	var show := Story.in_dream and Story.underwater
	_oxygen_root.visible = show
	if not show:
		return
	var gone := roundf(OXYGEN_FILL.size.y * (1.0 - clampf(Story.oxygen, 0.0, 1.0)))
	_oxygen_mask.size.y = gone


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
	_update_oxygen_bar()
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
