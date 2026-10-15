# 楼梯坡巷的人。坡顶:剧本 #16 海盗船长(在望远镜边上往路那头看)、#15 剑中石。
# 星浪(紫色的狼,一大堆小生物聚成的)在第一层台地上,走近了才聚起来;没有台词(人设没给)。
# 下水道地图和罗盘,等下水道做好再接。
# 角落:第二层的收钱小弟 + 第三层往下射的拿弩的。
#
# 拔剑中石(剧本 #15)分三步,每一步都要回来再握一次剑:
#   1. 握住剑 → 石缝里爬出 6 只锈虫,打完。
#   2. 还是锈死的 → 去修车废料巷找扫地机要油壶(它的尘盒是全城失物招领)。
#   3. 浇上油 → 连按攻击把石头拔下来(力量条,松手会往回掉,12 秒没拔下来就歇口气再来)。
#   拔下来:石头说它磨了剑一百年,跟你走 = 磨刀石(这一夜攻击 +15%);剑留在原地。
extends AlleyPeople

const WORM_SCENE: PackedScene = preload("res://entities/rust_npcs/sword/rust_worm.tscn")
const SWORD_TEX: Texture2D = preload("res://entities/rust_npcs/sword/sword_alone.png")
const STONE_TEX: Texture2D = preload("res://entities/rust_npcs/sword/stone_alone.png")
const WORMS := 6
const PLAZA_LEFT := 562.0
const PLAZA_RIGHT := 716.0
const PULL_PER_PRESS := 0.065
const PULL_DECAY := 0.25   # 一直在往回掉:每秒按 8 下约 4 秒拔下来,按 5 下拔不动
const PULL_TIME := 12.0

var _pirate: Npc
var _sword: Npc
var _wolf: Npc
var _wolf_formed := false
var _stone: Sprite2D = null
var _hud: MiniHud = null
var _worms_left := 0
var _pulling := false
var _pull := 0.0
var _pull_t := 0.0
var _since_press := 0.0
var _milestone := 0


func _setup() -> void:
	_pirate = npc("Pirate")
	_sword = npc("Sword")
	_wolf = npc("Wolf")
	_pirate.on_talk = _talk_pirate
	_sword.on_talk = _talk_sword
	_pirate.face(1.0)
	call_out(_pirate, "……看不见。", 48.0)
	_wolf.visible = false
	if Story.flag("sword_pulled", false):
		_sword.texture = SWORD_TEX


func _process(delta: float) -> void:
	super._process(delta)
	if _pulling:
		_tick_pull(delta)
	if _wolf == null or _wolf_formed or player == null:
		return
	if absf(player.global_position.x - _wolf.global_position.x) < 70.0 \
			and absf(player.global_position.y - _wolf.global_position.y) < 30.0:
		_wolf_formed = true
		_wolf.visible = true
		_wolf.face_x(player.global_position.x)
		_wolf.play_once(&"appear", &"idle")


func _talk_pirate() -> void:
	stop_call_out(_pirate)
	if not Story.flag("pirate_met", false):
		Story.set_flag("pirate_met", true)
		await Dialogue.say(["……看不见。", "喂，你。", "你是从那边来的吗？", "我的船还在吗？"], "海盗船长")
	else:
		await Dialogue.say(["海盗不交过路费。", "……我下去过一次。", "迷路了三天。"], "海盗船长")
	_pirate.face(1.0)


# ------------------------------------------------------------------ 剑中石
func _talk_sword() -> void:
	if Story.flag("sword_pulled", false):
		await Dialogue.say(["……反正也没人拔了。"], "剑")
		return
	if not Story.flag("sword_met", false):
		Story.set_flag("sword_met", true)
		await Dialogue.say(["又来一个。", "拔吧拔吧。", "都拔了一百年了。"], "剑")
	var pick := await Dialogue.ask(["拔吧拔吧。"], ["拔！", "算了"], "剑")
	if pick != 0:
		return
	if not Story.flag("worms_cleared", false):
		await Dialogue.say(["（你握住剑柄——", "石缝里有东西在动。）"])
		_start_worms.call_deferred()
	elif not Story.flag("has_oil", false):
		Story.set_flag("sword_needs_oil", true)
		await Dialogue.say(["（锈得死死的，纹丝不动。）", "（要是有点油就好了。）"])
	else:
		await Dialogue.say(["（你把油浇进石缝里。）"])
		_start_pull.call_deferred()


# 第一步:锈虫
func _start_worms() -> void:
	GangMob.truce = true
	pause_talk(true)
	_hud = MiniHud.open(self)
	_worms_left = WORMS
	_hud.banner("锈虫 × %d" % _worms_left, MiniHud.BAD)
	_sword.bark("……又来了。", 1.5)
	for i in WORMS:
		if not is_inside_tree():
			return
		var w := WORM_SCENE.instantiate() as Node2D
		w.set("min_x", PLAZA_LEFT)
		w.set("max_x", PLAZA_RIGHT)
		w.position = _sword.position + Vector2(-6.0 + (i % 3) * 3.0, 0.0)
		add_child(w)
		w.connect("died", _on_worm_died)
		await wait(0.5)


func _on_worm_died() -> void:
	_worms_left -= 1
	if _worms_left > 0:
		_hud.banner("锈虫 × %d" % _worms_left, MiniHud.BAD)
		return
	Story.set_flag("worms_cleared", true)
	_hud.banner("")
	_hud.big("清干净了", MiniHud.GOOD, 0.8)
	GangMob.truce = false
	pause_talk(false)
	await wait(1.2)
	if _hud != null:
		_hud.close()
		_hud = null
	_sword.bark("……松了一点。", 2.0)


