# res://levels/remi's_room/remi_room.gd
# 雷米的房间:一周目的"家"与选关界面。
# 管:收集品按进度显隐 / 昼夜窗景 / 点床入睡(窗户入夜→全黑→Venus 引路)/
#     早晨·惊醒两种醒来演出 / 点物品的自言自语与回顾梦。
# 状态与切场景在 Story autoload,全屏文字在 Dialogue autoload。
extends Node2D

const VENUS_SCENE: PackedScene = preload("res://levels/remi's_room/venus.tscn")

const DAY_TINT := Color(0.58, 0.535, 0.47, 1.0)
const NIGHT_TINT := Color(0.40, 0.43, 0.56, 1.0)
const NIGHT_SKY_COLOR := Color(0.08, 0.11, 0.28)

## 第 N 夜的梦醒来后,房间里多出的东西(从梦里带回来的)
const COLLECT_BY_NIGHT: Dictionary = {
	1: ["Table"],
	2: ["Watertank"],
	3: ["CopperLamp"],
	4: ["SaltLight"],
	5: ["SpiderQueenDoll"],
	6: ["Plant", "Flower", "BlueCrystal"],
	7: ["YunwuPaint", "RedCrystal"],
}
## 物品 → 它的灯
const GLOW_BY_ITEM: Dictionary = {
	"Watertank": "TankGlow",
	"SaltLight": "SaltGlow",
	"CopperLamp": "LampGlow",
	"BlueCrystal": "BlueCrystalGlow",
	"RedCrystal": "RedCrystalGlow",
	"Flower": "FlowerGlow",
}
## 挡在窗户前面的家具:入睡动画时直接淡出(黑剪影会挡窗),夜里整个隐藏
const WINDOW_BLOCKERS: Array[String] = ["Table", "CopperLamp"]

## 物品 → 回顾哪一夜的梦
const NIGHT_BY_ITEM: Dictionary = {
	"Table": 1, "Watertank": 2, "CopperLamp": 3, "SaltLight": 4,
	"SpiderQueenDoll": 5, "Plant": 6, "Flower": 6, "BlueCrystal": 6,
	"YunwuPaint": 7, "RedCrystal": 7,
}

