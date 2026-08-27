# 红丝虫 爬行状态(4 号)：慢慢蠕动一段——七成朝玩家拱过去(留一小段距离)，
# 三成随机换个地方。没有任何伤害，高权重纯粹用来稀释攻击频率、压低难度。
extends BasicState

@export var move_speed: float = 20.0
@export var min_time: float = 1.2
@export var max_time: float = 2.2
@export var stop_distance: float = 22.0    # 朝玩家爬时只拱到这个距离，不贴脸
@export var chance_toward_player: float = 0.7

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

var _rng := RandomNumberGenerator.new()
var _duration: float = 0.0
var _elapsed: float = 0.0
var _target_x: float = 0.0


func _ready() -> void:
	_rng.randomize()


func enter() -> void:
	_elapsed = 0.0
	_duration = _rng.randf_range(min_time, max_time)

	var min_x: float = monster.bound_min_x if "bound_min_x" in monster else 20.0
	var max_x: float = monster.bound_max_x if "bound_max_x" in monster else 140.0
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null

	if player != null and _rng.randf() < chance_toward_player:
		var px := player.global_position.x
		_target_x = px + (stop_distance if monster.global_position.x > px else -stop_distance)
	else:
		_target_x = _rng.randf_range(min_x, max_x)
	_target_x = clampf(_target_x, min_x, max_x)

	if is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Move"):
		ani_2d.play(&"Move")


func process(delta: float) -> void:
	_elapsed += delta
	var dx := _target_x - monster.global_position.x
	# 头朝行进方向(素材原生朝左,由主体统一镜像),别倒着爬
	if absf(dx) > 1.0 and monster.has_method("set_facing"):
		monster.set_facing(-1 if dx < 0.0 else 1)
	var step := move_speed * delta
	monster.global_position.x += clampf(dx, -step, step)
	if _elapsed >= _duration or absf(dx) <= 1.0:
		change_state(1)  # 回 Idle


func exit() -> void:
	pass
