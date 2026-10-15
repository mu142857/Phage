# 盾卫:矮壮、桶盔、一人高的铜塔盾。正面砍上去"当"一声没用,头顶劈下来/绕到背后才行;转身慢。
# 隔着盾从上沿捅长矛(Attack 第 4~6 帧,够得远);贴脸了用盾一顶(Bash)把你推开,推开不扣盾。
extends BureauMob

const CLANG_SPARKS: PackedScene = preload("res://entities/gang/shield/clang_sparks.tscn")

@export var turn_delay: float = 0.9
@export var overhead_height: float = 16.0
@export var bash_range: float = 16.0
@export var bash_push: float = 22.0

var _turn_timer := 0.0
var _bashing := false


## 盾卫转身慢:目标跑到背后,要愣一会儿才转过来
func _engage(delta: float) -> void:
	var f := foe()
	if f != null and (squad == null or _broken):
		var want := signf(f.global_position.x - global_position.x)
		if want != 0.0 and want != facing:
			_turn_timer += delta
			velocity.x = 0.0
			play(&"Idle")
			if _turn_timer >= turn_delay:
				_turn_timer = 0.0
				face(want)
			return
		_turn_timer = 0.0
	if f != null and cooldown <= 0.0 and absf(f.global_position.x - global_position.x) <= bash_range \
			and (f.global_position.x - global_position.x) * facing > 0.0:
		_bash()
		return
	super._engage(delta)


func _can_strike(f: Node2D) -> bool:
	return (f.global_position.x - global_position.x) * facing > -4.0


func _bash() -> void:
	_bashing = true
	start_attack(&"Bash")


func _end_attack() -> void:
	_bashing = false
	super._end_attack()


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation == &"Bash":
		if sprite.frame in [4, 5]:
			_bash_hit()
		return
	if sprite.animation == attack_anim and sprite.frame in hit_frames:
		try_hit()


## 盾顶:主角被推开(不扣盾),对面的人挨一下
func _bash_hit() -> void:
	if _hit_done or attack_check == null:
		return
	for body in attack_check.get_overlapping_bodies():
		if body == null or body == self:
			continue
		if body.is_in_group("player") and hostile_to_player():
			_hit_done = true
			MiniHud.knock(body as Node2D, facing, bash_push, 0.3)
			shout("bash", 0.8)
		elif is_enemy(body):
			_hit_done = true
			(body as GangMob).take_hit(40, global_position.x, self)


func _blocks(_value: int) -> bool:
	var p := player()
	if p == null:
		return false
	var in_front := (p.global_position.x - global_position.x) * facing > 0.0
	var from_above := global_position.y - p.global_position.y > overhead_height
	if not in_front or from_above:
		return false
	_clang()
	if state != S.ATTACK:
		state = S.CUSTOM
		play_once(&"Block", func() -> void: state = S.ENGAGE)
	return true


func _blocks_from(from_x: float) -> bool:
	if (from_x - global_position.x) * facing <= 0.0:
		return false
	_clang()
	return true


func _clang() -> void:
	shout("block", 0.6)
	var scene := get_tree().current_scene
	if scene != null:
		var fx := CLANG_SPARKS.instantiate() as Node2D
		scene.add_child(fx)
		fx.global_position = global_position + Vector2(facing * 12.0, -14.0)
	Game.shake_camera(1.5)


func _lines() -> Dictionary:
	return {
		"attack": ["刺。", "退后。"],
		"block": ["无效。", "当。", "请排队。"],
		"bash": ["请排队。", "退后。", "不许插队。"],
	}