## 物品自言自语。lines 打完弹选项;flavor 选项回一句再回到选项;replay 进旧梦。
## 文案铁律:第一人称自言自语,能省主语就省,严禁出现名字。
const ITEM_TALK: Dictionary = {
	"Table": {
		"lines": ["桌上那本书还摊开着。", "指尖的伤口,已经结痂了。"],
		"flavor": [
			["翻一页", "……就是这一页划的。纸真薄啊。"],
			["摸摸划痕", "有点痒。快好了。"],
		],
		"replay": "回到第一夜的梦里",
	},
	"Watertank": {
		"lines": ["水箱咕嘟咕嘟地冒着泡。", "珊瑚在灯下轻轻地摇。"],
		"flavor": [
			["敲敲玻璃", "……别打扰它们。里面睡着一整片海。"],
			["换点水", "今天已经换过了。"],
		],
		"replay": "回到珊瑚摇篮",
	},
	"CopperLamp": {
		"lines": ["铜灯的发条还剩一点劲儿。", "咔哒、咔哒,像那座城市的心跳。"],
		"flavor": [
			["上满发条", "……转起来了。别停下来啊。"],
			["听一会儿", "咔哒。咔哒。咔哒。"],
		],
		"replay": "回到铁锈城",
	},
	"SaltLight": {
		"lines": ["盐灯亮着一小团粉色的光。", "像把那座山搬回来了一角。"],
		"flavor": [
			["舔一下", "……咸的。果然是盐。"],
			["凑近看", "光里有细细的纹路,一层一层。"],
		],
		"replay": "回到盐做的山",
	},
	"SpiderQueenDoll": {
		"lines": ["毛茸茸的,八条腿。", "做成玩偶,就一点也不吓人了。"],
		"flavor": [
			["捏一捏", "软的。她本人可硬多了。"],
			["摆正一点", "好了,坐得端端正正。"],
		],
		"replay": "回到蛛网森林",
	},
	"Plant": {
		"lines": ["叶子绿得发亮。", "梦里的森林,就是这个味道。"],
		"flavor": [
			["浇点水", "咕咚咕咚。慢慢长啊。"],
			["闻一闻", "湿土和叶子的味道。"],
		],
		"replay": "回到森林",
	},
	"Flower": {
		"lines": ["小小的一朵,开得很认真。"],
		"flavor": [
			["碰碰花瓣", "软软的。"],
		],
		"replay": "回到森林",
	},
	"BlueCrystal": {
		"lines": ["蓝色的水晶,凉凉的。", "里面像冻着一小片森林的夜。"],
		"flavor": [
			["贴在脸上", "冰冰的,舒服。"],
		],
		"replay": "回到森林",
	},
	"YunwuPaint": {
		"lines": ["云雾的画。挂上去,房间都安静了。", "礼拜日的钟声,好像还在耳边。"],
		"flavor": [
			["看一会儿", "雾的深处,有一座塔的影子。"],
		],
		"replay": "回到修道院",
	},
	"RedCrystal": {
		"lines": ["红色的水晶,微微发烫。", "最后一个梦留下的东西。"],
		"flavor": [
			["握在手里", "一下,一下,像有心跳。"],
		],
		"replay": "回到修道院",
	},
	"MuziPaint": {
		"lines": ["沐子的画。一直挂在这儿。"],
		"flavor": [
			["擦擦灰", "干干净净。"],
			["想一会儿", "……什么时候能再见面呢。"],
		],
		"replay": "",
	},
	"Window": {
		"lines": [],  # 白天/夜晚动态生成
		"flavor": [],
		"replay": "",
	},
}

var _busy := false
var _glow_energy: Dictionary = {}  # 灯 → 原始 energy

@onready var _room: Node2D = $Room
@onready var _window_view: WindowView = $Room/WindowView
@onready var _sky: Sprite2D = $Room/WindowView/Sky
@onready var _moon: Sprite2D = $Room/WindowView/Moon
@onready var _bird: Sprite2D = $Room/WindowView/Bird
@onready var _twinkles: Node2D = $Room/WindowView/Twinkles
@onready var _window: Sprite2D = $Room/Window
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
@onready var _beams: Node2D = $Ambience/WindowBeams
@onready var _dust: GPUParticles2D = $Ambience/Dust
@onready var _lights: Node2D = $Lights
@onready var _window_glow: PointLight2D = $Lights/WindowGlow
@onready var _remi: Remi = $Remi

var _night_sky_rect: ColorRect = null


func _ready() -> void:
	ClickableItem.interaction_enabled = true
	# 点击区域允许画全、互相重叠:拾取按绘制顺序排序,且只发给最上层那一个。
	# 树(Plant)声明在沐子的画之后、画在上层,重叠处树优先吃到悬停/点击。
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	for light: PointLight2D in _lights.get_children():
		_glow_energy[light] = light.energy
	_trim_sky()
	_build_night_sky_rect()
	_apply_collected()
	_window_view.night = clampi(Story.nights_completed + 1, 1, 7)
	_apply_time(Story.is_night)
	for area: ClickableItem in get_tree().get_nodes_in_group(ClickableItem.GROUP):
		area.clicked.connect(_on_item_clicked)

	# 兜底:入梦演出把 HUD 隐了但中途折返(或死在字卡里)时,回房间必须能看见
	Game.buff_hold.show_now()

	match Story.wake_kind:
		"morning":
			_wake_up(false)
		"night":
			_wake_up(true)
		_:
			Story.release_cover()
	Story.wake_kind = ""


# 离开房间时把视口拾取设置还原,不影响别的场景
func _exit_tree() -> void:
	get_viewport().physics_object_picking_sort = false
	get_viewport().physics_object_picking_first_only = false


