"""竞技场看台观众:远景小帽兜人,每种一行,三帧 = 手藏袍里 / 举一只拳 / 两只都举。
蹦跳在游戏里用位移做(脚底不动的规矩只管帧本身)。
    "~/Desktop/程序programs/AI Oscar"/.venv/bin/python build_crowd.py
输出:phage-0.0/levels/rust_arena/crowd/spectators.png(1 倍,格 9×15)+ 本目录预览。
"""
import sys
from pathlib import Path

OSCAR = Path.home() / "Desktop/程序programs/AI Oscar"
sys.path.insert(0, str(OSCAR))
import numpy as np  # noqa: E402
from oscarkit.canvas import Canvas  # noqa: E402
from oscarkit.palette import ramp  # noqa: E402
from oscarkit.shade import ragged_hem, top_light  # noqa: E402
from oscarkit.checks import check_image, report  # noqa: E402

HERE = Path(__file__).resolve().parent
GAME = Path.home() / "Project 2026/Phage/phage-0.0/levels/rust_arena/crowd"
CW, CH = 9, 15          # 每格
FOOT = CH - 1           # 脚底行

# 每种:袍子底色、身高、下摆宽、帽尖往哪歪、点缀色(围巾/帽檐一抹,None=没有)
KINDS = [
    ((88, 80, 92), 11, 7, 1, None),
    ((104, 74, 62), 12, 7, -1, (176, 132, 70)),
    ((84, 66, 96), 10, 6, 0, None),
    ((74, 82, 90), 12, 8, 1, (150, 72, 66)),
    ((112, 92, 72), 11, 7, 0, None),
    ((96, 70, 84), 13, 7, -1, (190, 150, 120)),
    ((70, 70, 78), 10, 7, 1, (120, 140, 120)),
    ((100, 84, 98), 12, 6, 0, None),
]


def draw(kind, pose, seed):
    base, h, w, lean, accent = kind
    R = ramp(base, n=5, L_span=0.30, hue_shift=8)
    c = Canvas(CW, CH)
    top = FOOT - h + 1
    cx = CW // 2
    half = w / 2
    # 剪影:尖帽兜 → 窄肩 → 往下摆开的袍子
    body = c.poly([(cx + lean, top), (cx + 2, top + 3), (cx + 2, top + 5),
                   (int(cx + half), FOOT), (int(cx - half + 0.5), FOOT),
                   (cx - 2, top + 5), (cx - 2, top + 3)])
    body = ragged_hem(body, depth=1, seed=seed)
    top_light(c, body, R, bands=0.9, rim=1, under=0, folds=[cx], seed=seed)
    # 帽兜口:最暗的一小块,不点眼睛(观众不是敌人,别和红眼帮派混)
    face_x = cx + (1 if lean >= 0 else -1)
    c.put(face_x, top + 3, R[0])
    c.put(face_x, top + 4, R[0])
    if accent is not None:
        for x in range(cx - 2, cx + 3):
            if c.mask[top + 5, x]:
                c.put(x, top + 5, accent)
    # 胳膊:从肩膀往上一根 1 格的线,拳头亮一档
    arm_dark, fist = R[1], R[4]
    sh = top + 4
    if pose >= 1:
        for y in range(sh - 3, sh + 1):
            c.put(cx + 3, y, arm_dark)
        c.put(cx + 3, sh - 4, fist)
    if pose >= 2:
        for y in range(sh - 3, sh + 1):
            c.put(cx - 3, y, arm_dark)
        c.put(cx - 3, sh - 4, fist)
    return c


def main():
    rows = []
    for k, kind in enumerate(KINDS):
        rows.append([draw(kind, p, seed=k * 7 + 1).a for p in range(3)])
    sheet = np.zeros((CH * len(KINDS), CW * 3, 4), np.uint8)
    for r, frames in enumerate(rows):
        for f, a in enumerate(frames):
            sheet[r * CH:(r + 1) * CH, f * CW:(f + 1) * CW] = a
    GAME.mkdir(parents=True, exist_ok=True)
    Canvas(sheet.shape[1], sheet.shape[0], sheet).save(GAME / "spectators.png")
    Canvas(sheet.shape[1], sheet.shape[0], sheet).save(HERE / "spectators_x8.png", scale=8)
    print(report(check_image(rows[1][0], "minimal"), "kind1 rest"))


if __name__ == "__main__":
    main()
