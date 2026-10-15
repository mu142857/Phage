# 渲染工具:python3 render.py res://scene.tscn out.png x1,x2,... [py] [scale] [strip|grid]
# 在 levels/test/_tmp_render/ 建临时场景(去掉 DreamIntro/CityStory),逐点放主角,录 movie,取帧拼图。
import sys, os, subprocess, hashlib, shutil
from PIL import Image
PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
S = os.path.dirname(os.path.abspath(__file__))
scene, out, xs = sys.argv[1], sys.argv[2], [float(v) for v in sys.argv[3].split(",")]
py = float(sys.argv[4]) if len(sys.argv) > 4 else 70
scale = int(sys.argv[5]) if len(sys.argv) > 5 else 3
mode = sys.argv[6] if len(sys.argv) > 6 else "strip"
TMP = PROJ + "levels/test/_tmp_render/"
os.makedirs(TMP, exist_ok=True)
open(TMP + "drv.gd", "w").write('''extends Node
@export var xs: Array = []
@export var py := 70.0
var i := -1
var f := 0
func _process(_d: float) -> void:
	var p := get_parent().get_node_or_null("Player")
	if p == null: return
	if f % 40 == 0:
		i += 1
		if i >= xs.size():
			get_tree().quit(); return
	if f % 40 < 3:
		p.global_position = Vector2(xs[i], py)
		p.velocity = Vector2.ZERO
	f += 1
''')
src = open(PROJ + scene[6:]).read()
lines = []; skip = False
for ln in src.split("\n"):
    if ln.startswith("["):
        skip = ln.startswith('[node name="DreamIntro"') or ln.startswith('[node name="CityStory"') or 'parent="CityStory' in ln or 'parent="DreamIntro' in ln or (ln.startswith("[connection") and ("CityStory" in ln or "DreamIntro" in ln))
    if not skip: lines.append(ln)
s = "\n".join(lines)
i = s.index("[sub_resource") if "[sub_resource" in s else s.index("[node")
s = s[:i] + '[ext_resource type="Script" path="res://levels/test/_tmp_render/drv.gd" id="999_r"]\n\n' + s[i:]
s += '\n[node name="Drv" type="Node" parent="."]\nscript = ExtResource("999_r")\nxs = [%s]\npy = %s\n' % (", ".join(str(x) for x in xs), py)
open(TMP + "r.tscn", "w").write(s)
fr_dir = S + "/_frames"
for attempt in range(4):
    shutil.rmtree(fr_dir, ignore_errors=True); os.makedirs(fr_dir)
    subprocess.run(["/Applications/Godot.app/Contents/MacOS/Godot", "--path", PROJ, "res://levels/test/_tmp_render/r.tscn", "-t",
                    "--write-movie", fr_dir + "/f.png", "--fixed-fps", "30", "--quit-after", str(40 * len(xs) + 20)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    frames = [Image.open(fr_dir + "/f%08d.png" % (40 * k + 38)).convert("RGB") for k in range(len(xs))]
    uniq = len(set(hashlib.md5(f.tobytes()).hexdigest() for f in frames))
    if uniq == len(xs) or len(xs) == 1:
        break
    print("frozen, retry", attempt)
if mode == "strip":
    c = Image.new("RGB", (160 * len(frames), 90))
    for k, f in enumerate(frames): c.paste(f, (160 * k, 0))
else:
    cols = 2; rows = (len(frames) + 1) // 2
    c = Image.new("RGB", (164 * cols, 92 * rows), (255, 0, 255))
    for k, f in enumerate(frames): c.paste(f, ((k % cols) * 164, (k // cols) * 92))
c.resize((c.width * scale, c.height * scale), Image.NEAREST).save(out)
shutil.rmtree(TMP, ignore_errors=True)
print("ok", out, "uniq", uniq)
