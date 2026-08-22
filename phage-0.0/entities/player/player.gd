# res://entities/player/player.gd
class_name Player
extends CharacterBody2D

# ============================================================
# Constants - tweak here, applies to all states
# ============================================================
const GRAVITY: float = 1000.0
const MAX_HEALTH: int = 100
const IDLE_TO_CONTRACT_TIME: float = 3.0
const INVINCIBLE_DURATION: float = 0.3

# ---- 护盾机制 ----
# 两个独立护盾,各挡一次伤害,破掉后 10 秒各自充能(可无限循环)。
# 有盾(拿出护盾)时被碰:破当前盾、进短无敌、不掉血。
# 无盾(没拿出护盾)时被碰:直接死亡。
# 开盾键 E(Backpack): 无盾且有就绪的盾时拿出;有盾时按了没反应。
# 破盾键 R(ShieldBreak): 有盾时主动敲碎当前盾——照常进充能、照常触发
# 破盾特效(珊瑚水刺等),但不给无敌(无敌只属于挨打)。
const SHIELD_COUNT: int = 2
const SHIELD_RECHARGE_TIME: float = 10.0

# ---- Buff 数值(定义/文案见 BuffDefs;获得状态在 Story.buffs_owned) ----
const TABLE_BREAK_INVINCIBLE: float = 1.0   # 愈合的伤口:破盾后无敌延长
const PLANT_RECHARGE_TIME: float = 7.0      # 森林的谢礼:护盾充能加速
const CRYSTAL_DASH_COOLDOWN: float = 8.0    # 蓝水晶的力量:包裹冲刺冷却
const LAMP_ENERGY_MAX: int = 8              # 城市的心跳:攒满所需命中次数
const LAMP_FIRE_DURATION: float = 6.0       # 城市的心跳:火光持续时间
const LAMP_ATTACK_SPEED: float = 1.5        # 城市的心跳:火光期攻速倍率
const WINDOW_RAMP_RATE: float = 0.05        # 窗边的晨光:满盾时每秒+5%攻速
const WINDOW_RAMP_MAX_TIME: float = 8.0     # 窗边的晨光:8秒到顶(+40%)
const TIDE_DAMAGE_BONUS: float = 0.2        # 珊瑚潮汐:冲刺后下一击+20%(加法叠加)
const TIDE_SPIKE_DAMAGE: int = 60           # 珊瑚潮汐:破盾水刺单发伤害
const TIDE_SPIKE_SCALE: float = 1.5         # 珊瑚潮汐:水刺整体放大(更显眼)
const TIDE_RING_BONUS_HITS: int = 4         # 珊瑚潮汐:命中≥这么多根触发下一击强化
const TIDE_ALL_HIT_BONUS: float = 0.5       # 珊瑚潮汐:水刺够数命中→下一击+50%(加法叠加)
const MUZI_REVIVE_INVINCIBLE: float = 1.2   # 沐子的守望:复活后无敌
const TIDE_SPIKE_SCENE: PackedScene = preload("res://entities/player/BuffEffect/water_tank_bullet.tscn")
const EGG_SCENE: PackedScene = preload("res://entities/spider_egg/spider_egg.tscn")
# Buff 时刻的粒子(落地粒子的变色副本,配方见 BuffEffect 目录)
const MUZI_REVIVE_EFFECT_SCENE: PackedScene = preload("res://entities/player/BuffEffect/muzi_revive_effect.tscn")
const CRYSTAL_DASH_EFFECT_SCENE: PackedScene = preload("res://entities/player/BuffEffect/crystal_dash_effect.tscn")
const LAMP_IGNITE_EFFECT_SCENE: PackedScene = preload("res://entities/player/BuffEffect/lamp_ignite_effect.tscn")
const RUN_SPEED: float = 70.0 #(100.0)
const SPRINT_SPEED: float = 220.0
const SPRINT_COOLDOWN: float = 0.75
const JUMP_SPEED: float = -200.0
const MAX_JUMP_HOLD_TIME: float = 0.14
const JUMP_HOLD_GRAVITY_MULTIPLIER: float = 0.35
const MAX_JUMP_APEX_HANG_TIME: float = 0.08
const JUMP_APEX_VELOCITY_THRESHOLD: float = 24.0
const JUMP_APEX_GRAVITY_MULTIPLIER: float = 0.18
const LANDING_EFFECT_SCENE: PackedScene = preload("res://entities/player/player_jumping_effect.tscn")
const SHIELD_LANDING_EFFECT_SCENE: PackedScene = preload("res://entities/player/shield_player_jumping_effect.tscn")
const HIT_EFFECT_SCENE: PackedScene = preload("res://entities/player/attack_effect.tscn")
const JUMP_ATTACK_EFFECT_SCENE: PackedScene = preload("res://entities/player/jump_attack_effect.tscn")
const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/player/player_death_effect.tscn")

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_RUN: int = 2
const STATE_FALL: int = 3
const STATE_JUMP: int = 4
const STATE_SPRINT: int = 5
const STATE_CONTRACT: int = 6
const STATE_BALL: int = 7
const STATE_UNCONTRACT: int = 8
const STATE_ATTACK_1: int = 9

