extends Node2D 

@export var camera_limit_top: int = 0
@export var camera_limit_bottom: int = 90
@export var camera_limit_left: int = -80
@export var camera_limit_right: int = 1600
## 楼整体压暗,让主角和 NPC 从楼前面跳出来(1 = 不压)。
@export var buildings_brightness: float = 0.72

# 主角的 PointLight2D 默认照 light_mask 第 1 位的东西。楼挪到第 3 位(值 4),
# 主角的光就照不到楼,身后那块墙不会被照成全屏最亮。路灯本来就只照第 2 位,不受影响。
const BUILDING_LIGHT_MASK := 4


func _ready() -> void:
	add_to_group("camera_follow")
	_dim_buildings()


func _dim_buildings() -> void:
	var buildings := get_node_or_null("Buildings") as CanvasItem
	if buildings == null:
		return
	buildings.modulate = Color(buildings_brightness, buildings_brightness, buildings_brightness)
	for item in buildings.find_children("*", "CanvasItem", true, false):
		# 路灯贴图(light_mask=2,要被自己的灯照亮)和灯本身不动
		if item is PointLight2D or (item as CanvasItem).light_mask != 1:
			continue
		(item as CanvasItem).light_mask = BUILDING_LIGHT_MASK

func get_camera_limits() -> Dictionary:
	return {
		"left": camera_limit_left,
		"right": camera_limit_right,
		"top": camera_limit_top,
		"bottom": camera_limit_bottom,
	}
