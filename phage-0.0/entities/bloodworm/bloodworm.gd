# =============================================================================
# bloodworm.gd  —  红丝虫「伤口里的新住客」Boss 主体
# =============================================================================
# 周一《伤口》的关底 boss(球克之后、阿克缇诺斯之前)，定位：非常弱。
# 没有近战、没有接触伤害，技能只有两个：
#   Attack(5)      吐弹：第 5 帧(0 起数)从 Muzzle 左右各吐一发自己的子弹(bloodworm_spit)
#   BurrowLaser(6) 钻地激光秀：Disappear 离场 → 斜激光预警线慢慢织网 → 快速连发 → 换位钻出
# Idle/Move 权重压得很高，它大部分时间在爬和歇——难度靠这个压下来。
#
# 素材是 145×90 全屏画布帧(offset 已在 tscn 调好)：不翻转、不缩放，位移只挪节点。
#
# 出场流程(与其他 boss 不同)：场景一加载 → 立刻关传送门(进了房就出不去) →
# 在 enter_position 播 Enter 开场(玩家能走动) → 找场里的 BossIntro 播字卡
# (手动模式 play_for) → 开打。同一次启动内死亡重试：跳过 Enter，字卡由
# BossIntro 自己的 _played 快速跳过。
# 死亡：不会真死——Death 状态播 Disappear 钻走后 queue_free
# (正式关卡用 DreamEnd.watch_path 盯它收梦，BossIntro 会顺带重开传送门)。
# =============================================================================

extends CharacterBody2D

# --- 固定状态槽位 ------------------------------------------------------------
const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_DEATH: int = 2
const STATE_BATTLECRY: int = 3
const STATE_MOVE: int = 4
const STATE_ATTACK: int = 5
const STATE_BURROW: int = 6

# 同一次游戏启动内已在该场景放过 Enter → 死亡重试跳过开场
static var _entrance_played: Dictionary = {}

# --- 基础数值 ----------------------------------------------------------------
@export var max_health: int = 7777
@export var health: int = 7777
@export var idle_only: bool = false              # 调试用：只待机不攻击
@export var enter_position := Vector2(34.5, 80)  # Enter 开场固定位(奇数宽素材 .5 对齐)
@export var bound_min_x: float = 20.0
@export var bound_max_x: float = 140.0

# --- 破土前兆(仿 Actinos 的征兆,但从静到抖渐强,不分段) ------------------------
@export var omen_quiet_time: float = 0.6    # 进房先安静一会儿
@export var omen_time: float = 2.4          # 震屏从 0 渐强到峰值的时长
@export var omen_peak: float = 1.6          # 前兆震屏峰值(别太大,camera_fixed 房会露边)
@export var enter_burst_shake: float = 2.5  # 破土瞬间的重震
@export var enter_rumble: float = 1.0       # Enter 前段持续的小幅震屏
@export var enter_rumble_end_frame: int = 11  # Enter 播过这一帧(0 起数)就不再震

# --- 决策权重：Idle 结束抽下一手(Move 权重高 = 多爬多歇，压难度) --------------
@export var weight_move: float = 0.40
@export var weight_attack: float = 0.35
@export var weight_burrow: float = 0.25
@export var attack_combo_chance: float = 0.3     # 吐弹有这个概率连吐第二发

# --- 运行时状态 --------------------------------------------------------------
var hittable: bool = false          # 开打前 / 钻在血肉里都打不到
var battle_started: bool = false
var facing: int = -1                # 素材原生朝左(-1)；朝右=贴图+Muzzle 一起镜像
var initial_battlecry_shown: bool = false  # BossIntro 组件会预先设 true
var intro_shown: bool = false       # 外部编排(boss rush)预设 true=跳过自带出场,听指挥
var battlecry_done_half: bool = false  # 半血战吼只来一次
var pending_battlecry: bool = false    # 掉到半血先记账,等当前技能组放完再吼
var last_attack: int = -1
var combo_remaining: int = 0
var current_attack: int = -1
var rng := RandomNumberGenerator.new()

@onready var boss_health_ui = get_node_or_null("BossHealthUI")


func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	rng.randomize()

	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.hide_ui(false)

	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("Enabled", false)

	if has_node("StateMachine"):
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)

	# 出场：正常关卡自己演(锁门 → 前兆 → Enter → 找 BossIntro)。
	# 外部编排(boss rush)会预先把 intro_shown 设 true：全套跳过,摆好待机,
	# 字卡和开打状态都听编排者的 play_for / change_state。
	if intro_shown:
		battle_started = true
		hittable = true
		var idle_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if idle_sprite != null and idle_sprite.sprite_frames != null \
				and idle_sprite.sprite_frames.has_animation(&"Idle"):
			idle_sprite.play(&"Idle")
	else:
		# Enter 一开始就不能出房
		global_position = enter_position
		_close_teleports()
		_run_entrance()


func _physics_process(_delta: float) -> void:
	global_position.x = clampf(global_position.x, bound_min_x, bound_max_x)


