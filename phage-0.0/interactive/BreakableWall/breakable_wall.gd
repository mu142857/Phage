extends Node2D

@export var wall_id: StringName = &""
@export var wall_size: Vector2 = Vector2(16.0, 16.0)
@export var wall_color: Color = Color(0.36, 0.30, 0.25, 1.0)
@export var health: int = 1

var _is_broken: bool = false
var _resolved_wall_id: StringName = &""

@onready var solid_body: StaticBody2D = $SolidBody2D
@onready var damage_area: Area2D = $DamageArea2D
@onready var visual: Polygon2D = $Visual
@onready var solid_shape: CollisionShape2D = $SolidBody2D/CollisionShape2D
@onready var damage_shape: CollisionShape2D = $DamageArea2D/CollisionShape2D


func _ready() -> void:
	add_to_group("breakable_wall")
	_resolved_wall_id = _resolve_wall_id()
	_apply_geometry()
	_set_broken(not MapElementCounting.is_wall_intact(_resolved_wall_id))


func take_damage(amount: int) -> void:
	if _is_broken:
		return
	health -= amount
	if health <= 0:
		break_wall()


func break_wall() -> void:
	if _is_broken:
		return
	MapElementCounting.mark_wall_broken(_resolved_wall_id)
	_set_broken(true)


func restore_wall() -> void:
	MapElementCounting.mark_wall_restored(_resolved_wall_id)
	_set_broken(false)


func _resolve_wall_id() -> StringName:
	if wall_id != &"":
		return wall_id
	return StringName(str(get_path()))


func _apply_geometry() -> void:
	if is_instance_valid(visual):
		visual.color = wall_color
		var half_size := wall_size * 0.5
		visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])
	if is_instance_valid(solid_shape) and solid_shape.shape is RectangleShape2D:
		(solid_shape.shape as RectangleShape2D).size = wall_size
	if is_instance_valid(damage_shape) and damage_shape.shape is RectangleShape2D:
		(damage_shape.shape as RectangleShape2D).size = wall_size


func _set_broken(broken: bool) -> void:
	_is_broken = broken
	if is_instance_valid(visual):
		visual.visible = not broken
	if is_instance_valid(solid_shape):
		solid_shape.disabled = broken
	if is_instance_valid(damage_shape):
		damage_shape.disabled = broken
	if is_instance_valid(damage_area):
		damage_area.monitoring = not broken
		damage_area.monitorable = not broken
