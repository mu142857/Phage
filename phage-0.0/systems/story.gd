# res://systems/story.gd
# 一周目"七夜"主循环 autoload。
# 管:睡了几夜(nights_completed)/房间昼夜/入梦·通关·失败的场景路由/存档/
#     梦境破碎(死亡)演出/调试快捷键 F9 一键通关当前梦。
# 房间侧的演出(睡觉、Venus 引路、醒来)在 remi_room.gd,这里只管状态与切场景。
extends Node

const ROOM_SCENE := "res://levels/remi's_room/remi's_room.tscn"
## 七夜的梦。cradle_corridor / rust_city 还没做完,先直接进 boss 场景。
const DREAM_SCENES: Array[String] = [
	"res://levels/spawn_room/spawn_room.tscn",              # 周一《伤口》
	"res://levels/cradle_of_decay/cradle_of_decay.tscn",    # 周二《珊瑚摇篮》
	"res://levels/rust_arena/rust_arena.tscn",              # 周三《铁锈城》
	"res://levels/pink_land/pink_land.tscn",                # 周四《盐做的山》
	"res://levels/spider_forest/spider_forest.tscn",        # 周五《网》
	"res://levels/silvaron/silvaron.tscn",                  # 周六《森林的谢礼》
	"res://levels/crimson_sanctum/crimson_sanctum.tscn",    # 周日《礼拜日》
]
const SAVE_PATH := "user://phage_save.cfg"

var nights_completed := 0    # 已做完几个梦(0-7)
var is_night := false        # 房间时刻:false=白天;true=夜晚(梦里死了惊醒)
var buffs_owned: Array = []  # 已获得的 buff id(= 房间物品节点名,定义见 BuffDefs)
var auto_shield := false     # 自动开盾(床边选项):有就绪盾就自动拿出,E 变手动备份
var in_dream := false
var replay_mode := false     # 点旧物品"回到梦里"的回顾模式:不推进度、跳过字卡
var current_dream_night := 0 # 正在做第几夜的梦(1-7)
var wake_kind := ""          # 回到房间要播的醒来演出:"" / "morning" / "night"

var _dream_settled := false  # 当前梦已判定过通关/失败,防止双触发
var _shatter_layer: CanvasLayer = null

## 获得新 buff 时发出,供技能系统/HUD 接。
signal buff_gained(id: StringName)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()


func _input(event: InputEvent) -> void:
	# 调试快捷键:F9 = 一键通关当前梦(很多关还没做完的临时出口)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F9:
		if in_dream and not _dream_settled:
			print("[Story] F9 一键通关第 ", current_dream_night, " 夜")
			complete_dream()
	elif key.physical_keycode == KEY_F12:
		# 调试:清空进度,直接回到第一夜的白天空房间
		print("[Story] F12 清空进度,回到第一夜")
		nights_completed = 0
		is_night = false
		buffs_owned = []
		buff_removed.emit(&"")  # 让 BuffHold 等监听方刷新(id 无意义)
		in_dream = false
		replay_mode = false
		current_dream_night = 0
		_dream_settled = false
		wake_kind = ""
		Engine.time_scale = 1.0
		save_game()
		get_tree().change_scene_to_file(ROOM_SCENE)


# ============================================================
# 入梦
# ============================================================

## 进入第 night 夜的梦。调用方(房间)保证此刻屏幕已全黑。
func start_dream(night: int, replay := false) -> void:
	if in_dream:
		return
	night = clampi(night, 1, DREAM_SCENES.size())
	current_dream_night = night
	in_dream = true
	replay_mode = replay
	_dream_settled = false
	await Game.fade_cover(1.0, 0.0)  # 保底铺黑,盖住换场景的瞬间
	get_tree().change_scene_to_file(DREAM_SCENES[night - 1])
	await get_tree().process_frame
	await get_tree().process_frame
	# DreamIntro 播放时它自带的黑幕在下面接住;跳过字卡(回顾/死亡重试)就是普通淡入
	await Game.fade_cover(0.0, 0.35)


# ============================================================
# 梦的两种结局
# ============================================================

## 梦完成:通关触发器(DreamEnd)或 F9 调用。
func complete_dream() -> void:
	if not in_dream or _dream_settled:
		return
	_dream_settled = true
	if not replay_mode:
		nights_completed = maxi(nights_completed, current_dream_night)
		is_night = false
	wake_kind = "night" if is_night else "morning"
	save_game()
	await Game.fade_cover(1.0, 0.6)
	_goto_room()


