# 图书管理员章鱼的 boss 形态(周二原走廊 cradel_corridor 尽头),泰拉瑞亚肉山式:
# 主角走到红墙那段 → BossIntro 震屏、它从右边滑进来 → 一边上下飘,一边从右往左压过来。
# - Blocker 是推力区:主角从它左边缘进去,越往里被往回推得越狠(右边缘比跑速快一点 = 挤不过去,但不是空气墙);
#   只有进了本体 CollisionShape2D 那个圈才挨打。
# - 主角退到左门口(想离开房间)或者被一路挤到门口 = 剧情杀,所以得边退边打、尽快打赢。
# - 技能两个:
#   ①平时天上掉子弹:预判 / 堵后路 / 前后夹,一直往后退躲不掉,得前后挪着躲;
#   ②砸地(Slam,按阶段连砸 2/3/3 下):砸地帧之前把身体挪到 Hit 点正好压在地面(ground_y)的高度(不管当时飘在哪),
#     砸地那一帧震屏(可选闪屏),天上斜着落下一把子弹:各自带角度走弧线,落点分格打散、落地先后也打散,有缝但不规律;
#     砸完一整轮停 slam_rest_time 秒(不走不掉子弹),再接着压。
#   ③十字激光(Laser,用 Idle 动画):原地停住,身后以本体原点为交点摆十字预警线——一根瞄主角再往左 30°
#     (摆好就固定),一根和它垂直;开火后整个十字每秒转 20° 扫到开火时主角的位置,转完变细消失。
#     Idle 等够了在砸地和激光里按权重挑。
# - 不吃主角的光(贴图 light_mask 清 0);贴图颜色在两个很接近的色之间慢慢来回。
# - 打赢了不死(之后会变成 NPC):往上飞走 / 沉到地下,离开屏幕后删掉。
# 编辑器里摆的两个点:Hit = 砸地那一帧触手碰地的点;Low = Idle(移动也是它)时贴图最低点,飘到最低时离地 float_gap。
# 动画名:Idle(循环) / Slam(一次) / Battlecry(阶段吼)。没导帧的动画自动跳过、按计时兜底。
# 状态(按序号):Null(0) Idle(1) Flee(2) Battlecry(3) Slam(4) Laser(5)。
#   往前压、上下飘、推人、平时掉子弹都在主体里跑,状态只负责"演";下一招都问 get_next_attack_state()。
extends CharacterBody2D

const STATE_NULL := 0
const STATE_IDLE := 1
const STATE_FLEE := 2
const STATE_BATTLECRY := 3
const STATE_SLAM := 4
const STATE_LASER := 5

const PHASE_NORMAL := 0
const PHASE_HALF := 1
const PHASE_QUARTER := 2

const BULLET_SCENE: PackedScene = preload("res://entities/octopus/octopus_bullet.tscn")

@export_group("血量")
@export var max_health: int = 4500
@export var health: int = 4500
## 调试:开打后原地飘着,不走不打
@export var idle_only := false

@export_group("飘")
## 地面的 y:砸地时 Hit 落到这里;平时飘到最低时 Low 离它 float_gap
@export var ground_y: float = 80.0
@export var float_gap: float = 2.0
## 上下飘的幅度(像素)和一个来回的秒数
@export var bob_amplitude: float = 3.0
@export var bob_period: float = 2.4
## 偏离飘浮轨道时(刚出场、砸完地)追回去的最快速度 px/s
@export var bob_catchup: float = 40.0

@export_group("往前压")
## 每秒往左推进多少像素
@export var advance_speed: float = 9.6
## 各阶段(满血 / 半血以下 / 四分之一以下)推进速度的倍率
@export var phase_speed_mult: Array[float] = [1.0, 1.2, 1.45]

@export_group("推人与接触伤害")
## 主角在 Blocker 里被往回推(px/s):刚进左边缘是 push_min,越往里越大,到右边缘是 push_max。
## 主角跑速 70,章鱼自己还在往前压(约 10):push_max 比两者之和大一点 = 挤到快穿过去时就挤不动了,冲刺能多冲一截
@export var push_min: float = 0.0
@export var push_max: float = 90.0
## 推力随深度的曲线(1 = 线性;大于 1 = 前半段软、快到头才猛)
@export var push_curve: float = 1.5
## 进了本体 CollisionShape2D(那个圈)才挨打
@export var contact_damage: int = 10
@export var contact_cooldown: float = 0.6

