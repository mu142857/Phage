# 蓝史莱姆陪练(剧本 #3):三回合。
#   他出拳前王冠先歪一下(整个人往后仰,头顶冒"!")= 前摇 → 往前猛冲一拳 → 冲完晕一下(冒小星星)= 空档。
#   空档里砍他一刀就赢这一回合;没到空档就砍,会被他挡开("没打着!")。
#   被他打中 = 被推开、定一下、掉一个血点(不扣真血不破盾,陪练而已)。三个血点掉光 = 输。
#   第 1 回合单拳;第 2 回合连出两拳;第 3 回合他喊两个朋友(现有的小史莱姆换成蓝色),朋友蹦过来撞人,也能砍掉。
# 回合之间锁一下主角、大字"第二回合!"。
class_name SlimeSpar
extends Node2D

signal finished(won: bool)

const FRIEND_TEX: Texture2D = preload("res://entities/slime/mini_silme.png")
const LEFT := 168.0
const RIGHT := 328.0
const LIVES := 3
const WINDUP := [0.55, 0.42, 0.38]
const OPEN := [1.2, 1.0, 0.9]
const DASH := 34.0

var slime: Npc
var player: CharacterBody2D
var round_no := 1
var lives := LIVES

var _hud: MiniHud
var _hurt: Area2D
var _state := "idle"   # idle / approach / windup / dash / open / between / done
var _t := 0.0
var _punches_left := 0
var _dash_from := 0.0
var _dash_dir := 1.0
var _hit_this_dash := false
var _cool := 0.0
var _stars: Array = []
var _friends: Array = []
var _invuln := 0.0   # 挨了一下以后 1 秒内不再挨(身上一闪一闪),免得被连着打


func setup(s: Npc, p: CharacterBody2D) -> void:
	slime = s
	player = p


func _ready() -> void:
	GangMob.truce = true
	_hud = MiniHud.open(self)
	# 打他的地方:和主角的刀(打 layer 4 的东西)对得上
	_hurt = Area2D.new()
	_hurt.collision_layer = 4
	_hurt.collision_mask = 0
	_hurt.add_to_group("monster")
	_hurt.set_script(preload("res://levels/rust_city/boiler_alley/spar_hurtbox.gd"))
	_hurt.set("on_hit", _on_slime_hit)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	_hurt.add_child(shape)
	slime.add_child(_hurt)
	# 场地两头地上画两道粉笔线,主角出不去(像拳台的绳子)
	for x in [LEFT - 9.0, RIGHT + 9.0]:
		for k in 3:
			var r := ColorRect.new()
			r.color = Color(0.92, 0.9, 0.84)
			r.size = Vector2(1, 2)
			r.position = Vector2(x, slime.position.y - 2.0 - k * 4.0)
			r.z_index = 11
			add_child(r)
	for i in 2:
		var star := ColorRect.new()
		star.size = Vector2(1, 1)
		star.color = MiniHud.GOLD
		star.visible = false
		star.z_index = 30
		slime.add_child(star)
		_stars.append(star)
	_start_round.call_deferred()


func _start_round() -> void:
	_state = "between"
	player.set_lock(true)
	_hud.banner("第 %d 回合" % round_no)
	_hud.pips(lives, LIVES)
	_hud.big(["第一回合", "第二回合", "最后一回合"][round_no - 1], MiniHud.TEXT, 0.8)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	if round_no == 3:
		slime.bark("兄弟们！", 1.0)
		await get_tree().create_timer(0.6).timeout
		_spawn_friends()
	_hud.big("开始！", MiniHud.GOLD, 0.4)
	player.set_lock(false)
	_state = "approach"
	_t = 0.0
	_cool = 0.6


