#!/usr/bin/env python3
"""Generates placeholder pixel art (skill icons + sprites) from ASCII drawings.

Every drawing gets an automatic 1-px dark outline, which is the main trait of
the target style (chunky readable silhouettes). Output:
  game/assets/gen/atlas.png + atlas.json   (used by the game)
  docs/img/skill_icons.png                  (preview sheet for the docs)

Run: python3 tools/art_gen.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUTLINE = (26, 16, 32, 255)
CELL = 16

# Shared colour letters. A drawing may override any of them.
COLORS = {
    "k": "#3a2a4a", "m": "#8f8fb0", "y": "#ffd34d", "Y": "#ffbf3d", "w": "#fffbe8",
    "o": "#ffa040", "b": "#6a3d22", "B": "#a0663a", "n": "#d9a066", "t": "#f0c890",
    "c": "#7ad0ff", "d": "#3a7acc", "g": "#7fd67a", "G": "#3f9a52", "r": "#ff5a5a",
    "p": "#ff8cf0", "l": "#5a5a6e", "S": "#7a4a2e", "s": "#b07a4a", "f": "#f0c89a",
    "e": "#ffffff", "a": "#ffe066", "A": "#c9a020", "x": "#cfe8ff", "v": "#d0a8ff",
}

ICONS = {
    "lantern": ["...lll...", "..l...l..", "...lll...", ".mmmmmmm.", ".myyyyym.", ".myywyym.",
                ".mywwwym.", ".myywyym.", ".myyyyym.", ".mmmmmmm.", "...mmm..."],
    "slingshot": ["B.......B", "BB.....BB", ".BwwwwwB.", ".B.....B.", "..B...B..", "...B.B...",
                  "....B....", "....B....", "....B....", "...BBB..."],
    "jar": ["..mmmmm..", "..lllll..", ".cxxxxxc.", "cxxyxxxxc", "cxyyyxxyc", "cxxyxxyyc",
            "cxxxxxyxc", "cxxxxxxxc", ".ccccccc."],
    "jars": [".mmm...mmm.", ".lll...lll.", "cxxxc.cxxxc", "cxyxc.cxyxc", "cyyyc.cxyyc",
             "cxyxc.cxxxc", ".ccc...ccc."],
    "target": ["...rrrrr...", "..rwwwwwr..", ".rwrrrrrwr.", "rwrwwwwwrwr", "rwrwrrrwrwr",
               "rwrwryrwrwr", "rwrwrrrwrwr", "rwrwwwwwrwr", ".rwrrrrrwr.", "..rwwwwwr..", "...rrrrr..."],
    "dice": [".wwwwwwwww.", "wwwwwwwwwww", "wwkwwwwwkww", "wwwwwwwwwww", "wwwwwkwwwww",
             "wwwwwwwwwww", "wwkwwwwwkww", "wwwwwwwwwww", ".wwwwwwwww."],
    "pick": ["..mmmmmmm...", ".mm.....mm..", "m....BB...mm", ".....BB....y", ".....BB.....",
             ".....BB.....", ".....BB.....", ".....BB.....", ".....BB....."],
    "bolt": [".....yyy", "....yyy.", "...yyy..", "..yyyyyy", ".....yy.", "....yy..", "...yy...",
             "..yy....", ".y......"],
    "chain": ["mm.......", "m.m......", ".mmm.....", "..m.m....", "...mmm...", "....m.m..",
              ".....mmm.", "......m.m", ".......mm"],
    "burst": ["....o....", ".o..o..o.", "..o.y.o..", "...yyy...", "ooyywyyoo", "...yyy...",
              "..o.y.o..", ".o..o..o.", "....o...."],
    "gem": ["...cc...", "..cwcc..", ".cwcccc.", "cwcccccc", "cccccccd", ".ccccdd.", "..ccdd..", "...dd..."],
    "log": [".bbbbbbbbb...", "bBBBBBBBBBnn.", "bBBBBBBBBnttn", "bBBBBBBBBnttn", ".bbbbbbbbbnn."],
    "star": [".....y.....", "....yyy....", "....yyy....", "yyyyywyyyyy", ".yyyywyyyy.", "..yyyyyyy..",
             "...yyyyy...", "..yyy.yyy..", ".yy.....yy."],
    "firefly": ["..xx.xx..", ".xxxkxxx.", "..xkkkx..", "...kkk...", "...kkk...", "...yyy...",
                "..yyyyy..", "..yyyyy..", "...yyy..."],
    "moth": ["vv.....vv", "vvv.k.vvv", "vvvvkvvvv", ".vvvkvvv.", "..vvkvv..", ".vvvkvvv.",
             "vvv.k.vvv", "vv.....vv"],
    "beetle": ["..yyy....", "...y.....", "..mmmmm..", ".mmmlmmm.", "mmmmlmmmm", "mmmmlmmmm",
               ".mmmlmmm.", "..k...k.."],
    "drop": ["....o....", "...ooo...", "..ooooo..", ".oowoooo.", "oowwooooo", "ooooooooo",
             "ooooooooo", ".ooooooo.", "..ooooo.."],
    "boot": ["..bbbb...", "..bBBb...", "..bBBb...", "..bBBb...", "..bBBbbbb", ".bBBBBBBb",
             "bBBBBBBBb", "bbbbbbbbb"],
    "backpack": ["...bbbbb...", "..b.....b..", ".bbbbbbbbb.", ".bBBBBBBBb.", ".bBBnnnBBb.",
                 ".bBBnyBBBb.", ".bBBnnnBBb.", ".bBBBBBBBb.", ".bbbbbbbbb."],
    "coin": ["...AAAAA...", "..AYYYYYA..", ".AYYwYYYYA.", ".AYwYYYYYA.", ".AYYYYYYYA.",
             ".AYYYYYYoA.", "..AYYYYoA..", "...AAAAA..."],
    "clock": ["..mmmmm..", ".mwwwwwm.", "mwwwkwwwm", "mwwwkwwwm", "mwwwkkkwm", "mwwwwwwwm",
              "mwwwwwwwm", ".mwwwwwm.", "..mmmmm.."],
    "stall": ["rwrwrwrwrwr", "rwrwrwrwrwr", ".b.......b.", ".b.......b.", ".b..y.y..b.",
              ".bbbbbbbbb.", ".bBBBBBBBb.", ".bBBBBBBBb."],
    "magnet": ["ww.....ww", "rr.....rr", "rr.....rr", "rr.....rr", "rr.....rr", ".rr...rr.", "..rrrrr.."],
    "shield": ["..S.S.S..", ".SsSsSsS.", "SsSSSSSsS", ".SSSSSSS.", "SsSSSSSsS", ".SSSSSSS.",
               "SsSSSSSsS", ".SsSsSsS.", "..S.S.S.."],
    "flame": ["....o....", "...ooo...", "..ooyoo..", "..oyyyo..", ".ooywyoo.", ".oyywyyo.",
              "..oyyyo..", ".bbbbbbb.", "bb.....bb"],
    "flower": ["..ppp....", ".ppppp...", "ppyyypp..", "ppyyypp..", ".ppppp...", "..ppp....",
               "...g.....", "...g.gg..", "...gg...."],
    "moon": ["...yyyy..", "..yyy....", ".yyy.....", ".yy......", ".yy......", ".yyy.....",
             "..yyy....", "...yyyy.."],
    "map": [".gg......", "gggg.....", "gggg.....", ".gg...gg.", ".....gggg", ".....gggg",
            ".gg...gg.", "gggg.....", "gggg.....", ".gg......"],
    "tree": ["..ggggg..", ".gggGggg.", "gggggggGg", "gGggggggg", ".ggbgbgg.", "...bbb...",
             "...bbb...", "..bbbbb.."],
}
STAR_TINTS = {"star_silver": "#d8e4ff", "star_gold": "#ffd34d"}

SPRITES = {
    "hero_0": [".......l........", "......lYl.......", "....SSlYlS......", "..SsSSSSSSSs....",
               ".SSSsSSSSSsffff.", "SsSSSSsSSsffkfff", "SSSsSSSSSsfffffn", ".SSSSsSSsfffff..",
               "..SSSSSSsffff...", "...ff..ff......."],
    "hero_1": [".......l........", "......lYl.......", "....SSlYlS......", "..SsSSSSSSSs....",
               ".SSSsSSSSSsffff.", "SsSSSSsSSsffkfff", "SSSsSSSSSsfffffn", ".SSSSsSSsfffff..",
               "..SSSSSSsffff...", "..ff....ff......"],
    "block_stump": ["....bbbbbbbb....", "...bnnnnnnnnb...", "...bnttttttnb...", "...bnnnnnnnnb...",
                    "...bBBBBBBBBb...", "...bBBbBBBBBb...", "...bBBbBBBBBb...", "...bBBBBBbBBb...",
                    "..bBBBBBBbBBBb..", ".bBBBBBBBBBBBBb.", ".bbbbbbbbbbbbbb."],
    "block_crystal": [".....cc.....", "....cwcc....", ".c..cwcc..c.", "cwc.cwcc.cwc", "cwc.cwcc.cwc",
                      "cwccccccccwc", "cccccccccccd", ".dddddddddd."],
    "block_starbud": [".....yy.....", "....yyyy....", "...yywwyy...", "..yyywwyyy..", "..yyyyyyyy..",
                      "...yyyyyy...", "....gggg....", "...gg..gg...", "..gg....gg.."],
    "pick_amber": [".YY.", "YwYY", "YYYo", ".Yo."],
    "pick_wood": ["nnB", "ntB", "BBb"],
    "pick_crystal": [".c.", "cwc", "cdc", ".d."],
    "pick_pollen": [".y.", "ywy", ".y."],
    "jar_small": [".mmm.", "cxxxc", "cxyxc", "cxxxc", ".ccc."],
    "campfire": ["....o....", "...ooo...", "..oyyoo..", ".ooywyoo.", ".oyywyyo.", "bbBbbbBbb", ".bb...bb."],
}
CREATURE_SHAPES = {
    "bug": ["..x...x..", ".xxx.xxx.", "..xkkkx..", "..kekek..", "...kkk...", "...aaa...", "..aaaaa..",
            "..aAaaa..", "...aaa..."],
    "moth": ["aa.....aa", "aAa.k.aAa", "aaaekeaaa", ".aaakaaa.", "..aakaa..", ".aaakaaa.", "aAa.k.aAa",
             "aa.....aa"],
    "blob": ["....G....", "...gGg...", "..aaaaa..", ".aaaaaaa.", "aaeeaeeaa", "aaekaekaa", "aaaaaaaaa",
             "aaaaAAaaa", ".aaaaaaa.", "..aaaaa.."],
    "fish": ["...aaaa....", ".aaaaaaa..a", "aaekaaaaaaa", "aaaaaaaaaa.", ".aaAAaaa..a", "...aaaa...."],
}
FAMILY_SHAPE = {"firefly": "bug", "hummingmoth": "moth", "glowworm": "blob", "glowfish": "fish",
                "sporefairy": "blob", "dragonfly": "moth", "leafspirit": "blob", "snowmoth": "moth",
                "firebeetle": "bug"}


def hex_rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def darker(h, k=0.65):
    r, g, b, _ = hex_rgba(h)
    return "#%02x%02x%02x" % (int(r * k), int(g * k), int(b * k))


def render(rows, colors=None, rainbow=False):
    """ASCII rows -> RGBA image with a 1px outline around the drawing."""
    pal = dict(COLORS)
    pal.update(colors or {})
    w = max(len(r) for r in rows) + 2
    h = len(rows) + 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    rainbow_cols = ["#ff5a5a", "#ffa040", "#ffd34d", "#7fd67a", "#7ad0ff", "#d0a8ff"]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            col = pal[ch]
            if rainbow and ch in "yw":
                col = rainbow_cols[y % len(rainbow_cols)] if ch == "y" else "#ffffff"
            px[x + 1, y + 1] = hex_rgba(col)
    out = img.copy()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                    po[x, y] = OUTLINE
                    break
    return out


def build():
    items = {}
    for name, rows in ICONS.items():
        items["icon_" + name] = render(rows)
    star = ICONS["star"]
    for name, tint in STAR_TINTS.items():
        items["icon_" + name] = render(star, {"y": tint})
    items["icon_star_rainbow"] = render(star, rainbow=True)
    for name, rows in SPRITES.items():
        items[name] = render(rows)
    regions = json.loads((ROOT / "data/regions.json").read_text())["regions"]
    for reg in regions:
        acc = reg["colors"]["accent"]
        shape = CREATURE_SHAPES[FAMILY_SHAPE[reg["creature"]]]
        items["creature_" + reg["id"]] = render(shape, {"a": acc, "A": darker(acc), "G": darker(reg["colors"]["rim"]),
                                                         "g": reg["colors"]["rim"]})
    items["helper_moth"] = render(CREATURE_SHAPES["moth"], {"a": "#e8e0ff", "A": "#a090d0"})
    items["helper_beetle"] = render(ICONS["beetle"])

    names = list(items)
    cols = 16
    rows_n = (len(names) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * (CELL + 2), rows_n * (CELL + 2)), (0, 0, 0, 0))
    meta = {}
    for i, name in enumerate(names):
        im = items[name]
        cx, cy = (i % cols) * (CELL + 2), (i // cols) * (CELL + 2)
        ox, oy = cx + (CELL + 2 - im.width) // 2, cy + (CELL + 2 - im.height) // 2
        atlas.alpha_composite(im, (ox, oy))
        meta[name] = [ox, oy, im.width, im.height]
    out = ROOT / "game/assets/gen"
    out.mkdir(parents=True, exist_ok=True)
    atlas.save(out / "atlas.png")
    (out / "atlas.json").write_text(json.dumps(meta, indent=1))
    return items


def preview(items):
    skills = json.loads((ROOT / "data/skills.json").read_text())
    used = {}
    for tid, t in skills["types"].items():
        used.setdefault(t["icon"], []).append(t["name_en"].replace(": {region}", ""))
    scale, cw, ch = 4, 210, 84
    names = sorted(used)
    cols = 4
    sheet = Image.new("RGBA", (cols * cw + 16, ((len(names) + cols - 1) // cols) * ch + 16), (24, 20, 40, 255))
    d = ImageDraw.Draw(sheet)
    for i, icon in enumerate(names):
        im = items["icon_" + icon]
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        x, y = 8 + (i % cols) * cw, 8 + (i // cols) * ch
        sheet.alpha_composite(big, (x + (72 - big.width) // 2, y + (72 - big.height) // 2))
        label = ", ".join(used[icon])
        lines = [label[j:j + 22] for j in range(0, len(label), 22)][:4]
        d.text((x + 76, y + 6), icon, fill=(255, 211, 77, 255))
        for k, line in enumerate(lines):
            d.text((x + 76, y + 22 + k * 12), line, fill=(230, 230, 240, 255))
    img_dir = ROOT / "docs/img"
    img_dir.mkdir(parents=True, exist_ok=True)
    sheet.save(img_dir / "skill_icons.png")
    sprites = [n for n in items if not n.startswith("icon_")]
    sw = 96
    sp = Image.new("RGBA", (len(sprites) * sw // 2 + 16, 2 * sw + 8), (24, 20, 40, 255))
    for i, n in enumerate(sprites):
        im = items[n]
        big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        x, y = 8 + (i // 2) * sw, 8 + (i % 2) * sw
        sp.alpha_composite(big, (x + (sw - big.width) // 2, y + (sw - big.height) // 2))
    sp.save(img_dir / "sprites.png")


if __name__ == "__main__":
    items = build()
    preview(items)
    print(f"{len(items)} images -> game/assets/gen/atlas.png, docs/img/skill_icons.png, docs/img/sprites.png")