@export_group("剧情杀")
## 开打后主角退到这个世界 x 以左(左门口)= 想离开房间 → 剧情杀;章鱼前沿压到这里也算
@export var door_x: float = 8.0
## 剧情杀时章鱼扑过去用几秒
@export var kill_lunge_time: float = 0.35

@export_group("平时掉子弹")
## 各阶段两次掉落之间隔几秒
@export var drop_interval: Array[float] = [1.4, 1.1, 0.85]
@export var drop_jitter: float = 0.2
## 从屏幕上沿落到地面用几秒
@export var drop_fall_time: float = 0.9
## 预判:按主角当前速度往前估多少(1 = 落地那一刻他会跑到哪就砸哪;0 = 只砸脚下)
@export var drop_lead: float = 1.0
## "堵后路"砸在主角身后(远离章鱼那边)多远
@export var behind_min: float = 16.0
@export var behind_max: float = 30.0
## 各阶段:这一下砸他身后的概率
@export var behind_chance: Array[float] = [0.3, 0.3, 0.3]
## 各阶段:这一下前后夹的概率(脚下或预判处一颗 + 身后一颗,只能往章鱼那边躲)
@export var pincer_chance: Array[float] = [0.15, 0.3, 0.45]

@export_group("出招")
## 各阶段 Idle 里等几秒出一招(砸地或激光)
@export var attack_interval: Array[float] = [7.0, 6.0, 5.0]
@export var attack_interval_jitter: float = 1.0
## 出招时砸地和激光的权重(各 1 = 一半一半)
@export var slam_weight: float = 1.0
@export var laser_weight: float = 1.0

@export_group("砸地")
## 各阶段一轮砸地连砸几下(满血 / 半血以下 / 四分之一以下)
@export var slam_combo: Array[int] = [2, 3, 3]
## 一轮砸完停多久(不走、不掉子弹),然后接着往前压
@export var slam_rest_time: float = 1.5
## 砸下去那一帧的震屏 / 白闪(0 = 不要)
@export var slam_shake: float = 3.0
@export var slam_flash: float = 0.0
## 各阶段每砸一下天上落几颗(连砸次数多了,每下的量就少一点)
@export var burst_count: Array[int] = [3, 4, 4]
## 重力(px/s²):越小落得越慢、越好躲
@export var burst_gravity: float = 90.0
## 出发时往下的初速度(px/s),每颗在这个范围里随机
@export var burst_fall_speed_min: float = 0.0
@export var burst_fall_speed_max: float = 20.0
## 横着的速度(px/s,随机向左或向右):越大越斜
@export var burst_side_speed_min: float = 8.0
@export var burst_side_speed_max: float = 24.0
## 每颗出发前随机晚 0~这么多秒(落地有先有后)
@export var burst_stagger: float = 0.3
## 落点在每一格里随机的范围(0~1,两头留空保证相邻两颗至少隔开半格)
@export var burst_cell_jitter: float = 0.5

@export_group("变色")
## 贴图在两个颜色之间慢慢来回(只动一点点)
@export var tint_a: Color = Color(1.0, 0.96, 0.93)
@export var tint_b: Color = Color(0.93, 0.97, 1.0)
## 来回一趟的秒数
@export var tint_period: float = 6.0

@export_group("打赢以后")
## 不死,逃走:往上飞出屏幕 / 沉到地下
@export_enum("往上飞走", "沉下去") var flee_mode := 0
@export var flee_time: float = 1.4

@export_group("阶段")
@export var phase_half_ratio: float = 0.5
@export var phase_quarter_ratio: float = 0.25

var phase := PHASE_NORMAL
var pending_battlecry := 0
var battlecry_done_half := false
var battlecry_done_quarter := false
var hittable := true
## BossIntro 通用的出场标记(它会设成 true),这里用不上
var initial_battlecry_shown := false
var rng := RandomNumberGenerator.new()

