extends StaticBody2D

## Boss 门:Boss 不死不开。
## 挂在 StaticBody2D 上,子节点 Sprite2D(门贴图) + CollisionShape2D(门形状)。
## 盯着 boss_path 指向的 Boss,节点被释放(死亡)即开门(关碰撞+淡出)。
## 开门状态用 MapElementCounting 记账,同一次运行内重进场景门不会复活;
## door_state_id 留空则不记账,每次进场景都重新关门。
@export var boss_path: NodePath
@export var door_state_id: StringName = &""
@export var open_fade_time: float = 0.4

var _boss: Node = null


func _ready() -> void:
	if door_state_id != &"" and not MapElementCounting.is_wall_intact(door_state_id):
		queue_free()
		return
	_boss = get_node_or_null(boss_path)
	if _boss == null:
		_open()
		return
	_watch_boss()


func _watch_boss() -> void:
	while is_inside_tree() and is_instance_valid(_boss):
		await get_tree().process_frame
	if is_inside_tree():
		_open()


func _open() -> void:
	if door_state_id != &"":
		MapElementCounting.mark_wall_broken(door_state_id)
	_spawn_break_effect()
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, open_fade_time)
	tween.tween_callback(queue_free)


# 开门粒子(可选):有名为 BreakEffect 的 GPUParticles2D 子节点就播。
# 复制一份挂到场景根再发射,不跟着门一起被释放(broken_wall 同款做法)。
func _spawn_break_effect() -> void:
	var template := get_node_or_null(^"BreakEffect") as GPUParticles2D
	if template == null:
		return
	if get_tree().current_scene == null:
		return
	var effect := template.duplicate() as GPUParticles2D
	if effect == null:
		return
	effect.one_shot = true
	effect.emitting = true
	get_tree().current_scene.add_child(effect)
	effect.global_position = template.global_position
	effect.finished.connect(effect.queue_free)
