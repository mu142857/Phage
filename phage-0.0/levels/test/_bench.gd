extends Node
# 冲刺穿雾测试:主角站在喷射战士侦测范围外 → 按住右 + 能冲就冲 → 穿过雾柱 → 数被打中次数(dev 无敌下看 is_invincible 上升沿)
var cfg := {}
var _p: Player
var _s: Node
var _t := 0.0
var _phase := "wait"
var _phase_t := 0.0
var _runs := 0
var _hit_runs := 0
var _hits_this := 0
var _was_inv := false
var START_X := 12.0
var END_X := 150.0
const RUNS := 40

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2: cfg[kv[0]] = kv[1]
	Story.in_dream = true
	Story.buffs_owned = []

func _physics_process(delta: float) -> void:
	_t += delta
	if _p == null:
		_p = get_tree().get_first_node_in_group("player") as Player
		_s = get_tree().current_scene.get_node("Sprayer")
		if _p == null or _s == null: return
		_p.dev_god_mode = true
		_s.fogs_per_second = float(cfg.get("rate", "10"))
		_s.spread_degrees = float(cfg.get("spread", "30"))
		_s.fog_speed = Vector2(float(cfg.get("vmin", "30")), float(cfg.get("vmax", "210")))
		_s.only_when_player_near = cfg.get("always", "0") != "1"
		START_X = float(cfg.get("start", "12"))
		END_X = 150.0
		if cfg.has("det"):
			_s.detect_half_width = float(cfg["det"])
			_s.call("_apply_detect_width")
		_p.global_position = Vector2(START_X, 79)
		return
	var inv := _p.is_invincible
	if inv and not _was_inv and _phase == "run":
		_hits_this += 1
	_was_inv = inv
	_phase_t += delta
	match _phase:
		"wait":
			# 冷启动:侦测外站够久让喷雾停掉(linger 1.5)再冲;热启动(hot=1):先让它喷 2.5s 再冲
			var need := 2.6
			if _phase_t >= need:
				_phase = "run"; _phase_t = 0.0; _hits_this = 0
				Input.action_press(&"move_right")
		"run":
			if _p.can_sprint:
				Input.action_press(&"sprint")
			else:
				Input.action_release(&"sprint")
			if _p.global_position.x >= END_X or _phase_t > 4.0:
				Input.action_release(&"move_right"); Input.action_release(&"sprint")
				_runs += 1
				if _hits_this > 0: _hit_runs += 1
				_phase = "back"; _phase_t = 0.0
		"back":
			if _phase_t > 0.1:
				_p.global_position = Vector2(START_X, 79)
				_p.velocity = Vector2.ZERO
				if cfg.get("hot", "0") == "1":
					_s.set("_linger_left", 99.0)   # 让它一直喷着:模拟主角已经在旁边磨蹭过
				_phase = "wait"; _phase_t = 0.0
				if _runs >= RUNS:
					print("RESULT %s  hit_runs=%d/%d  fogs_alive=%d" % [cfg, _hit_runs, _runs, _count_fogs()])
					get_tree().quit()

func _count_fogs() -> int:
	var n := 0
	for c in get_tree().current_scene.get_children():
		if c is Area2D and c.has_method("_bounce_off"): n += 1
	return n