var _in_fight := false
var _advancing := false
var _drops_on := false
var _drop_cd := 0.0
var _contact_cd := 0.0
var _killing := false
var _extra_slams := 0   # 这一轮砸地还要再连砸几下
var _bobbing := true
var _bob_t := 0.0
var _y_tween: Tween = null
var _tint_t := 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var push_zone: Area2D = get_node_or_null("Blocker") as Area2D
@onready var hit_point: Node2D = get_node_or_null("Hit") as Node2D
@onready var low_point: Node2D = get_node_or_null("Low") as Node2D
@onready var boss_health_ui: BossHealthUI = get_node_or_null("BossHealthUI") as BossHealthUI


func _ready() -> void:
	add_to_group("monster")
	velocity = Vector2.ZERO
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	rng.randomize()
	phase = _calc_phase()
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.hide_ui(false)
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	_unlit(self)
	play_anim(&"Idle")


# 不吃主角的光:light_mask 不会往下继承,每个会画东西的节点都得自己清 0
func _unlit(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).light_mask = 0
	for child in node.get_children():
		_unlit(child)


# 贴图在 tint_a / tint_b 之间慢慢来回(self_modulate,不碰受击闪白和 BossIntro 的渐显)
func _process(delta: float) -> void:
	if ani_2d == null or tint_period <= 0.0:
		return
	_tint_t += delta
	ani_2d.self_modulate = tint_a.lerp(tint_b, 0.5 - 0.5 * cos(TAU * _tint_t / tint_period))


## BossIntro 开演前来问:这个梦里已经把它打跑了,回走廊就不再出来(打没打 Actinos 都会出来)
func intro_allowed() -> bool:
	return not Story.octopus_defeated


func _physics_process(delta: float) -> void:
	if not _in_fight or _killing:
		return
	if _advancing and not idle_only:
		global_position.x -= advance_speed * _phase_value(phase_speed_mult, 1.0) * delta
	_update_bob(delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_keep_player_on_front_side()
	_push_player(delta)
	_try_contact_damage()
	_update_drops(delta)
	_check_door()


# =============================================================================
# 开打 / 结束(状态调用)
# =============================================================================

## Idle 第一次进来时调(BossIntro 字卡播完切到 Idle)
func start_fight() -> void:
	if _in_fight:
		return
	_in_fight = true
	_bob_t = 0.0
	_bobbing = true
	# 字卡前那一小段停顿里主角可能冲得太靠前:别一开打就站在圈里挨打
	var player := _get_player()
	var edge := minf(front_x(), _zone_x_range().x)
	if player != null and player.global_position.x > edge - 8.0:
		player.global_position.x = edge - 10.0


func set_advancing(on: bool) -> void:
	_advancing = on


## 激光时要原地定住(十字交点就是本体原点,不能飘走);重新开飘时追回轨道是平滑的
func set_bobbing(on: bool) -> void:
	_bobbing = on


func set_drops(on: bool) -> void:
	if on and not _drops_on:
		_drop_cd = _phase_value(drop_interval, 1.2)  # 刚恢复先隔一拍,别和砸地的雨叠在一起
	_drops_on = on


## Flee 状态进来时调:记下"这个梦里打跑了",停掉一切(走、飘、推人、挨打、掉子弹),收血条
func end_fight() -> void:
	Story.octopus_defeated = true
	_in_fight = false
	_advancing = false
	_drops_on = false
	_extra_slams = 0
	_bobbing = false
	_kill_y_tween()
	hittable = false
	set_deferred("collision_layer", 0)
	if push_zone != null:
		push_zone.set_deferred("monitoring", false)
	hide_health_ui()


## 打赢后逃走的终点(世界 y):往上 = 整张贴图飞出屏幕顶;往下 = 整张贴图沉到屏幕底下(地面条先把它盖住)
func flee_target_y() -> float:
	var view := _view_rect()
	var sprite := _sprite_rect()
	if flee_mode == 0:
		return view.position.y - sprite.end.y - 4.0
	return view.end.y - sprite.position.y + 4.0


# =============================================================================
# 决策(集中在主体,状态演完都来问)
# =============================================================================

## 先插阶段战吼;Idle 等够了按权重挑砸地或激光(砸地这时按阶段定连砸几下);出完招/吼完回 Idle
func get_next_attack_state(from_state: int = STATE_IDLE) -> int:
	_update_phase()
	if pending_battlecry > 0:
		pending_battlecry -= 1
		_extra_slams = 0
		return STATE_BATTLECRY
	if from_state == STATE_IDLE and not idle_only:
		var total := maxf(slam_weight, 0.0) + maxf(laser_weight, 0.0)
		if total > 0.0 and rng.randf() * total < maxf(laser_weight, 0.0):
			return STATE_LASER
		_extra_slams = maxi(0, int(_phase_value(slam_combo, 1.0)) - 1)
		return STATE_SLAM
	return STATE_IDLE


## Slam 每砸完一下来问:这一轮还要不要再砸(有阶段战吼排着就不连了,先吼)
func take_extra_slam() -> bool:
	if pending_battlecry > 0 or _extra_slams <= 0:
		return false
	_extra_slams -= 1
	return true


## Idle 里等多久出一招
func attack_wait_time() -> float:
	var t := _phase_value(attack_interval, 6.0) + rng.randf_range(-attack_interval_jitter, attack_interval_jitter)
	return maxf(1.0, t)


func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 挨打
# =============================================================================

func take_damage(value: int) -> void:
	if not hittable or health <= 0:
		return
	health = clampi(health - value, 0, max_health)
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health, true)
	_update_phase()
	flash_hit()
	if health <= 0:
		change_state(STATE_FLEE)


