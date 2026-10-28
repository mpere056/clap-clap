"""Builds the game's icon PNGs (256x256, transparent).

Icons with a Blender render in art/icons/render3d (made by tools/icons3d.py) use it, with a thick
outline and drop shadow added here. The rest come from the flat SVG drawings below (thick dark
outlines, top-lit gradient fills); every icon has one, so add a function and list it in ICONS.

    python tools/icons.py            -> art/icons/svg/*.svg, art/icons/png/*.png, art/icons/sheet.png
    python tools/icons.py --lua      -> only rebuild src/shared/Icons.luau from art/icons/uploaded.json

New PNGs are uploaded through the Roblox Studio MCP (upload_image, served from a local
http.server over art/icons/png); add the returned ids to art/icons/uploaded.json.
"""
import math
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_SVG = os.path.join(ROOT, "art", "icons", "svg")
OUT_PNG = os.path.join(ROOT, "art", "icons", "png")
RENDER3D = os.path.join(ROOT, "art", "icons", "render3d")  # Blender renders from tools/icons3d.py
CHROME_PATHS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
]

INK = "#1d1528"  # outline colour
SW = 9  # outline width

# palette
YEL, GOLD, ORA, RED, PINK = "#FFD83B", "#FFBE2E", "#FF8A1F", "#F0433A", "#FF6FA8"
PUR, BLU, CYA, GRN, DGRN = "#9B5CF0", "#3D9BFF", "#4FD8F2", "#5BD14A", "#2E9E44"
BRN, DBRN, GRY, DGRY, WHT = "#B0703F", "#7A4A28", "#A3ACBF", "#5F6578", "#F7F8FF"
SKIN, LAVA, NAVY, CREAM = "#FFC896", "#FF5A1F", "#2B2F5C", "#FFF1CF"


def _mix(hex_color, target, k):
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    r, g, b = (round(c + (t - c) * k) for c, t in zip((r, g, b), target))
    return "#%02x%02x%02x" % (r, g, b)


def light(c, k=0.3):
    return _mix(c, (255, 255, 255), k)


def dark(c, k=0.2):
    return _mix(c, (0, 0, 0), k)


class Icon:
    def __init__(self, prefix="i"):
        self.prefix = prefix  # gradient ids must be unique when many icons share one page
        self.plain = False  # True: no sticker outline/shadow (backdrops)
        self.defs = []
        self.body = []
        self.grads = {}

    def fill(self, color, flat=False):
        if flat or not color.startswith("#"):
            return color
        if color not in self.grads:
            gid = "%s_g%d" % (self.prefix, len(self.grads))
            self.grads[color] = gid
            self.defs.append(
                f'<linearGradient id="{gid}" x1="0" y1="0" x2="0.25" y2="1">'
                f'<stop offset="0" stop-color="{light(color, 0.45)}"/>'
                f'<stop offset="0.45" stop-color="{color}"/>'
                f'<stop offset="1" stop-color="{dark(color, 0.22)}"/></linearGradient>'
            )
        return "url(#%s)" % self.grads[color]

    def _shape(self, tag, geom, color, sw, flat, extra=""):
        fill = self.fill(color, flat)
        stroke = f'stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"'
        if sw and not flat and color.startswith("#"):
            # shaded fill first (the bevel makes it read as a rounded 3D form), crisp outline on top
            self.body.append(f'<{tag} {geom} fill="{fill}" filter="url(#{self.prefix}_bevel)" {extra}/>')
            self.body.append(f'<{tag} {geom} fill="none" {stroke} {extra}/>')
        else:
            self.body.append(f'<{tag} {geom} fill="{fill}" {stroke if sw else ""} {extra}/>')

    def path(self, d, color, sw=SW, flat=False, extra=""):
        self._shape("path", f'd="{d}"', color, sw, flat, extra)

    def circle(self, cx, cy, r, color, sw=SW, flat=False, extra=""):
        self._shape("circle", f'cx="{cx}" cy="{cy}" r="{r}"', color, sw, flat, extra)

    def ellipse(self, cx, cy, rx, ry, color, sw=SW, rot=0, flat=False):
        self._shape("ellipse", f'cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})"', color, sw, flat)

    def rect(self, x, y, w, h, color, rx=0, sw=SW, rot=0, flat=False):
        cx, cy = x + w / 2, y + h / 2
        self._shape("rect", f'x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" transform="rotate({rot} {cx} {cy})"', color, sw, flat)

    def poly(self, pts, color, sw=SW, flat=False):
        p = " ".join(f"{x},{y}" for x, y in pts)
        self._shape("polygon", f'points="{p}"', color, sw, flat)

    def shine(self, cx, cy, rx, ry, rot=-30, op=0.6):
        self.body.append(
            f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="white" opacity="{op}"/>'
        )

    def stroke(self, d, color, width=10, outline=True):
        """an outlined line: a dark wide stroke with a coloured one on top"""
        if outline:
            self.body.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{width + SW}" stroke-linecap="round" stroke-linejoin="round"/>')
        self.body.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')

    def star4(self, cx, cy, r, color=WHT, outline=True):
        """a little four-point sparkle"""
        k = r * 0.28
        pts = [(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k), (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)]
        self.poly(pts, color, sw=6 if outline else 0, flat=True)

    def text(self, x, y, s, size, color, sw=SW):
        self.body.append(
            f'<text x="{x}" y="{y}" font-family="Arial Black, Arial" font-weight="900" font-size="{size}" text-anchor="middle" '
            f'fill="{color}" stroke="{INK}" stroke-width="{sw}" paint-order="stroke" stroke-linejoin="round">{s}</text>'
        )

    def raw(self, s):
        self.body.append(s)

    def group(self, transform):
        """returns (open, close) markers to wrap drawing calls in a transform"""
        self.body.append(f'<g transform="{transform}">')
        return lambda: self.body.append("</g>")

    def svg(self):
        p = self.prefix
        filters = (
            # bevel: a soft shadow crescent bottom-right and a light rim top-left, inside each shape
            f'<filter id="{p}_bevel" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">'
            '<feOffset in="SourceAlpha" dx="-9" dy="-13" result="o1"/>'
            '<feComposite in="SourceAlpha" in2="o1" operator="out" result="c1"/>'
            '<feGaussianBlur in="c1" stdDeviation="4" result="b1"/>'
            '<feFlood flood-color="#120a1e" flood-opacity="0.42"/><feComposite in2="b1" operator="in" result="shade"/>'
            '<feOffset in="SourceAlpha" dx="7" dy="9" result="o2"/>'
            '<feComposite in="SourceAlpha" in2="o2" operator="out" result="c2"/>'
            '<feGaussianBlur in="c2" stdDeviation="3" result="b2"/>'
            '<feFlood flood-color="#ffffff" flood-opacity="0.5"/><feComposite in2="b2" operator="in" result="rim"/>'
            '<feMerge result="m"><feMergeNode in="SourceGraphic"/><feMergeNode in="shade"/><feMergeNode in="rim"/></feMerge>'
            '<feComposite in="m" in2="SourceAlpha" operator="in"/>'
            '</filter>'
            # sticker: one thick dark outline around the whole silhouette, plus a drop shadow
            f'<filter id="{p}_sticker" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">'
            '<feMorphology in="SourceAlpha" operator="dilate" radius="6" result="dil"/>'
            f'<feFlood flood-color="{INK}"/><feComposite in2="dil" operator="in" result="outline"/>'
            '<feOffset in="dil" dx="0" dy="8" result="sh"/><feGaussianBlur in="sh" stdDeviation="4" result="shb"/>'
            '<feFlood flood-color="#000000" flood-opacity="0.45"/><feComposite in2="shb" operator="in" result="shadow"/>'
            '<feMerge><feMergeNode in="shadow"/><feMergeNode in="outline"/><feMergeNode in="SourceGraphic"/></feMerge>'
            '</filter>'
        )
        if self.plain:
            return (
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>'
            )
        # shrink a little so the outline and shadow fit inside the 256 square
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
            f'<defs>{"".join(self.defs)}{filters}</defs>'
            f'<g filter="url(#{p}_sticker)"><g transform="translate(16 12) scale(0.875)">{"".join(self.body)}</g></g></svg>'
        )


