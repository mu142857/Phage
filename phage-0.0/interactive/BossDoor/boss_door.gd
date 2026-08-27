extends StaticBody2D

## Boss 门:Boss 不死不开。
## 挂在 StaticBody2D 上,子节点 Sprite2D(门贴图) + CollisionShape2D(门形状),
## 可选子节点 BreakEffect(GPUParticles2D)在开门时爆一次。
## 盯着 boss_path 指向的 Boss,节点被释放(死亡)即开门(关碰撞+淡出)。
## 开门状态用 MapElementCounting 记账,同一次运行内重进场景门不会复活;
## door_state_id 留空则不记账,每次进场景都重新关门。
@export var boss_path: NodePath
@export var door_state_id: StringName = &""
@export var open_fade_time: float = 0.4
## false = 场景加载时门就立着(默认)。
## true = 平时没有这扇门,Boss 现身(战吼揭幕 visible 变 true)那一刻
## 悄悄浮现,适合开打后封住入口的门。
@export var appear_with_boss: bool = false
@export var appear_fade_time: float = 0.5

var _boss: Node = null


func _ready() -> void:
	if door_state_id != &"" and not MapElementCounting.is_wall_intact(door_state_id):
		queue_free()
		return
	_boss = get_node_or_null(boss_path)
	if _boss == null:
		push_warning("BossDoor '%s' 找不到 boss_path 指向的节点,门保持关闭。" % name)
		return
	if appear_with_boss:
		visible = false
		modulate.a = 0.0
		_set_collision_enabled(false)
		await _wait_boss_visible()
		if not is_inside_tree():
			return
		if is_instance_valid(_boss):
			_appear()
	_watch_boss()


# 等 Boss 揭幕。先空等几帧再开始盯:自带出场编排的 Boss(如丝虫破土)
# 要在第一两帧之后才把自己的 Sprite 藏起来,立刻判定会误当成已现身。
func _wait_boss_visible() -> void:
	for i in 3:
		await get_tree().process_frame
	while is_inside_tree() and is_instance_valid(_boss):
		if _boss_revealed():
			return
		await get_tree().process_frame


# 现身判定:根节点可见还不够,像丝虫这类 Boss 藏的是自己的 AnimatedSprite2D。
func _boss_revealed() -> bool:
	var boss_canvas := _boss as CanvasItem
	if boss_canvas == null:
		return true
	if not boss_canvas.is_visible_in_tree():
		return false
	var sprite := _boss.get_node_or_null(^"AnimatedSprite2D") as CanvasItem
	if sprite != null and not sprite.visible:
		return false
	return true


func _appear() -> void:
	visible = true
	_set_collision_enabled(true)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, appear_fade_time)


func _watch_boss() -> void:
	while is_inside_tree() and is_instance_valid(_boss):
		await get_tree().process_frame
	if is_inside_tree():
		_open()


func _open() -> void:
	if door_state_id != &"":
		MapElementCounting.mark_wall_broken(door_state_id)
	# 从未现身的门(appear_with_boss 且没等到揭幕)直接消失,不放特效
	if not visible:
		queue_free()
		return
	_spawn_break_effect()
	_set_collision_enabled(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, open_fade_time)
	tween.tween_callback(queue_free)


func _set_collision_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not enabled)


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