func flash_hit() -> void:
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")


func _calc_phase() -> int:
	if max_health <= 0:
		return PHASE_NORMAL
	var ratio := float(health) / float(max_health)
	if ratio <= phase_quarter_ratio:
		return PHASE_QUARTER
	if ratio <= phase_half_ratio:
		return PHASE_HALF
	return PHASE_NORMAL


# 跨过阶段线时排一次战吼(每条线只插一次)
func _update_phase() -> void:
	var new_phase := _calc_phase()
	if new_phase == phase:
		return
	phase = new_phase
	if phase >= PHASE_HALF and not battlecry_done_half:
		battlecry_done_half = true
		pending_battlecry += 1
	if phase >= PHASE_QUARTER and not battlecry_done_quarter:
		battlecry_done_quarter = true
		pending_battlecry += 1


# =============================================================================
# 上下飘 / 砸地时的升降
# =============================================================================

## 飘浮轨道的中线(世界 y):飘到最低时 Low 离地面 float_gap
func float_center_y() -> float:
	return ground_y - _low_offset() - float_gap - bob_amplitude


func _update_bob(delta: float) -> void:
	if not _bobbing:
		return
	_bob_t += delta
	var target := float_center_y() + bob_amplitude * sin(TAU * _bob_t / maxf(bob_period, 0.1))
	global_position.y = move_toward(global_position.y, target, bob_catchup * delta)


## Slam 开头调:duration 秒内把身体挪到 Hit 正好压在地面上的高度(不管现在飘在哪)
func slam_windup(duration: float) -> void:
	_bobbing = false
	_kill_y_tween()
	_y_tween = create_tween()
	_y_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_y_tween.tween_property(self, "global_position:y", ground_y - _hit_offset(), maxf(duration, 0.05))


## 砸下去那一帧:震屏(可选闪屏)+ 天上斜着落下一把子弹
func slam_impact() -> void:
	if slam_shake > 0.0:
		Game.shake_camera(slam_shake)
	if slam_flash > 0.0:
		Game.flash(slam_flash, Color(1.0, 1.0, 1.0, 0.8))
	_burst()