def burst_points(cx, cy, r1, r2, n, rot=0):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = r1 if i % 2 == 0 else r2
        pts.append((round(cx + r * math.sin(a), 1), round(cy - r * math.cos(a), 1)))
    return pts


def arc_path(cx, cy, r, a0, a1):
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {x0:.1f} {y0:.1f} A {r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}"


def wedge_path(cx, cy, r, a0, a1):
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    return f"M {cx} {cy} L {x0:.1f} {y0:.1f} A {r} {r} 0 0 1 {x1:.1f} {y1:.1f} Z"


# ------------------------------------------------------------------------------------------------
# reusable pieces


def draw_hands(ic, ox=0, oy=0, s=1.0, rays=True):
    end = ic.group(f"translate({ox} {oy}) scale({s})")
    # sleeves
    ic.rect(62, 186, 58, 40, BLU, rx=10, rot=-14)
    ic.rect(136, 186, 58, 40, BLU, rx=10, rot=14)
    # thumbs
    ic.rect(50, 112, 30, 66, SKIN, rx=15, rot=-38)
    ic.rect(176, 112, 30, 66, SKIN, rx=15, rot=38)
    # palms
    ic.rect(72, 46, 64, 156, SKIN, rx=32, rot=-12)
    ic.rect(120, 46, 64, 156, SKIN, rx=32, rot=12)
    # finger creases
    for x, r in ((92, -12), (104, -12)):
        ic.stroke(f"M {x} 60 L {x + 3} 92", dark(SKIN, 0.25), width=4, outline=False)
    for x in (152, 164):
        ic.stroke(f"M {x} 60 L {x - 3} 92", dark(SKIN, 0.25), width=4, outline=False)
    ic.shine(98, 90, 9, 26, rot=-12, op=0.55)
    if rays:
        for d in ("M 44 52 L 24 36", "M 36 86 L 12 84", "M 212 52 L 232 36", "M 220 86 L 244 84", "M 128 22 L 128 6"):
            ic.stroke(d, YEL, width=9)
    end()


def draw_planet(ic, cx, cy, r, ocean=BLU, land=GRN, clouds=True):
    ic.circle(cx, cy, r, ocean)
    k = r / 90
    ic.path(
        f"M {cx - 60 * k} {cy - 40 * k} C {cx - 30 * k} {cy - 70 * k}, {cx + 10 * k} {cy - 40 * k}, {cx - 5 * k} {cy - 10 * k} "
        f"C {cx - 20 * k} {cy + 15 * k}, {cx - 55 * k} {cy + 5 * k}, {cx - 60 * k} {cy - 40 * k} Z",
        land, sw=6,
    )
    ic.path(
        f"M {cx + 20 * k} {cy + 10 * k} C {cx + 60 * k} {cy - 5 * k}, {cx + 75 * k} {cy + 35 * k}, {cx + 45 * k} {cy + 60 * k} "
        f"C {cx + 25 * k} {cy + 75 * k}, {cx + 5 * k} {cy + 40 * k}, {cx + 20 * k} {cy + 10 * k} Z",
        land, sw=6,
    )
    if clouds:
        ic.stroke(f"M {cx - 40 * k} {cy + 45 * k} L {cx - 5 * k} {cy + 45 * k}", WHT, width=10 * k, outline=False)
        ic.stroke(f"M {cx + 25 * k} {cy - 50 * k} L {cx + 55 * k} {cy - 50 * k}", WHT, width=10 * k, outline=False)
    ic.shine(cx - r * 0.45, cy - r * 0.45, r * 0.22, r * 0.12, rot=-40)


def draw_cloud(ic, cx, cy, s, color=WHT):
    end = ic.group(f"translate({cx} {cy}) scale({s})")
    ic.path(
        "M -70 30 C -100 30, -100 -10, -70 -12 C -70 -45, -25 -55, -10 -30 C 0 -60, 55 -60, 55 -22 "
        "C 90 -25, 95 30, 60 30 Z",
        color,
    )
    ic.shine(-30, -20, 22, 10, rot=-10, op=0.7)
    end()


def draw_bolt(ic, ox=0, oy=0, s=1.0, color=YEL):
    end = ic.group(f"translate({ox} {oy}) scale({s})")
    ic.poly([(150, 14), (62, 138), (116, 138), (90, 242), (198, 100), (142, 100), (172, 14)], color)
    ic.poly([(150, 30), (88, 124), (112, 124)], "white", sw=0, flat=True)
    end()


def draw_mountain(ic, color=GRY, snow=WHT, cracked=False):
    ic.poly([(16, 226), (102, 62), (138, 112), (164, 88), (240, 226)], color)
    ic.poly([(102, 62), (80, 104), (96, 98), (106, 112), (120, 98), (130, 104)], snow, sw=6)
    ic.poly([(164, 88), (150, 112), (162, 108), (172, 118), (180, 110)], snow, sw=6)
    if cracked:
        ic.stroke("M 110 226 L 120 190 L 104 160 L 118 130", INK, width=6, outline=False)


def draw_wave(ic, color=BLU):
    ic.path(
        "M 18 226 C 18 130, 96 46, 178 54 C 236 60, 244 130, 200 142 C 214 108, 184 92, 162 108 "
        "C 128 134, 146 196, 238 226 Z",
        color,
    )
    for cx, cy, r in ((176, 56, 14), (200, 62, 12), (220, 76, 11), (232, 98, 10), (156, 60, 12)):
        ic.circle(cx, cy, r, WHT, sw=6)
    ic.shine(70, 140, 14, 40, rot=30, op=0.45)


def draw_volcano(ic):
    for cx, cy, r in ((128, 40, 24), (100, 58, 18), (156, 56, 20)):
        ic.circle(cx, cy, r, DGRY, sw=7)
    ic.poly([(20, 228), (92, 96), (164, 96), (236, 228)], BRN)
    ic.path("M 92 96 L 164 96 L 156 118 C 146 150, 140 120, 130 160 C 122 128, 110 150, 100 118 Z", LAVA, sw=7)
    ic.ellipse(128, 96, 36, 9, RED, sw=7)
    ic.circle(150, 160, 6, LAVA, sw=4)


def draw_burst(ic, outer=ORA, inner=YEL, core=WHT):
    ic.poly(burst_points(128, 128, 116, 70, 12), outer)
    ic.poly(burst_points(128, 128, 78, 46, 12, rot=15), inner, sw=7)
    ic.circle(128, 128, 30, core, sw=6)


def draw_gem_badge(ic, text, color=GOLD):
    ic.circle(196, 196, 46, color)
    ic.text(196, 214, text, 46, WHT, sw=8)


# ------------------------------------------------------------------------------------------------
# icons


def i_hands(ic):
    draw_hands(ic)


def i_strong_hands(ic):
    # a flexed arm: upper arm across, forearm up, fist on top, bicep bulging
    ic.rect(10, 150, 40, 70, BLU, rx=10)
    ic.rect(30, 150, 176, 64, SKIN, rx=32)
    ic.rect(158, 66, 58, 130, SKIN, rx=29, rot=8)
    ic.circle(188, 64, 42, SKIN)
    for y in (48, 64, 80):
        ic.stroke(f"M 168 {y} L 196 {y}", dark(SKIN, 0.25), width=5, outline=False)
    ic.ellipse(108, 150, 62, 50, SKIN, rot=-8)
    ic.shine(92, 130, 26, 12, rot=-15, op=0.7)
    for d in ("M 74 84 L 60 58", "M 112 76 L 114 46", "M 150 88 L 166 64"):
        ic.stroke(d, YEL, width=9)


def i_polite(ic):
    ic.ellipse(92, 188, 44, 32, PINK, rot=-22)
    ic.rect(122, 46, 20, 146, PINK, rx=8)
    ic.path("M 132 46 C 180 50, 210 80, 196 124 C 186 96, 160 92, 140 96 Z", PINK)
    ic.shine(80, 178, 14, 8, rot=-22)
    ic.star4(200, 180, 22, YEL)
    ic.star4(56, 70, 16, YEL)


