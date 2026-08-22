extends Node
class_name BossHealthUI

@export_group("Base UI Setup")
@export var health_bar_path: NodePath = ^"../CanvasLayer/HealthBar"
@export var health_label_path: NodePath = ^"../CanvasLayer/HealthLabel"
@export var fade_duration: float = 0.19
@export var base_tint: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var show_on_ready: bool = false
@export var auto_sync_from_parent: bool = true

@export_group("Hit Flash")
@export var hit_flash_tint: Color = Color(1.0, 0.7, 0.7, 1.0)
@export var hit_flash_in_duration: float = 0.06
@export var hit_flash_hold_duration: float = 0.06
@export var hit_flash_out_duration: float = 0.28
@export var hit_flash_scale: float = 1.12
@export var hit_flash_scale_in_duration: float = 0.04
@export var hit_flash_scale_out_duration: float = 0.10
@export var auto_flash_on_damage: bool = true

# ===== 新增：回血闪烁配置 =====
@export_group("Heal Flash")
@export var heal_flash_tint: Color = Color(0.4, 0.9, 0.4, 1.0)  # 回血变绿
@export var heal_flash_in_duration: float = 0.12
@export var heal_flash_hold_duration: float = 0.12
@export var heal_flash_out_duration: float = 0.65
@export var heal_flash_scale: float = 1.08
@export var heal_flash_scale_in_duration: float = 0.06
@export var heal_flash_scale_out_duration: float = 0.15
@export var auto_flash_on_heal: bool = true

var _health_bar: TextureProgressBar = null
var _health_label: RichTextLabel = null
var _ui_tween: Tween = null
var _flash_tween: Tween = null
var _last_health: int = -1
var _last_max_health: int = -1

func _ready() -> void:
	_resolve_nodes()
	if show_on_ready:
		show_ui(true)
	else:
		hide_ui()
	_sync_from_parent(true)

func _process(_delta: float) -> void:
	if not auto_sync_from_parent:
		return
	_sync_from_parent(false)

func refresh(health: int, max_health: int, trigger_flash: bool = false) -> void:
	if max_health <= 0:
		return
	var clamped_health := clampi(health, 0, max_health)
	var old_health := _last_health  # 在更新数值前，记录当前的旧血量
	
	if _health_bar != null:
		_health_bar.min_value = 0
		_health_bar.max_value = max_health
		_health_bar.value = clamped_health
	if _health_label != null:
		_health_label.text = "%d" % clamped_health
		
	_last_health = clamped_health
	_last_max_health = max_health
	
	if trigger_flash:
		if (_health_bar == null or not _health_bar.visible) and (_health_label == null or not _health_label.visible):
			show_ui(false)
		
		# 判断是回血还是受击：
		# 如果存在上一次的血量记录，且新血量大于旧血量，则执行绿闪；否则红闪
		if old_health >= 0 and clamped_health > old_health:
			flash_on_heal()  # 触发回血绿闪
		else:
			flash_on_hit()   # 触发受击红闪

# Boss 开场字卡用:从全透明快速淡入。show_ui(true) 的黑→灰调色渐变在
# 暗场景里看不出"渐显",这里走真正的 alpha 淡入。
func show_ui_fade(duration: float = 0.35) -> void:
	_resolve_nodes()
	_kill_tweens()
	var start_tint := Color(base_tint.r, base_tint.g, base_tint.b, 0.0)
	if _health_bar != null:
		_health_bar.visible = true
		_health_bar.scale = Vector2.ONE
		_health_bar.modulate = start_tint
	if _health_label != null:
		_health_label.visible = true
		_health_label.scale = Vector2.ONE
		_health_label.modulate = start_tint
	_ui_tween = create_tween()
	_ui_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _health_bar != null:
		_ui_tween.parallel().tween_property(_health_bar, "modulate", base_tint, duration)
	if _health_label != null:
		_ui_tween.parallel().tween_property(_health_label, "modulate", base_tint, duration)


func show_ui(animate: bool = true) -> void:
	_resolve_nodes()
	_kill_tweens()
	if _health_bar != null:
		_health_bar.visible = true
		_health_bar.scale = Vector2.ONE
	if _health_label != null:
		_health_label.visible = true
		_health_label.scale = Vector2.ONE
	if not animate:
		_set_ui_tint(base_tint)
		return
	_set_ui_tint(Color(0, 0, 0, 1.0))
	_ui_tween = create_tween()
	_ui_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _health_bar != null:
		_ui_tween.parallel().tween_property(_health_bar, "modulate", base_tint, fade_duration)
	if _health_label != null:
		_ui_tween.parallel().tween_property(_health_label, "modulate", base_tint, fade_duration)

func hide_ui(_animate: bool = false) -> void:
	_kill_tweens()
	if _health_bar != null:
		_health_bar.visible = false
		_health_bar.scale = Vector2.ONE
		_health_bar.modulate = base_tint
	if _health_label != null:
		_health_label.visible = false
		_health_label.scale = Vector2.ONE
		_health_label.modulate = base_tint

