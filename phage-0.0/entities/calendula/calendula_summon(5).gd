# =============================================================================
# calendula_summon(5).gd  —  召唤小蜘蛛（5 号）：三选轮换，垂降入场
# =============================================================================
# 行为：面向玩家 → 播一遍 Summon 动画 → 播完按轮换表召唤（垂降丝线，
#       套路同 spider_forest 的 _spawn_descending_spider）→ 问大脑。
# 全程保持轻微上下浮动（金盏一刻不停）。
#
# 轮换表（轮流来，打一轮循环一遍）：
#   0. 场景左右各一只【盾蜘蛛】(spider_2, 肉墙)
#   1. 场景左右各一只【远程蜘蛛】(spider_1, 吐弹)
#   2. 场景中间一只【跳跃蜘蛛】(spider_3, 最难打所以只有一只)
#
# 场上小蜘蛛 >= max_alive 时本次不召唤也不推进轮换（白挥一下）。
# Summon 动画必须【不循环】，靠 animation_finished 收尾；
# 动画不存在时兜底：播 Idle + 计时器代替，绝不卡死。
# =============================================================================

extends BasicState

@export var summon_animation: StringName = &"Summon"
@export var finish_delay: float = 0.15      # 召唤完到切状态的停顿
@export var fallback_windup: float = 0.5    # 没有动画时的前摇计时
@export var left_x: float = 25.0            # 左侧召唤点
@export var right_x: float = 135.0          # 右侧召唤点
@export var center_x: float = 80.0          # 中间召唤点（跳跃蜘蛛）
@export var max_alive: int = 4              # 场上召唤物上限
@export var summon_shake: float = 1.5       # 召唤瞬间震屏（没有 Summon 帧时的重要 tell）
@export var bob_amplitude: float = 2.5      # 攻击中轻微浮动幅度
@export var bob_speed: float = 2.5          # 浮动角速度
@export var bob_y_max: float = 45.0         # 高度铁律：root y ≤ 45（贴图下探 35，不进地面）

# 垂降参数（同 spider_forest）
const SPAWN_START_Y: float = -25.0
const SILK_ANCHOR_Y: float = -30.0
const LANDING_Y: float = 79.0
const DESCEND_TIME: float = 0.55

const SPIDER_SHIELD: PackedScene = preload("res://entities/spider/spider_2.tscn")
const SPIDER_RANGED: PackedScene = preload("res://entities/spider/spider_1.tscn")
const SPIDER_JUMPER: PackedScene = preload("res://entities/spider/spider_3.tscn")
const SILK_LINE_TEXTURE: Texture2D = preload("res://levels/spider_forest/web_silk_line.png")

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var summon_cycle: int = 0   # 轮换指针（状态节点常驻，整场战斗内持续轮换）
var _minions: Array = []    # 召唤物记录（数上限用）
var ticket: int = 0         # 防过期 await
var _base_y: float = 0.0
var _time: float = 0.0


func enter() -> void:
	monster.velocity = Vector2.ZERO
	ticket += 1
	_base_y = monster.global_position.y
	_time = 0.0

	if _has_animation(summon_animation):
		ani_2d.play(summon_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)
	else:
		# 兜底：没切 Summon 帧时播 Idle，计时器顶替 animation_finished
		if is_instance_valid(ani_2d):
			ani_2d.play(&"Idle")
		_fallback_windup(ticket)


func process(delta: float) -> void:
	# 轻微上下浮动：金盏没有真正的静止
	_time += delta
	monster.global_position.y = minf(_base_y + sin(_time * bob_speed) * bob_amplitude, bob_y_max)


func exit() -> void:
	ticket += 1  # 作废未完成的 await（被打断时不再召唤）
	if is_instance_valid(ani_2d):
		if ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.disconnect(_on_animation_finished)


func _on_animation_finished() -> void:
	if not is_instance_valid(ani_2d) or ani_2d.animation != summon_animation:
		return
	_do_summon()
	_finish(ticket)


func _fallback_windup(t: int) -> void:
	await get_tree().create_timer(fallback_windup).timeout
	if t != ticket:
		return
	_do_summon()
	_finish(t)


func _finish(t: int) -> void:
	await get_tree().create_timer(finish_delay).timeout
	if t != ticket:
		return
	# 演完问大脑
	if monster.has_method("get_next_attack_state"):
		change_state(int(monster.get_next_attack_state()))
	else:
		change_state(1)


# =============================================================================
# 召唤：按轮换表垂降；超上限就跳过且不推进轮换
# =============================================================================
func _do_summon() -> void:
	_minions = _minions.filter(func(m: Object) -> bool: return is_instance_valid(m))
	if _minions.size() >= max_alive:
		return
	# 召唤 tell：Summon 帧还没切时 boss 只会播 Idle，全靠这一下震屏告诉玩家「它干了什么」
	if summon_shake > 0.0:
		Game.shake_camera(summon_shake)

	match summon_cycle % 3:
		0:  # 盾蜘蛛：左右各一
			_spawn_descending(SPIDER_SHIELD, left_x)
			_spawn_descending(SPIDER_SHIELD, right_x)
		1:  # 远程蜘蛛：左右各一
			_spawn_descending(SPIDER_RANGED, left_x)
			_spawn_descending(SPIDER_RANGED, right_x)
		2:  # 跳跃蜘蛛：中间一只（最难打）
			_spawn_descending(SPIDER_JUMPER, center_x)
	summon_cycle += 1


# 垂降入场（同 spider_forest 的套路：先设位置再入树，垂降期间整体冻结）
func _spawn_descending(scene: PackedScene, x: float) -> void:
	var root := get_tree().current_scene
	if scene == null or root == null:
		return
	var spider := scene.instantiate() as CharacterBody2D
	if spider == null:
		return
	_minions.append(spider)
	spider.add_to_group("calendula_minion")  # 金盏死亡时随主人一起清场
	spider.z_index = 10
	# 必须先设位置再入树：腿部脚本在 _ready 里以当前位置为锚，晚了会拉出残影
	spider.position = Vector2(x, SPAWN_START_Y)
	root.add_child(spider)
	spider.process_mode = Node.PROCESS_MODE_DISABLED

	var line := Sprite2D.new()
	line.texture = SILK_LINE_TEXTURE
	line.centered = false
	line.z_index = 9
	line.position = Vector2(x - 1.0, SILK_ANCHOR_Y)
	line.scale = Vector2(1.0, 0.125)
	root.add_child(line)

	var tween := create_tween()
	tween.tween_method(_descend_step.bind(spider, line, x), SPAWN_START_Y, LANDING_Y, DESCEND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

	if is_instance_valid(spider):
		spider.process_mode = Node.PROCESS_MODE_INHERIT
		for child in spider.get_children():
			if child.has_method("reset_feet"):
				child.call("reset_feet")
	if is_instance_valid(line):
		var fade := create_tween()
		fade.tween_property(line, "modulate:a", 0.0, 0.5)
		fade.tween_callback(line.queue_free)


func _descend_step(y: float, spider: CharacterBody2D, line: Sprite2D, x: float) -> void:
	if is_instance_valid(spider):
		spider.global_position = Vector2(x, y)
	if is_instance_valid(line):
		# 基础贴图 8px 高，拉伸到锚点→蜘蛛身体的长度（纯色直线，拉伸无失真）
		line.scale = Vector2(1.0, maxf(1.0, y - 5.0 - SILK_ANCHOR_Y) / 8.0)


func _has_animation(anim: StringName) -> bool:
	return is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(anim)