# 天空贴图比窗框宽,右边多出一节会露出来,削掉 5px
const SKY_TRIM_RIGHT := 5.0

func _trim_sky() -> void:
	if _sky.texture == null:
		return
	var size := _sky.texture.get_size()
	_sky.region_enabled = true
	_sky.region_rect = Rect2(0, 0, size.x - SKY_TRIM_RIGHT, size.y)


# 夜空遮色片:盖在橙色天空上、月亮星星下面。alpha=0 是白天。
func _build_night_sky_rect() -> void:
	_night_sky_rect = ColorRect.new()
	_night_sky_rect.color = NIGHT_SKY_COLOR
	_night_sky_rect.position = _sky.position
	var size := Vector2(64, 64)
	if _sky.texture != null:
		size = _sky.texture.get_size() - Vector2(SKY_TRIM_RIGHT, 0)
	_night_sky_rect.size = size
	_night_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_sky_rect.modulate.a = 0.0
	# 跟窗外一起吃窗户的悬停提亮材质
	_night_sky_rect.use_parent_material = true
	_window_view.add_child(_night_sky_rect)
	_window_view.move_child(_night_sky_rect, _sky.get_index() + 1)


func _apply_collected() -> void:
	for night: int in COLLECT_BY_NIGHT:
		for item_name: String in COLLECT_BY_NIGHT[night]:
			# 开发者面板(Dev)可以逐件覆盖显隐,没覆盖就跟随进度
			var owned: bool = Dev.item_visible(item_name, night <= Story.nights_completed)
			var item := _room.get_node_or_null(NodePath(item_name)) as CanvasItem
			if item == null:
				continue
			item.visible = owned
			var area := item.get_node_or_null(^"Clickable") as Area2D
			if area != null:
				area.input_pickable = owned
			var glow := _glow_of(item_name)
			if glow != null:
				glow.visible = owned


func _glow_of(item_name: String) -> PointLight2D:
	if not GLOW_BY_ITEM.has(item_name):
		return null
	return _lights.get_node_or_null(NodePath(GLOW_BY_ITEM[item_name])) as PointLight2D


## 昼夜一键切换(瞬间到位;渐变都在各演出里自己做)
func _apply_time(night: bool) -> void:
	_canvas_modulate.color = NIGHT_TINT if night else DAY_TINT
	_night_sky_rect.modulate.a = 0.85 if night else 0.0
	_moon.visible = night
	_moon.modulate.a = 1.0
	_twinkles.visible = night
	_twinkles.modulate.a = 1.0
	# 小鸟一直都在,白天黑夜都不藏
	_bird.modulate.a = 1.0
	_beams.visible = not night
	_beams.modulate = Color.WHITE
	_window_glow.energy = 0.0 if night else _glow_energy[_window_glow]
	# 挡窗家具(桌子、铜灯)夜里藏掉;白天且已收集才显示
	for blocker_name in WINDOW_BLOCKERS:
		var blocker := _room.get_node_or_null(NodePath(blocker_name)) as CanvasItem
		if blocker == null:
			continue
		var owned: bool = Dev.item_visible(
			blocker_name, Story.nights_completed >= NIGHT_BY_ITEM[blocker_name])
		blocker.visible = owned and not night
		var area := blocker.get_node_or_null(^"Clickable") as Area2D
		if area != null:
			area.input_pickable = blocker.visible
		var glow := _glow_of(blocker_name)
		if glow != null:
			glow.visible = blocker.visible


# ============================================================
# 点击分发
# ============================================================
func _on_item_clicked(area: ClickableItem) -> void:
	if _busy or Dialogue.is_open:
		return
	var item := area.get_parent() as Node2D
	if item == null:
		return
	if item.name == "Bed":
		_bed_flow()
	elif ITEM_TALK.has(String(item.name)):
		_item_flow(item)