# 落点:把屏幕左边到主角能站的最右处等分成 N 格,每格里随机挑一个点(相邻至少隔半格,有缝但不整齐);
# 每颗从屏幕上沿外出发:横着匀速(side_speed,随机左右)、竖着从 fall_speed 开始按 burst_gravity 加速,
# 走出来就是一段有角度的弧。出发点是按落点倒推的,所以缝还在;再随机晚出发一点,落地有先有后
func _burst() -> void:
	var view := _view_rect()
	var left := maxf(view.position.x, 0.0) + 4.0
	var right := minf(view.end.x - 4.0, _reach_right_x() - 4.0)
	var count := maxi(1, int(_phase_value(burst_count, 6.0)))
	if right - left < 8.0:
		return
	var cell := (right - left) / float(count)
	var edge := clampf((1.0 - burst_cell_jitter) * 0.5, 0.0, 0.5)
	var top := view.position.y - 6.0
	var g := maxf(burst_gravity, 1.0)
	for i in count:
		var x := left + cell * (float(i) + rng.randf_range(edge, 1.0 - edge))
		var target := Vector2(x, _ground_y_at(x, top))
		var vy := rng.randf_range(burst_fall_speed_min, burst_fall_speed_max)
		var vx := rng.randf_range(burst_side_speed_min, burst_side_speed_max) * (1.0 if rng.randf() < 0.5 else -1.0)
		var dy := maxf(target.y - top, 1.0)
		var t := (-vy + sqrt(vy * vy + 2.0 * g * dy)) / g  # 落这么高要多久
		_launch_bullet(Vector2(x - vx * t, top), target, t, g, rng.randf_range(0.0, burst_stagger))


## 砸完:duration 秒内飘回轨道,然后接着上下飘
func slam_recover(duration: float) -> void:
	_kill_y_tween()
	_y_tween = create_tween()
	_y_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_y_tween.tween_property(self, "global_position:y", float_center_y(), maxf(duration, 0.1))
	_y_tween.tween_callback(_resume_bob)


func _resume_bob() -> void:
	_bob_t = 0.0
	_bobbing = true


func _kill_y_tween() -> void:
	if _y_tween != null and _y_tween.is_valid():
		_y_tween.kill()
	_y_tween = null


func _low_offset() -> float:
	return low_point.global_position.y - global_position.y if low_point != null else 0.0


func _hit_offset() -> float:
	return hit_point.global_position.y - global_position.y if hit_point != null else _low_offset()


# =============================================================================
# 前沿 / 推人 / 接触伤害 / 剧情杀
# =============================================================================

## 章鱼的"前沿"(世界 x):本体圈的左边缘 = 挨打的边界(剧情杀扑人、开打时别站进圈里用它)
func front_x() -> float:
	if body_shape != null and body_shape.shape != null:
		return body_shape.global_position.x + body_shape.shape.get_rect().position.x * absf(body_shape.global_scale.x)
	return global_position.x - 30.0


# Blocker 推力区左右边缘(世界 x);没有 Blocker 就当作从前沿往后 40
func _zone_x_range() -> Vector2:
	if push_zone != null:
		for child in push_zone.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
				var cs := child as CollisionShape2D
				var rect := cs.shape.get_rect()
				var sx := absf(cs.global_scale.x)
				var left := cs.global_position.x + rect.position.x * sx
				return Vector2(left, left + rect.size.x * sx)
			if child is CollisionPolygon2D and (child as CollisionPolygon2D).polygon.size() > 0:
				var poly := child as CollisionPolygon2D
				var lo := INF
				var hi := -INF
				for pt in poly.polygon:
					var gx := poly.to_global(pt).x
					lo = minf(lo, gx)
					hi = maxf(hi, gx)
				return Vector2(lo, hi)
	return Vector2(front_x(), front_x() + 40.0)


# 主角最右能站到哪(推力区挤不过去的那头):子弹落点的右边界,躲到章鱼身子底下也会被砸到
func _reach_right_x() -> float:
	return maxf(_zone_x_range().y, front_x())


# Blocker 推力区:主角从左边缘进去,越往里被往回推得越狠(左边缘 push_min → 右边缘 push_max)
func _push_player(delta: float) -> void:
	if push_zone == null or push_max <= 0.0:
		return
	var player := _get_player()
	if not (player is CharacterBody2D) or not push_zone.overlaps_body(player):
		return
	var zone := _zone_x_range()
	var t := clampf((player.global_position.x - zone.x) / maxf(zone.y - zone.x, 1.0), 0.0, 1.0)
	var speed := lerpf(push_min, push_max, pow(t, push_curve))
	(player as CharacterBody2D).move_and_collide(Vector2(-speed * delta, 0.0))


