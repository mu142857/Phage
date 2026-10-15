extends Node
## 临时:室内测试——打光帮派 → 钱袋;捡藏的铜板;重进一次看不复活/不重刷;捷径门锁。
const ROOMS := ["tenement_passage", "market_storage", "scrap_warehouse", "home_robbed_a", "home_robbed_b", "gang_den"]
var tree: SceneTree

func _ready() -> void:
	tree = get_tree()
	call_deferred("_go")

func _wait(n: int) -> void:
	for i in n:
		await tree.physics_frame

func _player() -> CharacterBody2D:
	return tree.current_scene.get_node("Player")

func _go() -> void:
	get_parent().remove_child(self)
	tree.root.add_child(self)
	Story.buffs_owned = []
	for r in ROOMS:
		var path := "res://levels/rust_city/interiors/%s/%s.tscn" % [r, r]
		tree.change_scene_to_file(path)
		await _wait(40)
		var p := _player()
		p.set("dev_god_mode", true)
		var c0: int = Story.coins
		var people := tree.current_scene.get_node("People")
		var gang := people.get_node_or_null("Gang")
		var n_mobs := 0
		if gang:
			for m in gang.get_children().duplicate():
				if is_instance_valid(m) and m is GangMob and m.health > 0:
					n_mobs += 1
					m.health = 0
					m._die()
		await _wait(150)
		var c_bag: int = Story.coins - c0
		# 捡藏的铜板
		var stash := people.get_node_or_null("Stash")
		var n_stash := 0
		if stash:
			for m in stash.get_children().duplicate():
				if is_instance_valid(m) and m is Marker2D:
					n_stash += 1
					p.global_position = (m as Marker2D).global_position + Vector2(0, 2)
					p.velocity = Vector2.ZERO
					await _wait(25)
		await _wait(10)
		var c1: int = Story.coins
		# 重进:不该再有活着的帮派、不该再掉钱袋、藏的铜板不该再出现
		tree.change_scene_to_file(path)
		await _wait(60)
		var alive := 0
		var g2 := tree.current_scene.get_node("People").get_node_or_null("Gang")
		if g2:
			for m in g2.get_children():
				if is_instance_valid(m) and m is GangMob and not m.is_queued_for_deletion():
					alive += 1
		var coins_left := 0
		var s2 := tree.current_scene.get_node("People").get_node_or_null("Stash")
		if s2:
			for n in s2.get_children():
				if is_instance_valid(n) and not (n is Marker2D):
					coins_left += 1
		print("ROOM %s mobs=%d  bag+mob_coins=%d  stash=%d picked=%d  | reenter alive=%d stash_coins=%d  coins_total=%d" % [
			r, n_mobs, c_bag, n_stash, c1 - c0 - c_bag, alive, coins_left, Story.coins])
	# 捷径门:一开始锁着
	tree.change_scene_to_file("res://levels/rust_city/boiler_alley/boiler_alley.tscn")
	await _wait(30)
	var door := tree.current_scene.get_node("ToWarehouse")
	print("SHORTCUT before: locked=", door.is_locked())
	Story.set_flag("shortcut_warehouse_boiler", false)
	tree.change_scene_to_file("res://levels/rust_city/interiors/scrap_warehouse/scrap_warehouse.tscn")
	await _wait(30)
	var p2 := _player()
	p2.global_position = Vector2(308, 76)
	await _wait(20)
	Input.action_press("Select"); await _wait(2); Input.action_release("Select")
	await _wait(80)
	print("SHORTCUT after: scene=", tree.current_scene.scene_file_path.get_file(), " flag=", Story.flag("shortcut_warehouse_boiler"), " locked=", tree.current_scene.get_node("ToWarehouse").is_locked())
	tree.quit()
