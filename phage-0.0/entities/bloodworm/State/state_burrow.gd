# 红丝虫 钻地激光秀(6 号)：Disappear 钻回血肉(播完才隐身+无敌，全程小幅震屏)
# → 预警线一根根慢慢亮起、斜着交织成一张网 → 全亮齐后再多停一拍(看清站位)
# → 然后按点亮顺序快速连发(哒哒哒,每发带震屏/小闪屏)：高空平斜的纯表演，
#   陡斜的带伤害(落点排队扫过场地) → 换个位置 Appear 钻出(也带小幅震屏) → 回 Idle。
# 节奏口径(用户定)：预警出现的间隔慢、释放的间隔快。
# 全部激光都是斜的(横平竖直不真实)；斜线在 160×90 原生分辨率下
# 渲染成大颗粒锯齿，正合巨像素风。做法参考《骑士山城》栗子劫念。
extends BasicState

const LASER_SCENE: PackedScene = preload("res://entities/bloodworm/bloodworm_laser.tscn")

# --- 高空平斜激光(纯表演,零伤害) ---
@export var sky_count: int = 3
@export var sky_y_min: float = 8.0          # 高空束两端 y 的取值范围(跳跃顶点之上)
@export var sky_y_max: float = 30.0
@export var sky_tilt_min: float = 6.0       # 高空束最小倾斜(度),保证没有一根是水平的
@export var sky_tilt_max: float = 14.0
@export var sky_shake: float = 2.0
@export var sky_flash: float = 0.1

# --- 陡斜激光帘(带伤害,落点排队扫过) ---
@export var curtain_count: int = 5
@export var curtain_x_min: float = 24.0
@export var curtain_x_max: float = 136.0
@export var curtain_jitter: float = 7.0     # 均匀落点上的随机抖动(保住空隙不塌)
@export var curtain_tilt_min_deg: float = 10.0  # 最小倾角(度),保证没有一根是竖直的
@export var curtain_tilt_max_deg: float = 28.0
@export var curtain_shake: float = 1.3
@export var curtain_flash: float = 0.06     # 帘幕开火的小闪屏(快节奏连发+闪屏出效果)
@export var laser_damage: int = 6

# --- 节奏：预警线慢慢一根根亮起 → 全亮齐多等一拍 → 快速连发 ---
@export var aim_appear_stagger: float = 0.5 # 预警线点亮间隔(慢,织网感)
@export var web_hold: float = 1.0           # 全部亮齐后的额外等待
@export var fire_stagger: float = 0.14      # 开火间隔(快,哒哒哒)

# --- 节奏/换位 ---
@export var dig_in_timeout: float = 1.0     # Disappear 兜底时长
@export var dig_rumble: float = 1.2         # Disappear/Appear 期间持续小幅震屏
@export var wave_gap: float = 0.35
@export var emerge_player_gap: float = 35.0 # 钻出点离玩家至少这么远
@export var appear_shake: float = 2.5
@export var appear_timeout: float = 1.4     # Appear 兜底时长

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var _rng := RandomNumberGenerator.new()
var _ticket: int = 0
var _beams: Array = []   # 本轮拉出的激光；被打断时把没开火的撤掉


func _ready() -> void:
	_rng.randomize()


func enter() -> void:
	monster.velocity = Vector2.ZERO
	_ticket += 1
	_run(_ticket)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	_ticket += 1
	# 无论怎么退出都别把无敌/隐身带出去；没开火的预警线也不许悬在场上
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(false)
	if is_instance_valid(ani_2d):
		ani_2d.visible = true
	for l in _beams:
		if is_instance_valid(l) and l.has_method("cancel"):
			l.call("cancel")
	_beams.clear()