def i_firm(ic):
    ic.poly(burst_points(128, 128, 118, 74, 10), RED)
    ic.poly(burst_points(128, 128, 84, 52, 10, rot=18), YEL, sw=7)
    ic.text(128, 158, "!", 92, WHT, sw=10)


def i_cupped(ic):
    for r, c in ((92, PUR), (62, BLU), (32, CYA)):
        ic.stroke(arc_path(70, 128, r, -55, 55), c, width=16)
    ic.circle(70, 128, 20, YEL)
    ic.stroke(arc_path(70, 128, 122, -40, 40), PINK, width=12)


def i_thunder(ic):
    draw_bolt(ic)


def i_sonic(ic):
    for x in (84, 120, 156):
        ic.ellipse(x, 128, 16, 62 - (156 - x) * 0.25, "none", sw=0)
        ic.raw(f'<ellipse cx="{x}" cy="128" rx="16" ry="{62 - (156 - x) * 0.25}" fill="none" stroke="{INK}" stroke-width="16"/>')
        ic.raw(f'<ellipse cx="{x}" cy="128" rx="16" ry="{62 - (156 - x) * 0.25}" fill="none" stroke="{CYA}" stroke-width="7"/>')
    ic.poly([(30, 128), (176, 96), (236, 128), (176, 160)], WHT)
    ic.poly([(176, 96), (236, 128), (176, 160), (196, 128)], CYA, sw=7)
    for y in (70, 186):
        ic.stroke(f"M 24 {y} L 70 {y}", WHT, width=8)


def i_shockwave(ic):
    draw_burst(ic)


def i_seismic(ic):
    ic.rect(28, 54, 200, 148, WHT, rx=18)
    for y in (90, 128, 166):
        ic.stroke(f"M 44 {y} L 212 {y}", "#cfd6ea", width=3, outline=False)
    ic.stroke("M 40 128 L 70 128 L 84 82 L 100 176 L 116 70 L 134 186 L 150 100 L 164 150 L 178 128 L 216 128", RED, width=9)
    ic.circle(216, 128, 10, RED, sw=6)


def i_tectonic(ic):
    ic.poly([(20, 112), (122, 96), (112, 150), (130, 176), (22, 196)], BRN)
    ic.poly([(136, 84), (236, 70), (236, 166), (146, 160), (128, 134)], dark(BRN, 0.1))
    ic.poly([(20, 112), (122, 96), (136, 84), (236, 70), (236, 60), (130, 72), (20, 100)], GRN, sw=7)
    for cx, cy, r in ((130, 200, 8), (148, 214, 6), (112, 214, 5)):
        ic.circle(cx, cy, r, DBRN, sw=4)
    ic.shine(64, 140, 20, 8, rot=-8, op=0.35)


def i_volcanic(ic):
    draw_volcano(ic)


def i_avalanche(ic):
    draw_mountain(ic, color="#8fb4d6")
    for cx, cy, r in ((54, 214, 20), (88, 196, 16), (196, 212, 22), (164, 198, 14)):
        ic.circle(cx, cy, r, WHT, sw=7)


def i_hurricane(ic):
    # a tornado: stacked swirling bands, widest at the top
    bands = ((24, 30, 208), (44, 70, 172), (70, 108, 130), (96, 144, 92), (116, 178, 58))
    for x, y, w in bands:
        ic.rect(x, y, w, 40, "#8aa8d0", rx=20)
        ic.stroke(f"M {x + 18} {y + 14} L {x + w * 0.45} {y + 14}", WHT, width=5, outline=False)
    ic.rect(126, 210, 30, 26, "#8aa8d0", rx=12)
    for cx, cy, r in ((40, 200, 10), (214, 160, 12), (60, 120, 7)):
        ic.circle(cx, cy, r, BRN, sw=5)


def i_earthquake(ic):
    ic.rect(18, 120, 220, 100, BRN, rx=14)
    ic.rect(18, 104, 220, 34, GRN, rx=14)
    ic.poly([(118, 104), (136, 104), (126, 140), (150, 166), (124, 220), (110, 220), (130, 166), (106, 140)], INK, sw=0, flat=True)
    for cx, cy, r in ((70, 80, 10), (180, 70, 12), (150, 50, 7)):
        ic.circle(cx, cy, r, BRN, sw=5)
    for d in ("M 40 60 L 56 76", "M 216 52 L 200 70"):
        ic.stroke(d, YEL, width=8)


def i_tsunami(ic):
    draw_wave(ic)


def i_mountain(ic):
    draw_mountain(ic, color="#6fae5a", cracked=True)
    ic.star4(200, 50, 18, YEL)


def i_supercell(ic):
    draw_cloud(ic, 128, 96, 1.15, color="#6d7590")
    draw_bolt(ic, 70, 112, 0.55)
    for x in (70, 100, 190):
        ic.stroke(f"M {x} 170 L {x - 10} 200", CYA, width=7)


def i_continental(ic):
    draw_planet(ic, 128, 128, 104, clouds=False)


def i_tidal(ic):
    ic.path("M 150 26 C 108 34, 90 90, 120 120 C 140 140, 176 140, 198 120 C 160 128, 128 90, 150 26 Z", YEL)
    ic.shine(126, 62, 7, 16, rot=20)
    end = ic.group("translate(0 60) scale(1 0.78)")
    draw_wave(ic, color="#2f86e8")
    end()


def i_atmospheric(ic):
    draw_cloud(ic, 120, 120, 1.25)
    for y, x0, x1 in ((186, 50, 150), (210, 90, 210), (64, 170, 230)):
        ic.stroke(f"M {x0} {y} L {x1} {y}", CYA, width=8)


def i_stratospheric(ic):
    end = ic.group("rotate(35 128 128)")
    ic.path("M 104 200 C 70 230, 70 238, 92 236 C 100 220, 112 212, 120 210 Z", ORA, sw=7)
    ic.poly([(110, 210), (128, 248), (146, 210)], YEL, sw=7)
    ic.path("M 84 190 L 84 150 L 104 130 Z", RED)
    ic.path("M 172 190 L 172 150 L 152 130 Z", RED)
    ic.path("M 128 14 C 170 50, 170 120, 158 206 L 98 206 C 86 120, 86 50, 128 14 Z", WHT)
    ic.path("M 128 14 C 146 30, 156 46, 160 64 L 96 64 C 100 46, 110 30, 128 14 Z", RED)
    ic.circle(128, 110, 22, CYA)
    ic.shine(120, 102, 8, 5)
    end()


def i_meteor(ic):
    ic.path("M 92 150 C 120 100, 180 40, 246 12 C 220 70, 170 140, 116 180 Z", ORA)
    ic.path("M 104 150 C 128 112, 170 70, 214 42 C 196 80, 160 130, 118 166 Z", YEL, sw=0)
    ic.circle(90, 170, 62, BRN)
    for cx, cy, r in ((70, 156, 14), (108, 190, 10), (104, 140, 8)):
        ic.circle(cx, cy, r, DBRN, sw=5)
    ic.shine(64, 140, 16, 8, rot=-40)


def i_extinction(ic):
    ic.path("M 30 180 C 10 150, 40 130, 70 150 L 90 160 Z", GRN)
    ic.ellipse(120, 160, 66, 44, GRN)
    ic.rect(88, 176, 24, 50, DGRN, rx=10)
    ic.rect(136, 176, 24, 50, DGRN, rx=10)
    for x in (84, 108, 132):
        ic.poly([(x, 124), (x + 12, 102), (x + 24, 122)], YEL, sw=6)
    ic.rect(150, 70, 44, 90, GRN, rx=20, rot=12)
    ic.ellipse(184, 74, 52, 34, GRN)
    ic.circle(196, 62, 10, WHT, sw=5)
    ic.circle(199, 62, 5, INK, sw=0, flat=True)
    ic.stroke("M 200 92 L 230 88", INK, width=4, outline=False)
    ic.shine(104, 142, 22, 10, rot=-10)


