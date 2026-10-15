# 每条巷子的人:NPC + 蹲在角落里的下水道帮 + 到处都在的大白鹅 + 九尾狐涂鸦。
# 挂在 <巷名>_people.tscn 的根上;巷子场景里只有一行实例,重跑巷子生成工具不会冲掉这里。
# 子类(<巷名>_people.gd)覆盖 _setup(),给 NPC 接 on_talk、设叫住的话。
#
# 约定:
#   子节点 Gang 下面放帮派怪(GangMob,设 leash/aggro_range/coins = 角落里的怪)。
#     这一夜打死的不再出现(Story 标记 gang_dead:<场景>:<节点名>);
#     放哨的吹哨 = 从天上掉一个收钱小弟下来(每次进巷子最多 reinforce_max 个)。
#   名字以 FoxTail 开头的 Npc = 墙上的九尾狐涂鸦,看一眼记一条尾巴(全城 9 条)。
#   goose_spots 不空 = 大白鹅每次都在其中一个地方等你:「我又来了。」
class_name AlleyPeople
extends Node2D

const NPC_SCENE: PackedScene = preload("res://systems/npc/npc.tscn")
const GOOSE_TEX: Texture2D = preload("res://entities/rust_npcs/goose.png")
const THUG_SCENE: PackedScene = preload("res://entities/gang/thug/thug.tscn")
const FOX_TOTAL := 9

## 大白鹅可能站的地方(脚底坐标,每次进巷子随机挑一个);空 = 这条巷子没有鹅
@export var goose_spots: PackedVector2Array = PackedVector2Array()
## 放哨的吹哨,最多叫来几个
@export var reinforce_max: int = 2

var player: Node2D = null
var _callouts: Array = []   # [npc, 半径, 句子, 走开以后下次说的话, 状态, 隔一下再冒的第二句]
var _reinforced := 0
var _talk_paused := false
var _broken_lights: Array = []   # [PointLight2D, 守着它的帮派怪们, 下次切换剩几秒]
var _talkable_before := {}


func _ready() -> void:
	# 主角在巷子场景里排在后面,等它进树
	_late_ready.call_deferred()


func _late_ready() -> void:
	if not is_inside_tree():
		return
	player = get_tree().get_first_node_in_group("player") as Node2D
	GangMob.truce = false   # 上一个场景的小游戏没收尾就切走了也不会一直停战
	if get_tree().get_first_node_in_group("coin_hud") == null:
		var hud := CoinHud.new()
		hud.add_to_group("coin_hud")
		add_child(hud)
	_setup_gang()
	_setup_broken_lights()
	_setup_fox_tails()
	_setup_goose()
	_setup()


## 子类在这里接 NPC 的话
func _setup() -> void:
	pass


# ------------------------------------------------------------------ 叫住
## 主角走近 radius 以内,npc 头顶冒 text(then_text 不空就隔 1.6 秒再冒一句);
## 没搭话就走远了,下次走近冒 ignored_text(空 = 还冒 text)。
func call_out(npc: Npc, text: String, radius := 48.0, ignored_text := "", then_text := "") -> void:
	_callouts.append([npc, radius, text, ignored_text, 0, then_text])


func _process(_delta: float) -> void:
	_tick_broken_lights(_delta)
	if player == null or not is_instance_valid(player) or Talk.busy() or _talk_paused:
		return
	for c in _callouts:
		var npc := c[0] as Npc
		if not is_instance_valid(npc) or not npc.visible:
			continue
		var near := absf(player.global_position.x - npc.global_position.x) < float(c[1]) \
			and absf(player.global_position.y - npc.global_position.y) < 30.0
		# 状态:0 还没碰到 / 1 冒过了人还在旁边 / 2 冒过了人走开了(没搭话)
		if near and c[4] != 1:
			var text: String = c[3] if c[4] == 2 and String(c[3]) != "" else c[2]
			npc.face_x(player.global_position.x)
			npc.bark(text, 1.5 if String(c[5]) != "" else 2.0)
			if String(c[5]) != "" and c[4] == 0:
				var then_text: String = c[5]
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					if is_instance_valid(npc) and not Talk.busy():
						npc.bark(then_text, 2.0))
			c[4] = 1
		elif not near and c[4] == 1:
			c[4] = 2


## 搭过话了,叫住的话不用再冒
func stop_call_out(npc: Npc) -> void:
	_callouts = _callouts.filter(func(c: Array) -> bool: return c[0] != npc)


## 小游戏进行时:这条巷子里的人都不接话、不叫住(免得赛跑时按 Q 跟大白鹅聊起来)
func pause_talk(paused: bool) -> void:
	if paused == _talk_paused:
		return
	_talk_paused = paused
	for n in get_children():
		if not (n is Npc):
			continue
		if paused:
			_talkable_before[n] = n.talkable
			n.talkable = false
			n.hide_bark()
		elif _talkable_before.has(n):
			n.talkable = _talkable_before[n]
	if not paused:
		_talkable_before.clear()


