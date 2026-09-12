extends Node
## 巡门测试(开发工具):F6 运行 door_tour.tscn,自动把 SCENES 里每扇 auto_teleport 门都传一遍,
## 打印落点、脚下有没有地、有没有卡进墙、有没有落回门区,跑完自动退出。
## 也可无头跑:Godot --headless --path . res://levels/test/door_tour.tscn
const SCENES := [
	"res://levels/cradle_corridor/cradle_room_1.tscn",
	"res://levels/cradle_corridor/cradle_room_2.tscn",
	"res://levels/cradle_of_decay/cradle_of_decay.tscn",
	"res://levels/cradle_of_decay/filling_levels/cradle_of_decay_21.tscn",
	"res://levels/cradle_of_decay/filling_levels/cradle_of_decay_22.tscn",
	"res://levels/cradle_of_decay/filling_levels/cradle_of_decay_23.tscn",
	"res://levels/cradle_corridor/cradel_corridor.tscn",
]
var _tree: SceneTree

func _ready() -> void:
	print("DOOR TOUR START")
	_tree = get_tree()
	Story.replay_mode = true  # 跳过入梦字卡
	call_deferred("_reparent")

# 挂到 root 上,换场景时自己不被删
func _reparent() -> void:
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	_run()

func _run() -> void:
	var tree := _tree
	var bad := 0
	for src in SCENES:
		var ps: PackedScene = load(src)
		var probe := ps.instantiate()
		var doors: Array = []
		_collect(probe, doors)
		probe.free()
		for d in doors:
			tree.change_scene_to_file(src)
			await tree.process_frame; await tree.process_frame
			await Game.change_scene(d["scene_path"], d["id"], false, true)
			await tree.physics_frame; await tree.physics_frame
			var scene := tree.current_scene
			var player: CharacterBody2D = _find_player(scene)
			var pos := player.global_position
			var stuck := player.test_move(player.global_transform, Vector2.ZERO)
			var floor_24 := player.test_move(player.global_transform, Vector2(0, 24))
			var dst_door := _find_door(scene, d["id"])
			var inside := dst_door != null and dst_door.overlaps_body(player)
			var ok := floor_24 and not stuck and not inside and dst_door != null
			if not ok:
				bad += 1
			print("%s [%s] %s(id %d) -> %s  落点=%s  24px内有地=%s 卡墙=%s 落回门区=%s%s" % [
				"OK " if ok else "BAD", src.get_file(), d["name"], d["id"], d["scene_path"].get_file(), pos,
				floor_24, stuck, inside, "" if dst_door != null else "  !!目标场景没有这个 id 的门"])
	print("DOOR TOUR DONE, bad = %d" % bad)
	tree.quit()

func _collect(n: Node, out: Array) -> void:
	if n.get("teleport_id") != null and n.get("scene_path") != null:
		out.append({"name": n.name, "id": n.teleport_id, "scene_path": n.scene_path})
	for c in n.get_children():
		_collect(c, out)

func _find_door(n: Node, id: int) -> Area2D:
	if n is Area2D and n.get("teleport_id") == id:
		return n
	for c in n.get_children():
		var r := _find_door(c, id)
		if r != null:
			return r
	return null

func _find_player(n: Node) -> CharacterBody2D:
	if n is Player:
		return n
	for c in n.get_children():
		var r := _find_player(c)
		if r != null:
			return r
	return null