def i_mantle(ic):
    ic.circle(128, 128, 104, "#4f9a52")
    ic.path(wedge_path(128, 128, 104, -90, 0), ORA)
    ic.path(wedge_path(128, 128, 72, -90, 0), "#ffb03a", sw=7)
    ic.path(wedge_path(128, 128, 40, -90, 0), YEL, sw=7)
    ic.shine(80, 160, 20, 10, rot=-40)


def i_core(ic):
    ic.poly(burst_points(128, 128, 120, 92, 16), ORA)
    ic.circle(128, 128, 84, RED)
    ic.circle(128, 128, 58, ORA, sw=7)
    ic.circle(128, 128, 34, YEL, sw=7)
    ic.shine(108, 108, 12, 7, rot=-40, op=0.8)


def i_magma(ic):
    ic.path("M 128 18 C 160 80, 208 112, 208 160 C 208 210, 170 236, 128 236 C 86 236, 48 210, 48 160 C 48 112, 96 80, 128 18 Z", LAVA)
    ic.circle(104, 170, 18, YEL, sw=6)
    ic.circle(150, 196, 12, YEL, sw=6)
    ic.circle(156, 146, 8, YEL, sw=5)
    ic.shine(92, 120, 10, 26, rot=20)


def i_crustbreaker(ic):
    ic.rect(116, 70, 26, 170, BRN, rx=10, rot=-35)
    ic.rect(56, 34, 128, 62, DGRY, rx=12, rot=-35)
    ic.rect(56, 34, 30, 62, GRY, rx=8, rot=-35)
    ic.shine(110, 56, 30, 7, rot=-35, op=0.5)
    for d in ("M 196 156 L 236 140", "M 186 186 L 224 204", "M 160 200 L 168 238"):
        ic.stroke(d, YEL, width=9)


def i_planetcracker(ic):
    draw_planet(ic, 116, 132, 96, clouds=False)
    ic.poly([(84, 40), (112, 92), (92, 128), (128, 168), (104, 228), (130, 226), (150, 170), (118, 128), (140, 92), (110, 38)], ORA, sw=6)
    ic.poly(burst_points(206, 60, 34, 16, 6), YEL, sw=6)


def i_gravity(ic):
    ic.raw(f'<ellipse cx="128" cy="128" rx="118" ry="40" fill="none" stroke="{INK}" stroke-width="30" transform="rotate(-18 128 128)"/>')
    ic.raw(f'<ellipse cx="128" cy="128" rx="118" ry="40" fill="none" stroke="{PINK}" stroke-width="16" transform="rotate(-18 128 128)"/>')
    ic.circle(128, 128, 62, "#141026", flat=True)
    ic.raw(f'<path d="{arc_path(128, 128, 118, 200, 340)}" fill="none" stroke="{PUR}" stroke-width="12" transform="rotate(-18 128 128) translate(0 0) scale(1 1)" opacity="0"/>')
    ic.raw(f'<path d="M 12 150 A 118 40 0 0 0 244 106" fill="none" stroke="{INK}" stroke-width="30" transform="rotate(-18 128 128)" opacity="0"/>')
    ic.star4(40, 50, 14, WHT)
    ic.star4(214, 210, 12, WHT)


def i_orbital(ic):
    ic.rect(14, 104, 70, 48, BLU, rx=4)
    ic.rect(172, 104, 70, 48, BLU, rx=4)
    for x in (37, 60, 195, 218):
        ic.stroke(f"M {x} 108 L {x} 148", light(BLU, 0.5), width=3, outline=False)
    ic.rect(80, 122, 96, 12, DGRY, rx=4)
    ic.rect(96, 88, 64, 80, GOLD, rx=12)
    ic.path("M 128 88 L 128 56", "none", sw=0)
    ic.stroke("M 128 88 L 128 52", DGRY, width=7)
    ic.ellipse(128, 44, 30, 12, WHT)
    ic.shine(110, 104, 8, 16, rot=0)


def i_cosmic(ic):
    ic.ellipse(128, 128, 112, 70, PUR, rot=-20)
    ic.path("M 128 128 C 60 120, 50 60, 120 50 C 70 70, 80 110, 128 112 Z", PINK, sw=6)
    ic.path("M 128 128 C 196 136, 206 196, 136 206 C 186 186, 176 146, 128 144 Z", PINK, sw=6)
    ic.circle(128, 128, 22, WHT, sw=6)
    for cx, cy, r in ((60, 180, 10), (196, 70, 12), (180, 196, 8), (70, 80, 7)):
        ic.star4(cx, cy, r, WHT)


# crowd


def i_classmate(ic):
    ic.rect(70, 170, 116, 70, NAVY, rx=26)
    ic.circle(128, 128, 62, SKIN)
    ic.path("M 70 120 C 70 70, 186 70, 186 120 C 160 100, 100 100, 70 120 Z", DBRN, sw=7)
    ic.poly([(48, 64), (128, 30), (208, 64), (128, 98)], "#2a2a3a")
    ic.stroke("M 190 66 L 196 112", GOLD, width=6)
    ic.circle(196, 118, 9, GOLD, sw=5)
    ic.circle(106, 136, 8, INK, sw=0, flat=True)
    ic.circle(150, 136, 8, INK, sw=0, flat=True)
    ic.stroke("M 108 162 C 120 174, 136 174, 148 162", INK, width=5, outline=False)
    ic.circle(92, 156, 9, PINK, sw=0, flat=True, extra='opacity="0.5"')
    ic.circle(164, 156, 9, PINK, sw=0, flat=True, extra='opacity="0.5"')


def i_teacher(ic):
    ic.rect(40, 180, 176, 40, BLU, rx=8)
    ic.rect(52, 144, 156, 40, RED, rx=8)
    ic.rect(36, 108, 172, 40, GRN, rx=8)
    for y in (196, 160, 124):
        ic.stroke(f"M 64 {y} L 190 {y}", WHT, width=4, outline=False)
    ic.circle(128, 70, 38, RED)
    ic.path("M 128 34 C 130 20, 140 14, 150 16", "none", sw=0)
    ic.stroke("M 128 36 C 130 22, 138 16, 146 16", DBRN, width=6)
    ic.ellipse(150, 26, 16, 8, GRN, rot=-20)
    ic.shine(114, 58, 9, 14, rot=-20)


def i_band(ic):
    ic.path("M 160 128 L 226 70 C 236 110, 236 150, 226 190 Z", GOLD)
    ic.rect(36, 112, 136, 34, GOLD, rx=14)
    ic.rect(60, 146, 100, 30, GOLD, rx=14)
    for x in (82, 106, 130):
        ic.rect(x, 82, 16, 34, light(GOLD, 0.2), rx=6)
        ic.ellipse(x + 8, 80, 12, 6, WHT, sw=6)
    ic.rect(18, 116, 26, 26, DGRY, rx=6)
    ic.shine(110, 120, 40, 6, rot=0, op=0.6)
    ic.ellipse(226, 130, 10, 58, dark(GOLD, 0.3), sw=7)


def i_cheer(ic):
    ic.path("M 60 100 L 196 40 L 196 216 L 60 156 Z", RED)
    ic.rect(36, 96, 34, 64, WHT, rx=10)
    ic.path("M 130 72 L 152 62 L 152 194 L 130 184 Z", WHT, sw=6)
    ic.rect(84, 150, 26, 60, DGRY, rx=8, rot=-10)
    ic.ellipse(196, 128, 18, 88, light(RED, 0.25))
    for d in ("M 224 70 L 244 56", "M 228 128 L 250 128", "M 224 186 L 244 200"):
        ic.stroke(d, YEL, width=9)