# 只有进了本体圈(CollisionShape2D)才挨打
func _try_contact_damage() -> void:
	if _contact_cd > 0.0 or body_shape == null or body_shape.shape == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape.shape
	query.transform = body_shape.global_transform
	query.collision_mask = 2
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 4):
		var body := hit["collider"] as Node
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", contact_damage)
			_contact_cd = contact_cooldown
			return


# 兜底:冲刺冲穿了整个推力区、跑到章鱼身后的,直接放回推力区左边
func _keep_player_on_front_side() -> void:
	var player := _get_player()
	if player == null:
		return
	var zone := _zone_x_range()
	if player.global_position.x > zone.y + 2.0:
		player.global_position.x = zone.x - 4.0


func _check_door() -> void:
	var player := _get_player()
	if player == null:
		return
	if player.global_position.x <= door_x or minf(front_x(), _zone_x_range().x) <= door_x + 6.0:
		_story_kill(player)


## 剧情杀:想从左门溜走,或者被一路挤到门口——章鱼猛扑过来,当场没了。
func _story_kill(player: Node2D) -> void:
	if _killing:
		return
	_killing = true
	_drops_on = false
	_extra_slams = 0
	_kill_y_tween()
	hittable = false
	change_state(STATE_NULL)
	if player.has_method("set_lock"):
		player.call("set_lock", true)
	# 还落在屏幕外老远的话,先挪到屏幕右边外面一点再扑,扑的过程要看得见;只往左扑(主角躲在它身子底下就原地)
	var to_front := global_position.x - front_x()
	var start_front := minf(front_x(), _view_rect().end.x + 4.0)
	global_position.x = start_front + to_front
	var end_front := minf(start_front, player.global_position.x + 4.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:x", end_front + to_front, kill_lunge_time)
	await tw.finished
	if not is_inside_tree():
		return
	Game.shake_camera(4.0)
	Game.flash(0.6, Color(0.85, 0.1, 0.1, 0.85))
	if is_instance_valid(player) and player.has_method("die_instantly"):
		player.call("die_instantly")
	# 开发者无敌模式死不了:把人挪出门口、章鱼退回去一截接着打,别把人锁死(也别原地反复扑)
	if is_instance_valid(player) and not bool(player.get("is_dying")):
		player.global_position.x = maxf(player.global_position.x, door_x + 16.0)
		global_position.x = player.global_position.x + 60.0 + to_front
		player.call("set_lock", false)
		hittable = true
		_killing = false
		change_state(STATE_IDLE)


# =============================================================================
# 平时天上掉子弹
# =============================================================================

func _update_drops(delta: float) -> void:
	if not _drops_on or idle_only:
		return
	_drop_cd -= delta
	if _drop_cd > 0.0:
		return
	_drop_cd = maxf(0.2, _phase_value(drop_interval, 1.2) + rng.randf_range(-drop_jitter, drop_jitter))
	_drop_volley()


# 一次掉落:砸预判点 / 砸身后(堵后路) / 前后夹。一直往后退 = 撞上预判和堵后路,得往前躲
func _drop_volley() -> void:
	var player := _get_player()
	if player == null:
		return
	var px := player.global_position.x
	var back := -1.0 if global_position.x >= px else 1.0  # "身后" = 远离章鱼、主角要退去的那边
	var vx := 0.0
	if player is CharacterBody2D:
		vx = (player as CharacterBody2D).velocity.x
	var aim_x := px + vx * drop_fall_time * drop_lead
	var behind_x := px + back * rng.randf_range(behind_min, behind_max)
	var roll := rng.randf()
	var pincer := _phase_value(pincer_chance, 0.0)
	var behind := _phase_value(behind_chance, 0.0)
	if roll < pincer:
		if absf(aim_x - behind_x) < 10.0:
			behind_x = aim_x + back * 12.0
		_drop_at(aim_x)
		_drop_at(behind_x)
	elif roll < pincer + behind:
		_drop_at(behind_x)
	else:
		_drop_at(aim_x)


func _drop_at(x: float) -> void:
	var view := _view_rect()
	var left := maxf(view.position.x, 0.0) + 3.0
	var right := minf(view.end.x - 3.0, _reach_right_x() - 4.0)
	if right <= left:
		return
	x = clampf(x, left, right)
	var y := view.position.y - 6.0  # 屏幕上沿外一点点,掉进画面
	_spawn_bullet(Vector2(x, y), _ground_y_at(x, y), drop_fall_time, 0.0)


# =============================================================================
# 杂项
# =============================================================================

func _spawn_bullet(start: Vector2, bullet_ground_y: float, fall_time: float, hover: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or BULLET_SCENE == null:
		return
	var bullet := BULLET_SCENE.instantiate()
	scene.add_child(bullet)
	bullet.call("setup", start, bullet_ground_y, fall_time, hover)


func _launch_bullet(start: Vector2, target: Vector2, flight_time: float, arc_gravity: float, delay: float = 0.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or BULLET_SCENE == null:
		return
	var bullet := BULLET_SCENE.instantiate()
	scene.add_child(bullet)
	bullet.call("launch", start, target, flight_time, arc_gravity, delay)


# 落点的地面高度:从出生点往下打射线找世界层(找不到按 ground_y)
func _ground_y_at(x: float, from_y: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, from_y + 400.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ground_y
	return (hit["position"] as Vector2).y


# 当前屏幕在世界里的范围
func _view_rect() -> Rect2:
	var half := Vector2(80.0, 45.0) / Game.zoom
	return Rect2(Game.get_screen_center_position() - half, half * 2.0)


# 当前这一帧贴图相对本体原点的范围
func _sprite_rect() -> Rect2:
	if ani_2d == null or ani_2d.sprite_frames == null or not has_anim(ani_2d.animation):
		return Rect2(-40.0, -40.0, 80.0, 80.0)
	var tex := ani_2d.sprite_frames.get_frame_texture(ani_2d.animation, ani_2d.frame)
	if tex == null:
		return Rect2(-40.0, -40.0, 80.0, 80.0)
	var size := tex.get_size()
	var top_left := ani_2d.position + ani_2d.offset - (size * 0.5 if ani_2d.centered else Vector2.ZERO)
	return Rect2(top_left, size)


func _phase_value(values: Array, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return float(values[clampi(phase, 0, values.size() - 1)])


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return (players[0] as Node2D) if not players.is_empty() else null


func has_anim(anim: StringName) -> bool:
	return ani_2d != null and ani_2d.sprite_frames != null \
		and ani_2d.sprite_frames.has_animation(anim) \
		and ani_2d.sprite_frames.get_frame_count(anim) > 0


## 没导帧的动画不播(空动画一 play 就结束),退回 Idle
func play_anim(anim: StringName) -> void:
	if ani_2d == null:
		return
	var target := anim
	if not has_anim(target):
		target = &"Idle"
		if not has_anim(target):
			return
	if ani_2d.animation != target or not ani_2d.is_playing():
		ani_2d.play(target)


## 从第 0 帧重播(一次性动画用)
func restart_anim(anim: StringName) -> void:
	if not has_anim(anim):
		return
	ani_2d.stop()
	ani_2d.play(anim)


## 从第 0 帧播到第 frame 帧开始要多少秒(没帧 = 0)
func anim_time_until(anim: StringName, frame: int) -> float:
	if not has_anim(anim):
		return 0.0
	var frames := ani_2d.sprite_frames
	var fps := frames.get_animation_speed(anim) * absf(ani_2d.speed_scale)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in mini(frame, frames.get_frame_count(anim)):
		total += frames.get_frame_duration(anim, i)
	return total / fps


## 动画播一遍多少秒(没帧 = 0)
func anim_length(anim: StringName) -> float:
	if not has_anim(anim):
		return 0.0
	return anim_time_until(anim, ani_2d.sprite_frames.get_frame_count(anim))


func show_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.show_ui(true)


func hide_health_ui() -> void:
	if boss_health_ui != null:
		boss_health_ui.hide_ui(false)
