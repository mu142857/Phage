# 竞技场街的人(路障那头,第三幕):剧本 3-2 肌肉哥。
# 举重:地上一根杠铃,分三下举 —— 拉起来、上胸、举过头。
#   每一下底下有根力量条,指针来回扫,扫到亮的那段按攻击 = 举上去一节;按早了按晚了 = 杠铃往下掉一节。
#   一节比一节快、亮的那段一节比一节短。失手三次 = 没举起来,歇会儿再来。
# 角落:黑着的街尾,碎砖堆边上蹲着一个大块头(举重的时候停战)。
extends AlleyPeople

const BARBELL_TEX: Texture2D = preload("res://entities/rust_npcs/gym/barbell.png")
# 每一节:[甜区宽, 指针速度(一来一回/秒)]
const STAGES := [[0.30, 0.55], [0.22, 0.75], [0.15, 0.95]]
# 杠铃在每一节的高度(离脚底)
const HEIGHTS := [1.0, 5.0, 8.0, 13.0]
const MISSES := 3

var _muscle: Npc
var _hud: MiniHud = null
var _bar: Sprite2D = null
var _lifting := false
var _stage := 0
var _cursor := 0.0
var _dir := 1.0
var _zone_a := 0.0
var _misses := 0
var _lock_input := 0.0


func _setup() -> void:
	_muscle = npc("Muscle")
	_muscle.on_talk = _talk_muscle
	call_out(_muscle, "兄弟！", 56.0, "", "你的肌肉在哭泣！")


func _talk_muscle() -> void:
	stop_call_out(_muscle)
	var pick := await Dialogue.ask(["兄弟！", "你的肌肉在哭泣！"], ["你在发光", "比比力气", "……"], "肌肉哥")
	if pick == 0:
		await Dialogue.say(["那是汗。"], "肌肉哥")
	elif pick == 1:
		await Dialogue.say(["举起来！", "看准了再使劲。"], "肌肉哥")
		_start_lift.call_deferred()


func _start_lift() -> void:
	GangMob.truce = true
	pause_talk(true)
	var p := player as CharacterBody2D
	p.global_position = Vector2(_muscle.position.x - 22.0, _muscle.position.y - 1.0)
	p.velocity = Vector2.ZERO
	if p.has_method("set_facing_direction"):
		p.call("set_facing_direction", 1)
	p.set_lock(true)
	_bar = Sprite2D.new()
	_bar.texture = BARBELL_TEX
	_bar.z_index = 11
	add_child(_bar)
	_hud = MiniHud.open(self)
	_hud.prompt(&"Attack1", "扫到亮的那段")
	_stage = 0
	_misses = 0
	_new_stage()
	_lifting = true


func _new_stage() -> void:
	var w: float = STAGES[_stage][0]
	_zone_a = randf_range(0.35, 0.95 - w)
	_cursor = 0.0
	_dir = 1.0
	_hud.banner(["拉起来", "上胸", "举过头"][_stage] + "  失手 %d/%d" % [_misses, MISSES])
	_place_bar()


func _place_bar() -> void:
	var p := player as Node2D
	_bar.position = Vector2(roundf(p.global_position.x), roundf(p.global_position.y - HEIGHTS[_stage] - 4.0))


func _process(delta: float) -> void:
	super._process(delta)
	if not _lifting:
		return
	var speed: float = STAGES[_stage][1]
	_cursor += _dir * speed * 2.0 * delta
	if _cursor >= 1.0:
		_cursor = 1.0
		_dir = -1.0
	elif _cursor <= 0.0:
		_cursor = 0.0
		_dir = 1.0
	var w: float = STAGES[_stage][0]
	_hud.meter_zone(_zone_a, _zone_a + w, _cursor)
	_lock_input -= delta
	if _lock_input <= 0.0 and Input.is_action_just_pressed(&"Attack1"):
		_hud.press_flash()
		if _cursor >= _zone_a and _cursor <= _zone_a + w:
			_lift_up()
		else:
			_slip()


func _lift_up() -> void:
	_stage += 1
	Game.shake_camera(1.2)
	_muscle.bark(["好！", "再来！", "上！"][mini(_stage - 1, 2)], 0.7)
	if _stage >= STAGES.size():
		_lifting = false
		_bar.position.y = roundf(player.global_position.y - HEIGHTS[3] - 4.0)
		_finish(true)
		return
	_lock_input = 0.25
	_new_stage()


func _slip() -> void:
	_misses += 1
	Game.shake_camera(2.5)
	_lock_input = 0.5
	_stage = maxi(0, _stage - 1)
	_muscle.bark("哎——", 0.7)
	if _misses >= MISSES:
		_lifting = false
		_place_bar()
		_finish(false)
		return
	_new_stage()


func _finish(ok: bool) -> void:
	_hud.clear_prompt()
	_hud.clear_meter()
	_hud.banner("")
	_hud.big("举起来了！" if ok else "没举起来……", MiniHud.GOLD if ok else MiniHud.TEXT, 1.0)
	if ok:
		Game.flash(0.1, Color(1, 0.95, 0.85))
	await wait(1.4)
	if is_instance_valid(_bar):
		_bar.queue_free()
	if _hud != null:
		_hud.close()
		_hud = null
	GangMob.truce = false
	pause_talk(false)
	(player as CharacterBody2D).set_lock(false)
	if ok and not Story.flag("muscle_won", false):
		Story.set_flag("muscle_won", true)
		Talk.begin()
		await Dialogue.say(["……兄弟！", "你的肌肉，", "不哭了。"], "肌肉哥")
		Talk.end()
	elif not ok:
		_muscle.bark("歇会儿再来！", 2.0)


func _exit_tree() -> void:
	GangMob.truce = false