def i_school(ic):
    ic.rect(20, 110, 216, 116, CREAM, rx=6)
    ic.rect(92, 64, 72, 162, WHT, rx=6)
    ic.circle(128, 96, 22, WHT)
    ic.stroke("M 128 84 L 128 96 L 138 102", INK, width=4, outline=False)
    for x in (34, 58, 182, 206):
        for y in (130, 170):
            ic.rect(x, y, 18, 22, CYA, rx=3, sw=5)
    ic.rect(110, 180, 36, 46, BRN, rx=4, sw=6)
    ic.rect(14, 102, 228, 16, RED, rx=6, sw=6)


def i_choir(ic):
    ic.rect(110, 120, 36, 108, DGRY, rx=14)
    ic.circle(128, 84, 54, GRY)
    for d in ("M 88 70 L 168 70", "M 82 92 L 174 92", "M 108 40 L 108 126", "M 148 40 L 148 126"):
        ic.stroke(d, DGRY, width=4, outline=False)
    ic.shine(108, 60, 12, 8, rot=-30, op=0.7)
    ic.ellipse(46, 110, 16, 12, PINK, rot=-20)
    ic.stroke("M 60 106 L 60 52 L 80 60", PINK, width=8)
    ic.ellipse(206, 70, 14, 11, PUR, rot=-20)
    ic.stroke("M 218 66 L 218 22", PUR, width=8)


def i_orchestra(ic):
    end = ic.group("rotate(-30 128 128)")
    ic.rect(118, 10, 20, 90, DBRN, rx=6)
    ic.circle(128, 14, 12, DBRN, sw=7)
    ic.path("M 128 92 C 70 92, 74 140, 96 150 C 66 160, 66 236, 128 236 C 190 236, 190 160, 160 150 C 182 140, 186 92, 128 92 Z", BRN)
    ic.stroke("M 108 150 L 108 196", INK, width=5, outline=False)
    ic.stroke("M 148 150 L 148 196", INK, width=5, outline=False)
    ic.rect(118, 100, 20, 120, "#2a2030", rx=6, sw=0, flat=True)
    ic.shine(102, 120, 8, 16)
    end()
    ic.stroke("M 40 214 L 220 60", CREAM, width=7)


def i_stadium(ic):
    ic.ellipse(128, 150, 118, 70, GRY)
    ic.ellipse(128, 146, 94, 52, light(GRY, 0.3), sw=7)
    ic.ellipse(128, 150, 66, 32, GRN, sw=7)
    ic.stroke("M 128 120 L 128 180", WHT, width=3, outline=False)
    for x in (30, 226):
        ic.stroke(f"M {x} 150 L {x} 50", DGRY, width=7)
        ic.rect(x - 22, 30, 44, 26, YEL, rx=6, sw=6)


def i_nation(ic):
    ic.stroke("M 40 236 L 40 24", DGRY, width=10)
    ic.circle(40, 24, 12, GOLD, sw=6)
    ic.path("M 46 36 C 100 20, 150 60, 230 40 L 230 156 C 150 176, 100 136, 46 152 Z", WHT)
    ic.circle(138, 96, 34, RED, sw=7)
    ic.shine(90, 60, 22, 7, rot=-10, op=0.7)


def i_global(ic):
    ic.raw(f'<path d="M 128 236 L 128 216" stroke="{INK}" stroke-width="14"/>')
    ic.rect(80, 220, 96, 20, BRN, rx=8)
    draw_planet(ic, 128, 112, 92)
    ic.raw(f'<path d="{arc_path(128, 112, 108, 120, 300)}" fill="none" stroke="{INK}" stroke-width="18"/>')
    ic.raw(f'<path d="{arc_path(128, 112, 108, 120, 300)}" fill="none" stroke="{GOLD}" stroke-width="8"/>')


def i_drummers(ic):
    ic.stroke("M 40 30 L 120 110", CREAM, width=12)
    ic.stroke("M 216 30 L 136 110", CREAM, width=12)
    ic.path("M 46 110 C 40 150, 40 190, 54 226 L 202 226 C 216 190, 216 150, 210 110 Z", RED)
    ic.ellipse(128, 110, 82, 26, CREAM)
    ic.ellipse(128, 110, 54, 15, light(CREAM, 0.3), sw=0)
    for x in (66, 96, 128, 160, 190):
        ic.circle(x, 152, 6, GOLD, sw=4)
    ic.shine(70, 170, 9, 26, rot=0, op=0.4)


def i_cosmos(ic):
    ic.stroke("M 92 60 L 74 22", GRN, width=8)
    ic.stroke("M 164 60 L 182 22", GRN, width=8)
    ic.circle(74, 20, 12, YEL, sw=6)
    ic.circle(182, 20, 12, YEL, sw=6)
    ic.path("M 128 44 C 210 44, 222 120, 190 170 C 168 206, 148 226, 128 226 C 108 226, 88 206, 66 170 C 34 120, 46 44, 128 44 Z", GRN)
    ic.ellipse(94, 132, 26, 36, INK, rot=30, sw=0, flat=True)
    ic.ellipse(162, 132, 26, 36, INK, rot=-30, sw=0, flat=True)
    ic.ellipse(88, 122, 7, 10, WHT, rot=30, sw=0, flat=True)
    ic.ellipse(156, 122, 7, 10, WHT, rot=-30, sw=0, flat=True)
    ic.stroke("M 116 190 C 124 196, 132 196, 140 190", INK, width=5, outline=False)
    ic.shine(100, 70, 22, 9, rot=-20)


# stages


def i_ceremony(ic):
    ic.rect(40, 150, 176, 56, CREAM, rx=26, rot=-14)
    ic.ellipse(206, 154, 18, 28, light(CREAM, 0.2), rot=-14)
    ic.rect(110, 158, 22, 40, RED, rx=4, rot=-14, sw=6)
    ic.path("M 70 96 L 70 70 L 186 70 L 186 96 C 160 118, 96 118, 70 96 Z", "#2a2a3a")
    ic.poly([(20, 64), (128, 20), (236, 64), (128, 108)], "#3a3a50")
    ic.stroke("M 128 64 L 210 74 L 214 126", GOLD, width=6)
    ic.circle(214, 132, 10, GOLD, sw=5)
    ic.circle(128, 64, 9, GOLD, sw=5)


def i_gym(ic):
    ic.circle(128, 128, 106, ORA)
    for d in ("M 22 128 L 234 128", "M 128 22 L 128 234", "M 54 54 C 100 100, 100 156, 54 202", "M 202 54 C 156 100, 156 156, 202 202"):
        ic.stroke(d, INK, width=6, outline=False)
    ic.shine(84, 76, 22, 11, rot=-40)


def i_town(ic):
    ic.rect(120, 110, 104, 110, CREAM, rx=4)
    ic.poly([(108, 116), (172, 56), (236, 116)], BLU)
    ic.rect(160, 160, 28, 60, BRN, rx=4, sw=6)
    ic.rect(132, 128, 24, 24, CYA, rx=3, sw=5)
    ic.rect(30, 130, 96, 90, WHT, rx=4)
    ic.poly([(18, 136), (78, 76), (138, 136)], RED)
    ic.rect(62, 168, 30, 52, BRN, rx=4, sw=6)
    ic.rect(98, 150, 20, 20, CYA, rx=3, sw=5)
    ic.rect(10, 216, 236, 18, GRN, rx=8, sw=7)


def i_city(ic):
    for x, y, w, c in ((20, 96, 60, "#5f8fd8"), (164, 70, 64, "#4a78c4"), (82, 30, 82, "#6aa8f0")):
        ic.rect(x, y, w, 226 - y, c, rx=6)
        for wy in range(y + 16, 214, 28):
            for wx in range(x + 12, x + w - 16, 22):
                ic.rect(wx, wy, 12, 14, YEL, rx=2, sw=0)
    ic.stroke("M 123 30 L 123 8", DGRY, width=6)
    ic.rect(8, 222, 240, 14, DGRY, rx=6, sw=6)


def i_region(ic):
    ic.circle(196, 60, 36, RED, sw=7)
    ic.poly([(10, 226), (96, 70), (160, 70), (246, 226)], "#5b7fc0")
    ic.path("M 96 70 L 160 70 L 186 116 C 170 104, 162 124, 148 106 C 138 124, 122 106, 112 120 C 100 104, 86 118, 72 112 Z", WHT, sw=7)
    ic.shine(70, 180, 10, 24, rot=30, op=0.3)