func flash_on_hit() -> void:
	if is_instance_valid(_ui_tween):
		_ui_tween.kill()
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	if (_health_bar == null or not _health_bar.visible) and (_health_label == null or not _health_label.visible):
		show_ui(false)
	_set_ui_tint(base_tint)
	_set_ui_scale(Vector2.ONE)
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "modulate", hit_flash_tint, hit_flash_in_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "modulate", hit_flash_tint, hit_flash_in_duration)
	var flash_scale := Vector2.ONE * maxf(1.0, hit_flash_scale)
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "scale", flash_scale, hit_flash_scale_in_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "scale", flash_scale, hit_flash_scale_in_duration)
	if hit_flash_hold_duration > 0.0:
		_flash_tween.tween_interval(hit_flash_hold_duration)
	_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "modulate", base_tint, hit_flash_out_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "modulate", base_tint, hit_flash_out_duration)
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "scale", Vector2.ONE, hit_flash_scale_out_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "scale", Vector2.ONE, hit_flash_scale_out_duration)

# ===== 新增：执行回血闪烁缓动 =====
func flash_on_heal() -> void:
	if is_instance_valid(_ui_tween):
		_ui_tween.kill()
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	if (_health_bar == null or not _health_bar.visible) and (_health_label == null or not _health_label.visible):
		show_ui(false)
	_set_ui_tint(base_tint)
	_set_ui_scale(Vector2.ONE)
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 颜色渐变至绿色
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "modulate", heal_flash_tint, heal_flash_in_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "modulate", heal_flash_tint, heal_flash_in_duration)
	
	# 微幅放大抖动（象征注入生命力的反馈）
	var flash_scale := Vector2.ONE * maxf(1.0, heal_flash_scale)
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "scale", flash_scale, heal_flash_scale_in_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "scale", flash_scale, heal_flash_scale_in_duration)
		
	if heal_flash_hold_duration > 0.0:
		_flash_tween.tween_interval(heal_flash_hold_duration)
		
	_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# 渐渐褪回默认颜色
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "modulate", base_tint, heal_flash_out_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "modulate", base_tint, heal_flash_out_duration)
	if _health_bar != null:
		_flash_tween.parallel().tween_property(_health_bar, "scale", Vector2.ONE, heal_flash_scale_out_duration)
	if _health_label != null:
		_flash_tween.parallel().tween_property(_health_label, "scale", Vector2.ONE, heal_flash_scale_out_duration)


func _sync_from_parent(force: bool) -> void:
	var host := get_parent()
	if host == null:
		return
	if not _has_property(host, "health") or not _has_property(host, "max_health"):
		return
	var current_health := int(host.get("health"))
	var current_max_health := int(host.get("max_health"))
	if current_max_health <= 0:
		return
	if force or current_max_health != _last_max_health:
		if _health_bar != null:
			_health_bar.min_value = 0
			_health_bar.max_value = current_max_health
	if force or current_health != _last_health:
		if _health_bar != null:
			_health_bar.value = clampi(current_health, 0, current_max_health)
		if _health_label != null:
			_health_label.text = "%d" % clampi(current_health, 0, current_max_health)
		
		# 判断血量变动情况：
		if not force and _last_health >= 0:
			if current_health < _last_health and auto_flash_on_damage:
				# 血量减少 -> 受击闪红
				flash_on_hit()
			elif current_health > _last_health and auto_flash_on_heal:
				# ===== 新增：血量上升 -> 回血闪绿 =====
				flash_on_heal()
				
	_last_health = current_health
	_last_max_health = current_max_health

func _resolve_nodes() -> void:
	if _health_bar == null:
		_health_bar = get_node_or_null(health_bar_path) as TextureProgressBar
		if _health_bar == null and get_parent() != null:
			_health_bar = get_parent().get_node_or_null(health_bar_path) as TextureProgressBar
	if _health_label == null:
		_health_label = get_node_or_null(health_label_path) as RichTextLabel
		if _health_label == null and get_parent() != null:
			_health_label = get_parent().get_node_or_null(health_label_path) as RichTextLabel

func _set_ui_tint(color: Color) -> void:
	if _health_bar != null:
		_health_bar.modulate = color
	if _health_label != null:
		_health_label.modulate = color

func _set_ui_scale(scale_value: Vector2) -> void:
	if _health_bar != null:
		_health_bar.scale = scale_value
	if _health_label != null:
		_health_label.scale = scale_value

func _kill_tweens() -> void:
	if is_instance_valid(_ui_tween):
		_ui_tween.kill()
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()

func _has_property(target: Object, property_name: String) -> bool:
	for property_data in target.get_property_list():
		if StringName(property_data.name) == property_name:
			return true
	return false
