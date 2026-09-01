# res://levels/remi's_room/clickable_item.gd
# 挂在物体 Sprite2D 下的 Area2D 上。CollisionPolygon2D 的区域在编辑器里手画。
# 悬停 → 自己提亮,房间里其他可点物体一起压暗(聚焦效果);移开 → 全体缓缓归零。
# 亮度走 highlight.gdshader 的乘法调节,逐通道钳到 0.99,永远不过泛光阈值。
# 点击 → 发出 clicked 信号(以后接文字/剧情用)。
class_name ClickableItem
extends Area2D

signal clicked(item: ClickableItem)

# 房间演出/对话期间整组关掉点击与悬停(remi_room.gd 控制)
static var interaction_enabled := true

const HIGHLIGHT_SHADER: Shader = preload("res://levels/remi's_room/highlight.gdshader")
const GROUP: StringName = &"remi_room_clickable"
# 非可点的背景节点(Background/Roof/WindowView/Ambience 等)加进这个组,
# 悬停任何物体时整组用 modulate 一起压暗 —— 变暗不会过泛光阈值,可以放心用 modulate。
const DIM_GROUP: StringName = &"remi_room_dimmable"

# 背景压暗 tween,按节点存,新的悬停会顶掉旧 tween
static var _dim_tweens: Dictionary = {}

# 当前被悬停的物体(全局唯一)。A→B 快速切换时,后到的 enter 接管,
# 迟到的 A 的 exit 发现自己已不是 active,就不会把 B 的状态清掉。
static var _active: ClickableItem = null

@export var target: CanvasItem = null                    # 留空 = 用父节点(物体 Sprite2D)
# 悬停自己时不跟着压暗的背景节点(比如窗户豁免 WindowView:窗外夜空是窗户的一部分)
@export var exempt_nodes: Array[NodePath] = []
# 跟着 target 一起提亮/压暗的附属视觉(比如窗户的 WindowView:窗外和窗框同呼吸)。
# 附属节点会被挂上同款高亮材质,其无材质的子孙自动 use_parent_material 继承。
@export var extra_brighten: Array[NodePath] = []
@export_range(0.0, 1.0) var hover_strength: float = 0.3  # 悬停时自己提亮多少
@export_range(0.0, 1.0) var dim_strength: float = 0.5    # 别人被悬停时自己压暗多少
@export var rise_time: float = 0.15
@export var fall_time: float = 0.35

var _tween: Tween = null
var _amount: float = 0.0  # 当前亮度值(tween 起点)
var _extra_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	add_to_group(GROUP)
	if target == null:
		target = get_parent() as CanvasItem
	if is_instance_valid(target):
		if target.material == null:
			var mat := ShaderMaterial.new()
			mat.shader = HIGHLIGHT_SHADER
			target.material = mat
		elif not (target.material is ShaderMaterial and (target.material as ShaderMaterial).shader == HIGHLIGHT_SHADER):
			push_warning("ClickableItem: %s 已有别的材质,悬停提亮不会生效" % target.name)
	for path in extra_brighten:
		var node := get_node_or_null(path) as CanvasItem
		if node == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = HIGHLIGHT_SHADER
		node.material = mat
		_inherit_material_recursive(node)
		_extra_materials.append(mat)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# 无材质的子孙统一继承附属节点的高亮材质
func _inherit_material_recursive(node: Node) -> void:
	for child in node.get_children():
		var canvas := child as CanvasItem
		if canvas != null and canvas.material == null:
			canvas.use_parent_material = true
		_inherit_material_recursive(child)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not interaction_enabled or Dialogue.is_open:
		return
	# 触屏按钮压住的位置不响应(玩家是在按按钮,不是点物品)
	if TouchControls.covers(get_viewport().get_mouse_position()):
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		clicked.emit(self)

func _on_mouse_entered() -> void:
	if not interaction_enabled or Dialogue.is_open:
		return
	# 触屏按钮压住的位置不响应悬停(物理拾取的悬停拦不住事件,只能在这儿挡)
	if TouchControls.covers(get_viewport().get_mouse_position()):
		return
	_active = self
	_tween_highlight(hover_strength, rise_time)
	for item: ClickableItem in get_tree().get_nodes_in_group(GROUP):
		if item != self:
			item._tween_highlight(-item.dim_strength, rise_time)
	_dim_background(dim_strength, rise_time)

func _on_mouse_exited() -> void:
	if _active != self:
		return  # 已经有新的物体被悬停,状态归它管
	_active = null
	for item: ClickableItem in get_tree().get_nodes_in_group(GROUP):
		item._tween_highlight(0.0, item.fall_time)
	_dim_background(0.0, fall_time)

func _dim_background(amount: float, duration: float) -> void:
	var exempt: Array[CanvasItem] = []
	for path in exempt_nodes:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			exempt.append(node)
	for node: CanvasItem in get_tree().get_nodes_in_group(DIM_GROUP):
		# 豁免节点保持原亮(可能正处于上一次悬停的压暗中,所以也要 tween 回 1.0)
		var v := 1.0 if node in exempt else 1.0 - amount
		var prev: Tween = _dim_tweens.get(node)
		if prev != null and prev.is_running():
			prev.kill()
		var tween := node.create_tween()
		tween.tween_property(node, "modulate", Color(v, v, v, 1.0), duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_dim_tweens[node] = tween

func _tween_highlight(amount: float, duration: float) -> void:
	if not is_instance_valid(target) or not (target.material is ShaderMaterial):
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_amount, _amount, amount, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _apply_amount(value: float) -> void:
	_amount = value
	(target.material as ShaderMaterial).set_shader_parameter(&"highlight_amount", value)
	for mat in _extra_materials:
		mat.set_shader_parameter(&"highlight_amount", value)
