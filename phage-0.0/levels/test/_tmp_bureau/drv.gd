extends Node2D

@export var mode := "war"
var t := 0.0
var _next := 0.0
var _deaths := []

func _ready() -> void:
	Story.buffs_owned = []
	BureauMob.pass_ok = mode == "war"
	for m in get_tree().get_nodes_in_group("monster"):
		if m is GangMob:
			(m as GangMob).died.connect(func(x: GangMob) -> void:
				_deaths.append("%.1f %s(%s)" % [t, x.name, x.faction()]))

func _physics_process(delta: float) -> void:
	t += delta
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.set("dev_god_mode", true)
	if t >= _next:
		_next += 1.0
		var s := "t=%.0f " % t
		for m in get_tree().get_nodes_in_group("monster"):
			if m is GangMob:
				var g := m as GangMob
				s += "%s:%d@%d[%s] " % [g.name, g.health, int(g.global_position.x), str(g.state)]
		print(s)
	if t > 30.0:
		print("DEATHS ", _deaths)
		get_tree().quit()