func _begin_interaction() -> void:
	_busy = true
	ClickableItem.interaction_enabled = false
	_remi.set_lock(true)
	_clear_hover_states()


func _end_interaction() -> void:
	_clear_hover_states()
	ClickableItem.interaction_enabled = true
	_remi.set_lock(false)
	_busy = false


# 悬停的提亮/压暗可能停在半路,收尾时全体归零
func _clear_hover_states() -> void:
	ClickableItem._active = null
	for area: ClickableItem in get_tree().get_nodes_in_group(ClickableItem.GROUP):
		area._tween_highlight(0.0, 0.2)
		area._dim_background(0.0, 0.2)


# ============================================================
# 床:推进主线
# ============================================================
func _bed_flow() -> void:
	_begin_interaction()
	if Story.nights_completed >= 7:
		await Dialogue.say([
			"七个梦,都做完了。",
			"房间里满满当当,像把一整个星期都摆了出来。",
			"……晚安。",
		])
		_end_interaction()
		return

	# 选项里带一个"自动开盾"开关,切换后留在原对话继续选
	var lines: Array
	if Story.is_night:
		lines = ["……心跳还没停下来。", "没事的。只是个梦。", "得回去,把它做完。"]
	else:
		lines = ["……窗外都安静下来了。", "今晚,又会梦见什么呢。"]
	var sleep_label: String = "再睡一次" if Story.is_night else "钻进被窝"
	var leave_label: String = "缓一缓" if Story.is_night else "再待一会儿"
	var pick: int
	while true:
		var auto_label := "自动开盾:开" if Story.auto_shield else "自动开盾:关"
		pick = await Dialogue.ask(lines, [sleep_label, auto_label, leave_label])
		if pick == 1:
			Story.auto_shield = not Story.auto_shield
			Story.save_game()
			lines = []  # 切开关后不再重打前面的话,直接回到选项
			continue
		break
	if pick != 0:
		_end_interaction()
		return
	await _sleep_cutscene()


## 入睡演出:房间飞快压黑(只留窗户和窗光)→ 窗外入夜 → 全黑 → Venus 引路 → 入梦。
func _sleep_cutscene() -> void:
	var fast := 0.35
	# 左上角 buff HUD 跟着一起沉入黑暗,字卡结束后由 DreamIntro 叫回来
	Game.buff_hold.fade_out(fast)
	# ① 除了窗户、窗外和窗光,全部飞快压黑;挡窗家具(桌子、铜灯)直接淡没
	var blockers: Array[CanvasItem] = []
	for blocker_name in WINDOW_BLOCKERS:
		var blocker := _room.get_node_or_null(NodePath(blocker_name)) as CanvasItem
		if blocker != null:
			blockers.append(blocker)
	for node: CanvasItem in _all_room_visuals():
		if node == _beams:
			continue
		var target := Color(0, 0, 0, 0) if node in blockers else Color.BLACK
		create_tween().tween_property(node, "modulate", target, fast)
	for light: PointLight2D in _lights.get_children():
		if light != _window_glow:
			create_tween().tween_property(light, "energy", 0.0, fast)
	_dust.visible = false
	await get_tree().create_timer(fast + 0.25).timeout

	# ② 窗外入夜:橙色→深蓝,光线消失,月亮浮现(惊醒后的夜里本来就黑着,跳过)
	if not Story.is_night:
		var night_tween := create_tween()
		night_tween.tween_property(_night_sky_rect, "modulate:a", 0.85, 2.2)
		var beam_tween := create_tween()
		beam_tween.tween_interval(0.4)
		beam_tween.tween_property(_beams, "modulate", Color(1, 1, 1, 0), 1.6)
		beam_tween.parallel().tween_property(_window_glow, "energy", 0.0, 1.6)
		_moon.visible = true
		_moon.modulate.a = 0.0
		_twinkles.visible = true
		_twinkles.modulate.a = 0.0
		var moon_tween := create_tween()
		moon_tween.tween_interval(1.2)
		moon_tween.tween_property(_moon, "modulate:a", 1.0, 1.4)
		moon_tween.parallel().tween_property(_twinkles, "modulate:a", 1.0, 1.4)
		await get_tree().create_timer(3.2).timeout
	else:
		await get_tree().create_timer(0.5).timeout

	# ③ 窗户也沉入黑暗
	create_tween().tween_property(_window, "modulate", Color.BLACK, 0.9)
	create_tween().tween_property(_window_view, "modulate", Color.BLACK, 0.9)
	await get_tree().create_timer(1.2).timeout

	# ④ 全黑里 Venus 引路
	await _venus_flight()
	Story.start_dream(Story.nights_completed + 1)


