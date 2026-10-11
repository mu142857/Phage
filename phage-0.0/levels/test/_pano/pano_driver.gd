extends Node
## 临时:每 N 帧把主角挪到下一个 x,录全景。
var xs: Array = []
var i := 0
var f := 0
func _ready() -> void:
	var x := 80.0
	while x <= 1600.0:
		xs.append(x); x += 140.0
func _process(_d: float) -> void:
	var p := get_parent().get_node_or_null("Player")
	if p == null: return
	if f % 30 == 0:
		if i >= xs.size():
			get_tree().quit(); return
		p.global_position = Vector2(xs[i], 70)
		print("X ", xs[i], " frame ", f)
		i += 1
	f += 1
