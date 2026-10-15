# 刀翼兵(精英):细腰长腿、尖嘴盔,背上五片钢刀翼。不落地,离地 hover 格悬着飘。
# 看见目标:飞到它斜上方 → 展翅往上一提憋一下(Rise)→ 斜着俯冲下来(Dive,一路都有判定)
# → 冲到底收翅喘一口(Recover,这时候离地近、最好打)→ 再飞回悬停高度。
extends BureauMob

@export var hover: float = 18.0
@export var dive_speed: float = 170.0
@export var rise_time: float = 0.45
@export var rise_speed: float = 24.0
@export var standoff: float = 46.0
@export var recover_time: float = 0.8

enum W { HOVER, RISE, DIVE, RECOVER }

var _w: W = W.HOVER
var _wt := 0.0
var _dive_dir := Vector2.DOWN


func _ready() -> void:
	super._ready()
	gravity = 0.0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	_foe_hold = maxf(0.0, _foe_hold - delta)
	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity = Vector2(_knock_vx, 0.0)
		move_and_slide()
		return
	var ground_y := _ground_below()
	var f := foe()
	_wt += delta
	match _w:
		W.HOVER:
			_hover(f, ground_y)
		W.RISE:
			velocity = Vector2(0.0, -rise_speed)
			if _wt >= rise_time:
				_dive(f)
		W.DIVE:
			velocity = _dive_dir * dive_speed
			try_hit()
			if _wt > 0.7 or global_position.y >= ground_y - 1.0 or get_slide_collision_count() > 0:
				_w = W.RECOVER
				_wt = 0.0
				play_once(&"Recover")
		W.RECOVER:
			velocity *= 0.8
			if _wt >= recover_time:
				_w = W.HOVER
				cooldown = attack_cooldown
	move_and_slide()


func _hover(f: Node2D, ground_y: float) -> void:
	var target := Vector2(post_x(), ground_y - hover)
	if f != null:
		var dx := f.global_position.x - global_position.x
		var side := -signf(dx) if dx != 0.0 else -facing
		target = Vector2(f.global_position.x + side * standoff, ground_y - hover)
		face(signf(dx))
		if not _spotted:
			_spotted = true
			_on_spotted()
		if cooldown <= 0.0 and absf(dx) < standoff + 18.0 and absf(dx) > 18.0 and state == S.ENGAGE:
			_w = W.RISE
			_wt = 0.0
			play_once(&"Rise")
			return
	else:
		_salute_tick()
	var to := target - global_position
	velocity = to * 3.0
	if velocity.length() > move_speed:
		velocity = velocity.normalized() * move_speed
	if state == S.ENGAGE:
		if f == null and absf(to.x) < 3.0:
			face(rest_facing())
		play(&"Fly" if absf(velocity.x) > 10.0 else &"Idle")


func _dive(f: Node2D) -> void:
	_w = W.DIVE
	_wt = 0.0
	_hit_done = false
	var aim := (f.global_position + Vector2(0, -3)) if f != null else global_position + Vector2(facing * 30.0, hover)
	_dive_dir = (aim - global_position).normalized()
	if _dive_dir.y < 0.35:
		_dive_dir = Vector2(signf(_dive_dir.x) if _dive_dir.x != 0.0 else facing, 0.6).normalized()
	face(signf(_dive_dir.x))
	shout("attack", 0.5)
	play(&"Dive")


func _ground_below() -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, 240), 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return global_position.y + hover
	return (hit.position as Vector2).y


func _lines() -> Dictionary:
	return {
		"spot": ["目标确认。", "……"],
		"attack": ["俯冲。", "——！"],
		"foe_spot": ["黑衣服的。", "清理。"],
	}
