# =============================================================================
# player_jump_trail.gd — 跳跃像素残影拖尾
# =============================================================================
# 跟 penitent 镰刀(sickle_line_2d.gd)同款做法:每隔一小段就把主角当前帧复制成
# 一个淡出的 Sprite2D,天然像素化。挂在 Player 下,与 AnimatedSprite2D 同级。
# 由跳跃状态调用 set_active(true) 打开,落地(进 Idle/Run)时关闭。
# 残影直接用主角当前帧,所以拿盾时会自然显示带盾外壳。
# =============================================================================
extends Node2D

@export var interval: float = 0.035        # 每隔多久留一个残影
@export var ghost_lifetime: float = 0.25   # 残影淡出时长
@export var start_alpha: float = 0.45      # 残影初始不透明度
@export var tint: Color = Color(1, 1, 1, 1)

var active: bool = false
var _t: float = 0.0
@onready var _sprite: AnimatedSprite2D = get_node_or_null("../AnimatedSprite2D") as AnimatedSprite2D


func set_active(value: bool) -> void:
	active = value
	if not value:
		_t = 0.0
	elif value:
		_spawn_ghost()  # 起跳瞬间先留一帧,拖尾不断头


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(_sprite):
		return
	_t += delta
	if _t < interval:
		return
	_t = 0.0
	_spawn_ghost()


func _spawn_ghost() -> void:
	if not is_instance_valid(_sprite):
		return
	var frames := _sprite.sprite_frames
	if frames == null:
		return
	var tex := frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# 防图集相邻帧渗色:复制成 filter_clip 的 AtlasTexture。
	var draw_tex: Texture2D = tex
	if tex is AtlasTexture:
		var clipped := AtlasTexture.new()
		clipped.atlas = (tex as AtlasTexture).atlas
		clipped.region = (tex as AtlasTexture).region
		clipped.filter_clip = true
		draw_tex = clipped
	var g := Sprite2D.new()
	g.texture = draw_tex
	g.offset = _sprite.offset
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 残影加进场景根,z_index 是绝对值:用主角(父节点)的 z 作基准,排在主角身后一层。
	var owner_z := 0
	var p := get_parent()
	if p is Node2D:
		owner_z = (p as Node2D).z_index
	g.z_index = owner_z + _sprite.z_index - 1
	g.modulate = Color(tint.r, tint.g, tint.b, start_alpha)
	scene.add_child(g)
	g.global_transform = _sprite.global_transform  # 加进树后再对齐世界位置/朝向/缩放
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, ghost_lifetime)
	tw.tween_callback(g.queue_free)