func _physics_process(delta: float) -> void:
	# 拳台:主角出不了两道粉笔线
	if _state != "done":
		var px0 := player.global_position.x
		if px0 < LEFT - 8.0 or px0 > RIGHT + 8.0:
			player.global_position.x = clampf(px0, LEFT - 8.0, RIGHT + 8.0)
			player.velocity.x = 0.0
	_tick_invuln(delta)
	if _state == "between" or _state == "done":
		return
	_t += delta
	_cool -= delta
	var px := player.global_position.x
	var dx := px - slime.position.x
	match _state:
		"approach":
			slime.face_x(px)
			# 一跳一跳地凑过去,保持一拳的距离
			if absf(dx) > DASH + 4.0:
				slime.position.x = clampf(slime.position.x + signf(dx) * 26.0 * delta, LEFT, RIGHT)
				slime.sprite.position.y = -roundf(absf(sin(_t * 9.0)) * 2.0)
			elif _cool <= 0.0:
				_punches_left = 2 if round_no >= 2 else 1
				_windup()
		"windup":
			# 王冠先歪一下:整个人往后仰,越来越歪
			var k := clampf(_t / WINDUP[round_no - 1], 0.0, 1.0)
			slime.sprite.rotation = -_dash_dir * 0.35 * k
			if _t >= WINDUP[round_no - 1]:
				_dash()
		"dash":
			var k2 := clampf(_t / 0.18, 0.0, 1.0)
			slime.position.x = clampf(_dash_from + _dash_dir * DASH * k2, LEFT, RIGHT)
			slime.sprite.rotation = _dash_dir * 0.25
			slime.sprite.scale = Vector2(1.3, 0.8) if k2 < 1.0 else Vector2.ONE
			if not _hit_this_dash and absf(player.global_position.x - slime.position.x) < 9.0 \
					and absf(player.global_position.y - slime.position.y) < 10.0:
				_hit_this_dash = true
				_player_hit(_dash_dir)
			if k2 >= 1.0:
				slime.sprite.rotation = 0.0
				slime.sprite.scale = Vector2.ONE
				_punches_left -= 1
				if _punches_left > 0:
					_windup(0.5)
				else:
					_state = "open"
					_t = 0.0
		"open":
			# 晕一下:身子晃,头顶两颗星星转
			slime.sprite.rotation = sin(_t * 14.0) * 0.12
			for i in _stars.size():
				var a := _t * 8.0 + i * PI
				var st: ColorRect = _stars[i]
				st.visible = true
				st.position = Vector2(roundf(cos(a) * 4.0), roundf(-slime.height() - 3.0 + sin(a) * 1.5))
			if _t >= OPEN[round_no - 1]:
				_end_open()
	_tick_friends(delta)


func _windup(scale_time := 1.0) -> void:
	_state = "windup"
	_t = (1.0 - scale_time) * WINDUP[round_no - 1]
	_dash_dir = signf(player.global_position.x - slime.position.x)
	if _dash_dir == 0.0:
		_dash_dir = 1.0
	slime.face(_dash_dir)
	slime.bark("！", 0.5)


func _dash() -> void:
	_state = "dash"
	_t = 0.0
	_dash_from = slime.position.x
	_hit_this_dash = false
	Game.shake_camera(0.8)


func _end_open() -> void:
	slime.sprite.rotation = 0.0
	for st in _stars:
		st.visible = false
	_state = "approach"
	_t = 0.0
	_cool = 0.5


func _on_slime_hit() -> void:
	if _state == "open":
		_round_won()
	elif _state != "between" and _state != "done":
		# 没到空档:挡开
		slime.bark("没打着！", 0.7)
		slime.hop(2.0, 0.15)


func _tick_invuln(delta: float) -> void:
	if _invuln <= 0.0:
		return
	_invuln -= delta
	var spr = player.get("sprite")
	if spr is CanvasItem:
		(spr as CanvasItem).self_modulate.a = 1.0 if _invuln <= 0.0 or int(_invuln * 16.0) % 2 == 0 else 0.35


func _player_hit(dir: float) -> void:
	if _invuln > 0.0:
		return
	_invuln = 1.1
	lives -= 1
	_hud.pips(lives, LIVES)
	MiniHud.knock(player, dir, 18.0, 0.5)
	slime.bark("嘿嘿！", 0.8)
	if lives <= 0:
		_finish(false)


