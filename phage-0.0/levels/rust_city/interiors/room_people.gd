# 屋里的人(继承巷子的 AlleyPeople:叫住、帮派打死本夜不复活、掉铜板、铜板 HUD 都现成)。
# 屋里多两件事:
#   1. 屋里的奥斯卡帮全打完 → 一袋钱从房梁上掉到主角头上(bag_coins,本夜一次)。
#   2. 子节点 Stash 下面每个 Marker2D = 藏着的一枚铜板(柜顶、阁楼、架子上),本夜捡过不再出现。
# 挂在 <屋名>_people.tscn 的根上;屋子场景里只有一行实例(生成工具 A.people())。
class_name RoomPeople
extends AlleyPeople

const MONEY_BAG: PackedScene = preload("res://entities/gang/money_bag/money_bag.tscn")
const COIN: PackedScene = preload("res://entities/gang/coin/coin_pickup.tscn")

## 屋里的帮派全打完给多少(0 = 不给钱袋)
@export var bag_coins: int = 0
## 钱袋落点限制在屋里这一段(别掉进墙里)
@export var room_left: float = 16.0
@export var room_right: float = 144.0

var _bag_key := ""


func _setup() -> void:
	_bag_key = "room_bag:%s" % _scene_key()
	_setup_stash()
	_watch_gang()


func _setup_stash() -> void:
	var stash := get_node_or_null("Stash")
	if stash == null:
		return
	for m in stash.get_children():
		if not (m is Marker2D):
			continue
		var key := "stash:%s:%s" % [_scene_key(), m.name]
		if Story.flag(key, false):
			continue
		var coin := COIN.instantiate() as Node2D
		coin.position = (m as Marker2D).position
		stash.add_child(coin)
		# 捡走了才记(换场景时也会出树,那时 _taken 是假的)
		coin.tree_exiting.connect(func() -> void:
			if coin.get("_taken"):
				Story.set_flag(key, true))


func _alive_mobs() -> Array:
	var gang := get_node_or_null("Gang")
	if gang == null:
		return []
	return gang.get_children().filter(func(m: Node) -> bool:
		return m is GangMob and not m.is_queued_for_deletion() and (m as GangMob).health > 0)


func _watch_gang() -> void:
	if bag_coins <= 0 or Story.flag(_bag_key, false):
		return
	var mobs := _alive_mobs()
	if mobs.is_empty():
		return
	for m in mobs:
		(m as GangMob).died.connect(func(_x: Node) -> void: _check_cleared())
	var gang := get_node("Gang")
	gang.child_entered_tree.connect(func(n: Node) -> void:   # 放哨的吹哨叫来的小弟也算
		if n is GangMob:
			(n as GangMob).died.connect(func(_x: Node) -> void: _check_cleared()))


func _check_cleared() -> void:
	if Story.flag(_bag_key, false) or not _alive_mobs().is_empty():
		return
	Story.set_flag(_bag_key, true)
	var bag := MONEY_BAG.instantiate() as Node2D
	bag.set("coins", bag_coins)
	var px := player.global_position.x if player != null and is_instance_valid(player) else (room_left + room_right) / 2.0
	bag.position = Vector2(clampf(px, room_left, room_right), -8.0)
	add_child(bag)