# Maximum downward speed (terminal velocity). Normal jumps shouldn't hit this.
const MAX_FALL_SPEED: float = 600.0
const FALL_GRAVITY_MULTIPLIER: float = 1.6
const COYOTE_TIME: float = 0.10
const JUMP_BUFFER_TIME: float = 0.10
# 在地面上连续站稳这么久,当前位置才算"安全点"(避免擦着地刺滑过时被误记)。
const SAFE_RECORD_SETTLE_TIME: float = 0.12
# 安全点离平台左右边缘至少留这么多像素(主角半宽),免得复活在边缘直接滑落。
const SAFE_EDGE_MARGIN: float = 2.0
# 侧向探针在地面接触点上下各探这么多像素(够覆盖落差,又不会探到下层平台)。
const SAFE_GROUND_PROBE_HEIGHT: float = 6.0

var _grounded_time: float = 0.0

# ============================================================
# State (read by states, written by player or specific states)
# ============================================================
var health: int = MAX_HEALTH
var facing_direction: int = 1  # 1 = right, -1 = left
var can_sprint: bool = true
var is_invincible: bool = false
var is_dying: bool = false  # 死亡序列进行中,避免重复触发
var is_in_ball_form: bool = false  # true when contracted; modifies hitbox + buffs
var input_locked: bool = false

# 护盾状态: shield_ready[i] 是否就绪; shield_recharge[i] 剩余充能秒数。
# is_guarding = 当前是否拿出了护盾(显示外壳); guard_slot = 拿出的是哪个盾(-1=无)。
var shield_ready: Array[bool] = [true, true]
var shield_recharge: Array[float] = [0.0, 0.0]
var is_guarding: bool = false
var guard_slot: int = -1

# ---- Buff 运行态(战斗内临时状态,进梦重置) ----
var tide_next_hit: bool = false        # 珊瑚潮汐:冲刺后的下一击强化,命中即消耗
var tide_ring_bonus: bool = false      # 珊瑚潮汐:水刺全中的下一击强化,命中即消耗
var crystal_dash_active: bool = false  # 蓝水晶:本次冲刺被水晶包裹(完全免疫)
var _tide_ring_pending: int = 0        # 还在飞的水刺数
var _tide_ring_hits: int = 0
var _egg: Node2D = null                # 蜘蛛的伪装:常驻漂浮卵(格林之子式)
var _crystal_cooldown: float = 0.0
var _lamp_energy: int = 0
var _lamp_fire_left: float = 0.0
var _window_ramp: float = 0.0
var _invincibility_token: int = 0

# ---- 开发者模式 ----
# F1(或 ` 反引号)切换:开启后不死不破盾,全身金色提示。
# 地刺仍会把人弹回安全点(respawn_to_safe 不走 take_damage),方便继续跑图。
var dev_god_mode: bool = false
# 走路特效当前应否发射(有盾时改由 ShieldPlayerWalkingEffect 发射)。
var _walking_effect_enabled: bool = false