def i_country(ic):
    ic.rect(56, 70, 26, 160, RED, rx=4)
    ic.rect(174, 70, 26, 160, RED, rx=4)
    ic.rect(42, 104, 172, 20, RED, rx=4)
    ic.path("M 14 48 C 80 66, 176 66, 242 48 L 236 74 C 176 86, 80 86, 20 74 Z", "#2a2030")
    ic.rect(30, 70, 196, 18, RED, rx=4, sw=7)
    ic.rect(116, 86, 24, 22, RED, rx=2, sw=6)


def i_planet(ic):
    draw_planet(ic, 128, 128, 108)


def i_molten(ic):
    ic.circle(128, 128, 108, "#5a2020")
    for d in ("M 40 100 L 90 120 L 110 90 L 160 110", "M 60 170 L 110 150 L 140 186 L 196 160", "M 150 50 L 170 90 L 214 100"):
        ic.stroke(d, LAVA, width=10)
        ic.stroke(d, YEL, width=4, outline=False)
    ic.shine(80, 70, 20, 10, rot=-40, op=0.35)


def i_space(ic):
    ic.circle(128, 132, 74, PUR)
    ic.raw(f'<ellipse cx="128" cy="132" rx="122" ry="30" fill="none" stroke="{INK}" stroke-width="26" transform="rotate(-16 128 132)"/>')
    ic.raw(f'<ellipse cx="128" cy="132" rx="122" ry="30" fill="none" stroke="{GOLD}" stroke-width="12" transform="rotate(-16 128 132)"/>')
    ic.path(wedge_path(128, 132, 74, 180, 360), PUR, sw=9)
    ic.shine(98, 100, 20, 10, rot=-40)
    for cx, cy, r in ((32, 40, 12), (222, 36, 14), (214, 220, 10)):
        ic.star4(cx, cy, r, WHT)


# events


def i_pumpkin(ic):
    ic.rect(118, 18, 22, 40, DGRN, rx=8, rot=12)
    for cx, rx in ((70, 58), (186, 58), (128, 70)):
        ic.ellipse(cx, 144, rx, 92, ORA)
    ic.poly([(80, 112), (106, 112), (93, 90)], YEL, sw=6)
    ic.poly([(150, 112), (176, 112), (163, 90)], YEL, sw=6)
    ic.path("M 70 160 L 92 174 L 108 160 L 128 176 L 148 160 L 164 174 L 186 160 C 176 200, 80 200, 70 160 Z", YEL, sw=6)
    ic.shine(100, 84, 16, 8, rot=-30, op=0.5)


def i_boost(ic):
    ic.circle(128, 128, 110, PUR)
    draw_bolt(ic, 40, 30, 0.62)
    ic.text(160, 206, "2×", 70, YEL)


def i_bat(ic):
    ic.path("M 128 110 C 100 70, 50 70, 10 96 C 30 110, 30 130, 24 150 C 44 140, 60 146, 70 162 C 80 146, 100 140, 118 150 Z", "#3a2a52")
    ic.path("M 128 110 C 156 70, 206 70, 246 96 C 226 110, 226 130, 232 150 C 212 140, 196 146, 186 162 C 176 146, 156 140, 138 150 Z", "#3a2a52")
    ic.ellipse(128, 130, 30, 40, "#4b3866")
    ic.poly([(106, 98), (112, 70), (124, 96)], "#4b3866", sw=7)
    ic.poly([(132, 96), (144, 70), (150, 98)], "#4b3866", sw=7)
    ic.circle(116, 120, 8, YEL, sw=0, flat=True)
    ic.circle(140, 120, 8, YEL, sw=0, flat=True)
    ic.poly([(120, 146), (124, 156), (128, 146)], WHT, sw=0, flat=True)
    ic.poly([(130, 146), (134, 156), (138, 146)], WHT, sw=0, flat=True)


def i_ghost(ic):
    ic.path("M 52 230 L 52 110 C 52 50, 204 50, 204 110 L 204 230 L 178 208 L 154 230 L 128 208 L 102 230 L 78 208 Z", WHT)
    ic.ellipse(102, 120, 14, 20, INK, sw=0, flat=True)
    ic.ellipse(154, 120, 14, 20, INK, sw=0, flat=True)
    ic.ellipse(128, 164, 14, 18, INK, sw=0, flat=True)
    ic.shine(88, 76, 18, 9, rot=-30, op=0.9)
    ic.circle(78, 150, 10, PINK, sw=0, flat=True, extra='opacity="0.5"')
    ic.circle(178, 150, 10, PINK, sw=0, flat=True, extra='opacity="0.5"')


def i_santa(ic):
    ic.path("M 46 170 C 60 90, 120 30, 200 70 C 220 80, 226 120, 214 150 C 200 120, 170 100, 160 110 C 190 140, 200 160, 196 170 Z", RED)
    ic.rect(30, 158, 196, 46, WHT, rx=22)
    ic.circle(214, 156, 26, WHT)
    ic.shine(110, 80, 22, 9, rot=-30)


def i_snowflake(ic):
    for rot in (0, 60, 120):
        end = ic.group(f"rotate({rot} 128 128)")
        ic.stroke("M 128 20 L 128 236", CYA, width=14)
        ic.stroke("M 104 40 L 128 64 L 152 40", CYA, width=10)
        ic.stroke("M 104 216 L 128 192 L 152 216", CYA, width=10)
        end()
    ic.circle(128, 128, 22, WHT, sw=7)


def i_star(ic):
    ic.poly(burst_points(128, 132, 116, 50, 5), GOLD)
    ic.shine(104, 104, 16, 8, rot=-30, op=0.7)
    ic.circle(108, 140, 7, INK, sw=0, flat=True)
    ic.circle(148, 140, 7, INK, sw=0, flat=True)


def i_candy(ic):
    # a swirl lollipop
    ic.rect(116, 150, 24, 92, WHT, rx=10, rot=10)
    ic.circle(128, 106, 90, PINK)
    ic.raw(f'<path d="M 128 106 m 0 -12 a 12 12 0 1 1 -12 12 a 26 26 0 1 1 26 26 a 40 40 0 1 1 -40 -40 a 56 56 0 1 1 56 56 a 70 70 0 0 1 -66 -40" '
           f'fill="none" stroke="{WHT}" stroke-width="12" stroke-linecap="round"/>')
    ic.circle(128, 106, 90, "none", sw=SW)
    ic.shine(90, 64, 20, 10, rot=-40, op=0.7)


def i_present(ic):
    ic.rect(30, 100, 196, 130, RED, rx=12)
    ic.rect(20, 76, 216, 44, light(RED, 0.15), rx=10)
    ic.rect(114, 76, 28, 154, GOLD, rx=4, sw=7)
    ic.path("M 128 76 C 90 30, 50 50, 80 76 Z", GOLD, sw=7)
    ic.path("M 128 76 C 166 30, 206 50, 176 76 Z", GOLD, sw=7)
    ic.shine(70, 140, 12, 26, rot=0, op=0.4)


# UI


def i_trophy(ic):
    ic.stroke("M 70 70 C 20 70, 30 140, 90 140", GOLD, width=12)
    ic.stroke("M 186 70 C 236 70, 226 140, 166 140", GOLD, width=12)
    ic.path("M 60 40 L 196 40 C 196 120, 170 160, 128 160 C 86 160, 60 120, 60 40 Z", GOLD)
    ic.rect(114, 156, 28, 40, GOLD, rx=4)
    ic.rect(72, 190, 112, 40, BRN, rx=8)
    ic.rect(98, 202, 60, 16, GOLD, rx=3, sw=5)
    ic.shine(92, 76, 12, 30, rot=0, op=0.6)
    ic.star4(128, 92, 18, WHT)


