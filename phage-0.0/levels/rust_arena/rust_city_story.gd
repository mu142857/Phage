# res://levels/rust_arena/rust_city_story.gd
# 铁锈城·一 的剧情(剧本:Phage/Story/rust_city_script.md 第一幕 1-1 ~ 1-3)。
#   1-1 水沟里的铜板喊住你 → 踩到它,捡起来(屏幕右上角出现铜板数)
#   1-2 铁皮点灯人从右边走来,拧亮第一盏灯,叫住你说话;然后一路往右把路灯拧亮带路
#   1-3 走到工地:修路工、收费员、过路费一百 → 目标"凑够一百个铜板",点灯人在路障边等
# 进度记在 Story.flags(每次入梦清空;F6 单跑死亡重载时保留)。每段开演前先查标记,
# 演过的跳过,场景按标记还原:哪些灯亮着、铜板还在不在、点灯人站在哪。
extends Node

const TOLL := 100
## 开场就亮着的灯(出生点身后那盏,让开局不至于一片黑)。
const START_LIT: Array[String] = ["Light2"]
## 点灯人带路要拧的灯,按从左到右的顺序。Light13 在路障那边,点不到,一直黑着。
const GUIDE_LAMPS: Array[String] = [
	"Light1", "Light3", "Light4", "Light5", "Light6", "Light7",
	"Light8", "Light9", "Light10", "Light11", "Light12",
]
const LAMPLIGHTER_ENTER_X := 200.0   # 点灯人从右边画外走进来
const LAMPLIGHTER_WAIT_X := 1506.0   # 在路障边等你的位置
const POLE_OFFSET := 3.0             # 杆子在贴图里离脚底中点 3 格:站在灯柱左边 3 格,杆子正好对着灯
const GUIDE_SPEED := 42.0
const GUIDE_CATCHUP_SPEED := 72.0    # 主角跑到他前面去了,他小跑追上
const GUIDE_MAX_LEAD := 110.0        # 领先主角超过这么多就停下等
const SITE_TRIGGER_X := 1500.0       # 主角走到这里,工地那场戏开演(收费员、点灯人、修路工、路障都在画面里)
# 点灯人说话的打字速度:刚上满发条时很快,等得越久越慢(整夜的时钟)
const CPS_WOUND := 26.0
const CPS_NORMAL := 16.0
const CPS_SLOW := 9.0

@onready var _buildings: Node = $"../Buildings"
@onready var _coin: Npc = $"../Npcs/TalkingCoin"
@onready var _lamplighter: Npc = $"../Npcs/Lamplighter"
@onready var _worker: Npc = $"../Npcs/RoadWorker"
@onready var _toll: Npc = $"../Npcs/TollCollector"
# 建筑地精(梧桐画的小个子):两组抬钢梁来回搬,工头举旗站在路障前。场景里没摆就跳过
@onready var _goblin_pairs: Array = [get_node_or_null("../Npcs/GoblinPairA"), get_node_or_null("../Npcs/GoblinPairB")]
@onready var _goblin_flag: Npc = get_node_or_null("../Npcs/GoblinFlag") as Npc

var _player: Node2D = null
var _hud: CoinHud = null
var _lights: Dictionary = {}       # 灯名 → PointLight2D
var _light_energy: Dictionary = {} # 灯名 → 原本的亮度
var _bark_cooldown: Dictionary = {}
var _lamplighter_near := false     # 主角在不在点灯人身边(走近时他叫你一声)


func _ready() -> void:
	_hud = CoinHud.new()
	add_child(_hud)
	_setup_lamps()
	_restore_npcs()
	_run()


# ============================================================
# 场景还原
# ============================================================

func _setup_lamps() -> void:
	for lamp in _buildings.get_children():
		if not String(lamp.name).begins_with("Light"):
			continue
		var light := lamp.get_node_or_null("PointLight2D") as PointLight2D
		if light == null:
			continue
		_lights[String(lamp.name)] = light
		_light_energy[String(lamp.name)] = light.energy
	for lamp_name: String in _lights:
		_set_lamp(lamp_name, lamp_name in _lit_lamps(), false)