# ============================================================
# Node references
# ============================================================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_overlay: AnimatedSprite2D = $AnimatedSprite2D/ShieldOverlay
# 技能特效层(默认隐藏,技能系统开关):蓝水晶包裹/铜灯火光/水族箱水花。
@onready var blue_crystal_overlay: AnimatedSprite2D = $AnimatedSprite2D/BlueCrystalOverlay
@onready var fire_attack_overlay: AnimatedSprite2D = $AnimatedSprite2D/FireAttackOverlay
@onready var water_tank_overlay: AnimatedSprite2D = $AnimatedSprite2D/WaterTankOverlay
@onready var collision_normal: CollisionShape2D = $CollisionNormal
@onready var collision_ball: CollisionShape2D = $CollisionBall
@onready var walking_effect: GPUParticles2D = $PlayerWalkingEffect
@onready var shield_walking_effect: GPUParticles2D = $ShieldPlayerWalkingEffect
@onready var jump_trail: Node2D = $JumpTrail
@onready var attack_hitbox_1: Area2D = $HitBox/Attack1_1
@onready var attack_hitbox_2: Area2D = $HitBox/Attack1_2
@onready var hitbox_root: Node2D = $HitBox
@onready var state_machine: StateManager = $StateMachine

# ============================================================
# Signals
# ============================================================
signal health_changed(new_health: int)
signal died
# 护盾状态变化(拿出/收起/破盾/充能完成),供以后接 UI 用。
signal shield_changed

func _ready() -> void:
	add_to_group("player")
	set_ball_form(false)
	clear_attack_hitboxes()
	can_sprint = true
	# 盾壳/技能特效都是独立的 overlay 精灵,被动跟随本体的动画帧(不自己 play)。
	sprite.animation_changed.connect(_sync_overlays)
	sprite.frame_changed.connect(_sync_overlays)
	# 按持有的 buff 决定护盾层数(花=1/树=3/默认2),出生全部充满。
	_apply_shield_layout()
	# 中途放下/拿起 buff(左上角 HUD 右键)时,护盾布局和铜灯状态要跟上。
	Story.buff_gained.connect(_on_buffs_changed)
	Story.buff_removed.connect(_on_buffs_changed)
	# 蜘蛛的伪装常驻卵:等场景就位后自动出场(current_scene 此刻可能还没赋值)。
	_update_egg_companion.call_deferred()
	# 每次出生(新梦/死亡重试)守望都完好如初。
	Story.set_muzi_broken(false)
	# 出生默认拿出 0 号盾,否则一出生被碰就死。
	is_guarding = true
	guard_slot = 0
	_refresh_shield_visual()
	shield_changed.emit()

# 像素对齐:物理体停在浮点坐标(保证移动/相机插值丝滑),
# 只把渲染用的 sprite 节点局部偏移到整数像素,消除脚底与地板间的亚像素缝隙。
# 只吸附 Y 轴 —— 缝隙是垂直方向的,横向不碰,避免水平移动出现像素跳动。
# 在 _process(渲染帧)里做,不污染物理状态。
func _process(_delta: float) -> void:
	if not is_instance_valid(sprite):
		return
	# 让 sprite.global_position.y 落到整数:补偿父级(物理体)的小数残差。
	sprite.position.y = roundf(global_position.y) - global_position.y

func _physics_process(_delta: float) -> void:
	# 开发者模式切换不受 input_locked 限制,任何时候都能开关。
	if Input.is_action_just_pressed(&"dev_god_mode"):
		_toggle_dev_god_mode()
	_update_shield_recharge(_delta)
	_update_buff_timers(_delta)
	if not input_locked and Input.is_action_just_pressed(&"Backpack"):
		raise_shield()
	if not input_locked and Input.is_action_just_pressed(&"ShieldBreak"):
		manual_break_shield()

	# 持续记录最后的安全落脚点,供地刺等危险物弹回使用。
	# 站稳一小会儿才记录;受伤无敌期间不记录(刚被弹回时别立刻覆盖);
	# 脚下是陷阱平台(unsafe_ground 组)时不记录,免得重生在陷阱上。
	# 只在"平台内侧"记录:脚下左右各 SAFE_EDGE_MARGIN 处都得有地面。
	# 这样贴地走下平台时(土狼时间内中心已越过边缘的那几帧)不会被记录,
	# 自动保留上一个内侧安全点,避免复活在悬空边缘后直接滑落。
	if is_on_floor() and not _is_on_unsafe_ground():
		_grounded_time += _delta
		if _grounded_time >= SAFE_RECORD_SETTLE_TIME and not is_invincible and _is_interior_floor_spot():
			Game.record_safe_position(global_position)
	else:
		_grounded_time = 0.0

