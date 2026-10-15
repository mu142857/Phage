# 锅炉管道巷的人。剧本 #3 戴皇冠的蓝史莱姆(叫住;不理他下次就"你怕了吧!")。
# 陪练三回合就在巷子里打(slime_spar.gd);赢了他托你给拳王带封信。蓝龙在大锅炉顶上飞(没有台词,人设没给)。
# 角落:吊桥底下的井盖盾兵 + 吊桥上的扔瓶子的(陪练的时候停战)。
extends AlleyPeople

const SPAR_SCRIPT := preload("res://levels/rust_city/boiler_alley/slime_spar.gd")
const LETTER_TEX: Texture2D = preload("res://entities/rust_npcs/spar/letter.png")

var _slime: Npc
var _dragon: Npc
var _dragon_y := 0.0
var _t := 0.0
var _home_x := 0.0
var _spar: SlimeSpar = null


func _setup() -> void:
	_slime = npc("Slime")
	_dragon = npc("Dragon")
	_dragon_y = _dragon.position.y
	_home_x = _slime.position.x
	_slime.on_talk = _talk_slime
	call_out(_slime, "站住！", 52.0, "你怕了吧！")


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if _dragon != null:
		_dragon.position.y = _dragon_y + roundf(sin(_t * 1.6) * 2.0)
		if player != null:
			_dragon.face_x(player.global_position.x)


func _talk_slime() -> void:
	stop_call_out(_slime)
	if not Story.flag("slime_met", false):
		Story.set_flag("slime_met", true)
		await Dialogue.say(["站住！", "……你看起来很能打。"], "蓝史莱姆")
	var won: bool = Story.flag("slime_letter", false)
	var lines := ["陪我练练！"] if not won else ["……再来一次？"]
	var pick := await Dialogue.ask(lines, ["来！", "你哥是谁？", "下次"], "蓝史莱姆")
	if pick == 1:
		await Dialogue.say(["我哥是拳王。", "这个王冠就是他给我的。"], "蓝史莱姆")
		await Dialogue.say(["（王冠是纸折的。）"])
		return
	if pick != 0:
		return
	await Dialogue.say(["看我王冠。", "王冠一歪，我就要出拳了。", "躲开，然后砍我！"], "蓝史莱姆")
	_start_spar.call_deferred()


func _start_spar() -> void:
	if _spar != null:
		return
	pause_talk(true)
	_spar = SPAR_SCRIPT.new()
	_spar.setup(_slime, player as CharacterBody2D)
	_spar.finished.connect(_on_spar_finished)
	add_child(_spar)


func _on_spar_finished(won: bool) -> void:
	_spar = null
	pause_talk(false)
	# 走回原位
	var tw := create_tween()
	tw.tween_property(_slime, "position:x", _home_x, 0.5)
	await tw.finished
	_slime.face_x(player.global_position.x)
	if not won:
		_slime.bark("再来！", 2.0)
		return
	if Story.flag("slime_letter", false):
		_slime.bark("……你比我哥还凶。", 2.0)
		return
	Story.set_flag("slime_letter", true)
	Talk.begin()
	await Dialogue.say([
		"……你比我哥还凶。",
		"你要去那边？",
		"帮我带封信。",
		"三个月没见他了。",
	], "蓝史莱姆")
	await Dialogue.say_gain("拿到了一封信 {icon}", LETTER_TEX, "给路那边的拳王。")
	await Dialogue.say([
		"他说，等我变强了，",
		"就来看我打。",
		"……我还没变强。",
	], "蓝史莱姆")
	Talk.end()