func _restore_npcs() -> void:
	_coin.visible = not Story.flag("coin_found")
	_coin.talkable = false
	if Story.flag("lamp_at_site"):
		_lamplighter.global_position.x = LAMPLIGHTER_WAIT_X
		_lamplighter.face(-1)
	elif Story.flag("lamp_intro"):
		# 带路带到一半(死亡重载):站回最后一盏点亮的灯下
		var last_x := _lamp_x("Light1") - POLE_OFFSET
		for lamp_name in GUIDE_LAMPS:
			if lamp_name in _lit_lamps():
				last_x = _lamp_x(lamp_name) - POLE_OFFSET
		_lamplighter.global_position.x = last_x
	else:
		_lamplighter.visible = false
		_lamplighter.global_position.x = LAMPLIGHTER_ENTER_X
	# 工地这场戏之前,三个人都还不能搭话(修路工只会自己嘀咕)
	var road_seen: bool = Story.flag("road_seen")
	_lamplighter.talkable = road_seen
	_worker.talkable = road_seen
	_toll.talkable = road_seen
	_dig_loop()
	for i in _goblin_pairs.size():
		var pair := _goblin_pairs[i] as Npc
		if pair != null:
			_carry_loop(pair, pair.global_position.x, pair.global_position.x + (14.0 if i == 0 else -14.0), i * 0.9)
	if _goblin_flag != null:
		_flag_loop()


# 修路工一直在挖:一下一下往下砸
func _dig_loop() -> void:
	while is_inside_tree():
		if not Talk.busy():
			await _worker.hop(-1.0, 0.25)
		await _wait(0.55)


# 抬钢梁的地精:慢吞吞地在两点之间来回搬(有人说话时停下)
func _carry_loop(pair: Npc, a: float, b: float, delay: float) -> void:
	await _wait(delay)
	var to_b := true
	while is_inside_tree():
		if Talk.busy():
			await _wait(0.3)
			continue
		await pair.walk_to(b if to_b else a, 12.0)
		to_b = not to_b
		await _wait(0.8)


# 举旗的工头:隔一会儿蹦一下,挥挥旗
func _flag_loop() -> void:
	while is_inside_tree():
		await _wait(randf_range(1.0, 2.2))
		if not Talk.busy():
			await _goblin_flag.hop(2.0, 0.2)


# 剧情协程统一用这两个等待。过门换场景时,本场景先被移出场景树、稍后才释放,
# 中间那一帧协程还会醒来,这时 get_tree() 是 null。离开场景树就原地挂起
# (等一个不会再来的 tree_entered),节点释放后这条协程随之作废,不会往下演。
func _frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		await tree_entered


