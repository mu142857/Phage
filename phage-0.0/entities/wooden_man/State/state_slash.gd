# 木头人 刀哥冲砍(6 号)：没了线的刀哥掉到地上 → 冲向主角 → 到距离就播 Slash，
# 只在 hit_frame_start..hit_frame_end(0 起数)开刀判定(SlashHitbox) → 连砍 slash_count 刀
# → 告诉木偶师打完了 → Vanish 化开。
# 冲刺有刹车：追到 reach 距离内就停，不撞进主角身上(见 attack-lunge 规范)。
extends BasicState

@export var slash_count: int = 2
@export var damage: int = 12
@export var fall_gravity: float = 900.0
@export var dash_speed: float = 120.0
@export var reach: float = 26.0            # 刀光够得着的距离(冲到这就出刀)
@export var dash_timeout: float = 1.6      # 追不上也得出刀
@export var hit_frame_start: int = 4       # 刀光帧(0 起数)
@export var hit_frame_end: int = 6
@export var slash_fallback_time: float = 1.2  # 没有 Slash 动画时一刀的时长
@export var gap_time: float = 0.35         # 两刀之间的停顿
@export var hit_shake: float = 2.0

@onready var monster: CharacterBody2D = $"../.."

var _ticket: int = 0
var _phase: int = 0          # 0 掉地 / 1 冲刺 / 2 出刀 / 3 停顿
var _dash_time: float = 0.0
var _hit_done: bool = false


func enter() -> void:
	_ticket += 1
	_phase = 0
	_hit_done = false
	monster.velocity = Vector2.ZERO
	monster.slash_hitbox.monitoring = false
	monster.play_anim(&"BladeIdle")
	_run(_ticket)


func process(delta: float) -> void:
	match _phase:
		0:  # 掉到地上
			monster.velocity.y += fall_gravity * delta
			monster.global_position.y += monster.velocity.y * delta
			if monster.global_position.y >= monster.floor_y:
				monster.global_position.y = monster.floor_y
				monster.velocity = Vector2.ZERO
				Game.shake_camera(1.5)
				_phase = 3
		1:  # 冲向主角(刹车：够得着就停)
			_dash_time += delta
			var player: Node2D = monster.get_player()
			if player == null:
				_phase = 2
				return
			var dx: float = player.global_position.x - monster.global_position.x
			monster.set_facing(1 if dx >= 0.0 else -1)
			if absf(dx) <= reach or _dash_time >= dash_timeout:
				_phase = 2
				return
			var step := dash_speed * delta
			monster.global_position.x += signf(dx) * minf(step, absf(dx) - reach)
			monster.global_position.x = clampf(monster.global_position.x, monster.bound_min_x, monster.bound_max_x)
		2:  # 出刀中：只在刀光帧开判定
			var frame: int = monster.sprite.frame if monster.sprite.animation == &"Slash" else hit_frame_start
			var active := frame >= hit_frame_start and frame <= hit_frame_end
			monster.slash_hitbox.monitoring = active
			if active and not _hit_done:
				_try_hit()


func exit() -> void:
	_ticket += 1
	monster.slash_hitbox.monitoring = false


func _run(t: int) -> void:
	# 等掉地
	while _phase == 0:
		await get_tree().process_frame
		if t != _ticket or not is_instance_valid(monster):
			return
	for i in slash_count:
		# 冲
		_phase = 1
		_dash_time = 0.0
		monster.play_anim(&"BladeMove" if monster.has_anim(&"BladeMove") else &"BladeIdle")
		while _phase == 1:
			await get_tree().process_frame
			if t != _ticket or not is_instance_valid(monster):
				return
		# 砍
		_hit_done = false
		_phase = 2
		if monster.has_anim(&"Slash"):
			monster.play_anim(&"Slash")
			await monster.sprite.animation_finished
		else:
			await get_tree().create_timer(slash_fallback_time).timeout
		if t != _ticket or not is_instance_valid(monster):
			return
		monster.slash_hitbox.monitoring = false
		# 歇
		_phase = 3
		monster.play_anim(&"BladeIdle")
		await get_tree().create_timer(gap_time).timeout
		if t != _ticket or not is_instance_valid(monster):
			return
	monster.on_attack_finished()
	change_state(monster.STATE_VANISH)


func _try_hit() -> void:
	for body in monster.slash_hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_hit_done = true
		if hit_shake > 0.0:
			Game.shake_camera(hit_shake)
		break