## Venus 在纯黑里飞过,身后拖一串光点。
func _venus_flight() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var venus := VENUS_SCENE.instantiate() as Node2D
	venus.position = Vector2(200, 58)
	layer.add_child(venus)

	# 拖尾和烟花都是 venus.tscn 里的实体节点(Trail/Burst),参数直接在编辑器里调
	var trail := venus.get_node_or_null(^"Trail") as GPUParticles2D
	var burst := venus.get_node_or_null(^"Burst") as GPUParticles2D

	# 飞进来 → 停顿(拖尾停,放一朵烟花) → 重开拖尾飞走。整体放慢,优雅一点。
	var fly_in := create_tween()
	fly_in.tween_property(venus, "position", Vector2(96, 44), 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fly_in.finished

	if trail != null:
		trail.emitting = false
	if burst != null:
		burst.restart()

	var bob := create_tween()
	bob.tween_property(venus, "position:y", 41.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(venus, "position:y", 46.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await bob.finished
	await get_tree().create_timer(0.4).timeout

	if trail != null:
		trail.emitting = true
	var fly_out := create_tween()
	fly_out.tween_property(venus, "position", Vector2(-40, 24), 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fly_out.finished
	await get_tree().create_timer(0.3).timeout
	layer.queue_free()


# ============================================================
# 醒来
# ============================================================
## morning:黑 → 窗户和光先亮 → 房间跟上。night(惊醒):黑 → 房间冷色直接浮现,无窗光。
func _wake_up(night: bool) -> void:
	_begin_interaction()
	_apply_time(night)
	# 先把一切摆成黑,再撤外层遮罩,交接瞬间画面不变
	var visuals := _all_room_visuals()
	visuals.append(_window)
	visuals.append(_window_view)
	for node: CanvasItem in visuals:
		node.modulate = Color.BLACK
	for light: PointLight2D in _lights.get_children():
		light.energy = 0.0
	_remi.global_position = Vector2(120, 80)
	Story.release_cover()
	await get_tree().create_timer(0.4).timeout

	if night:
		for node: CanvasItem in visuals:
			create_tween().tween_property(node, "modulate", Color.WHITE, 1.2)
		for light: PointLight2D in _lights.get_children():
			if light != _window_glow and light.visible:
				create_tween().tween_property(light, "energy", _glow_energy[light], 1.2)
		await get_tree().create_timer(1.4).timeout
	else:
		# 窗户的光先照进来
		create_tween().tween_property(_window, "modulate", Color.WHITE, 1.0)
		create_tween().tween_property(_window_view, "modulate", Color.WHITE, 1.0)
		create_tween().tween_property(_beams, "modulate", Color.WHITE, 1.4)
		create_tween().tween_property(_window_glow, "energy", _glow_energy[_window_glow], 1.4)
		await get_tree().create_timer(0.9).timeout
		for node: CanvasItem in visuals:
			if node == _window or node == _window_view:
				continue
			create_tween().tween_property(node, "modulate", Color.WHITE, 1.3)
		for light: PointLight2D in _lights.get_children():
			if light != _window_glow and light.visible:
				create_tween().tween_property(light, "energy", _glow_energy[light], 1.3)
		await get_tree().create_timer(1.4).timeout
	_end_interaction()


## 房间里所有参与明暗演出的可见体(不含 Window/WindowView,它们常被单独处理)
func _all_room_visuals() -> Array[CanvasItem]:
	var visuals: Array[CanvasItem] = []
	for child in _room.get_children():
		var canvas := child as CanvasItem
		if canvas != null and canvas != _window and canvas != _window_view and canvas.visible:
			visuals.append(canvas)
	visuals.append(_beams)
	visuals.append(_remi)
	return visuals


# ============================================================
# 物品:自言自语 + 回顾梦
# ============================================================
func _item_flow(item: Node2D) -> void:
	_begin_interaction()
	_focus_item(item, true)

	var talk: Dictionary = ITEM_TALK[String(item.name)]
	var lines: Array = talk["lines"]
	if item.name == "Window":
		lines = _window_lines()
	if not lines.is_empty():
		await Dialogue.say(lines)

	while true:
		var options: Array = []
		# 物品对应的 buff 还没拿 → 第一个选项就是"收下"
		var buff_id := StringName(String(item.name))
		var buff_index := -1
		if BuffDefs.has_buff_def(buff_id) and not Story.has_buff(buff_id):
			buff_index = options.size()
			options.append("收下这份力量")
		var flavor: Array = talk["flavor"]
		var flavor_base: int = options.size()
		for entry: Array in flavor:
			options.append(entry[0])
		var replay_text: String = talk["replay"]
		var replay_index := -1
		if not replay_text.is_empty():
			replay_index = options.size()
			options.append(replay_text)
		var leave_index: int = options.size()
		options.append("离开")

		var pick := await Dialogue.ask([], options)
		if pick == leave_index or pick < 0:
			break
		if pick == buff_index:
			if Story.buffs_owned.size() >= Story.MAX_BUFFS:
				await Dialogue.say(["手里已经握着两份力量了。", "得先放下一个,才能接住新的。"])
				continue
			Story.grant_buff(buff_id)
			await Dialogue.say_gain(
				"获得 buff\n「{icon}%s」" % BuffDefs.display_name(buff_id),
				BuffDefs.icon(buff_id),
				BuffDefs.desc(buff_id))
			continue
		if pick == replay_index:
			_focus_item(item, false)
			Game.buff_hold.fade_out(0.45)  # 回顾梦没有字卡,DreamIntro 的跳过分支会叫回来
			await Game.fade_cover(1.0, 0.45)
			Story.start_dream(NIGHT_BY_ITEM[String(item.name)], true)
			return
		await Dialogue.say([flavor[pick - flavor_base][1]])

	_focus_item(item, false)
	_end_interaction()


func _window_lines() -> Array:
	if Story.is_night:
		return ["窗玻璃凉凉的。", "月亮又圆了一点。"]
	return ["窗户擦得很干净。", "小鸟在窗台上蹦来蹦去。"]


## 聚焦物品:房间沉下去,只有它和自己还亮着。
func _focus_item(item: Node2D, focused: bool) -> void:
	var dim := Color(0.12, 0.12, 0.14) if focused else Color.WHITE
	var visuals := _all_room_visuals()
	visuals.append(_window)
	visuals.append(_window_view)
	# 窗外的天空/小鸟是窗户的一部分,聚焦窗户时跟着一起亮
	var keep: Array[CanvasItem] = [item, _remi]
	if item == _window:
		keep.append(_window_view)
	for node: CanvasItem in visuals:
		if node in keep:
			continue
		create_tween().tween_property(node, "modulate", dim, 0.35)
	var item_glow := _glow_of(String(item.name))
	for light: PointLight2D in _lights.get_children():
		if not light.visible or light == item_glow:
			continue
		if light == _window_glow and Story.is_night:
			continue  # 夜里窗光本来就是灭的,别碰
		var energy: float = _glow_energy[light] * (0.15 if focused else 1.0)
		create_tween().tween_property(light, "energy", energy, 0.35)
