extends Node

## BossIntro:Boss 开场演出组件(头衔+名字字卡,参考 DreamIntro 的节奏)。
## 流程:进场安静一会儿 → 征兆(震屏渐强) → Boss 现身(天降/渐显) → 镜头聚焦+放大
##      → 头衔打字机逐字出现 → 名字大字砸入 → 停住等玩家按一下 → 字卡渐隐
##      → 血条亮起、状态机开打。全程锁玩家。
## 用法一(全自动):实例进关卡根节点(放 DreamIntro 之后),填 boss_path 指向场上摆好的 boss。
##   组件会在自己 _ready 时把 boss 藏起来冻结(先于 DreamIntro 的冻结,所以不会被它解冻)。
## 用法二(手动,如珊瑚摇篮):boss_path 留空 + auto_start=false,
##   关卡自己演完登场后 await play_for(boss) 播字卡并开打。
## 死亡重试(同一次启动内重进同关):跳过字卡和征兆,快速现身直接开打。

static var _played: Dictionary = {}

@export var boss_path: NodePath              ## 场上已摆好的 boss;留空=手动模式
@export var title_text := ""                 ## 头衔(小字,打字机)
@export var boss_name_text := ""             ## 名字(大字,砸入)
@export var auto_start := true               ## ready 后自动走完整开场
@export var trigger_distance := 0.0          ## >0:等玩家横向靠近 boss 这么多像素才开演(走路关用)
@export var pre_delay := 1.2                 ## 触发后的安静停顿
@export_enum("Drop", "Fade") var appear_mode := 0  ## 现身方式:天降 / 渐显
@export var reveal_animation: StringName = &""     ## 现身过程播的动画(空=Idle;落地后自动回 Idle)
## 字卡期间播的动画(空=Idle)。注意:动画播完会发 animation_finished,
## 只能用「没连信号」或「处理函数有动画名守卫」的动画(如 penitent 的 Battlecry)。
@export var card_animation: StringName = &""
@export var fight_state := 1                 ## 开打时切的状态号(-1=没有状态机,只解冻)
@export var focus_offset := Vector2(0, -14)  ## 字卡运镜聚焦点相对 boss 的偏移
@export var zoom_amount := 1.15              ## 字卡镜头放大倍率
@export var name_hold := 0.9                 ## 名字砸下后至少停多久才接受按键

const TYPE_CPS := 8.0  # 头衔就几个字,打慢点才有打字机的仪式感

var _boss: Node2D = null
var _target_pos := Vector2.ZERO
var _player: Node = null
var _guard_lock := false
var _advance := false
var _replay_fast := false
var _camera_dirty := false   # 运镜是否已打上(异常退出时要清)
var _finished := false

@onready var _dim: ColorRect = $Layer/Dim
@onready var _title: Label = $Layer/TitleLabel
@onready var _name: Label = $Layer/NameLabel


func _ready() -> void:
	_title.text = ""
	_name.text = boss_name_text
	_name.modulate.a = 0.0
	_dim.modulate.a = 0.0

	if boss_path.is_empty():
		return  # 手动模式,等关卡调 play_for
	_boss = get_node_or_null(boss_path) as Node2D
	if _boss == null:
		push_warning("[BossIntro] boss_path 指向的节点不存在: %s" % boss_path)
		return
	_target_pos = _boss.global_position
	_prepare_boss()
	# 有的 boss 状态在 enter 里会震屏(azure 的 Null 落地吼),按回 Null 时会带出一下,按停
	Game.stop_shake()
	if auto_start:
		_run()


