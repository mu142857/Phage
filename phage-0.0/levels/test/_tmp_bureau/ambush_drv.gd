extends Node

var t := 0.0
var lvl: Node = null
var _cd := 0.0
var kills := 0

func _ready() -> void:
	Story.buffs_owned = []
	Story.flags = {}
	lvl = (load("res://levels/rust_city/back_alley/back_alley.tscn") as PackedScene).instantiate()
	add_child(lvl)

func _physics_process(delta: float) -> void:
	t += delta
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	p.set("dev_god_mode", true)
	if t > 0.5 and t < 1.0:
		p.global_position.x = 220.0
	_cd -= delta
	if _cd <= 0.0 and t > 2.0:
		_cd = 0.25
		var best: GangMob = null
		for m in get_tree().get_nodes_in_group("gang"):
			var g := m as GangMob
			if g != null and g.health > 0 and g.state != GangMob.S.FALL:
				if best == null or absf(g.global_position.x - p.global_position.x) < absf(best.global_position.x - p.global_position.x):
					best = g
		if best != null:
			p.global_position.x = best.global_position.x - 12.0
			best.take_damage(90)
			if best.health <= 0:
				kills += 1
	if int(t * 2) != int((t - delta) * 2) and int(t) % 5 == 0:
		print("t=%d kills=%d done=%s gang=%d" % [int(t), kills, str(Story.flag("back_alley_ambush_done")), get_tree().get_nodes_in_group("gang").size()])
	if Story.flag("back_alley_ambush_done") or t > 70.0:
		print("RESULT done=%s kills=%d t=%.1f coins=%d" % [str(Story.flag("back_alley_ambush_done")), kills, t, Story.coins])
		get_tree().quit()
