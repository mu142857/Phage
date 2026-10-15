import sys
from PIL import Image
def sheet(ims, out, scale=5, bg=(60, 58, 62, 255)):
    from pxlib import Canvas
    ims = [i.im if isinstance(i, Canvas) else i for i in ims]
    ims = [i.convert("RGBA") for i in ims]
    W = sum(i.width + 3 for i in ims); H = max(i.height for i in ims)
    c = Image.new("RGBA", (W, H), bg); x = 0
    for i in ims:
        c.alpha_composite(i, (x, H - i.height)); x += i.width + 3
    c.resize((W * scale, H * scale), Image.NEAREST).save(out)
