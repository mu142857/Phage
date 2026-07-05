# =============================================================================
# sickle_line_2d.gd  —  镰刀像素残影拖尾（挂在 SickleRoot/Node/Line2D 上）
# =============================================================================
# 原本用 Line2D 画矢量渐变带子，跟像素画风格不搭。改成「精灵残影」：每隔一小段
# 就在当前位置复制一份镰刀的当前帧(Sprite2D)，然后淡出——用的就是原始像素帧，
# 天然像素化。Line2D 本身不再画线（清空点、宽度 0）。
#
# 兼容：保留 point_count / is_spawn 两个旧导出名（不再使用），避免 tscn 里残留的
# 赋值报“property not found”。
# =============================================================================
extends Line2D

@export var interval: float = 0.035        # 每隔多久留一个残影
@export var ghost_lifetime: float = 0.22   # 残影淡出时长
@export var start_alpha: float = 0.5        # 残影初始不透明度
@export var tint: Color = Color(1, 1, 1, 1) # 想发红就设 (1.6, 0.5, 0.5, 1)
@export var only_while_spin: bool = true    # 只在飞行(Spin)时留残影

# —— 兼容旧 tscn 赋值，未使用 ——
@export var point_count: int = 0
@export var is_spawn: bool = true

var _t: float = 0.0
@onready var _sprite: AnimatedSprite2D = get_node_or_null("../../AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	clear_points()   # 不再画矢量线
	width = 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_sprite):
		return
	if only_while_spin and _sprite.animation != &"Spin":
		return
	_t += delta
	if _t < interval:
		return
	_t = 0.0
	_spawn_ghost()


func _spawn_ghost() -> void:
	var frames := _sprite.sprite_frames
	if frames == null:
		return
	var tex := frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# 防图集相邻帧渗色：复制成 filter_clip 的 AtlasTexture（把采样夹在本帧区域内，
	# 不会带出上一行那一帧最底下的一两像素）
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
	g.z_index = _sprite.z_index - 1
	g.modulate = Color(tint.r, tint.g, tint.b, start_alpha)
	scene.add_child(g)
	g.global_transform = _sprite.global_transform   # 加进树后再对齐世界位置/旋转/缩放
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, ghost_lifetime)
	tw.tween_callback(g.queue_free)
