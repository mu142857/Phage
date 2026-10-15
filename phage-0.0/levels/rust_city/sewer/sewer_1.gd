# 下水道第一段【过段费】:从主街井盖跳下来,井盖在头顶合上,一片漆黑——
# 黑暗里一个声音:"站住。交钱。" 灯一盏盏亮起来:检查站、稽查员、两个戟卫、铁栅门。
extends SewerRoom

@export var lamps: Array[NodePath] = []

var _cm: CanvasModulate = null


func _setup() -> void:
	if Story.flag("sewer_intro_done"):
		return
	_cm = _find_canvas_modulate()
	var target := _cm.color if _cm != null else Color.WHITE
	var lights: Array = []
	for p in lamps:
		var l := get_node_or_null(p) as PointLight2D
		if l != null:
			l.enabled = false
			lights.append(l)
	if _cm != null:
		_cm.color = Color(0.02, 0.02, 0.025)
	_intro(lights, target)


func _intro(lights: Array, target: Color) -> void:
	Talk.begin()
	await get_tree().create_timer(0.9).timeout
	await Dialogue.say(["站住。", "交钱。"], "？？？")
	for l in lights:
		(l as PointLight2D).enabled = true
		Game.shake_camera(0.6)
		await get_tree().create_timer(0.28).timeout
	if _cm != null:
		var tw := create_tween()
		tw.tween_property(_cm, "color", target, 0.5)
		await tw.finished
	Story.set_flag("sewer_intro_done")
	Talk.end()


func _find_canvas_modulate() -> CanvasModulate:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for c in scene.get_children():
		if c is CanvasModulate:
			return c
	return null


func _fee_lines() -> Array:
	return [["稽查员", "你交的是上面的钱。"], ["稽查员", "这一段，另算。"]]


func _refuse_options(can_pay: bool) -> Array:
	return ["凭什么", "没钱了"] if can_pay else ["没钱了", "凭什么"]


func _refused_reply(idx: int, can_pay: bool) -> Array:
	var opts := _refuse_options(can_pay)
	return ["那就打。"] if opts[idx] == "没钱了" else ["凭我在这儿。"]
