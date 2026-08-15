extends Node

## DreamIntro:每夜入梦的开场演出(Preacher 式镂空标题字卡)。
## 流程:纯黑+打字机剧情 → 场景微亮(无主角) → 第二段剧情 → 咚!镂空标题
##      (第一行白色小字"周几的梦",第二行大字挖空、字内是活场景,四周全黑)
##      → 哗!变黑 → 主角球形态现身 → 站起(Uncontract) → 场景全亮 → 解冻开战。
## 用法:实例进关卡根节点,且放在最后一个子节点(保证所有怪已 add_to_group("monster"))。
## 开场期间:所有 "monster" 组节点 PROCESS_MODE_DISABLED 冻结;
##   disable_process_paths 里的节点(刷怪器/带刷怪循环的关卡根)set_process(false)。
## 任意按键:打字中=整段显示;显示完=跳到下一阶段(连按等于快进到主角出现)。
## 死亡是 reload_current_scene 整场景重载,用 static 记录避免重播(每次启动游戏重置)。

static var _played: Dictionary = {}

@export_multiline var story_text_1 := ""  ## 纯黑阶段:昨晚睡前发生的事
@export_multiline var story_text_2 := ""  ## 微亮阶段:关于这个梦的一句引子
@export var weekday_text := ""            ## 标题第一行(白色小字):周几的梦
@export var title_text := ""              ## 标题第二行(镂空大字):这一夜的名字
@export_range(0.0, 1.0) var dim_brightness := 0.4
@export var title_hold := 3.5
## 开场期间要 set_process(false) 的节点(相对本节点的路径)。
## 关卡根自带刷怪循环时填 [".."],独立刷怪器填 ["../SlimeSpawner"] 这类。
@export var disable_process_paths: Array[NodePath] = []
@export var ambient_stream: AudioStream   ## 场景环境声(占位,可空)
@export var boom_stream: AudioStream      ## 标题"咚"(占位,可空)
@export var whoosh_stream: AudioStream    ## 变黑"哗"(占位,可空)

const TYPE_CPS := 16.0

var _player: Node = null
var _canvas_modulate: CanvasModulate = null
var _original_tint := Color.WHITE
var _frozen: Array[Node] = []
var _disabled_process: Array[Node] = []
var _advance := false
# Game.change_scene 会在淡入完成后解锁玩家,和开场的锁抢时序;
# 揭幕前发现锁被解就按回去,揭幕后交还控制权流程。
var _guard_lock := false
# 连按快进时,上一阶段的渐变可能还在跑,阶段切换前必须杀掉,
# 否则黑幕/亮度会被残留 tween 拉扯。
var _fade_tween: Tween = null
var _tint_tween: Tween = null

@onready var _viewport: SubViewport = $MaskViewport
@onready var _title: Label = $MaskViewport/TitleLabel
@onready var _cutout: ColorRect = $Overlay/Cutout
@onready var _story: Label = $TextLayer/StoryLabel
@onready var _weekday: Label = $MaskViewport/WeekdayLabel


func _ready() -> void:
	var level := get_parent()
	var key: String = level.scene_file_path if level != null else "?"
	if _played.get(key, false):
		queue_free()
		return
	_played[key] = true
	_setup(level)
	_start(level)


# 冻结必须等关卡根自己 ready 之后:Godot 是子先父后,DreamIntro._ready 时
# 关卡根的 _ready 还没跑——spider_forest 在根 _ready 里 add_child 的怪会逃过冻结,
# 根节点的 _process 也要等它 READY 时被引擎自动启用之后才关得掉。
func _start(level: Node) -> void:
	if not level.is_node_ready():
		await level.ready
	_freeze_world()
	_run()


func _freeze_world() -> void:
	for m in get_tree().get_nodes_in_group("monster"):
		if m.process_mode != Node.PROCESS_MODE_DISABLED:
			m.process_mode = Node.PROCESS_MODE_DISABLED
			_frozen.append(m)
	for path in disable_process_paths:
		var n := get_node_or_null(path)
		if n != null and n.is_processing():
			n.set_process(false)
			_disabled_process.append(n)
	print("[DreamIntro] 冻结怪物: ", _frozen.size(), " 停刷怪: ", _disabled_process.size())