def i_gear(ic):
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5 + 11.25)
        r = 112 if (i // 1) % 2 == 0 else 84
        pts.append((round(128 + r * math.cos(a), 1), round(128 + r * math.sin(a), 1)))
    teeth = []
    for i in range(8):
        a0 = math.radians(i * 45 - 12)
        a1 = math.radians(i * 45 + 12)
        teeth += [(128 + 84 * math.cos(a0 - 0.12), 128 + 84 * math.sin(a0 - 0.12)), (128 + 114 * math.cos(a0), 128 + 114 * math.sin(a0)),
                  (128 + 114 * math.cos(a1), 128 + 114 * math.sin(a1)), (128 + 84 * math.cos(a1 + 0.12), 128 + 84 * math.sin(a1 + 0.12))]
    ic.poly([(round(x, 1), round(y, 1)) for x, y in teeth], GRY)
    ic.circle(128, 128, 36, DGRY, sw=8)
    ic.shine(92, 84, 18, 9, rot=-40)


def i_map(ic):
    ic.poly([(20, 60), (92, 36), (164, 60), (236, 36), (236, 196), (164, 220), (92, 196), (20, 220)], CREAM)
    ic.poly([(92, 36), (164, 60), (164, 220), (92, 196)], light(CREAM, 0.3) if False else "#f3dfae", sw=7)
    ic.stroke("M 50 180 C 80 150, 120 170, 140 130 C 156 100, 190 110, 200 80", RED, width=6, outline=False)
    ic.raw(f'<path d="M 50 180 C 80 150, 120 170, 140 130" fill="none" stroke="{RED}" stroke-width="6" stroke-dasharray="2 12" opacity="0"/>')
    ic.path("M 200 86 C 184 66, 184 40, 200 36 C 216 40, 216 66, 200 86 Z", RED, sw=6)
    ic.circle(200, 50, 6, WHT, sw=0, flat=True)


def i_walk(ic):
    ic.path("M 30 150 C 30 100, 60 70, 96 70 L 130 70 C 140 100, 170 120, 210 130 C 236 136, 240 170, 226 186 L 34 186 C 26 176, 26 162, 30 150 Z", RED)
    ic.rect(22, 180, 214, 30, WHT, rx=12)
    ic.path("M 96 70 L 130 70 C 120 100, 100 110, 80 112 Z", WHT, sw=6)
    for x in (110, 128, 146):
        ic.stroke(f"M {x} 112 L {x + 12} 100", WHT, width=5, outline=False)
    ic.shine(64, 110, 14, 8, rot=-30)


def i_chair(ic):
    ic.rect(60, 30, 136, 110, BRN, rx=16)
    ic.rect(48, 132, 160, 34, light(BRN, 0.15), rx=10)
    ic.rect(60, 162, 22, 70, DBRN, rx=6)
    ic.rect(174, 162, 22, 70, DBRN, rx=6)
    ic.shine(100, 62, 22, 9, rot=-10, op=0.4)


def i_crowd(ic):
    for cx, cy, c, s in ((70, 112, BLU, 0.8), (186, 112, GRN, 0.8), (128, 120, ORA, 1.0)):
        r = 36 * s
        ic.rect(cx - 52 * s, cy + 40 * s, 104 * s, 80 * s, c, rx=34 * s)
        ic.circle(cx, cy, r, SKIN)
        ic.circle(cx - 12 * s, cy, 5, INK, sw=0, flat=True)
        ic.circle(cx + 12 * s, cy, 5, INK, sw=0, flat=True)


def i_upgrade(ic):
    ic.poly([(128, 18), (230, 130), (172, 130), (172, 236), (84, 236), (84, 130), (26, 130)], GRN)
    ic.shine(110, 90, 12, 34, rot=35, op=0.55)



def i_curtain(ic):
    # stage curtains drawn back, with a spotlight
    ic.rect(14, 18, 228, 34, RED, rx=10)
    ic.path("M 18 46 C 30 120, 90 150, 104 236 L 18 236 Z", RED)
    ic.path("M 238 46 C 226 120, 166 150, 152 236 L 238 236 Z", RED)
    ic.ellipse(128, 214, 46, 14, YEL, sw=6)
    for x in (40, 62):
        ic.stroke(f"M {x} 70 C {x + 8} 130, {x + 30} 170, {x + 40} 230", dark(RED, 0.3), width=5, outline=False)
    for x in (216, 194):
        ic.stroke(f"M {x} 70 C {x - 8} 130, {x - 30} 170, {x - 40} 230", dark(RED, 0.3), width=5, outline=False)
    ic.circle(70, 132, 10, GOLD, sw=5)
    ic.circle(186, 132, 10, GOLD, sw=5)
    ic.star4(128, 150, 26, YEL)


def i_rebirth(ic):
    # a pair of white wings around a glowing halo
    for side in (-1, 1):
        end = ic.group(f"translate(128 0) scale({side} 1) translate(-128 0)")
        ic.path("M 120 140 C 90 70, 40 50, 12 70 C 30 84, 26 100, 18 116 C 40 112, 46 124, 34 140 C 60 136, 70 150, 60 166 C 84 158, 104 160, 120 140 Z", WHT)
        ic.stroke("M 104 132 C 80 110, 56 96, 30 90", "#c9d6f0", width=4, outline=False)
        end()
    ic.raw(f'<ellipse cx="128" cy="64" rx="40" ry="14" fill="none" stroke="{INK}" stroke-width="22"/>')
    ic.raw(f'<ellipse cx="128" cy="64" rx="40" ry="14" fill="none" stroke="{GOLD}" stroke-width="10"/>')
    ic.circle(128, 164, 30, CYA)
    ic.shine(118, 154, 9, 5)



def i_lock(ic):
    ic.raw(f'<path d="M 82 120 L 82 82 C 82 30, 174 30, 174 82 L 174 120" fill="none" stroke="{INK}" stroke-width="40" stroke-linecap="round"/>')
    ic.raw(f'<path d="M 82 120 L 82 82 C 82 30, 174 30, 174 82 L 174 120" fill="none" stroke="{GRY}" stroke-width="22" stroke-linecap="round"/>')
    ic.rect(44, 110, 168, 126, GOLD, rx=22)
    ic.circle(128, 160, 18, INK, sw=0, flat=True)
    ic.rect(120, 166, 16, 36, INK, rx=6, sw=0, flat=True)
    ic.shine(78, 134, 16, 8, rot=-20, op=0.6)


def i_ad(ic):
    ic.stroke("M 96 40 L 128 70 L 160 40", DGRY, width=8)
    ic.rect(20, 66, 216, 156, PUR, rx=26)
    ic.rect(40, 84, 176, 120, NAVY, rx=14, sw=7)
    ic.poly([(108, 112), (108, 176), (164, 144)], GRN, sw=7)
    ic.shine(70, 104, 16, 8, rot=-30, op=0.5)


def i_crown(ic):
    ic.poly([(30, 196), (20, 70), (80, 124), (128, 46), (176, 124), (236, 70), (226, 196)], GOLD)
    ic.rect(26, 186, 204, 40, GOLD, rx=10)
    for cx, c in ((76, RED), (128, BLU), (180, GRN)):
        ic.circle(cx, 206, 12, c, sw=6)
    for cx, cy in ((20, 70), (128, 46), (236, 70)):
        ic.circle(cx, cy, 14, WHT, sw=6)
    ic.shine(90, 150, 14, 26, rot=0, op=0.45)



def i_rays(ic):
    # white light rays fading out from the centre; tinted and spun behind icons in the menus
    ic.plain = True
    p = ic.prefix
    ic.defs.append(
        f'<radialGradient id="{p}_fade" cx="128" cy="128" r="128" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="white" stop-opacity="1"/><stop offset="0.35" stop-color="white" stop-opacity="0.85"/>'
        '<stop offset="1" stop-color="white" stop-opacity="0"/></radialGradient>'
    )
    wedges = []
    for i in range(12):
        a0, a1 = i * 30 - 7, i * 30 + 7
        x0, y0 = 128 + 180 * math.cos(math.radians(a0)), 128 + 180 * math.sin(math.radians(a0))
        x1, y1 = 128 + 180 * math.cos(math.radians(a1)), 128 + 180 * math.sin(math.radians(a1))
        wedges.append(f"M 128 128 L {x0:.1f} {y0:.1f} L {x1:.1f} {y1:.1f} Z")
    ic.raw(f'<path d="{" ".join(wedges)}" fill="url(#{p}_fade)"/>')
    ic.raw(f'<circle cx="128" cy="128" r="70" fill="url(#{p}_fade)" opacity="0.55"/>')


ICONS = {
    # techniques
    "tech_Polite": i_polite, "tech_Firm": i_firm, "tech_Cupped": i_cupped, "tech_Thunder": i_thunder,
    "tech_Sonic": i_sonic, "tech_Shockwave": i_shockwave, "tech_Seismic": i_seismic, "tech_Tectonic": i_tectonic,
    "tech_Volcanic": i_volcanic, "tech_Avalanche": i_avalanche, "tech_Hurricane": i_hurricane, "tech_Earthquake": i_earthquake,
    "tech_Tsunami": i_tsunami, "tech_Mountain": i_mountain, "tech_Supercell": i_supercell, "tech_Continental": i_continental,
    "tech_Tidal": i_tidal, "tech_Atmospheric": i_atmospheric, "tech_Stratospheric": i_stratospheric, "tech_Meteor": i_meteor,
    "tech_Extinction": i_extinction, "tech_Mantle": i_mantle, "tech_Core": i_core, "tech_Magma": i_magma,
    "tech_Crustbreaker": i_crustbreaker, "tech_Planetcracker": i_planetcracker, "tech_Gravity": i_gravity,
    "tech_Orbital": i_orbital, "tech_Cosmic": i_cosmic,
    # crowd
    "crowd_Classmate": i_classmate, "crowd_Teacher": i_teacher, "crowd_Band": i_band, "crowd_Cheer": i_cheer,
    "crowd_School": i_school, "crowd_Choir": i_choir, "crowd_Orchestra": i_orchestra, "crowd_Stadium": i_stadium,
    "crowd_Nation": i_nation, "crowd_Global": i_global, "crowd_Drummers": i_drummers, "crowd_Cosmos": i_cosmos,
    # stages
    "stage_Ceremony": i_ceremony, "stage_Gym": i_gym, "stage_Town": i_town, "stage_City": i_city,
    "stage_Region": i_region, "stage_Country": i_country, "stage_Planet": i_planet, "stage_Molten": i_molten,
    "stage_Space": i_space,
    # event items and currencies
    "item_pumpkin": i_pumpkin, "item_boost": i_boost, "item_bat": i_bat, "item_ghost": i_ghost,
    "item_santa": i_santa, "item_snowflake": i_snowflake, "item_star": i_star, "cur_candy": i_candy, "cur_present": i_present,
    # UI
    "ui_hands": i_hands, "ui_strong": i_strong_hands, "ui_trophy": i_trophy, "ui_gear": i_gear, "ui_map": i_map,
    "ui_walk": i_walk, "ui_chair": i_chair, "ui_crowd": i_crowd, "ui_upgrade": i_upgrade,
    "ui_curtain": i_curtain, "ui_rebirth": i_rebirth,
    "ui_lock": i_lock, "ui_ad": i_ad, "ui_crown": i_crown, "ui_rays": i_rays,
}


def find_chrome():
    for p in CHROME_PATHS:
        if os.path.exists(p):
            return p
    sys.exit("Chrome/Edge not found")


def outline3d(im):
    """thick rounded ink outline and a soft drop shadow around a 512px render, scaled to 256px"""
    from PIL import Image, ImageChops, ImageFilter

    alpha = im.getchannel("A")
    grown = alpha.filter(ImageFilter.GaussianBlur(7)).point(lambda v: 255 if v > 12 else v * 21)
    grown = grown.filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    shadow.putalpha(ImageChops.offset(grown, 0, 12).point(lambda v: v * 0.45).filter(ImageFilter.GaussianBlur(5)))
    out.alpha_composite(shadow)
    edge = Image.new("RGBA", im.size, tuple(int(INK[i:i + 2], 16) for i in (1, 3, 5)) + (0,))
    edge.putalpha(grown)
    out.alpha_composite(edge)
    out.alpha_composite(im)
    return out.resize((256, 256), Image.LANCZOS)


def main():
    from PIL import Image

    os.makedirs(OUT_SVG, exist_ok=True)
    os.makedirs(OUT_PNG, exist_ok=True)
    names = list(ICONS)
    # icons that only exist as 3D renders (no flat drawing) are copied over as they are
    only3d = sorted(f[:-4] for f in os.listdir(RENDER3D) if f.endswith(".png") and f[:-4] not in ICONS) if os.path.isdir(RENDER3D) else []
    svgs = {}
    for name in names:
        ic = Icon(name)
        ICONS[name](ic)
        svgs[name] = ic.svg()
        with open(os.path.join(OUT_SVG, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(svgs[name])

    # render everything on one transparent page, then cut it up
    cols = 8
    rows = math.ceil(len(names) / cols)
    cells = "".join(f'<div style="position:absolute;left:{(i % cols) * 256}px;top:{(i // cols) * 256}px">{svgs[n]}</div>' for i, n in enumerate(names))
    html = os.path.join(ROOT, "art", "icons", "_render.html")
    with open(html, "w", encoding="utf-8") as f:
        f.write(f'<!doctype html><html><body style="margin:0;background:transparent">{cells}</body></html>')
    page = os.path.join(ROOT, "art", "icons", "_render.png")
    subprocess.run(
        [find_chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         "--default-background-color=00000000", f"--window-size={cols * 256},{rows * 256}", f"--screenshot={page}",
         "file:///" + html.replace("\\", "/")],
        check=True, capture_output=True,
    )
    sheet = Image.open(page).convert("RGBA")
    for i, name in enumerate(names):
        x, y = (i % cols) * 256, (i // cols) * 256
        render = os.path.join(RENDER3D, name + ".png")
        if os.path.exists(render):  # a 3D render replaces the flat drawing
            sheet.paste(outline3d(Image.open(render).convert("RGBA")), (x, y))
        sheet.crop((x, y, x + 256, y + 256)).save(os.path.join(OUT_PNG, name + ".png"))

    for name in only3d:
        outline3d(Image.open(os.path.join(RENDER3D, name + ".png")).convert("RGBA")).save(os.path.join(OUT_PNG, name + ".png"))

    # a contact sheet on a dark card colour, for checking by eye
    preview = Image.new("RGBA", sheet.size, (36, 38, 52, 255))
    preview.alpha_composite(sheet)
    preview.convert("RGB").resize((sheet.width // 2, sheet.height // 2)).save(os.path.join(ROOT, "art", "icons", "sheet.png"))
    os.remove(html)
    os.remove(page)
    print(f"{len(names)} icons -> art/icons/png")


def write_lua():
    """rebuild src/shared/Icons.luau from the upload record (art/icons/uploaded.json)"""
    import json

    record = os.path.join(ROOT, "art", "icons", "uploaded.json")
    ids = json.load(open(record))
    missing = sorted(set(ICONS) - set(ids))  # (3D-only icons aren't checked)
    lines = [
        "--!strict",
        "-- Uploaded icon images. Generated by tools/icons.py from art/icons/uploaded.json; don't edit by hand.",
        '-- Icons.get("tech_Thunder") -> "rbxassetid://..."',
        "",
        "local Icons = {}",
        "",
        "local IDS: { [string]: string } = {",
    ]
    lines += [f'\t{k} = "rbxassetid://{v}",' for k, v in sorted(ids.items())]
    lines += ["}", "", "function Icons.get(name: string): string", '\treturn IDS[name] or ""', "end", "", "return Icons", ""]
    with open(os.path.join(ROOT, "src", "shared", "Icons.luau"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"Icons.luau: {len(ids)} ids" + (f"; not uploaded yet: {', '.join(missing)}" if missing else ""))


if __name__ == "__main__":
    if "--lua" not in sys.argv:
        main()
    write_lua()