# 抢在 DreamIntro 冻结之前(它 await level.ready 之后才冻)把 boss 冻住:
# DreamIntro 只解冻「自己冻的」怪,提前冻的 boss 不会被它中途放出来。
func _prepare_boss() -> void:
	# 预先掐掉各 boss 自带的出场分支:战吼状态里的英文名/运镜、忏悔者的见人自爆战吼
	if "initial_battlecry_shown" in _boss:
		_boss.initial_battlecry_shown = true
	if "intro_shown" in _boss:
		_boss.intro_shown = true
	if "fighting" in _boss:
		_boss.fighting = true
	# 状态机按回 Null(0):我们 _ready 在 boss 状态机 _ready 之后,Idle 可能已经入场,
	# 各 Idle 都有票据防过期,exit 会作废已排的计时器
	_change_boss_state(0)
	# 有的 boss(azure)在 _ready 里就把血条亮出来了,收回去,开打时再亮
	if _boss.has_method("hide_health_ui"):
		_boss.call("hide_health_ui")
	_boss.visible = false
	_boss.process_mode = Node.PROCESS_MODE_DISABLED


func _change_boss_state(id: int) -> void:
	if _boss == null or id < 0:
		return
	# 优先走 boss 自己的 change_state(有的会顺带记 current_state_id)
	if _boss.has_method("change_state"):
		_boss.call("change_state", id)
		return
	var sm := _boss.get_node_or_null("StateMachine")
	if sm != null and sm.has_method("change_state"):
		sm.call("change_state", id)


func _run() -> void:
	await get_tree().process_frame
	# 入梦字卡在播时等它演完(它结束会 queue_free 自己)
	var dream_intro := get_parent().get_node_or_null("DreamIntro")
	if dream_intro != null:
		await dream_intro.tree_exited
	if not is_inside_tree():
		return

	var key := _scene_key()
	_replay_fast = _played.get(key, false)
	_played[key] = true

	# 触发:走路关等玩家靠近,竞技场关等一小会儿
	if trigger_distance > 0.0:
		while is_inside_tree():
			var p := _get_player()
			if p != null and absf(p.global_position.x - _target_pos.x) <= trigger_distance:
				break
			await get_tree().process_frame
		if not is_inside_tree():
			return
	await _sleep(0.4 if _replay_fast else pre_delay)
	if not is_inside_tree():
		return

	_set_lock(true)
	_close_teleports()
	if not _replay_fast:
		await _omen()
		if not is_inside_tree():
			return
	await _reveal()
	if not is_inside_tree():
		return
	if not _replay_fast:
		await _play_card()
		if not is_inside_tree():
			return
	_start_fight()
	_set_lock(false)
	_finished = true
	_watch_boss_and_reopen()


## 手动模式入口(珊瑚摇篮):关卡自己演完登场后调这里,播字卡并开打。
func play_for(boss: Node2D) -> void:
	_boss = boss
	if _boss == null:
		return
	_target_pos = _boss.global_position
	if "initial_battlecry_shown" in _boss:
		_boss.initial_battlecry_shown = true
	# 字卡期间不许它的状态机自己开打(Idle 计时器到点会切攻击):按回 Null 并冻结本体,
	# 贴图由 _play_card 里的 ALWAYS 保持在动
	_change_boss_state(0)
	_boss.process_mode = Node.PROCESS_MODE_DISABLED
	var key := _scene_key()
	_replay_fast = _played.get(key, false)
	_played[key] = true
	_set_lock(true)
	_close_teleports()
	if not _replay_fast:
		await _play_card()
	if not is_inside_tree():
		return
	_start_fight()
	_set_lock(false)
	_finished = true
	_watch_boss_and_reopen()


# =============================================================================
# 演出各阶段
# =============================================================================

# 征兆:三段渐强震屏,越来越近的感觉
func _omen() -> void:
	await _shake_for(0.35, 0.8)
	await _sleep(0.25)
	await _shake_for(0.7, 0.8)
	await _sleep(0.2)
	await _shake_for(1.2, 0.6)


func _shake_for(amount: float, duration: float) -> void:
	var t := 0.0
	while t < duration:
		if not is_inside_tree():
			return
		Game.shake_camera(amount)
		await get_tree().process_frame
		t += get_process_delta_time()
	Game.stop_shake()


func _sleep(duration: float) -> void:
	var t := 0.0
	while t < duration:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		t += get_process_delta_time()