func _setup(level: Node) -> void:
	var players := get_tree().get_nodes_in_group("player")
	_player = players[0] if not players.is_empty() else null
	if _player != null:
		_player.set_lock(true)
		_player.visible = false
	_guard_lock = true

	_canvas_modulate = level.get_node_or_null("CanvasModulate") as CanvasModulate
	if _canvas_modulate == null:
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.name = "CanvasModulate"
		level.add_child(_canvas_modulate)
	_original_tint = _canvas_modulate.color
	_canvas_modulate.color = _dim_color()

	var mat := _cutout.material as ShaderMaterial
	mat.set_shader_parameter("mask_tex", _viewport.get_texture())
	mat.set_shader_parameter("mask_enabled", 0.0)
	mat.set_shader_parameter("glyph_white", 0.0)
	_cutout.modulate.a = 1.0

	_title.text = title_text
	# 字体按 11px 网格设计,字号必须用 11 的整倍数,否则像素网格会被碾碎
	var title_size := 44
	if title_text.length() > 2:
		title_size = 33
	if title_text.length() > 4:
		title_size = 22
	_title.add_theme_font_size_override("font_size", title_size)
	_weekday.text = weekday_text
	_weekday.visible = false
	_story.text = ""

	if ambient_stream != null:
		$Ambient.stream = ambient_stream
		$Ambient.play()


# CanvasModulate 的 alpha 必须保持不变:Color * float 会连 alpha 一起乘,
# 半透明的 CanvasModulate 会让整个场景透出清屏色。
func _dim_color() -> Color:
	return Color(
		_original_tint.r * dim_brightness,
		_original_tint.g * dim_brightness,
		_original_tint.b * dim_brightness,
		_original_tint.a
	)


var _reveal_started := false
var _finished := false


func _process(_delta: float) -> void:
	# Game.change_scene 的迟到解锁(传送淡入 0.35s 后)可能落在开场任意时刻,按回去。
	if _guard_lock and _player != null and not _player.input_locked:
		_player.set_lock(true)
		if not _reveal_started:
			_player.visible = false
		else:
			# 揭幕后被抢锁:set_lock(true) 会强制退球,重新摆回球形态
			_player.set_ball_form(true)
			_player.play_anim(&"Ball")


# 开场没走完场景就被拆掉(比如意外死亡触发 reload)时,
# 把打在 autoload 相机上的运镜清掉,否则重载后相机永久钉死。
func _exit_tree() -> void:
	if not _finished:
		Game.clear_position_override()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			_advance = true


func _run() -> void:
	await get_tree().process_frame
	# ① 纯黑 + 第一段剧情
	await _type_text(story_text_1)
	_story.text = ""
	# ② 场景微亮(无主角)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_cutout, "modulate:a", 0.0, 1.6)
	await _wait(1.6)
	# ③ 第二段剧情
	await _type_text(story_text_2)
	_story.text = ""
	# ④ 咚!镂空标题
	_show_title_card()
	await _wait(title_hold)
	# ⑤ 哗!变黑
	await _blackout()
	# ⑥ 球形态现身 → 站起 → 全亮 → 开战
	await _finale()


func _type_text(text: String) -> void:
	if text.is_empty():
		return
	_advance = false
	_story.text = text
	_story.visible_characters = 0
	var acc := 0.0
	while _story.visible_characters < text.length():
		if _advance:
			_story.visible_characters = -1
			break
		acc += get_process_delta_time() * TYPE_CPS
		while acc >= 1.0 and _story.visible_characters < text.length():
			_story.visible_characters += 1
			acc -= 1.0
		await get_tree().process_frame
	_story.visible_characters = -1
	await _wait(1.4)


func _wait(duration: float) -> void:
	_advance = false
	var t := 0.0
	while t < duration:
		if _advance:
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	_advance = false


