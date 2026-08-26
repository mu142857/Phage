# =============================================================================
# calendula_ram(6).gd  —  冲刺（6 号）：轰炸机航线 + 唯一的换边时机
# =============================================================================
# 流程（process 驱动）：
#   0 撤离：从当前悬浮位【缓慢】朝本侧上角飘出屏幕（off_screen_x 已算上
#     81px 宽贴图的半宽，越线 = 整个身子真的看不见了）
#   1 屏外整备（pre_sweep_wait）：短暂消失，然后【换边】——
#     monster.set_side(-side)，整个角色 scale.x 翻转，这是全场唯一的翻转时机
#   2 轰炸横扫：从对侧屏外进场，沿 y=sweep_y(20，玩家够不到) 匀速略加速扫过全屏，
#     全程震屏；途经投弹线时，网弹从屏幕顶(y=-10)以 vx=0,vy=0 纯重力落下
#   3 清网留白：扫出对面屏外后【在屏幕外待 off_screen_wait(6s)】——
#     强制留白给玩家清理刚炸下来的网 → 问大脑 → Idle 平滑拉回新侧悬浮位
#
# Ram 动画建议【循环】（整个冲刺期间一直播，不靠 animation_finished）。
# =============================================================================

extends BasicState

@export var ram_animation: StringName = &"Ram"
@export var exit_speed: float = 55.0         # 撤离段的缓慢速度
@export var exit_y: float = 8.0              # 撤离目标高度（朝上角飘）
# 越过这条线才算真出屏：房间半宽 80 + 贴图半宽 ~41 + 余量
@export var off_screen_x: float = 135.0
@export var pre_sweep_wait: float = 0.8      # 屏外整备（换边）的短停
@export var off_screen_wait: float = 4.0     # 扫完后的屏外留白（玩家清网时间）
@export var return_y: float = 40.0           # 留白结束后从新边屏外回场的高度
@export var sweep_y: float = 20.0            # 轰炸航线高度（玩家打不到）
@export var sweep_speed_start: float = 100.0 # 起扫速度（基本匀速的基准）
@export var sweep_speed_max: float = 160.0   # 扫程中的速度上限
@export var sweep_accel: float = 60.0        # 扫程加速度（只在扫的时候加速）
@export var sweep_shake: float = 1.5         # 横扫全程震屏（压迫感）
@export var bomb_drop_xs: Array[float] = [-48.0, -16.0, 16.0, 48.0]  # 四枚炸弹的投放线
@export var bomb_spawn_y: float = -10.0      # 炸弹从屏幕顶这个高度落下
@export var damage_amount: int = 10          # 航线上撞到玩家的伤害（基本撞不到）
@export var hit_shake: float = 2.0           # 命中额外震屏（0=不震）

const BOLT_SCENE: PackedScene = preload("res://entities/calendula/calendula_web_bolt.tscn")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var stage: int = 0
var stage_time: float = 0.0
var sweep_dir: float = 1.0
var sweep_speed: float = 0.0
var _drop_queue: Array[float] = []
var damage_applied: bool = false


func enter() -> void:
	monster.velocity = Vector2.ZERO
	stage = 0
	stage_time = 0.0
	damage_applied = false
	# 撤离段是慢悠悠飘出去，播 Idle；带拖尾的 Ram 动画等真正开扫再切
	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")


func process(delta: float) -> void:
	stage_time += delta
	var side: int = monster.side if "side" in monster else 1
	match stage:
		0:  # 撤离：缓慢朝本侧上角飘出屏幕（整个贴图完全离屏才算）
			var target := Vector2(_center() + float(side) * (off_screen_x + 8.0), exit_y)
			var to_target := target - monster.global_position
			if to_target.length() <= exit_speed * delta:
				monster.global_position = target
			else:
				monster.global_position += to_target.normalized() * exit_speed * delta
			if absf(monster.global_position.x - _center()) >= off_screen_x:
				_next_stage(1)
		1:  # 屏外整备：短停后换边 + 摆到对侧屏外的航线起点
			if stage_time >= pre_sweep_wait:
				var new_side: int = -side
				if monster.has_method("set_side"):
					monster.set_side(new_side)
				sweep_dir = -float(new_side)  # 新边在左(-1)就从左往右扫，反之亦然
				monster.global_position = Vector2(_center() - sweep_dir * (off_screen_x + 8.0), sweep_y)
				sweep_speed = sweep_speed_start
				_prepare_drop_queue()
				if is_instance_valid(ani_2d):
					ani_2d.play(ram_animation)  # 开扫才用带拖尾的冲刺动画
				_next_stage(2)
		2:  # 轰炸横扫：匀速略加速，全程震屏，途经投放线丢弹
			sweep_speed = minf(sweep_speed + sweep_accel * delta, sweep_speed_max)
			monster.global_position.x += sweep_dir * sweep_speed * delta
			monster.global_position.y = sweep_y
			if sweep_shake > 0.0:
				Game.shake_camera(sweep_shake)
			_drop_bombs_passed()
			if not damage_applied:
				_try_damage_player()
			if (monster.global_position.x - _center()) * sweep_dir >= off_screen_x:
				Game.stop_shake()
				_next_stage(3)
		3:  # 清网留白：在屏幕外老实待够 off_screen_wait 秒再回场
			if stage_time >= off_screen_wait:
				# 扫完落在对侧屏外，直接（屏外无感）挪到自己新边的屏外入口，
				# Idle 从自己那边正脸滑进来——不许倒着横穿全场回家，很诡异
				monster.global_position = Vector2(_center() + float(side) * (off_screen_x + 8.0), return_y)
				stage = -1  # 防止重复问大脑
				if monster.has_method("get_next_attack_state"):
					change_state(int(monster.get_next_attack_state()))
				else:
					change_state(1)


func exit() -> void:
	Game.stop_shake()


func _next_stage(next: int) -> void:
	stage = next
	stage_time = 0.0


# 投放队列按扫的方向排好序，扫过一条线丢一枚（投放线以场地中心为原点，入队转成世界 x）
func _prepare_drop_queue() -> void:
	_drop_queue.clear()
	for x in bomb_drop_xs:
		_drop_queue.append(_center() + x)
	_drop_queue.sort()
	if sweep_dir < 0.0:
		_drop_queue.reverse()


# 场地中心 x（蛛网森林=0，0~160 的房间=80），出屏/航线判定都以它为原点
func _center() -> float:
	return monster.center_x if "center_x" in monster else 0.0


func _drop_bombs_passed() -> void:
	while not _drop_queue.is_empty() \
			and (monster.global_position.x - _drop_queue[0]) * sweep_dir >= 0.0:
		var x: float = _drop_queue.pop_front()
		_spawn_bomb(x)


# 炸弹：从屏幕顶垂直落下，vx=0 vy=0 只吃重力（不从 boss 身上出）
func _spawn_bomb(x: float) -> void:
	if BOLT_SCENE == null or get_tree().current_scene == null:
		return
	var bolt := BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	if bolt.has_method("setup_arc"):
		bolt.setup_arc(Vector2(x, bomb_spawn_y), Vector2.ZERO)
	else:
		bolt.global_position = Vector2(x, bomb_spawn_y)


func _try_damage_player() -> void:
	var hitbox := monster.get_node_or_null("RamHitbox") as Area2D
	if hitbox == null:
		return
	for body in hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)
		damage_applied = true
		if hit_shake > 0.0:
			Game.shake_camera(hit_shake)
		break
