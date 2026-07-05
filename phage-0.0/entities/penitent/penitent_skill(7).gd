# =============================================================================
# Skill(7)  —  镰刀弹幕：SkillStart → SkillLoop(逐个召唤镰刀) → SkillEnd → 传送冲刺
# =============================================================================
# 旧邪帽把这拆成 SkillStart / Skill / SkillEnd 三个状态，新版合并到一个状态里，
# 用动画阶段驱动。按血量阶段决定召唤几把镰刀（3/5/7/9），从预设组合里随机抽一组，
# 逐把召唤（大/中/小）。放完 → 传送到场地边缘 → Prominence(升起) → SprintAttack。
# =============================================================================
extends BasicState

const BIG_SICKLE: PackedScene = preload("res://entities/penitent/big_sickle.tscn")
const MID_SICKLE: PackedScene = preload("res://entities/penitent/mid_sickle.tscn")
const SMALL_SICKLE: PackedScene = preload("res://entities/penitent/small_sickle.tscn")

# 各血量阶段（镰刀数）对应的可选组合，随机抽一组按顺序放
const SKILL_GROUPS := {
	3: [["small", "small", "small"], ["mid", "mid", "mid"],
		["big", "small", "small"], ["big", "mid", "mid"], ["big", "big", "big"]],
	5: [["big", "mid", "mid", "mid", "mid"], ["big", "small", "small", "small", "small"],
		["big", "mid", "mid", "mid", "big"], ["big", "small", "mid", "mid", "small"]],
	7: [["big", "mid", "mid", "mid", "mid", "mid", "mid"],
		["big", "small", "mid", "small", "mid", "small", "mid"],
		["big", "big", "mid", "mid", "mid", "mid", "mid"]],
	9: [["big", "mid", "mid", "mid", "mid", "mid", "mid", "mid", "mid"],
		["big", "small", "mid", "small", "mid", "small", "mid", "small", "mid"],
		["big", "big", "big", "small", "small", "small", "mid", "mid", "mid"]],
}

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var is_active: bool = false
var _chosen_group: Array = []


func enter() -> void:
	is_active = true
	monster.velocity = Vector2.ZERO
	monster.show()
	monster.face_player()
	# 按血量阶段决定镰刀数并抽一组
	var count: int = [0, 3, 5, 7, 9][monster.health_tier()]
	var groups: Array = SKILL_GROUPS[count]
	_chosen_group = groups[monster.rng.randi() % groups.size()]
	if is_instance_valid(ani_2d):
		ani_2d.play(&"SkillStart")


func process(_delta: float) -> void:
	pass


func exit() -> void:
	is_active = false


func _on_animated_sprite_2d_animation_finished() -> void:
	if not is_instance_valid(ani_2d):
		return
	if ani_2d.animation == &"SkillStart":
		ani_2d.play(&"SkillLoop")
		_summon_loop()
	elif ani_2d.animation == &"SkillEnd":
		_go_sprint()


# 逐把召唤，每把之间等一段冷却
func _summon_loop() -> void:
	for skill_name in _chosen_group:
		if not is_active:
			return
		_spawn_sickle(skill_name)
		await get_tree().create_timer(_cooldown()).timeout
		if not is_active:
			return
	if is_instance_valid(ani_2d):
		ani_2d.play(&"SkillEnd")


func _cooldown() -> float:
	# 血越多冷却越长（0.42 ~ 0.72s）
	return 0.42 + float(monster.health) / float(monster.max_health) * 0.30


func _spawn_sickle(skill_name: String) -> void:
	match skill_name:
		"big":
			_add_sickle(BIG_SICKLE, 0)
		"mid":
			_add_sickle(MID_SICKLE, 0)
		"small":
			# 小镰刀成对：一左一右
			_add_sickle(SMALL_SICKLE, 1)
			_add_sickle(SMALL_SICKLE, -1)


func _add_sickle(scene: PackedScene, dir: int) -> void:
	if scene == null:
		return
	var sce := scene.instantiate()
	if sce is Node2D:
		(sce as Node2D).global_position = monster.global_position
	if dir != 0 and "_direction" in sce:
		sce._direction = dir
	monster.spawn_in_world(sce)


# 弹幕放完 → 传送到某一侧边缘，朝场内 → Prominence
func _go_sprint() -> void:
	monster.hide()
	if monster.rng.randi_range(0, 1) == 0:
		monster.global_position.x = monster.bound_min_x + monster.edge_margin
		monster.direct = 1     # 从左往右冲
	else:
		monster.global_position.x = monster.bound_max_x - monster.edge_margin
		monster.direct = -1    # 从右往左冲
	monster.global_position.y = monster.floor_y
	monster.apply_facing()
	change_state(monster.STATE_PROMINENCE)