# =============================================================================
# 出场：Enter 开场动画 → BossIntro 字卡(手动模式) → 开打
# =============================================================================
func _run_entrance() -> void:
	await get_tree().process_frame  # 等全场 ready(BossIntro 手动模式不会抢冻结)
	if not is_inside_tree():
		return
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var key := _scene_key()
	var replay: bool = _entrance_played.get(key, false)
	_entrance_played[key] = true

	if replay:
		# 死亡重试：前兆和开场都看过了，直接摆好待机
		if sprite != null and sprite.sprite_frames != null \
				and sprite.sprite_frames.has_animation(&"Idle"):
			sprite.play(&"Idle")
	elif sprite != null and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(&"Enter"):
		# 破土前兆：先藏起来安静一会儿，然后震屏从无到有、越抖越大(压迫感)
		sprite.stop()
		sprite.visible = false
		await _sleep_frames(omen_quiet_time)
		var t := 0.0
		while t < omen_time and is_inside_tree():
			Game.shake_camera(lerpf(0.0, omen_peak, t / omen_time))
			await get_tree().process_frame
			t += get_process_delta_time()
		if not is_inside_tree():
			return
		Game.stop_shake()
		# 破土而出：重震一下接 Enter，前几帧(钻出土那下)持续小幅隆隆，之后安静
		Game.shake_camera(enter_burst_shake)
		sprite.visible = true
		sprite.play(&"Enter")
		var rumble_done := false
		while is_inside_tree() and is_instance_valid(sprite) \
				and sprite.animation == &"Enter" and sprite.is_playing():
			if enter_rumble > 0.0 and sprite.frame <= enter_rumble_end_frame:
				Game.shake_camera(enter_rumble)
			elif not rumble_done:
				rumble_done = true
				Game.stop_shake()
			await get_tree().process_frame
		Game.stop_shake()
	if not is_inside_tree():
		return

	var intro := _find_boss_intro()
	if intro != null and intro.has_method("play_for"):
		await intro.call("play_for", self)
		if not is_inside_tree():
			return
		battle_started = true
		hittable = true
	else:
		start_battle()  # 没挂字卡组件的兜底(比如临时测试场)


# 兜底开战入口(正常流程走 BossIntro.play_for)
func start_battle() -> void:
	if battle_started:
		return
	battle_started = true
	hittable = true
	change_state(STATE_BATTLECRY)


# =============================================================================
# 受伤
# =============================================================================
func take_damage(value: int) -> void:
	if not hittable:
		return  # 开场演出中 / 钻在血肉里打不到

	health -= value
	health = clampi(health, 0, max_health)

	# 掉进半血：记一笔战吼账，等手头技能组放完、回到 Idle 的决策点再吼
	if not battlecry_done_half and health > 0 and health * 2 <= max_health:
		battlecry_done_half = true
		pending_battlecry = true

	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)

	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")

	if health <= 0:
		change_state(STATE_DEATH)


# =============================================================================
# 钻地/出土 统一开关(BurrowLaser、Death 用)
# 钻着时无敌 + 本体碰撞关掉。恢复碰撞值必须是 4(层号 3)，
# 别用 set_collision_layer_value(4,..) —— 那是层号 4/值 8，会打错位。
# =============================================================================
func set_burrowed(burrowed: bool) -> void:
	hittable = not burrowed and battle_started
	set_deferred("collision_layer", 0 if burrowed else 4)


# =============================================================================
# 朝向：素材原生朝左，身体画在节点原点上，绕原点镜像不跳位。
# 贴图 scale.x 取反 + Muzzle 的 x 镜像(翻转必须带上判定点，项目口径)。
# =============================================================================
func set_facing(dir: int) -> void:
	if dir == 0 or dir == facing:
		return
	facing = dir
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.scale.x = 1.0 if facing == -1 else -1.0
	var muzzle := get_node_or_null("Muzzle") as Node2D
	if muzzle != null:
		muzzle.position.x = -absf(muzzle.position.x) if facing == -1 else absf(muzzle.position.x)


func face_player() -> void:
	var player := _get_player()
	if player == null:
		return
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		set_facing(-1 if dx < 0.0 else 1)


# =============================================================================
# 状态切换转发
# =============================================================================
func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 决策核心 —— Idle 结束时问这里要下一手
# =============================================================================
func get_next_attack_state() -> int:
	# 连招没放完先放完(战吼不打断技能组)
	if combo_remaining > 0:
		combo_remaining -= 1
		return current_attack

	# 半血战吼插播(Battlecry 吼完自己回 Idle)
	if pending_battlecry:
		pending_battlecry = false
		return STATE_BATTLECRY

	current_attack = _pick_next_attack()
	if current_attack == STATE_ATTACK and rng.randf() < attack_combo_chance:
		combo_remaining = 1
	last_attack = current_attack
	return current_attack


# 权重抽签；钻地不许连着来两次(刚钻出来又钻回去太赖皮)
func _pick_next_attack() -> int:
	var w_move := weight_move
	var w_attack := weight_attack
	var w_burrow := 0.0 if last_attack == STATE_BURROW else weight_burrow
	var total := w_move + w_attack + w_burrow
	if total <= 0.0:
		return STATE_IDLE
	var roll := rng.randf() * total
	if roll < w_move:
		return STATE_MOVE
	if roll < w_move + w_attack:
		return STATE_ATTACK
	return STATE_BURROW


# =============================================================================
# 血条 UI 接口
# =============================================================================
func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)

func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)


# =============================================================================
# 工具
# =============================================================================
func _get_player() -> Node2D:
	var player_check := get_node_or_null("PlayerCheck") as Area2D
	if player_check != null:
		for body in player_check.get_overlapping_bodies():
			if body != null and body.is_in_group("player"):
				return body as Node2D
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null


func _close_teleports() -> void:
	for t in get_tree().get_nodes_in_group("teleport"):
		if t.has_method("deactivate"):
			t.call("deactivate")


func _find_boss_intro() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("BossIntro", true, false)


func _scene_key() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "unknown"
	if scene.scene_file_path != "":
		return scene.scene_file_path
	return String(scene.name)


# 逐帧睡(BossIntro._sleep 同款)，DreamIntro 冻结期间也不会跑飞
func _sleep_frames(duration: float) -> void:
	var t := 0.0
	while t < duration:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		t += get_process_delta_time()