func _reveal() -> void:
	if _boss == null:
		return
	# 只让贴图动起来:本体保持冻结,不跑 AI、不触发任何状态逻辑
	var ani := _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if ani != null:
		ani.process_mode = Node.PROCESS_MODE_ALWAYS
	_boss.visible = true

	if appear_mode == 0:
		# 天降:从屏幕上方砸到摆放位置
		_play_boss_anim(reveal_animation)
		_boss.global_position = _target_pos + Vector2(0.0, -110.0)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_boss, "global_position", _target_pos, 0.45)
		await tw.finished
		if not is_inside_tree():
			return
		Game.shake_camera(2.5)
		Game.flash(0.35, Color(1.0, 1.0, 1.0))
		_play_boss_anim(&"")  # 落地回 Idle
	else:
		# 渐显:原地从透明浮现
		_play_boss_anim(reveal_animation)
		_boss.modulate.a = 0.0
		Game.flash(0.25, Color(1.0, 1.0, 1.0))
		var tw := create_tween()
		tw.tween_property(_boss, "modulate:a", 1.0, 0.7)
		await tw.finished
	if is_inside_tree() and _boss != null and _boss.has_method("set_facing_from_player"):
		_boss.call("set_facing_from_player")
	await _sleep(0.15)


# 字卡:运镜聚焦 → 头衔打字机 → 名字砸入 → 等一次按键 → 渐隐复位
func _play_card() -> void:
	if _boss != null:
		var ani := _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ani != null:
			ani.process_mode = Node.PROCESS_MODE_ALWAYS
		_play_boss_anim(card_animation)
		Game.set_position_override_smooth(_focus_position(), 0.25)
		Game.zoom_to(Vector2(zoom_amount, zoom_amount), 0.2)
		_camera_dirty = true

	$Layer.visible = true
	var dim_tween := create_tween()
	dim_tween.tween_property(_dim, "modulate:a", 1.0, 0.4)

	# 头衔:打字机逐字出现(此段不可跳过)
	_title.text = title_text
	_title.visible_characters = 0
	var acc := 0.0
	while _title.visible_characters < title_text.length():
		if not is_inside_tree():
			return
		acc += get_process_delta_time() * TYPE_CPS
		while acc >= 1.0 and _title.visible_characters < title_text.length():
			_title.visible_characters += 1
			acc -= 1.0
		await get_tree().process_frame
	_title.visible_characters = -1
	await _sleep(0.35)
	if not is_inside_tree():
		return

	# 名字:大字砸入(缩放 2.2→1 + 落定震屏,参考 DreamIntro 标题)
	_name.pivot_offset = _name.size / 2.0
	_name.scale = Vector2(2.2, 2.2)
	_name.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_name, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_name, "modulate:a", 1.0, 0.1)
	tw.set_parallel(false)
	tw.tween_callback(Game.shake_camera.bind(2.0))
	await tw.finished
	if not is_inside_tree():
		return

	# 砸下后至少停 name_hold 秒(按键作废),然后等一次按键/点击才继续
	var t := 0.0
	while t < name_hold:
		_advance = false
		await get_tree().process_frame
		t += get_process_delta_time()
	_advance = false
	while not _advance:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_advance = false

	# 渐隐 + 运镜复位(都不许硬切)
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(_title, "modulate:a", 0.0, 0.4)
	out.tween_property(_name, "modulate:a", 0.0, 0.4)
	out.tween_property(_dim, "modulate:a", 0.0, 0.4)
	_clear_camera(0.4)
	await out.finished
	$Layer.visible = false


func _start_fight() -> void:
	_clear_camera(0.25)
	Game.stop_shake()
	if _boss == null:
		return
	var ani := _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if ani != null:
		ani.process_mode = Node.PROCESS_MODE_INHERIT
	_boss.process_mode = Node.PROCESS_MODE_INHERIT
	_change_boss_state(fight_state)
	# 血条:等名字字卡完全收干净才淡入(show_ui 的黑→灰渐变看不出来,用 alpha 淡入)
	var ui := _boss.get_node_or_null("BossHealthUI")
	if ui != null and ui.has_method("show_ui_fade"):
		ui.call("show_ui_fade", 0.35)
	elif _boss.has_method("show_health_ui"):
		_boss.call("show_health_ui")