func _wait(seconds: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		await tree_entered


# ============================================================
# 主线
# ============================================================

func _run() -> void:
	await _frame()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	# 等入梦字卡演完、主角站起来
	var intro := get_node_or_null("../DreamIntro")
	if intro != null and not intro.is_queued_for_deletion() and not intro.get("done"):
		await intro.finished
	if not Story.flag("coin_found"):
		await _scene_coin()
	if not Story.flag("lamp_intro"):
		await _scene_lamplighter()
	if not Story.flag("lamp_at_site"):
		await _guide_to_site()
	if not Story.flag("road_seen"):
		await _scene_road()
	_setup_free_talk()


# ---- 1-1 捡到铜板 ----
func _scene_coin() -> void:
	var called := false
	while true:
		var dx := absf(_coin.global_position.x - _player.global_position.x)
		if not called and dx < 48.0:
			_coin.bark("喂！下面！", 0.0)
			called = true
		if dx <= 3.0:
			break
		await _frame()
	_coin.hide_bark()
	Talk.begin()
	await Dialogue.talk([["铜板", "……你踩着我了。"]])
	_coin.visible = false
	Story.set_flag("coin_found")
	Story.set_flag("coins_seen")
	Story.set_flag("talking_coin_in_wallet")
	Story.add_coins(1)
	await Dialogue.talk([
		["铜板", "你要花我吗？"],
		["铜板", "别花我。"],
		["铜板", "我是会说话的。会说话的不能花。"],
	])
	Talk.end()


# ---- 1-2 点灯人 ----
func _scene_lamplighter() -> void:
	_lamplighter.visible = true
	_lamplighter.global_position.x = LAMPLIGHTER_ENTER_X
	_lamplighter.bark("咔哒，咔哒", 0.0)
	await _lamplighter.walk_to(_lamp_x("Light1") - POLE_OFFSET, 36.0)
	_lamplighter.hide_bark()
	await _light_lamp("Light1")
	# 转过来,看见你
	_lamplighter.face_x(_player.global_position.x)
	await _lamplighter.hop(3.0, 0.2)
	await _walk_up_to_player(_lamplighter, 40.0)
	Talk.begin()
	_lamplighter.face_x(_player.global_position.x)
	var pick := await Dialogue.ask(
		["哇！新来的！", "你也是今晚刚上的发条吗？"], ["点头", "摇头"], "点灯人", CPS_WOUND)
	Story.set_flag("lamp_nodded", pick == 0)
	if pick == 0:
		await Dialogue.say(["我也是！满满的！", "咔哒咔哒的，停都停不下来！"], "点灯人", CPS_WOUND)
	else:
		await Dialogue.say(["没有发条？", "那你是怎么动的？", "……好厉害。"], "点灯人", CPS_WOUND)
	await Dialogue.say([
		"我是点灯的。",
		"每天晚上，把整条街的灯拧一遍。",
		"一盏，一盏，一盏……",
		"拧完了，天就亮了。",
	], "点灯人", CPS_WOUND)
	# 往右走两步,又回头
	await _lamplighter.walk_to(_lamplighter.global_position.x + 10.0, 30.0)
	_lamplighter.face_x(_player.global_position.x)
	await Dialogue.say([
		"可是那边的灯，好久没人拧了。",
		"路修了三个月，一直没修好。",
		"我先去前面了！咔哒咔哒！",
	], "点灯人", CPS_WOUND)
	Talk.end()
	Story.set_flag("lamp_intro")


# 主角离得远就自己走过去(主角跑开了也能追上),走到 gap 以内停下
func _walk_up_to_player(npc: Npc, gap: float) -> void:
	while is_inside_tree():
		var dx := _player.global_position.x - npc.global_position.x
		if absf(dx) <= gap + 8.0:
			break
		npc.face(dx)
		npc.walking = true
		npc.global_position.x += signf(dx) * 50.0 * get_process_delta_time()
		await _frame()
	npc.walking = false


# 一路把灯拧亮,主角落后太多就停下等、喊一声
func _guide_to_site() -> void:
	for lamp_name in GUIDE_LAMPS:
		if lamp_name in _lit_lamps():
			continue
		await _guide_walk_to(_lamp_x(lamp_name) - POLE_OFFSET)
		await _light_lamp(lamp_name)
	await _guide_walk_to(LAMPLIGHTER_WAIT_X)
	_lamplighter.face(-1)
	Story.set_flag("lamp_at_site")


func _guide_walk_to(x: float) -> void:
	var call_timer := 1.0
	while is_inside_tree() and _lamplighter.global_position.x < x:
		var delta := get_process_delta_time()
		var lead := _lamplighter.global_position.x - _player.global_position.x
		if lead > GUIDE_MAX_LEAD or Talk.busy():
			_lamplighter.walking = false
			_lamplighter.face(-1)
			call_timer -= delta
			if call_timer <= 0.0 and not Talk.busy():
				_lamplighter.bark("这边！", 1.6)
				call_timer = 4.0
		else:
			var speed := GUIDE_CATCHUP_SPEED if lead < -16.0 else GUIDE_SPEED
			_lamplighter.face(1)
			_lamplighter.walking = true
			_lamplighter.global_position.x = minf(_lamplighter.global_position.x + speed * delta, x)
		await _frame()
	_lamplighter.walking = false


# ---- 1-3 前面在修路 ----
func _scene_road() -> void:
	while _player.global_position.x < SITE_TRIGGER_X or not Story.flag("lamp_at_site"):
		await _frame()
	Talk.begin()
	_lamplighter.face(1)
	await Dialogue.talk([
		["点灯人", "……过不去。", CPS_NORMAL],
		["修路工", "前面在修路。"],
		["点灯人", "修多久了？", CPS_NORMAL],
		["修路工", "三个月。"],
		["点灯人", "还要多久？", CPS_NORMAL],
		["修路工", "不知道。"],
		["修路工", "老板只让我挖。"],
	])
	_toll.face_x(_player.global_position.x)
	await Dialogue.talk([
		["收费员", "想去那边？"],
		["收费员", "走下水道。"],
		["收费员", "过路费，一百。"],
		["", "（点灯人摸了摸身上，什么都没有。）"],
		["点灯人", "我没有钱。", CPS_NORMAL],
		["点灯人", "我只有发条。", CPS_NORMAL],
		["收费员", "发条不收。"],
	])
	_lamplighter.face_x(_player.global_position.x)
	await Dialogue.ask(
		["你……能帮我去那边吗？", "那边的灯，黑了三个月了。"],
		["我去想办法", "……"], "点灯人", CPS_NORMAL)
	await Dialogue.say(["那我在这儿等你。", "咔哒，咔哒。"], "点灯人", CPS_NORMAL)
	Story.set_flag("road_seen")
	Story.set_flag("coin_goal", TOLL)
	_hud.refresh()
	Talk.end()


# ============================================================
# 主线演完之后:可以随便找三个人说话
# ============================================================

func _setup_free_talk() -> void:
	_lamplighter.talkable = true
	_worker.talkable = true
	_toll.talkable = true
	_lamplighter.on_talk = _talk_lamplighter
	_worker.on_talk = _talk_worker
	_toll.on_talk = _talk_toll


# 剧本 1-3 的表:钱攒得越多(=等得越久),他越慢。
# [对话里的整句, 打字速度, 头顶冒的短句(世界里 11px 字很大,头顶的话最多五六个字)]
func _lamplighter_line() -> Array:
	var progress := float(Story.coins) / float(TOLL)
	if progress < 0.5:
		return ["咔哒咔哒！你回来啦！", CPS_WOUND, "咔哒咔哒！"]
	if progress < 0.9:
		return ["咔哒，咔哒。……还差多少呀？", CPS_NORMAL, "咔哒，咔哒。"]
	return ["咔哒。……我不急。……咔哒。", CPS_SLOW, "……咔哒。"]


func _talk_lamplighter() -> void:
	_lamplighter.face_x(_player.global_position.x)
	var line := _lamplighter_line()
	await Dialogue.say([line[0]], "点灯人", line[1])


func _talk_worker() -> void:
	var pick := await Dialogue.ask(["前面在修路。", "挖。"], ["修什么？", "工钱呢？", "没事"], "修路工")
	if pick == 0:
		await Dialogue.say([
			"老板只让我挖。",
			"每天挖一个坑。",
			"第二天来，坑又平了。",
			"……所以我再挖。",
		], "修路工")
	elif pick == 1:
		await Dialogue.say(["付的是……剑。", "我又不会用剑。"], "修路工")


func _talk_toll() -> void:
	_toll.face_x(_player.global_position.x)
	if Story.coins < TOLL:
		await Dialogue.say(["过路费，一百。", "你这儿只有 %d 个。" % Story.coins], "收费员")
	else:
		# 下水道还没做(第二步之后接上交钱、下井盖)
		await Dialogue.say(["……一百。", "（下水道还在施工，下次再来。）"], "收费员")


# 主角走近时,点灯人/修路工头顶冒一句(不打断操作)
func _process(delta: float) -> void:
	if _player == null or Talk.busy():
		return
	for key in _bark_cooldown.keys():
		_bark_cooldown[key] = maxf(_bark_cooldown[key] - delta, 0.0)
	var to_worker := absf(_player.global_position.x - _worker.global_position.x)
	if not Story.flag("road_seen") and to_worker < 50.0 and _bark_cooldown.get("worker", 0.0) <= 0.0:
		_worker.bark("前面在修路。", 2.0)
		_bark_cooldown["worker"] = 6.0
	if Story.flag("road_seen"):
		var near := absf(_player.global_position.x - _lamplighter.global_position.x) < 60.0
		if near and not _lamplighter_near:
			_lamplighter.bark(String(_lamplighter_line()[2]), 2.5)
		_lamplighter_near = near


# ============================================================
# 路灯
# ============================================================

func _lit_lamps() -> Array:
	return Story.flag("lit_lamps", START_LIT.duplicate())


func _lamp_x(lamp_name: String) -> float:
	var lamp := _buildings.get_node_or_null(lamp_name) as Node2D
	return lamp.global_position.x if lamp != null else 0.0


func _set_lamp(lamp_name: String, on: bool, animate: bool) -> void:
	var light: PointLight2D = _lights.get(lamp_name)
	if light == null:
		return
	var energy: float = _light_energy[lamp_name]
	light.enabled = on
	if not on:
		return
	if animate:
		# 啪地一亮:先冲高一下再回落
		light.energy = 0.0
		var tw := light.create_tween()
		tw.tween_property(light, "energy", energy * 1.7, 0.12)
		tw.tween_property(light, "energy", energy, 0.35)
	else:
		light.energy = energy


# 站在灯下,杆子往上拧三圈,灯亮
func _light_lamp(lamp_name: String) -> void:
	_lamplighter.face(1)
	for i in 3:
		await _lamplighter.hop(2.0, 0.18)
		await _wait(0.06)
	_set_lamp(lamp_name, true, true)
	var lit := _lit_lamps()
	if not lamp_name in lit:
		lit.append(lamp_name)
	Story.set_flag("lit_lamps", lit)
	await _wait(0.25)