# ------------------------------------------------------------------ 帮派
func _setup_gang() -> void:
	var gang := get_node_or_null("Gang")
	if gang == null:
		return
	for m in gang.get_children():
		if not (m is GangMob):
			continue
		var key := "gang_dead:%s:%s" % [_scene_key(), m.name]
		if Story.flag(key, false):
			m.queue_free()
			continue
		(m as GangMob).died.connect(func(_x: Node) -> void: Story.set_flag(key, true))
		if m.has_signal("whistled"):
			m.connect("whistled", _on_whistle)


# ------------------------------------------------------------------ 坏路灯
## 帮派角落 60 格以内的灯(路灯和灯泡)坏了:大部分时间是黑的,偶尔闪两下。
## 那一拨黑衣人全打完,灯就好了、常亮——清掉一个角落,街上就亮一块。
func _setup_broken_lights() -> void:
	var gang := get_node_or_null("Gang")
	var top: Node = self
	while top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	if gang == null or top == null:
		return
	var mobs: Array = []
	for m in gang.get_children():
		if m is GangMob and not m.is_queued_for_deletion():
			mobs.append(m)
	if mobs.is_empty():
		return
	for l in top.find_children("*", "PointLight2D", true, false):
		var light := l as PointLight2D
		if light.get_parent() == player or not light.enabled:
			continue
		var near: Array = []
		for m in mobs:
			if absf(light.global_position.x - (m as Node2D).global_position.x) < 60.0:
				near.append(m)
		if not near.is_empty():
			light.enabled = false
			_broken_lights.append([light, near, randf_range(0.3, 1.5)])


func _tick_broken_lights(delta: float) -> void:
	for b in _broken_lights.duplicate():
		var light := b[0] as PointLight2D
		if not is_instance_valid(light):
			_broken_lights.erase(b)
			continue
		var alive := (b[1] as Array).filter(func(m: Variant) -> bool:
			return is_instance_valid(m) and (m as GangMob).health > 0)
		if alive.is_empty():
			light.enabled = true   # 修好了
			_broken_lights.erase(b)
			continue
		b[2] = float(b[2]) - delta
		if float(b[2]) <= 0.0:
			light.enabled = not light.enabled
			# 亮一下就灭(0.05~0.15 秒),灭的时间长(0.4~2.2 秒)
			b[2] = randf_range(0.05, 0.15) if light.enabled else randf_range(0.4, 2.2)


func _on_whistle(lookout: Node2D) -> void:
	if _reinforced >= reinforce_max or player == null or not is_instance_valid(player):
		return
	_reinforced += 1
	var side := 1.0 if randf() < 0.5 else -1.0
	var x := player.global_position.x + side * randf_range(36.0, 56.0)
	var thug := THUG_SCENE.instantiate() as GangMob
	thug.drop_in = true
	thug.position = Vector2(x, -26.0)
	thug.leash = 70.0
	thug.aggro_range = 140.0
	thug.coins = 1
	get_node("Gang").add_child(thug)
	thug.home_x = x


func _scene_key() -> String:
	var top: Node = self
	while top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	return top.scene_file_path.get_file().get_basename() if top.scene_file_path != "" else str(top.name)


# ------------------------------------------------------------------ 九尾狐涂鸦
func _setup_fox_tails() -> void:
	for n in get_children():
		if n is Npc and String(n.name).begins_with("FoxTail"):
			var npc := n as Npc
			var key := "fox_tail:%s:%s" % [_scene_key(), npc.name]
			npc.on_talk = func() -> void:
				if not Story.flag(key, false):
					Story.set_flag(key, true)
					Story.set_flag("fox_tails", int(Story.flag("fox_tails", 0)) + 1)
				await Dialogue.say(["墙上画着一条尾巴。（%d/%d）" % [int(Story.flag("fox_tails", 0)), FOX_TOTAL]])


# ------------------------------------------------------------------ 大白鹅
func _setup_goose() -> void:
	if goose_spots.is_empty():
		return
	var goose := NPC_SCENE.instantiate() as Npc
	goose.name = "Goose"
	goose.display_name = "大白鹅"
	goose.texture = GOOSE_TEX
	goose.position = goose_spots[randi() % goose_spots.size()]
	add_child(goose)
	if player != null:
		goose.face_x(player.global_position.x)
	call_out(goose, "我又来了。", 40.0)
	goose.on_talk = func() -> void:
		goose.face_x(player.global_position.x)
		await Dialogue.say(["我又来了。"], "大白鹅")


# ------------------------------------------------------------------ 小工具
func npc(node_name: String) -> Npc:
	return get_node_or_null(node_name) as Npc


## 场景切走了也不会在空树上醒来的等待
func wait(seconds: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		await tree_entered


func pay(amount: int) -> void:
	Story.set_flag("coins_seen", true)
	Story.add_coins(amount)
