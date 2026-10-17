# 录视频素材:python3 capture.py 镜头名 [镜头名...]   (镜头表在 shots.py)
# 把 cap.gd + 镜头表放进 levels/test/_tmp_capture/,Godot movie 模式 60fps 逐帧录 160×90,
# 查冻帧(窗口被挡/熄屏会定格)自动重录,再按最近邻放大 12 倍压成 1920×1080 mp4。录完删临时目录。
import sys, os, json, shutil, subprocess, hashlib, tempfile, re
from shots import SHOTS

PROJ = "/Users/jiamulin/Project 2026/Phage/phage-0.0/"
HERE = os.path.dirname(os.path.abspath(__file__))
TMP = PROJ + "levels/test/_tmp_capture/"
OUT = "/Users/jiamulin/Project 2026/Phage/视频素材/铁锈城第一期/"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
FPS = 60


def strip_intro(res_path):
    """有 DreamIntro 的场景做一份去掉字卡的拷贝,返回新路径。"""
    src = open(PROJ + res_path[6:]).read()
    if 'node name="DreamIntro"' not in src:
        return res_path
    out, skip = [], False
    for ln in src.split("\n"):
        if ln.startswith("["):
            skip = ln.startswith('[node name="DreamIntro"') or 'parent="DreamIntro' in ln \
                or (ln.startswith("[connection") and "DreamIntro" in ln)
        if not skip:
            out.append(ln)
    name = "cap_" + os.path.basename(res_path)
    open(TMP + name, "w").write("\n".join(out))
    return "res://levels/test/_tmp_capture/" + name


def frozen(frames_dir, n, limit=1.5):
    """连续 1.5 秒以上完全相同的帧 = 冻了(镜头本身静止的段落用 allow_still 跳过检查)。"""
    run, last = 0, None
    for i in range(n):
        f = frames_dir + "/f%08d.png" % i
        if not os.path.exists(f):
            break
        h = hashlib.md5(open(f, "rb").read()).hexdigest()
        run = run + 1 if h == last else 0
        last = h
        if run > FPS * limit:
            return True
    return False


def capture(name):
    shot = SHOTS[name]
    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP)
    steps = []
    for st in shot["steps"]:
        if st[0] == "scene":
            st = [st[0], strip_intro(st[1])] + list(st[2:])
        steps.append(st)
    json.dump({"steps": steps, "flags": shot.get("flags", {}), "truce": shot.get("truce", True)},
              open(TMP + "shot.json", "w"), ensure_ascii=False)
    shutil.copy(HERE + "/cap.gd", TMP + "cap.gd")
    open(TMP + "boot.tscn", "w").write(
        '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://levels/test/_tmp_capture/cap.gd" id="1"]\n\n'
        '[node name="Boot" type="Node"]\nscript = ExtResource("1")\n')
    fr = os.path.join(tempfile.gettempdir(), "phage_cap_" + name)
    max_frames = int(shot["max_sec"] * FPS)
    ok = False
    # 录像分辨率 = 项目窗口尺寸(逻辑点)。临时 override.cfg 把窗口改成 960×540:canvas_items 下字按 6 倍渲染才清楚
    # (1920×1080 点的窗口比 Retina 屏 1512×982 点大,macOS 不画,全是冻帧;960×540 再最近邻 ×2 到 1080p)
    # (160×90 录再放大,中文字是在 160×90 里光栅化的,糊成一团)。录完马上删。
    ovr = PROJ + "override.cfg"
    open(ovr, "w").write("[display]\n\nwindow/size/window_width_override=960\nwindow/size/window_height_override=540\nwindow/size/mode=0\nwindow/dpi/allow_hidpi=true\n")
    for attempt in range(4):
        shutil.rmtree(fr, ignore_errors=True)
        os.makedirs(fr)
        subprocess.run([GODOT, "--path", PROJ, "res://levels/test/_tmp_capture/boot.tscn", "-t",
                        "--write-movie", fr + "/f.png", "--fixed-fps", str(FPS), "--quit-after", str(max_frames)],
                       stdout=open(fr + "/log.txt", "w"), stderr=subprocess.STDOUT)
        n = len([f for f in os.listdir(fr) if f.endswith(".png")])
        if not frozen(fr, n, 4.0 if shot.get("allow_still") else 1.5):
            ok = True
            break
        print(name, "冻帧,重录", attempt + 1)
    os.remove(ovr)
    os.makedirs(OUT, exist_ok=True)
    out = OUT + name + ".mp4"
    wav = [f for f in os.listdir(fr) if f.endswith(".wav")]
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", fr + "/f%08d.png"]
    if wav:
        cmd += ["-i", fr + "/" + wav[0]]
    cmd += ["-vf", "scale=1920:1080:flags=neighbor", "-c:v", "libx264", "-preset", "slow", "-crf", "14",
            "-pix_fmt", "yuv420p"]
    if wav:
        cmd += ["-c:a", "aac", "-b:a", "192k", "-shortest"]
    subprocess.run(cmd + [out])
    shutil.rmtree(TMP, ignore_errors=True)
    print(name, "ok" if ok else "可能冻帧", n, "帧", out, "日志", fr + "/log.txt")
    return fr


if __name__ == "__main__":
    for nm in sys.argv[1:]:
        capture(nm)