func _show_title_card() -> void:
	_kill_stage_tweens()
	# 字卡期间场景直接拉到全白:各关原色只有五成多灰,不拉满字里的世界看不清。
	# 全白比正常游玩亮得多,正好是 Preacher 字卡那种过曝的鲜活感。
	_tint_tween = create_tween()
	_tint_tween.tween_property(
		_canvas_modulate, "color",
		Color(1.0, 1.0, 1.0, _original_tint.a), 0.6)
	# 缓慢横移运镜
	Game.set_position_override_smooth(Game.global_position + Vector2(14, 0), title_hold + 1.0)
	var mat := _cutout.material as ShaderMaterial
	mat.set_shader_parameter("mask_enabled", 1.0)
	# 字内白色滤镜:从全透明渐到八成白,字形慢慢泛白亮起,底下透着两成活场景
	mat.set_shader_parameter("glyph_white", 0.0)
	_tint_tween.set_parallel(true)
	_tint_tween.tween_property(
		mat, "shader_parameter/glyph_white", 0.8, minf(2.0, title_hold * 0.6))
	_cutout.modulate.a = 1.0
	_weekday.visible = true
	# 砸入:标题从 2.2 倍缩到 1,落定的同时震屏
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2(2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(_title, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(Game.shake_camera.bind(2.0))
	if boom_stream != null:
		$Boom.stream = boom_stream
		$Boom.play()


func _blackout() -> void:
	_kill_stage_tweens()
	if whoosh_stream != null:
		$Whoosh.stream = whoosh_stream
		$Whoosh.play()
	_weekday.visible = false
	var mat := _cutout.material as ShaderMaterial
	mat.set_shader_parameter("mask_enabled", 0.0)
	_cutout.modulate.a = 1.0
	Game.clear_position_override()
	_canvas_modulate.color = _dim_color()
	await _wait(0.5)


func _kill_stage_tweens() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()


# 开场期间玩家被锁,状态机物理停了,重力不生效——关卡里摆在半空的出生点
# 不会自己落地,揭幕会悬空现身。揭幕前(屏幕还黑着)射线找脚下地面直接贴地。
# 各关地面高度不同(pink_land/silvaron 有平台出生点),射线比写死 y 稳。
func _snap_player_to_ground() -> void:
	var body := _player as PhysicsBody2D
	if body == null:
		return
	await get_tree().physics_frame
	var space := body.get_world_2d().direct_space_state
	# 从脚底略上方起投,防出生点已微陷地面时射线漏检
	var from: Vector2 = body.global_position + Vector2(0.0, -2.0)
	var params := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, 400.0), body.collision_mask, [body.get_rid()])
	var hit := space.intersect_ray(params)
	if not hit.is_empty():
		body.global_position.y = hit["position"].y


func _finale() -> void:
	_reveal_started = true
	await _snap_player_to_ground()
	if _player != null:
		_player.visible = true
		# set_lock(true) 已停掉状态机,手动摆球形态不会被覆盖
		_player.set_ball_form(true)
		_player.play_anim(&"Ball")
	var tw := create_tween()
	tw.tween_property(_cutout, "modulate:a", 0.0, 0.5)
	await tw.finished
	await get_tree().create_timer(0.35).timeout
	if _player != null:
		var sprite := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		# Uncontract 播完由 player 场景里的直连信号自动 exit_ball_form + 回 Idle,
		# 锁定状态下 Idle 只播待机,不会乱跑
		_player.play_anim(&"Uncontract")
		if sprite != null:
			# 不能裸 await animation_finished:极端时序下 Uncontract 可能被循环动画
			# 顶掉(循环动画永不发 finished),协程会永久悬置。条件等待 + 超时兜底。
			var elapsed := 0.0
			while elapsed < 1.5:
				var anim := String(sprite.animation)
				if not anim.begins_with("Uncontract"):
					break
				if not sprite.is_playing():
					break
				await get_tree().process_frame
				elapsed += get_process_delta_time()
	create_tween().tween_property(_canvas_modulate, "color", _original_tint, 0.9)
	if $Ambient.playing:
		var atw := create_tween()
		atw.tween_property($Ambient, "volume_db", -40.0, 1.2)
		atw.tween_callback($Ambient.stop)
	for n in _disabled_process:
		if is_instance_valid(n):
			n.set_process(true)
	for m in _frozen:
		if is_instance_valid(m):
			m.process_mode = Node.PROCESS_MODE_INHERIT
	# 交还控制权:守卫留到最后一刻,交接前保证球形态已退干净(极端时序的兜底)
	_guard_lock = false
	if _player != null:
		if _player.is_in_ball_form:
			_player.set_ball_form(false)
		_player.set_lock(false)
	_finished = true
	await get_tree().create_timer(1.4).timeout
	queue_free()