# 脚下左右两侧 SAFE_EDGE_MARGIN 处都有地面 → 站在平台内侧(非边缘悬空)。
func _is_interior_floor_spot() -> bool:
	var ground_y := _floor_contact_y()
	if is_inf(ground_y):
		return true  # 拿不到接触点时不阻止记录(退回原行为)
	return _has_ground_below(global_position.x - SAFE_EDGE_MARGIN, ground_y) \
		and _has_ground_below(global_position.x + SAFE_EDGE_MARGIN, ground_y)

# 脚下地面接触点的 Y(全局),取不到返回 INF。
func _floor_contact_y() -> float:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < -0.5:  # 只看脚下(法线朝上)的接触面
			return collision.get_position().y
	return INF

# 在 (x, ground_y) 附近上下各探一小段,判断该处脚下是否有地面。
func _has_ground_below(x: float, ground_y: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := Vector2(x, ground_y - SAFE_GROUND_PROBE_HEIGHT)
	var to := Vector2(x, ground_y + SAFE_GROUND_PROBE_HEIGHT)
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	return not space.intersect_ray(query).is_empty()

# 检查脚下踩着的碰撞体是否属于 "unsafe_ground" 组(陷阱平台)。
func _is_on_unsafe_ground() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		# 只看脚下(法线朝上)的接触面
		if collision.get_normal().y < -0.5:
			var collider := collision.get_collider()
			if collider is Node and (collider as Node).is_in_group("unsafe_ground"):
				return true
	return false

# 被地刺等危险物击中时调用:弹回上一个安全点,清零速度并给无敌帧。
func respawn_to_safe() -> void:
	if not Game.has_safe_position:
		return
	global_position = Game.last_safe_position
	velocity = Vector2.ZERO
	_grounded_time = 0.0
	change_state(STATE_IDLE)
	_start_invincibility()

func change_state(state_id: int) -> void:
	state_machine.change_state(state_id)

func set_lock(locked: bool) -> void:
	input_locked = locked
	if locked:
		set_ball_form(false)
		change_state(STATE_IDLE)
		velocity = Vector2.ZERO
		clear_attack_hitboxes()
	if is_instance_valid(state_machine):
		state_machine.set_process(not locked)
		state_machine.set_physics_process(not locked)

func _toggle_dev_god_mode() -> void:
	dev_god_mode = not dev_god_mode
	# 用根节点 modulate 做金色提示,不碰 sprite.modulate(攻击发光在用它)。
	modulate = Color(1.0, 0.85, 0.45) if dev_god_mode else Color.WHITE
	print("[DEV] 无敌模式: ", "开" if dev_god_mode else "关")

func take_damage(_amount: int) -> void:
	if dev_god_mode:
		# 开发者模式:不掉血不破盾,只给短无敌,免得贴着怪连帧触发。
		_start_invincibility()
		return
	if crystal_dash_active:
		return  # 蓝水晶:水晶包裹的冲刺,完全免疫
	if is_invincible:
		return
	if is_guarding:
		# 有盾:破当前盾、开始充能、进入无盾(不掉血)。愈合的伤口把无敌延长到 1 秒。
		_break_guard_shield()
		Game.play_hit_feedback()
		_start_invincibility(TABLE_BREAK_INVINCIBLE if has_buff(&"Table") else INVINCIBLE_DURATION)
		return
	# 无盾:沐子的守望可以带盾再站起来一次(之后破碎,本次尝试内无效),否则直接死亡。
	if has_buff(&"MuziPaint") and not Story.muzi_broken:
		_muzi_revive()
		return
	health = 0
	health_changed.emit(health)
	_die()

# 蔚蓝式死亡:原地炸开 → 冻结/隐藏 → 交给 Game 黑屏重载房间(清怪+回出生点)。
func _die() -> void:
	if is_dying:
		return
	is_dying = true
	died.emit()
	_spawn_oneshot_particles(DEATH_EFFECT_SCENE)  # 在死亡位置炸开(先炸再隐藏)
	set_lock(true)                                # 冻结输入/状态机
	set_jump_trail(false)
	set_walking_effect(false)
	velocity = Vector2.ZERO
	if is_instance_valid(sprite):
		sprite.visible = false
	Game.handle_player_death()

# ============================================================
# 护盾
# ============================================================
func _update_shield_recharge(delta: float) -> void:
	for i in shield_recharge.size():
		if shield_ready[i]:
			continue
		shield_recharge[i] = maxf(shield_recharge[i] - delta, 0.0)
		if shield_recharge[i] <= 0.0:
			shield_ready[i] = true
			shield_changed.emit()

func _first_ready_shield() -> int:
	for i in shield_ready.size():
		if shield_ready[i]:
			return i
	return -1

# 开盾键 E:无盾时拿出下一个就绪的盾;已有盾时无事发生。
# (收盾没有免费出口——想进无盾伤害加成,用 R 敲碎它,付一个盾的代价。)
func raise_shield() -> void:
	if is_guarding:
		return
	var slot := _first_ready_shield()
	if slot == -1:
		return  # 没有就绪的盾可拿
	is_guarding = true
	guard_slot = slot
	# 开盾的视觉反馈就是盾壳 overlay 出现,不需要额外特效。
	_refresh_shield_visual()
	shield_changed.emit()

# 破盾键 R:主动敲碎当前盾。走和挨打完全一样的破盾流程(充能、珊瑚水刺等
# 破盾特效),区别只在不给无敌帧——无敌是挨打的补偿,不是按键白送的。
func manual_break_shield() -> void:
	if not is_guarding:
		return
	_break_guard_shield()
	Game.shake_camera(2)

func _break_guard_shield() -> void:
	if guard_slot >= 0 and guard_slot < shield_ready.size():
		shield_ready[guard_slot] = false
		shield_recharge[guard_slot] = shield_recharge_time()
	is_guarding = false
	guard_slot = -1
	_refresh_shield_visual()
	shield_changed.emit()
	if has_buff(&"Watertank"):
		_fire_tide_ring()

# 统一的播放动画入口(盾壳 overlay 靠信号自动跟帧,这里只管本体)。
func play_anim(anim_name: StringName) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.play(anim_name)

# 护盾拿出/收起:盾壳 overlay 显示/隐藏,本体动画不动,姿势天然不跳帧。
func _refresh_shield_visual() -> void:
	_apply_walking_effect()  # 护盾切换时走路特效也跟着二选一
	set_effect_overlay(shield_overlay, is_guarding)

# 技能特效层开关(蓝水晶包裹/铜灯火光/水族箱水花…同样适用盾壳):
# 开的瞬间立即对齐当前帧,避免露一帧旧画面。
func set_effect_overlay(overlay: AnimatedSprite2D, on: bool) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.visible = on
	if on:
		_sync_one_overlay(overlay)

# 所有 overlay 跟随本体当前动画帧。overlay 从不自己 play,全靠本体的
# animation_changed / frame_changed 信号驱动,不存在漂移。
func _sync_overlays() -> void:
	for child in sprite.get_children():
		var overlay := child as AnimatedSprite2D
		if overlay != null and overlay.visible:
			_sync_one_overlay(overlay)

func _sync_one_overlay(overlay: AnimatedSprite2D) -> void:
	var anim := sprite.animation
	if overlay.sprite_frames == null or not overlay.sprite_frames.has_animation(anim):
		return
	overlay.animation = anim
	overlay.frame = sprite.frame

# 时长可变(愈合的伤口/复活),token 防止旧的短无敌把新的长无敌提前掐掉。
func _start_invincibility(duration: float = INVINCIBLE_DURATION) -> void:
	_invincibility_token += 1
	var token := _invincibility_token
	is_invincible = true
	await get_tree().create_timer(duration).timeout
	if token == _invincibility_token:
		is_invincible = false


# ============================================================
# Buff 效果(获得/文案在 BuffDefs+Story,这里只管战斗内表现)
# ============================================================
func has_buff(id: StringName) -> bool:
	return Story.has_buff(id)


## 护盾层数:花(绽放的代价)=1 层;树(森林的谢礼)=3 层;默认 2 层。
func _apply_shield_layout() -> void:
	var count := SHIELD_COUNT
	if has_buff(&"Flower"):
		count = 1
	elif has_buff(&"Plant"):
		count = 3
	shield_ready.clear()
	shield_recharge.clear()
	for i in count:
		shield_ready.append(true)
		shield_recharge.append(0.0)


func shield_recharge_time() -> float:
	return PLANT_RECHARGE_TIME if has_buff(&"Plant") else SHIELD_RECHARGE_TIME


## 持有 buff 变化(HUD 右键放下等):护盾布局重算(重置为全满),铜灯没了就熄火,
## 蜘蛛卵随 buff 出现/收回。
func _on_buffs_changed(_id: StringName) -> void:
	_apply_shield_layout()
	if guard_slot >= shield_ready.size():
		guard_slot = shield_ready.size() - 1
	if not has_buff(&"CopperLamp"):
		_lamp_energy = 0
		_lamp_fire_left = 0.0
		set_effect_overlay(fire_attack_overlay, false)
	_update_egg_companion()
	shield_changed.emit()


func _update_buff_timers(delta: float) -> void:
	if _crystal_cooldown > 0.0:
		_crystal_cooldown -= delta
	# 城市的心跳:火光倒计时,烧完熄灭
	if _lamp_fire_left > 0.0:
		_lamp_fire_left -= delta
		if _lamp_fire_left <= 0.0:
			set_effect_overlay(fire_attack_overlay, false)
	# 窗边的晨光:护盾全满时攻速逐秒上涨,缺盾立刻清零
	if has_buff(&"Window") and shield_ready.all(func(ready: bool) -> bool: return ready):
		_window_ramp = minf(_window_ramp + delta, WINDOW_RAMP_MAX_TIME)
	else:
		_window_ramp = 0.0


## 攻击动画速度倍率(攻击状态套到 sprite.speed_scale 上)。
func attack_speed_multiplier() -> float:
	var mult := 1.0
	if _lamp_fire_left > 0.0:
		mult *= LAMP_ATTACK_SPEED
	if has_buff(&"Window"):
		mult *= 1.0 + WINDOW_RAMP_RATE * _window_ramp
	return mult


## 攻击力加法增益(设计要求加法叠加,攻击状态算伤害时乘 (1+总和))。
func attack_damage_bonus() -> float:
	var bonus := 0.0
	if tide_next_hit:
		bonus += TIDE_DAMAGE_BONUS
	if tide_ring_bonus:
		bonus += TIDE_ALL_HIT_BONUS
	return bonus


## 攻击命中(至少打中一个目标)回调:消耗潮汐强化、给铜灯攒心跳。
func on_attack_landed() -> void:
	tide_next_hit = false
	tide_ring_bonus = false
	if has_buff(&"CopperLamp") and _lamp_fire_left <= 0.0:
		_lamp_energy += 1
		if _lamp_energy >= LAMP_ENERGY_MAX:
			_lamp_energy = 0
			_lamp_fire_left = LAMP_FIRE_DURATION
			set_effect_overlay(fire_attack_overlay, true)
			_spawn_oneshot_particles(LAMP_IGNITE_EFFECT_SCENE)  # 橙色升腾:心跳点燃


## 冲刺开始/结束(Sprint 状态调用)。
func on_sprint_started() -> void:
	if has_buff(&"BlueCrystal") and _crystal_cooldown <= 0.0:
		crystal_dash_active = true
		set_effect_overlay(blue_crystal_overlay, true)
		_spawn_oneshot_particles(CRYSTAL_DASH_EFFECT_SCENE)  # 冰蓝迸发:水晶成形


func on_sprint_ended() -> void:
	if crystal_dash_active:
		crystal_dash_active = false
		_crystal_cooldown = CRYSTAL_DASH_COOLDOWN
		set_effect_overlay(blue_crystal_overlay, false)
	if has_buff(&"Watertank"):
		tide_next_hit = true


## 珊瑚潮汐:破盾时朝上半圈射出扇形 7 根水刺(以正上为 0°,每 30° 一根,
## 从左平射扫到右平射)。向下那根打地板没意义,砍掉了。
## 命中 ≥ TIDE_RING_BONUS_HITS 根 → 下一击再+50%(与冲刺强化加法叠加;
## 扇形大半朝天,"全中"不现实,改成够数即触发)。
func _fire_tide_ring() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_tide_ring_hits = 0
	_tide_ring_pending = 0
	for deg in [-90, -60, -30, 0, 30, 60, 90]:
		var rad := deg_to_rad(float(deg))
		var dir := Vector2(sin(rad), -cos(rad))
		var spike := TIDE_SPIKE_SCENE.instantiate() as Area2D
		scene.add_child(spike)
		spike.global_position = global_position
		spike.call("setup", dir, TIDE_SPIKE_DAMAGE)
		spike.scale *= TIDE_SPIKE_SCALE  # setup 里可能镜像了 scale.x,只能乘不能盖
		spike.connect("hit_landed", _on_tide_spike_hit)
		spike.tree_exited.connect(_on_tide_spike_gone)
		_tide_ring_pending += 1
	# 潮汐涌出的反馈:淡青色闪屏,让破盾瞬间一眼可见。
	Game.flash(0.18, Color(0.55, 0.9, 1.0, 0.5))


func _on_tide_spike_hit() -> void:
	_tide_ring_hits += 1


func _on_tide_spike_gone() -> void:
	if not is_inside_tree():
		return  # 换场景的连锁销毁,别再结算
	_tide_ring_pending -= 1
	if _tide_ring_pending == 0 and _tide_ring_hits >= TIDE_RING_BONUS_HITS:
		tide_ring_bonus = true


## 蜘蛛的伪装:有 buff 就自动带着漂浮卵(格林之子式常驻仆从),放下即收回。
func _update_egg_companion() -> void:
	if has_buff(&"SpiderQueenDoll"):
		if is_instance_valid(_egg):
			return
		var scene := get_tree().current_scene
		if scene == null:
			return
		_egg = EGG_SCENE.instantiate() as Node2D
		scene.add_child(_egg)
		_egg.call("setup", self)
	elif is_instance_valid(_egg):
		_egg.call("despawn")
		_egg = null


## 召唤物快照用:主角此刻的单发攻击力(一段基础伤 × 破盾/花/红水晶倍率)。
func snapshot_attack_power() -> int:
	var attack_state: Node = state_machine.get_node(^"Attack1(9)")
	var power: float = float(attack_state.ATTACK1_1_DAMAGE)
	if not is_guarding or has_buff(&"Flower"):
		var mult: float = attack_state.RED_CRYSTAL_NO_SHIELD_MULT \
			if has_buff(&"RedCrystal") else attack_state.NO_SHIELD_DAMAGE_MULT
		power *= mult
	return int(round(power))


## 沐子的守望:无盾被碰不死,带一层盾原地站起来。用掉后守望"破碎"
## (HUD 图标换成碎的),直到下一次出生才复原。
func _muzi_revive() -> void:
	Story.set_muzi_broken(true)
	is_guarding = true
	guard_slot = 0
	shield_ready[0] = true
	shield_recharge[0] = 0.0
	_refresh_shield_visual()
	shield_changed.emit()
	_spawn_oneshot_particles(MUZI_REVIVE_EFFECT_SCENE)  # 红色迸发:守望碎裂
	Game.flash(0.35, Color(1.0, 1.0, 1.0, 1.0))
	Game.shake_camera(3)
	_start_invincibility(MUZI_REVIVE_INVINCIBLE)

var reached_terminal: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

func apply_gravity(delta: float, multiplier: float = 1.0) -> void:
	# Apply gravity and clamp to terminal velocity. Mark if terminal reached.
	velocity.y += GRAVITY * multiplier * delta
	if velocity.y > MAX_FALL_SPEED:
		velocity.y = MAX_FALL_SPEED
		reached_terminal = true

func set_ball_form(enabled: bool) -> void:
	is_in_ball_form = enabled
	collision_normal.disabled = enabled
	collision_ball.disabled = not enabled

func set_walking_effect(enabled: bool) -> void:
	_walking_effect_enabled = enabled
	_apply_walking_effect()

# 走路特效二选一:有盾发 ShieldPlayerWalkingEffect,无盾发 PlayerWalkingEffect。
func _apply_walking_effect() -> void:
	if is_instance_valid(walking_effect):
		walking_effect.emitting = _walking_effect_enabled and not is_guarding
	if is_instance_valid(shield_walking_effect):
		shield_walking_effect.emitting = _walking_effect_enabled and is_guarding

# 跳跃像素残影拖尾开关(由跳跃状态调用,落地时关闭)。
func set_jump_trail(enabled: bool) -> void:
	if is_instance_valid(jump_trail) and jump_trail.has_method("set_active"):
		jump_trail.call("set_active", enabled)

func spawn_landing_effect() -> void:
	# 落地特效二选一:有盾用护盾版本。
	_spawn_oneshot_particles(SHIELD_LANDING_EFFECT_SCENE if is_guarding else LANDING_EFFECT_SCENE)

# 在主角位置放一个一次性粒子特效,播完自动清掉。
func _spawn_oneshot_particles(scene: PackedScene) -> void:
	if not is_inside_tree() or scene == null:
		return
	var effect := scene.instantiate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	if get_tree().current_scene == null:
		effect.queue_free()
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	await get_tree().create_timer(effect.lifetime).timeout
	if is_instance_valid(effect):
		effect.queue_free()

func spawn_hit_effect(posx: float) -> void:
	if not is_inside_tree() or HIT_EFFECT_SCENE == null:
		return
	var effect := HIT_EFFECT_SCENE.instantiate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	if get_tree().current_scene == null:
		effect.queue_free()
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = Vector2(posx, $HitBox/HitEffectPosition.global_position.y)
	await get_tree().create_timer(effect.lifetime).timeout
	if is_instance_valid(effect):
		effect.queue_free()

func spawn_jump_attack_effect(posx: float) -> void:
	if not is_inside_tree() or JUMP_ATTACK_EFFECT_SCENE == null:
		return
	var effect := JUMP_ATTACK_EFFECT_SCENE.instantiate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	if get_tree().current_scene == null:
		effect.queue_free()
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = Vector2(posx, $HitBox/HitEffectPosition.global_position.y)
	await get_tree().create_timer(effect.lifetime).timeout
	if is_instance_valid(effect):
		effect.queue_free()

func set_facing_direction(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = sign(direction)
	var scale_x := absf(sprite.scale.x)
	if scale_x == 0.0:
		scale_x = 1.0
	sprite.scale.x = scale_x * float(facing_direction)
	if is_instance_valid(hitbox_root):
		var hitbox_scale_x := absf(hitbox_root.scale.x)
		if hitbox_scale_x == 0.0:
			hitbox_scale_x = 1.0
		hitbox_root.scale.x = hitbox_scale_x * float(facing_direction)

func enter_ball_form() -> void:
	set_ball_form(true)

func exit_ball_form() -> void:
	set_ball_form(false)

func start_attack() -> void:
	clear_attack_hitboxes()
	change_state(STATE_ATTACK_1)

func set_attack_hitbox(stage: int, enabled: bool = true) -> void:
	if stage == 1:
		if is_instance_valid(attack_hitbox_1):
			attack_hitbox_1.monitoring = enabled
		if is_instance_valid(attack_hitbox_2):
			attack_hitbox_2.monitoring = false
		return

	if stage == 2:
		if is_instance_valid(attack_hitbox_1):
			attack_hitbox_1.monitoring = false
		if is_instance_valid(attack_hitbox_2):
			attack_hitbox_2.monitoring = enabled
		return

	clear_attack_hitboxes()

func clear_attack_hitboxes() -> void:
	if is_instance_valid(attack_hitbox_1):
		attack_hitbox_1.monitoring = false
	if is_instance_valid(attack_hitbox_2):
		attack_hitbox_2.monitoring = false

func finish_attack() -> void:
	clear_attack_hitboxes()
	if is_in_ball_form:
		change_state(STATE_BALL)
		return
	if not is_on_floor():
		change_state(STATE_FALL)
		return
	var move_input := Input.get_axis(&"move_left", &"move_right")
	if abs(move_input) > 0.0:
		change_state(STATE_RUN)
	else:
		change_state(STATE_IDLE)
