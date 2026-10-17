extends Node
## 录像驱动:挂在 root 下跨场景存活,按 shot 表一步步"按键",配合 --write-movie 逐帧录。
## 命令:
##   ["scene", path, x, y]        直接换场景并把主角放到 (x,y)
##   ["wait", 秒]
##   ["walk", 目标x, 冲刺?]       按住方向走到 x;卡住自动跳
##   ["tap", action]              按一下
##   ["talkto", 最多几秒]         一直按 Q 直到对话框打开
##   ["hold", action] / ["release", action]
##   ["face", 1|-1]               原地转向(点一下方向)
##   ["talk", 每句停几秒, [第1次选项, 第2次...]]  对话开着就自动推进,弹选项就按顺序选
##   ["move", 节点名, x, y]       把场景里某个节点挪到指定位置
##   ["follow", 节点名, 跟在它后面几格, 秒]  跟着某个 NPC 走(点灯人带路)
##   ["god"]                      主角无敌
##   ["flag", 名, 值]
##   ["end"]

var shot: Array = []
var _scene_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/test/_tmp_capture/shot.json"))
	shot = cfg["steps"]
	for k: String in cfg.get("flags", {}):
		Story.set_flag(k, cfg["flags"][k])
	if cfg.get("truce", true):
		var gm: Script = load("res://entities/gang/gang_mob.gd")
		gm.set("truce", true)
	_run.call_deferred()


func _player() -> Node2D:
	var s := get_tree().current_scene
	if s == null:
		return null
	return s.get_node_or_null("Player") as Node2D


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(t: float) -> void:
	await _frames(int(round(t * 60.0)))


func _run() -> void:
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	for step: Array in shot:
		var cmd: String = step[0]
		match cmd:
			"scene":
				tree.change_scene_to_file(step[1])
				await _frames(2)
				while _player() == null:
					await tree.process_frame
				var p := _player()
				p.global_position = Vector2(step[2], step[3])
				p.velocity = Vector2.ZERO
				if p.has_method("set_lock"):
					p.set_lock(false)
				await _frames(1)
			"wait":
				await _secs(step[1])
			"walk":
				await _walk(float(step[1]), step.size() > 2 and step[2])
			"tap":
				Input.action_press(step[1])
				await _frames(2)
				Input.action_release(step[1])
			"hold":
				Input.action_press(step[1])
			"release":
				Input.action_release(step[1])
			"face":
				var a := "move_right" if int(step[1]) > 0 else "move_left"
				Input.action_press(a)
				await _frames(2)
				Input.action_release(a)
			"talkto":
				# 一直按 Q 直到对话框打开(NPC 在走动/附近有别的可交互时)
				var tries := 0
				while not Dialogue.is_open and tries < int(float(step[1]) / 0.25):
					Input.action_press("Select")
					await _frames(2)
					Input.action_release("Select")
					await _frames(13)
					tries += 1
			"talk":
				var picks: Array = step[2] if step.size() > 2 else [0]
				await _talk(float(step[1]), picks)
			"move":
				var n := get_tree().current_scene.find_child(step[1], true, false) as Node2D
				if n != null:
					n.global_position = Vector2(step[2], step[3])
			"flag":
				Story.set_flag(step[1], step[2])
			"god":
				# 主角无敌(混剪镜头里被管道局打两下没关系,别死)
				var gp := _player()
				if gp != null:
					gp.set("dev_god_mode", true)
			"follow":
				await _follow(step[1], float(step[2]), float(step[3]))
			"end":
				tree.quit()
				return
	tree.quit()


func _walk(tx: float, sprint: bool) -> void:
	var p := _player()
	var dir := "move_right" if tx > p.global_position.x else "move_left"
	var sgn := 1.0 if dir == "move_right" else -1.0
	Input.action_press(dir)
	var stuck := 0
	var last_x := p.global_position.x
	var sprint_cd := 0
	while (tx - p.global_position.x) * sgn > 1.0:
		await get_tree().process_frame
		p = _player()
		if p == null:
			break
		if absf(p.global_position.x - last_x) < 0.2:
			stuck += 1
		else:
			stuck = 0
		last_x = p.global_position.x
		if stuck > 4:
			Input.action_press("jump")
			await _frames(22)
			Input.action_release("jump")
			stuck = 0
		if sprint:
			sprint_cd -= 1
			if sprint_cd <= 0:
				Input.action_press("sprint")
				await _frames(2)
				Input.action_release("sprint")
				sprint_cd = 60
	Input.action_release(dir)


func _talk(hold: float, picks: Array) -> void:
	var pi := 0
	var waited := 0
	while not Dialogue.is_open and waited < 1200:
		await get_tree().process_frame
		waited += 1
	var closed := 0
	while closed < 45:
		if not Dialogue.is_open:
			closed += 1
			await get_tree().process_frame
			continue
		closed = 0
		var label: Label = Dialogue.get("_label")
		var panel: Control = Dialogue.get("_options_panel")
		if panel != null and panel.visible:
			await _secs(hold)
			Dialogue.emit_signal("_picked", int(picks[mini(pi, picks.size() - 1)]))
			pi += 1
			await _frames(2)
		elif label != null and label.visible_characters == -1:
			await _secs(hold)
			Dialogue.set("_advance", true)
			await _frames(2)
		else:
			await get_tree().process_frame


func _follow(node_name: String, gap: float, t: float) -> void:
	var n := get_tree().current_scene.find_child(node_name, true, false) as Node2D
	var frames := int(t * 60.0)
	var held := ""
	for i in frames:
		var p := _player()
		if n == null or p == null:
			break
		var want := n.global_position.x - gap
		var dx := want - p.global_position.x
		var a := ""
		if dx > 4.0:
			a = "move_right"
		elif dx < -12.0:
			a = "move_left"
		if a != held:
			if held != "":
				Input.action_release(held)
			if a != "":
				Input.action_press(a)
			held = a
		await get_tree().process_frame
	if held != "":
		Input.action_release(held)
