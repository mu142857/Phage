from pxlib import *

def build(seed=3):
    W, H = 62, 96
    c = Canvas(W, H, seed)
    L, R, TOP = 2, 59, 14
    c.wall(L, TOP, R, H - 1, OCHRE, base=2.7, spread=3.0, scale=10)
    c.stains(L, TOP, R, H - 1, 22, RUST[1], r=6, t=0.55)
    c.rust_band(L, R, TOP, 7)
    # 屋顶:女儿墙 + 檐口
    c.rect(L - 1, TOP - 3, R + 1, TOP - 1, OCHRE[2])
    c.hline(L - 1, R + 1, TOP - 3, OCHRE[5])
    c.hline(L - 1, R + 1, TOP - 1, OCHRE[1])
    for x in range(L, R + 1, 3):
        c.set(x, TOP, OCHRE[1]); c.set(x, TOP + 1, OCHRE[1])
    # 烟囱
    c.wall(7, 2, 12, TOP - 4, BRICK, base=3, spread=1.5, scale=2)
    c.hline(6, 13, 2, STONE[4]); c.hline(6, 13, 3, STONE[2])
    c.set(9, 1, STONE[1]); c.set(10, 1, STONE[1])
    # 水箱(木桶上架子)
    c.wall(42, 1, 53, 8, [WOOD_D, WOOD, WOOD_L, (120, 80, 56)], base=1.6, spread=1.0, scale=2)
    for y in (2, 5, 8):
        c.hline(42, 53, y, IRON_D)
    c.hline(41, 54, 0, WOOD_D)
    c.set(43, 9, IRON_D); c.set(43, 10, IRON_D); c.set(52, 9, IRON_D); c.set(52, 10, IRON_D)
    c.set(47, 9, IRON_D); c.set(48, 10, IRON_D)
    # 楼层线
    floors = [34, 54, 74]
    for y in floors:
        c.ledge(L, R, y)
        c.rust_band(L, R, y + 2, 5)
        c.drips(L, R, y + 3, 12, maxlen=9)
    # 左半窗户
    lit = {(0, 1), (2, 0)}
    for fi, ftop in enumerate([TOP + 1, 36, 56]):
        for wi, wx in enumerate([6, 17]):
            c.window(wx, ftop + 6, 6, 8, lit=(fi, wi) in lit, shutter=None if fi != 1 else (88, 102, 86))
    # 消防梯(右半)
    FX0, FX1 = 30, R + 1
    # 梯后面的窗/门
    c.window(40, TOP + 7, 6, 8)
    c.door(50, 22, 5, 12, color=(70, 72, 60), knob=True, step=False)    # 顶层平台上那扇门(以后可进)
    c.window(36, 42, 6, 8, lit=True)
    c.window(50, 42, 6, 8)
    c.window(42, 62, 6, 8)
    for y in floors:
        c.railing(FX0, FX1, y, h=5)
        c.bracket(FX0, y + 2, 4)
        c.drips(FX0, FX1, y + 2, 5, maxlen=9, color=RUST[0])
    c.stair(33, 73, 52, 55)
    c.stair(56, 53, 37, 35)
    # 搭在栏杆上晾的床单
    sheet = (150, 152, 140)
    for x in range(34, 41):
        for y in range(29, 29 + 6 + (x % 2)):
            c.set(x, y, sheet if (x + y) % 5 else shade(sheet, 0.8))
    c.hline(34, 40, 29, shade(sheet, 1.15))
    rug = (120, 52, 44)
    for x in range(46, 51):
        for y in range(49, 57):
            c.set(x, y, rug if (y % 3) else (176, 119, 58))
    # 底层:双开门 + 小铺面窗
    c.door(7, 83, 8, 12, color=WOOD, double=True)
    c.window(20, 82, 7, 8, lit=True, cross=False, sill=WOOD_L)
    c.rect(19, 79, 28, 80, (96, 44, 36)); c.hline(19, 28, 79, (128, 66, 50))   # 小雨棚
    c.window(46, 82, 6, 8)
    c.drainpipe(27, TOP - 2, H - 2)
    c.grime_bottom(L, R, H - 1, 9, k=0.5)
    # 墙身两侧竖边阴影(立体)
    for y in range(TOP, H):
        c.darken(R, y, 0.6); c.darken(R - 1, y, 0.8); c.tint(L, y, OCHRE[5], 0.3)
    return c

if __name__ == "__main__":
    build().save("out/house_ochre.png", scale=6)