func _round_won() -> void:
	_state = "between"
	Game.flash(0.1, Color(1, 1, 1))
	Game.shake_camera(2.0)
	slime.sprite.rotation = 0.0
	for st in _stars:
		st.visible = false
	slime.hop(4.0, 0.3)
	MiniHud.float_text(get_parent(), slime.global_position + Vector2(0, -16), "啪！", MiniHud.TEXT)
	_clear_friends()
	if round_no >= 3:
		_finish(true)
		return
	round_no += 1
	# 两个人拉开站好再开下一回合
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	_start_round()


# ------------------------------------------------------------------ 第三回合的朋友
func _spawn_friends() -> void:
	for side in [-1.0, 1.0]:
		var f := Node2D.new()
		f.z_index = 10
		var spr := Sprite2D.new()
		spr.texture = FRIEND_TEX
		spr.modulate = Color(0.45, 0.72, 1.0)
		spr.position = Vector2(0, -3)
		f.add_child(spr)
		var box := Area2D.new()
		box.collision_layer = 4
		box.collision_mask = 0
		box.add_to_group("monster")
		box.set_script(preload("res://levels/rust_city/boiler_alley/spar_hurtbox.gd"))
		box.set("on_hit", _on_friend_hit.bind(f))
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 6)
		shape.shape = rect
		shape.position = Vector2(0, -3)
		box.add_child(shape)
		f.add_child(box)
		f.position = Vector2(clampf(player.global_position.x + side * 46.0, LEFT, RIGHT), slime.position.y - 40.0)
		f.set_meta("vy", 0.0)
		f.set_meta("ground", slime.position.y)
		f.set_meta("cool", 0.8 + randf() * 0.6)
		get_parent().add_child(f)
		_friends.append(f)


func _tick_friends(delta: float) -> void:
	for f: Node2D in _friends.duplicate():
		if not is_instance_valid(f):
			_friends.erase(f)
			continue
		var vy: float = f.get_meta("vy") + 520.0 * delta
		var ground: float = f.get_meta("ground")
		f.position.y += vy * delta
		var cool: float = f.get_meta("cool") - delta
		if f.position.y >= ground:
			f.position.y = ground
			vy = 0.0
			if cool <= 0.0:
				# 朝主角蹦一下
				vy = -150.0
				cool = 1.4 + randf() * 0.6
				f.set_meta("dir", signf(player.global_position.x - f.position.x))
		else:
			f.position.x = clampf(f.position.x + float(f.get_meta("dir", 0.0)) * 40.0 * delta, LEFT, RIGHT)
		f.set_meta("vy", vy)
		f.set_meta("cool", cool)
		if absf(player.global_position.x - f.position.x) < 6.0 and absf(player.global_position.y - f.position.y) < 8.0:
			_player_hit(signf(player.global_position.x - f.position.x))
		if _state == "done":
			return


func _on_friend_hit(f: Node2D) -> void:
	if not is_instance_valid(f):
		return
	MiniHud.float_text(get_parent(), f.global_position + Vector2(0, -6), "噗", MiniHud.TEXT)
	_friends.erase(f)
	f.queue_free()


func _clear_friends() -> void:
	for f in _friends:
		if is_instance_valid(f):
			f.queue_free()
	_friends.clear()


# ------------------------------------------------------------------ 收尾
func _finish(won: bool) -> void:
	_state = "done"
	_invuln = 0.0
	var spr = player.get("sprite")
	if spr is CanvasItem:
		(spr as CanvasItem).self_modulate.a = 1.0
	_clear_friends()
	slime.sprite.rotation = 0.0
	slime.sprite.scale = Vector2.ONE
	for st in _stars:
		st.visible = false
	player.set_lock(false)
	_hud.big("赢了！" if won else "输了……", MiniHud.GOOD if won else MiniHud.BAD, 1.0)
	await get_tree().create_timer(1.3).timeout
	if is_instance_valid(_hurt):
		_hurt.queue_free()
	for st in _stars:
		st.queue_free()
	_hud.close()
	GangMob.truce = false
	finished.emit(won)
	queue_free()


func _exit_tree() -> void:
	GangMob.truce = false