## 梦里死亡:梦境破碎,惊醒在夜里。由 Game.handle_player_death 委托过来。
func fail_dream() -> void:
	if not in_dream or _dream_settled:
		return
	_dream_settled = true
	# 死亡瞬间可能还挂着顿帧/慢动作,先恢复正常时间
	Game.slowmo_token += 1
	Engine.time_scale = 1.0
	# 停一拍,看清爆炸(真实时间)
	await get_tree().create_timer(0.45, true, false, true).timeout
	await _play_shatter()
	is_night = true
	wake_kind = "night"
	save_game()
	_goto_room()


func _goto_room() -> void:
	in_dream = false
	replay_mode = false
	current_dream_night = 0
	set_muzi_broken(false)  # 回到房间,守望复原
	get_tree().change_scene_to_file(ROOM_SCENE)


## 房间摆好自己的"全黑初始状态"后调用:撤掉所有换场景用的遮罩。
func release_cover() -> void:
	Game.fade_cover(0.0, 0.0)
	if is_instance_valid(_shatter_layer):
		_shatter_layer.queue_free()
	_shatter_layer = null


# ============================================================
# 梦境破碎:画面定格 → 碎成巨像素块坠落 → 露出黑底。
# 渲染铁律禁旋转,所以不做斜碎玻璃,用 160×90 网格的方块坠落。
# ============================================================
func _play_shatter() -> void:
	var viewport := get_viewport()
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	var texture := ImageTexture.create_from_image(image)

	_shatter_layer = CanvasLayer.new()
	_shatter_layer.layer = 900
	add_child(_shatter_layer)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shatter_layer.add_child(black)

	var logical := viewport.get_visible_rect().size          # 160×90
	var texture_scale := logical.x / float(texture.get_width())
	var cell := 10.0                                          # 逻辑像素的碎块边长
	var cols := int(ceilf(logical.x / cell))
	var rows := int(ceilf(logical.y / cell))
	var shards: Node2D = Node2D.new()
	_shatter_layer.add_child(shards)

	for row in rows:
		for col in cols:
			var shard := Sprite2D.new()
			shard.texture = texture
			shard.centered = false
			shard.region_enabled = true
			shard.region_rect = Rect2(
				col * cell / texture_scale, row * cell / texture_scale,
				cell / texture_scale, cell / texture_scale)
			shard.scale = Vector2(texture_scale, texture_scale)
			shard.position = Vector2(col * cell, row * cell)
			shards.add_child(shard)
			var delay := randf() * 0.25 + float(row) * 0.02
			var fall := logical.y - shard.position.y + cell + randf() * 40.0
			var tween := shard.create_tween()
			tween.tween_interval(delay)
			tween.tween_property(shard, "position:y", shard.position.y + fall,
				0.45 + randf() * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(shard, "modulate",
				Color(0.4, 0.4, 0.5, 1.0), 0.5)
	# 先碎一声震一下
	Game.shake_camera(1.5)
	await get_tree().create_timer(1.15, true, false, true).timeout
	# 碎块清掉,只留黑底盖着接下来的换场景
	shards.queue_free()


# ============================================================
# Buff(定义见 BuffDefs,id = 房间物品节点名)
# 同时最多持有 MAX_BUFFS 个;放下后物品会重新提供"收下"选项。
# ============================================================
const MAX_BUFFS: int = 2

## 放下 buff 时发出,供 HUD/技能系统接。
signal buff_removed(id: StringName)

# 沐子的守望本场尝试已用掉(HUD 显示成"破碎的守望")。运行态,不入存档;
# 每次主角出生(新梦/死亡重试)和回房间时复原。
var muzi_broken := false
signal muzi_broken_changed


func set_muzi_broken(broken: bool) -> void:
	if muzi_broken == broken:
		return
	muzi_broken = broken
	muzi_broken_changed.emit()


func has_buff(id: StringName) -> bool:
	return String(id) in buffs_owned


## 获得 buff 并立即存档。已拥有或手里已满返回 false。
func grant_buff(id: StringName) -> bool:
	if has_buff(id):
		return false
	if buffs_owned.size() >= MAX_BUFFS:
		return false
	buffs_owned.append(String(id))
	save_game()
	buff_gained.emit(id)
	return true


## 放下 buff 并立即存档。未持有返回 false。
func remove_buff(id: StringName) -> bool:
	if not has_buff(id):
		return false
	buffs_owned.erase(String(id))
	save_game()
	buff_removed.emit(id)
	return true


# ============================================================
# 存档
# ============================================================
func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "nights_completed", nights_completed)
	config.set_value("progress", "is_night", is_night)
	config.set_value("progress", "buffs_owned", buffs_owned)
	config.set_value("progress", "auto_shield", auto_shield)
	config.save(SAVE_PATH)


func load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	nights_completed = int(config.get_value("progress", "nights_completed", 0))
	is_night = bool(config.get_value("progress", "is_night", false))
	buffs_owned = config.get_value("progress", "buffs_owned", []) as Array
	auto_shield = bool(config.get_value("progress", "auto_shield", false))