func _run(ticket: int) -> void:
	# 1. 钻入：播完 Disappear 才隐身+无敌(用户口径)，钻的时候地皮小幅隆隆
	if is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Disappear"):
		ani_2d.play(&"Disappear")
		if not await _wait_anim_end(&"Disappear", dig_in_timeout, ticket, dig_rumble):
			return
	Game.stop_shake()
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(true)
	if is_instance_valid(ani_2d):
		ani_2d.visible = false
	if not await _sleep(0.25, ticket):
		return

	# 2. 织网：高空平斜(表演)和陡斜帘幕(伤害)的预警线交替慢慢点亮，
	#    斜着交织成网 → 全亮齐再多停一拍 → 按点亮顺序快速连发。
	#    帘幕的地面落点仍从一头排到另一头(顺序感)，倾角随机但绝不竖直。
	var lasers: Array[Dictionary] = []

	var sky_pool: Array[Dictionary] = []
	for i in sky_count:
		var y1 := _rng.randf_range(sky_y_min, sky_y_max)
		var tilt := deg_to_rad(_rng.randf_range(sky_tilt_min, sky_tilt_max)) \
				* (1.0 if _rng.randi() % 2 == 0 else -1.0)
		var y2 := clampf(y1 + tan(tilt) * 176.0, sky_y_min - 6.0, sky_y_max + 6.0)
		sky_pool.append({
			"from": Vector2(-8.0, y1), "to": Vector2(168.0, y2),
			"damage": false, "shake": sky_shake, "flash": sky_flash,
		})

	var curtain_pool: Array[Dictionary] = []
	var span := curtain_x_max - curtain_x_min
	var xs: Array[float] = []
	for i in curtain_count:
		var base := curtain_x_min + span * (float(i) + 0.5) / float(curtain_count)
		xs.append(clampf(base + _rng.randf_range(-curtain_jitter, curtain_jitter),
				curtain_x_min, curtain_x_max))
	if _rng.randi() % 2 == 0:
		xs.reverse()
	for x in xs:
		var mag := deg_to_rad(_rng.randf_range(curtain_tilt_min_deg, curtain_tilt_max_deg))
		var tilt := mag * (1.0 if _rng.randi() % 2 == 0 else -1.0)
		curtain_pool.append({
			"from": Vector2(x - tan(tilt) * 88.0, -8.0), "to": Vector2(x, 80.0),
			"damage": true, "shake": curtain_shake, "flash": curtain_flash,
		})

	# 交替混编(表演一根、帘幕一根……)，织网效果最好
	while not sky_pool.is_empty() or not curtain_pool.is_empty():
		if not sky_pool.is_empty():
			lasers.append(sky_pool.pop_front())
		if not curtain_pool.is_empty():
			lasers.append(curtain_pool.pop_front())

	# 预警线慢慢亮
	_beams.clear()
	for cfg in lasers:
		var l := _spawn_aim(cfg["from"], cfg["to"], cfg["damage"],
				cfg["shake"], cfg["flash"])
		if l != null:
			_beams.append(l)
		if not await _sleep(aim_appear_stagger, ticket):
			return
	# 全亮齐了，多停一拍让玩家找好空隙
	if not await _sleep(web_hold, ticket):
		return
	# 快速连发(哒哒哒)，每根自带震屏/闪屏
	for l in _beams:
		if is_instance_valid(l) and l.has_method("fire"):
			l.call("fire")
		if not await _sleep(fire_stagger, ticket):
			return
	_beams.clear()
	# 等最后一束收完
	if not await _sleep(0.5 + wave_gap, ticket):
		return

	# 3. 换位钻出：一冒头就能打(弱 boss，对玩家慷慨点)，头朝玩家那边，小幅震屏
	monster.global_position.x = _pick_emerge_x()
	if is_instance_valid(ani_2d):
		ani_2d.visible = true
	if monster.has_method("set_burrowed"):
		monster.set_burrowed(false)
	if monster.has_method("face_player"):
		monster.face_player()
	Game.shake_camera(appear_shake)
	if is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Appear"):
		ani_2d.play(&"Appear")
		if not await _wait_anim_end(&"Appear", appear_timeout, ticket, dig_rumble):
			return
	Game.stop_shake()
	change_state(1)  # 回 Idle


func _spawn_aim(from: Vector2, to: Vector2, deals_damage: bool,
		shake: float, flash_amount: float) -> Node2D:
	var scene := get_tree().current_scene
	if scene == null or LASER_SCENE == null:
		return null
	var laser := LASER_SCENE.instantiate()
	scene.add_child(laser)
	if "damage" in laser:
		laser.damage = laser_damage
	if laser.has_method("show_aim"):
		laser.call("show_aim", from, to, deals_damage, shake, flash_amount)
	return laser as Node2D


func _pick_emerge_x() -> float:
	var min_x: float = monster.bound_min_x if "bound_min_x" in monster else 20.0
	var max_x: float = monster.bound_max_x if "bound_max_x" in monster else 140.0
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	for _i in 8:
		var x := _rng.randf_range(min_x, max_x)
		if player == null or absf(x - player.global_position.x) >= emerge_player_gap:
			return x
	# 抽不出来就去离玩家远的那半边
	if player != null:
		return min_x if player.global_position.x > (min_x + max_x) * 0.5 else max_x
	return (min_x + max_x) * 0.5


# 等指定动画播完(轮询，不依赖 animation_finished)；超时兜底；可选持续小幅震屏。
# 返回 false=票据过期
func _wait_anim_end(anim: StringName, timeout: float, ticket: int,
		rumble: float = 0.0) -> bool:
	var t := 0.0
	while t < timeout:
		if ticket != _ticket or not is_inside_tree():
			return false
		if not is_instance_valid(ani_2d) or ani_2d.animation != anim \
				or not ani_2d.is_playing():
			return true
		if rumble > 0.0:
			Game.shake_camera(rumble)
		await get_tree().process_frame
		t += get_process_delta_time()
	return ticket == _ticket


func _sleep(duration: float, ticket: int) -> bool:
	await get_tree().create_timer(duration).timeout
	return ticket == _ticket and is_inside_tree()