# 第三步:连按拔
func _start_pull() -> void:
	GangMob.truce = true
	pause_talk(true)
	var p := player as CharacterBody2D
	p.global_position = Vector2(_sword.position.x - 13.0, _sword.position.y - 1.0)
	p.velocity = Vector2.ZERO
	if p.has_method("set_facing_direction"):
		p.call("set_facing_direction", 1)
	p.set_lock(true)
	# 剑和石头拆开画,石头才能一下下地动、最后飞出去
	_sword.texture = SWORD_TEX
	_stone = Sprite2D.new()
	_stone.texture = STONE_TEX
	_stone.centered = false
	_stone.position = _stone_home()
	_stone.self_modulate = _sword.sprite.self_modulate
	_stone.z_index = 1
	_sword.add_child(_stone)
	_hud = MiniHud.open(self)
	_hud.banner("拔！")
	_hud.prompt(&"Attack1", "连按")
	_pull = 0.0
	_pull_t = 0.0
	_since_press = 1.0
	_milestone = 0
	_hud.meter(0.0)
	_pulling = true


func _stone_home() -> Vector2:
	# 原图里石头在 (2,0);Npc 把贴图左上角放在 (-宽/2, -高)
	return Vector2(-floorf(SWORD_TEX.get_width() / 2.0) + 2.0, -SWORD_TEX.get_height())


func _tick_pull(delta: float) -> void:
	_pull_t += delta
	_since_press += delta
	_pull = maxf(0.0, _pull - PULL_DECAY * delta)
	if Input.is_action_just_pressed(&"Attack1"):
		_pull = minf(1.0, _pull + PULL_PER_PRESS)
		_since_press = 0.0
		_hud.press_flash()
		_jiggle()
		Game.shake_camera(0.6)
	var col := MiniHud.GOOD if _pull < 0.5 else (MiniHud.GOLD if _pull < 0.85 else MiniHud.BAD)
	_hud.meter(_pull, col)
	# 拔到三分之一、三分之二各"咔"一声,掉渣
	if _milestone < 2 and _pull >= (_milestone + 1) / 3.0:
		_milestone += 1
		_dust(6)
		Game.shake_camera(1.5)
		_sword.bark("咔……", 0.8)
	if _pull >= 1.0:
		_pulling = false
		_pull_done(true)
	elif _pull_t >= PULL_TIME:
		_pulling = false
		_pull_done(false)


func _jiggle() -> void:
	if _stone == null:
		return
	_stone.position = _stone_home() + Vector2(randi_range(-1, 1), randi_range(-1, 0))
	_dust(1)
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(_stone):
			_stone.position = _stone_home())


func _dust(n: int) -> void:
	for i in n:
		var r := ColorRect.new()
		r.size = Vector2(1, 1)
		r.color = Color(0.62, 0.6, 0.55) if i % 2 == 0 else Color(0.5, 0.32, 0.2)
		r.position = _sword.position + Vector2(randf_range(-8.0, 2.0), -3.0)
		r.z_index = 12
		add_child(r)
		var tw := r.create_tween()
		tw.tween_property(r, "position", r.position + Vector2(randf_range(-6.0, 6.0), randf_range(-7.0, -3.0)), 0.25)
		tw.tween_property(r, "position:y", _sword.position.y - 1.0, 0.2)
		tw.tween_callback(r.queue_free)


func _pull_done(ok: bool) -> void:
	_hud.clear_prompt()
	_hud.clear_meter()
	var p := player as CharacterBody2D
	if not ok:
		_hud.big("拔不动……", MiniHud.TEXT, 0.9)
		await wait(1.0)
		_sword.texture = preload("res://entities/rust_npcs/sword_stone.png")
		if is_instance_valid(_stone):
			_stone.queue_free()
		_end_pull(p)
		_sword.bark("歇口气再来。", 2.0)
		return
	# 石头飞出去,落在剑旁边
	Game.flash(0.15, Color(1, 0.96, 0.85))
	Game.shake_camera(3.0)
	_dust(10)
	_hud.big("拔下来了！", MiniHud.GOLD, 0.9)
	var land := _stone.position + Vector2(16, 0)
	var tw := create_tween()
	tw.tween_property(_stone, "position", _stone.position + Vector2(8, -14), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_stone, "position", land, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: Game.shake_camera(1.0))
	await tw.finished
	await wait(0.6)
	Story.set_flag("sword_pulled", true)
	_end_pull(p)
	Talk.begin()
	await Dialogue.talk([
		["石头", "……终于。"],
		["剑", "我自由了！我是传说！"],
		["石头", "你不是。"],
		["石头", "你是把普通的剑。"],
		["石头", "我磨了你一百年。"],
		["剑", "…………"],
		["石头", "带我走吧。"],
	])
	Story.set_flag("whetstone", true)
	if is_instance_valid(_stone):
		_stone.queue_free()
	await Dialogue.say_gain("拿到了磨刀石 {icon}", STONE_TEX, "这一夜，攻击力提高。")
	var pick := await Dialogue.ask(["……那我呢？"], ["你也一起走", "你留在这儿"], "剑")
	if pick == 0:
		await Dialogue.say(["（捡不起来。）"])
		await Dialogue.say(["……"], "剑")
	else:
		await Dialogue.say(["……好吧。", "反正也没人拔了。"], "剑")
	Talk.end()


func _end_pull(p: CharacterBody2D) -> void:
	if _hud != null:
		_hud.close()
		_hud = null
	GangMob.truce = false
	pause_talk(false)
	if is_instance_valid(p):
		p.set_lock(false)


func _exit_tree() -> void:
	GangMob.truce = false
