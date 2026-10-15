# 刀仔:矮、快。保持半个身位外绕着你转,刀光一闪(第 2~3 帧,前摇)就整个人冲过来划一刀
# (第 4~6 帧冲刺+判定),刹住以后往后蹦开。打完一刀要歇一会儿,这时候追上去砍。
extends GangMob

@export var dash_speed: float = 170.0
@export var keep_distance: float = 34.0
@export var strike_distance: float = 56.0
@export var hop_speed: Vector2 = Vector2(80.0, -150.0)

var _hopping := false


func _engage(_delta: float) -> void:
	var p := player()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	var dist := absf(dx)
	face(signf(dx))
	if cooldown <= 0.0 and dist <= strike_distance and dist >= 14.0:
		start_attack()
		return
	if dist > strike_distance - 6.0:
		walk(facing, move_speed, &"Run")
	elif dist < keep_distance - 10.0 and floor_ahead(-facing):
		_hop_back()
	else:
		velocity.x = _separation()
		play(&"Idle")


func _attack_tick(_delta: float) -> void:
	var f := sprite.frame if sprite.animation == attack_anim else -1
	if f >= 4 and f <= 6:
		velocity.x = facing * dash_speed if floor_ahead(facing) else 0.0
		try_hit()
	elif f == 7 or f == 8:
		velocity.x = facing * dash_speed * 0.25 if floor_ahead(facing) else 0.0
	else:
		velocity.x = 0.0


func _end_attack() -> void:
	cooldown = attack_cooldown
	_hop_back()


func _hop_back() -> void:
	if not is_on_floor():
		state = S.ENGAGE
		return
	state = S.CUSTOM
	_hopping = false
	play_once(&"Hop", func() -> void: state = S.ENGAGE)


func _custom_tick(_delta: float) -> void:
	if sprite.animation == &"Hop":
		if sprite.frame == 1 and not _hopping and is_on_floor():
			_hopping = true
			velocity.y = hop_speed.y
		if _hopping and not is_on_floor():
			velocity.x = -facing * hop_speed.x if floor_ahead(-facing) else 0.0
		elif is_on_floor():
			velocity.x = 0.0
	else:
		velocity.x = 0.0
