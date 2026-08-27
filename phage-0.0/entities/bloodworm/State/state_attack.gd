# 红丝虫 吐弹状态(5 号)：面向玩家播 Attack，第 shoot_frame 帧(0 起数，默认 5)
# 从 Muzzle 一口气吐两发自己的子弹(bloodworm_spit，从喷吐触手复制后单独调参)——
# 一发往左、一发往右，不瞄准，低抛物线沉到地面撞地爆。
# 弹频不在这里压，靠决策里 Idle/Move 的高权重。
extends BasicState

const BULLET_SCENE: PackedScene = preload("res://entities/bloodworm/bloodworm_spit.tscn")

@export var shoot_frame: int = 5    # 0 起数
@export var timeout: float = 1.4    # 兜底：动画缺帧/卡住也能回 Idle

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var muzzle: Node2D = get_node_or_null("../../Muzzle") as Node2D

var _shot: bool = false
var _elapsed: float = 0.0


func enter() -> void:
	_shot = false
	_elapsed = 0.0
	monster.velocity = Vector2.ZERO
	if monster.has_method("face_player"):
		monster.face_player()
	if is_instance_valid(ani_2d) and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Attack"):
		ani_2d.play(&"Attack")
	else:
		change_state(1)


func process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(ani_2d) and ani_2d.animation == &"Attack":
		if not _shot and ani_2d.frame >= shoot_frame:
			_shot = true
			_shoot()
		if not ani_2d.is_playing():
			change_state(1)  # 回 Idle
			return
	if _elapsed >= timeout:
		change_state(1)


func exit() -> void:
	pass


# 左右各一发，不瞄准玩家
func _shoot() -> void:
	if BULLET_SCENE == null or get_tree().current_scene == null:
		return
	var start: Vector2 = muzzle.global_position if is_instance_valid(muzzle) \
			else monster.global_position + Vector2(0, -20)
	for dir in [-1.0, 1.0]:
		var bullet := BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(bullet)
		if bullet.has_method("setup"):
			bullet.call("setup", start, dir)
