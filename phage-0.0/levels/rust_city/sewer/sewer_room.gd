# 下水道(管道局的地盘)每一段的底子。挂在房间场景的 Room 节点上,子类写这一段的戏。
#
# 一段一个检查站:稽查员(officer)守着铁栅门(gate)收一笔"X 费"。主角走到他跟前就开口:
#   交钱 → 这一段的人都不把你当敌人(BureauMob.pass_ok),敬礼放行,门开;
#   不交 / 没钱 / 中途动手 → 全体翻脸,打到这一段管道局的人全倒下门才开。
# Bureau 节点下的管道局兵(含 BureauSquad 里的)打死了这一夜不再出现(Story 标记 sewer_dead:<场景>:<节点路径>);
# 交过钱 / 打通了也记着,回头再走不用再来一遍。自带铜板 HUD。
class_name SewerRoom
extends Node

## 这一段叫什么(标记用),比如 "sewer_1"
@export var room_key: String = "sewer_1"
@export var fee: int = 20
@export var fee_name: String = "过段费"
@export var officer_path: NodePath
@export var gate_path: NodePath
## 主角走到离稽查员多近,他开口
@export var talk_radius: float = 44.0

var player: Node2D = null
var officer: BureauMob = null
var gate: BureauGate = null
var _talked := false
var _fighting := false


func _ready() -> void:
	add_to_group("bureau_listener")
	_late_ready.call_deferred()


func _late_ready() -> void:
	if not is_inside_tree():
		return
	player = get_tree().get_first_node_in_group("player") as Node2D
	GangMob.truce = false
	if get_tree().get_first_node_in_group("coin_hud") == null:
		var hud := CoinHud.new()
		hud.add_to_group("coin_hud")
		add_child(hud)
	officer = get_node_or_null(officer_path) as BureauMob
	gate = get_node_or_null(gate_path) as BureauGate
	_setup_dead()
	# 进场先不打人:等稽查员开口(交过钱的一直不打,路过敬礼)
	BureauMob.pass_ok = true
	BureauMob.waved_through = paid()
	if paid() or cleared():
		_talked = true
		if gate != null:
			gate.open(true)
	_setup()
	_check_clear.call_deferred()


## 子类:这一段自己的东西(开场戏、奥斯卡帮…)
func _setup() -> void:
	pass


func paid() -> bool:
	return bool(Story.flag("sewer_paid:" + room_key))


func cleared() -> bool:
	return bool(Story.flag("sewer_clear:" + room_key))


# ------------------------------------------------------------------ 打死的不再出现
func _setup_dead() -> void:
	var scene := get_tree().current_scene
	var scene_key := scene.scene_file_path.get_file().get_basename() if scene != null else "?"
	for m in get_tree().get_nodes_in_group("bureau"):
		var b := m as BureauMob
		if b == null:
			continue
		var key := "sewer_dead:%s:%s" % [scene_key, String(scene.get_path_to(b))]
		if Story.flag(key):
			b.queue_free()
			continue
		b.died.connect(func(_x: GangMob) -> void:
			Story.set_flag(key)
			_check_clear.call_deferred())


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or Talk.busy():
		return
	if not _talked and not _fighting and can_talk():
		if officer == null or not is_instance_valid(officer) or officer.health <= 0:
			officer = _next_officer()
		if officer != null and absf(player.global_position.x - officer.global_position.x) < talk_radius \
				and absf(player.global_position.y - officer.global_position.y) < 30.0:
			_talked = true
			_ask_fee()
	_tick()


## 子类:现在能不能收钱(混战打完之前不收)
func can_talk() -> bool:
	return true


## 稽查员倒了:换一个还站着的管道局的人来收
func _next_officer() -> BureauMob:
	for m in get_tree().get_nodes_in_group("bureau"):
		var b := m as BureauMob
		if b != null and b.health > 0 and not b.is_queued_for_deletion():
			return b
	return null


## 子类:每帧
func _tick() -> void:
	pass


# ------------------------------------------------------------------ 收钱
func _ask_fee() -> void:
	Talk.begin()
	officer.face(signf(player.global_position.x - officer.global_position.x))
	await Dialogue.talk(_fee_lines())
	var options: Array = []
	var can_pay := Story.coins >= fee
	if can_pay:
		options.append("交（%d）" % fee)
	options.append_array(_refuse_options(can_pay))
	var pick := await Dialogue.ask(["%s，%d。" % [fee_name, fee]], options, "稽查员")
	if can_pay and pick == 0:
		Story.add_coins(-fee)
		Story.set_flag("sewer_paid:" + room_key)
		await Dialogue.say(_paid_lines(), "稽查员")
		Talk.end()
		_on_paid()
		return
	var refuse_idx := pick - (1 if can_pay else 0)
	await Dialogue.say(_refused_reply(refuse_idx, can_pay), "稽查员")
	Talk.end()
	start_fight()


## 子类:开口那几句([[说话人, 句子], ...])
func _fee_lines() -> Array:
	return [["稽查员", "站住。"], ["稽查员", "这一段，另算。"]]


func _refuse_options(can_pay: bool) -> Array:
	return ["凭什么" if can_pay else "没钱了", "……"]


func _refused_reply(idx: int, can_pay: bool) -> Array:
	if idx == 0:
		return ["凭我在这儿。"] if can_pay else ["那就打。"]
	return ["不说话，就是不交。", "按章处理。"]


func _paid_lines() -> Array:
	return ["收据拿好。", "下一位。"]


func _on_paid() -> void:
	BureauMob.pass_ok = true
	BureauMob.waved_through = true
	if gate != null:
		gate.open()


## 开打:这一段的管道局全体把主角当敌人
func start_fight() -> void:
	if _fighting:
		return
	_fighting = true
	BureauMob.pass_ok = false
	BureauMob.waved_through = false
	if officer != null and is_instance_valid(officer):
		officer.shout("provoked", 1.0, true)
	_check_clear.call_deferred()


## 交过钱以后动手(BureauMob.provoke 叫过来的)
func on_bureau_provoked() -> void:
	_talked = true
	_fighting = true
	_check_clear.call_deferred()


func _check_clear() -> void:
	if not is_inside_tree() or cleared():
		return
	for m in get_tree().get_nodes_in_group("bureau"):
		var b := m as BureauMob
		if b != null and b.health > 0 and not b.is_queued_for_deletion():
			return
	Story.set_flag("sewer_clear:" + room_key)
	if gate != null:
		gate.open()
	_on_cleared()


## 子类:这一段的管道局全倒下了
func _on_cleared() -> void:
	pass
