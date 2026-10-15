# 晾衣巷的人。剧本 #4 纸壳文字框、#14 摆烂仔;尽头(去后巷那扇门前)蹲着收钱小弟和放哨的。
# 纸壳认了妈妈以后跟着飘、旧电脑认领那段,等室内(修车铺里屋)做好再接。
extends AlleyPeople

const BOX_TEX: Texture2D = preload("res://entities/rust_npcs/paper_box.png")
const BUBBLE_TEX: Texture2D = preload("res://entities/rust_npcs/paper_box_bubble.png")
const LIE_SECONDS := 30.0

var _box: Npc
var _lazy: Npc
var _shake_t := 0.0


func _setup() -> void:
	_box = npc("PaperBox")
	_lazy = npc("Lazy")
	if Story.flag("box_mom", false):
		_box.texture = BUBBLE_TEX
	elif Story.flag("box_refused", false):
		call_out(_box, "……", 30.0)
	_box.on_talk = _talk_box
	_lazy.on_talk = _talk_lazy
	call_out(_lazy, "……喂。", 44.0, "", "……算了。")


func _process(delta: float) -> void:
	super._process(delta)
	# 纸箱一直在发抖
	if _box != null and not Story.flag("box_mom", false) and not Talk.busy():
		_shake_t += delta
		if _shake_t > 1.3:
			_shake_t = 0.0
			_box.hop(1.0, 0.12)


func _talk_box() -> void:
	if Story.flag("box_mom", false):
		await Dialogue.say(["妈妈！"])
		return
	var pick := await Dialogue.ask(["（一个纸箱在发抖。底下露出一截对话框的小尖尾巴。）"], ["掀开纸壳", "算了"])
	if pick != 0:
		return
	_box.texture = BUBBLE_TEX
	var answer := await Dialogue.ask(["妈妈？"], ["我不是你妈妈", "……嗯"])
	if answer == 0:
		# 它把纸壳戴回去;随时可以回来改主意
		_box.texture = BOX_TEX
		if not Story.flag("box_refused", false):
			Story.set_flag("box_refused", true)
			call_out(_box, "……", 30.0)
		return
	Story.set_flag("box_mom", true)
	stop_call_out(_box)
	await Dialogue.say(["妈妈！"])


func _talk_lazy() -> void:
	stop_call_out(_lazy)
	var pick := await Dialogue.ask(["我先摆烂了。"], ["起来", "你在干嘛", "躺下"], "摆烂仔")
	if pick == 0:
		await Dialogue.say(["不想动。"], "摆烂仔")
	elif pick == 1:
		await Dialogue.say(["摆烂。"], "摆烂仔")
	else:
		await _lie_down()


# 反任务:躺下以后什么都不按,30 秒
func _lie_down() -> void:
	await Dialogue.say(["（你在他旁边躺下。）"])
	await wait(0.2)
	var t := 0.0
	var mumbled := 0
	while t < LIE_SECONDS:
		await wait(0.0)
		t += get_process_delta_time()
		for action in ["move_left", "move_right", "jump", "Attack1", "Attack2", "Select", "sprint"]:
			if Input.is_action_just_pressed(action):
				await Dialogue.say(["（你坐起来了。）"])
				await Dialogue.say(["……"], "摆烂仔")
				return
		if t > 10.0 * (mumbled + 1) and mumbled < 2:
			mumbled += 1
			_lazy.bark("……", 1.5)
	await Dialogue.say(["……", "你懂我。"], "摆烂仔")
	if not Story.flag("lazy_paid", false):
		Story.set_flag("lazy_paid", true)
		pay(5)