# Boss 开打 = 这个梦只能打完或者死:把场里所有传送点关掉,防止中途走人。
func _close_teleports() -> void:
	for t in get_tree().get_nodes_in_group("teleport"):
		if t.has_method("deactivate"):
			t.call("deactivate")


# Boss 死亡(节点被释放)后把场里的传送点重新打开:
# spawn_room 这类"打完 boss 还要继续走"的关需要门恢复可用;
# 打赢即离开的关(complete_dream 淡出换场景)本节点随场景销毁,不受影响。
func _watch_boss_and_reopen() -> void:
	while is_inside_tree() and is_instance_valid(_boss):
		await get_tree().process_frame
	if not is_inside_tree():
		return
	for t in get_tree().get_nodes_in_group("teleport"):
		if t.has_method("activate"):
			t.call("activate")


# =============================================================================
# 杂项
# =============================================================================

func _play_boss_anim(anim: StringName) -> void:
	if _boss == null:
		return
	var ani := _boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if ani == null or ani.sprite_frames == null:
		return
	var target := anim
	if target == &"" or not ani.sprite_frames.has_animation(target):
		target = &"Idle"
	if not ani.sprite_frames.has_animation(target):
		return
	ani.play(target)


# position_override 不吃 Camera2D 的 limits(实测会看到场地外的黑),得自己夹。
# 语义还分两种:camera_fixed 房间 anchor 是左上角,override=视口左上角坐标;
# camera_follow 关卡 anchor 是中心,override=视口中心坐标。
func _focus_position() -> Vector2:
	var view_half := Vector2(80.0, 45.0) / zoom_amount
	var center: Vector2 = _boss.global_position + focus_offset
	var min_c: Vector2
	var max_c: Vector2
	if Game.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		# 固定房间按项目铁律就是原点起的 160×90(它们不报 limits,不能拿来夹)
		min_c = view_half
		max_c = Vector2(160.0, 90.0) - view_half
	else:
		min_c = Vector2(float(Game.limit_left), float(Game.limit_top)) + view_half
		max_c = Vector2(float(Game.limit_right), float(Game.limit_bottom)) - view_half
	center.x = clampf(center.x, minf(min_c.x, max_c.x), maxf(min_c.x, max_c.x))
	center.y = clampf(center.y, minf(min_c.y, max_c.y), maxf(min_c.y, max_c.y))
	if Game.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		return center - view_half
	return center


func _clear_camera(duration: float) -> void:
	if not _camera_dirty:
		return
	_camera_dirty = false
	if Game.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		# 固定房间:smooth 清除的回归目标正好是 (0,0)=房间原位,平滑归位
		Game.clear_position_override_smooth(duration)
	else:
		# 跟随关卡:smooth 清除会先飞回世界原点再被跟随拉回,难看;
		# 直接交还,跟随镜头的指数平滑自己会滑回玩家身上
		Game.clear_position_override()
	Game.reset_zoom(duration)


func _scene_key() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else "?"


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return (players[0] as Node2D) if not players.is_empty() else null


func _set_lock(locked: bool) -> void:
	_guard_lock = locked
	_player = _get_player()
	if _player == null:
		return
	# 战吼式锁定:空中的主角落地站好,全程无敌+解锁后余量无敌(残留弹幕兜底)
	if _player.has_method("set_battlecry_lock"):
		_player.call("set_battlecry_lock", locked)
	elif _player.has_method("set_lock"):
		_player.call("set_lock", locked)


# Game.change_scene 的迟到解锁可能落在演出任意时刻,每帧按回去(同 DreamIntro)
func _process(_delta: float) -> void:
	if _guard_lock and _player != null and not _player.input_locked:
		_player.set_battlecry_lock(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			_advance = true


# 演出没走完场景就被拆掉(死亡/切场景)时,清掉打在 autoload 相机上的运镜,
# 否则重载后相机永久钉死(DreamIntro 踩过的坑)
func _exit_tree() -> void:
	if not _finished and _camera_dirty:
		Game.clear_position_override()
		Game.reset_zoom(0.1)
		Game.stop_shake()
