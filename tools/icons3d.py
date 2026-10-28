"""Models the game's icons in 3D and renders them with Blender, for a chunky "toy render" look
like the item art of popular Roblox simulators.

Every icon is a small scene built from rounded primitives (spheres, capsules, beveled boxes,
extruded shapes, lathed shapes) with glossy plastic materials, a dark inverted-hull outline and
three-point lighting, rendered with EEVEE on a transparent background.

    blender -b --factory-startup -P tools/icons3d.py              -> art/icons/render3d/*.png (512px)
    blender -b --factory-startup -P tools/icons3d.py -- a b c     -> only icons a, b, c

Then `python tools/icons.py` adds the silhouette outline and shadow and writes art/icons/png.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "icons", "render3d")
SIZE = 512
HULL = 0.034  # inner outline thickness, in model units (icons are ~2 units across)
FONT = r"C:\Windows\Fonts\ariblk.ttf"

# palette (sRGB)
YEL, GOLD, ORA, RED, PINK = "#FFD83B", "#FFB41F", "#FF8A1F", "#F0433A", "#FF6FA8"
PUR, BLU, CYA, GRN, DGRN = "#9B5CF0", "#3D8BFF", "#4FD8F2", "#5BD14A", "#2E9E44"
BRN, DBRN, GRY, DGRY, WHT = "#B0703F", "#7A4A28", "#A3ACBF", "#5F6578", "#F4F6FF"
SKIN, LAVA, NAVY, CREAM, INK = "#FFC896", "#FF5A1F", "#2B2F5C", "#FFF1CF", "#1d1528"


# ---------------------------------------------------------------- materials

def lin(hex_color):
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return out


_mats = {}


def _input(node, *names):
    for n in names:
        if n in node.inputs:
            return node.inputs[n]
    return None


def mat(color, rough=0.3, metal=0.0, emit=0.0, coat=0.5):
    key = (color, rough, metal, emit, coat)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(f"m{len(_mats)}")
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgba = (*lin(color), 1)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if _input(bsdf, "Coat Weight"):
        _input(bsdf, "Coat Weight").default_value = coat
        _input(bsdf, "Coat Roughness").default_value = 0.15
    if emit:
        _input(bsdf, "Emission Color", "Emission").default_value = rgba
        _input(bsdf, "Emission Strength").default_value = emit
    _mats[key] = m
    return m


def ink():
    if "ink" in _mats:
        return _mats["ink"]
    m = bpy.data.materials.new("ink")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    # the outline shell must not shade the object it surrounds: transparent to shadow rays
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*lin(INK), 1)
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(path.outputs["Is Shadow Ray"], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], out.inputs[0])
    m.use_backface_culling = True
    for attr in ("use_transparent_shadow",):
        if hasattr(m, attr):
            setattr(m, attr, True)
    _mats["ink"] = m
    return m


# ---------------------------------------------------------------- scene objects

_root = None


def xform(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    return (Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
            @ Matrix.Diagonal((*scale, 1)))


def _finish(bm, color, loc, rot, scale, smooth=True, bevel=0.0, hull=True, cut=(), recalc=True, sharp=0, **mk):
    bmesh.ops.transform(bm, matrix=xform(loc, rot, scale), verts=bm.verts)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("mesh")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if sharp:  # smooth bevels, crisp flat faces
        me.set_sharp_from_angle(angle=math.radians(sharp))
    ob = bpy.data.objects.new("part", me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat(color, **mk))
    me.materials.append(ink())
    for c in cut:  # carve holes with cutter() objects
        b = ob.modifiers.new("cut", "BOOLEAN")
        b.operation = "DIFFERENCE"
        b.object = c
        b.solver = "EXACT"
    if bevel:
        bv = ob.modifiers.new("bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 4
        bv.limit_method = "ANGLE"
        bv.angle_limit = math.radians(40)
        wn = ob.modifiers.new("wn", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
    if hull:
        so = ob.modifiers.new("hull", "SOLIDIFY")
        so.thickness = HULL if hull is True else hull
        so.offset = 1
        so.use_flip_normals = True
        so.use_rim = False
        so.use_even_offset = False
        so.material_offset = 1
    ob.parent = _root
    return ob


def cutter(ob):
    """turn a part into an invisible boolean cutter for another part's cut=[...]"""
    ob.hide_render = True
    ob.modifiers.clear()
    return ob


def sphere(loc, r, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=48, **kw):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    if isinstance(scale, (int, float)):
        scale = (scale,) * 3
    return _finish(bm, color, loc, rot, scale, **kw)


def box(loc, size, color, rot=(0, 0, 0), bevel=0.08, **kw):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    return _finish(bm, color, loc, rot, size, bevel=bevel, **kw)


def cyl(loc, r, h, color, rot=(0, 0, 0), r2=None, seg=48, bevel=0.05, scale=(1, 1, 1), **kw):
    """cylinder (or cone with r2) along local Z"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    if isinstance(scale, (int, float)):
        scale = (scale,) * 3
    return _finish(bm, color, loc, rot, scale, bevel=bevel, **kw)


def lathe(profile, color, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), seg=48, ribs=0, rib_depth=0.0, closed=False, **kw):
    """spin a (radius, z) profile around Z; profile ends with radius 0 are closed to a point.
    ribs > 0 makes pumpkin-like lobes; closed=True joins the last point back to the first (rings)."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            rr = r * (1 - rib_depth * (0.5 - 0.5 * math.cos(ribs * a))) if ribs else r
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    for ra, rb in zip(rings, rings[1:] + (rings[:1] if closed else [])):
        if len(ra) == 1 and len(rb) == 1:
            continue
        for i in range(seg):
            j = (i + 1) % seg
            if len(ra) == 1:
                bm.faces.new((ra[0], rb[i], rb[j]))
            elif len(rb) == 1:
                bm.faces.new((ra[i], ra[j], rb[0]))
            else:
                bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if len(rings[0]) > 1 and not closed:
        bm.faces.new(rings[0])
    if len(rings[-1]) > 1 and not closed:
        bm.faces.new(rings[-1])
    if isinstance(scale, (int, float)):
        scale = (scale,) * 3
    return _finish(bm, color, loc, rot, scale, **kw)


def capsule(p1, p2, r, color, r2=None, seg=32, **kw):
    """rounded rod from p1 to p2 (radius r at p1, r2 at p2)"""
    r2 = r if r2 is None else r2
    a, b = Vector(p1), Vector(p2)
    length = (b - a).length
    prof = []
    n = 8
    for i in range(n + 1):  # bottom cap
        t = -math.pi / 2 + (math.pi / 2) * i / n
        prof.append((r * math.cos(t), r * math.sin(t)))
    for i in range(n + 1):  # top cap
        t = (math.pi / 2) * i / n
        prof.append((r2 * math.cos(t), length + r2 * math.sin(t)))
    prof[0] = (0, prof[0][1])
    prof[-1] = (0, prof[-1][1])
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    bm = bmesh.new()
    _lathe_into(bm, prof, seg)
    m = Matrix.Translation(a) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return _finish(bm, color, (0, 0, 0), (0, 0, 0), (1, 1, 1), **kw)


def _lathe_into(bm, profile, seg):
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
                          for i in range(seg)])
    for ra, rb in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            if len(ra) == 1:
                bm.faces.new((ra[0], rb[i], rb[j]))
            elif len(rb) == 1:
                bm.faces.new((ra[i], ra[j], rb[0]))
            else:
                bm.faces.new((ra[i], ra[j], rb[j], rb[i]))


def torus(loc, R, r, color, rot=(0, 0, 0), a0=0, a1=360, seg=64, rseg=20, scale=(1, 1, 1), **kw):
    """ring in the local XY plane; a0..a1 (degrees) for an arc with rounded ends"""
    bm = bmesh.new()
    full = abs(a1 - a0) >= 360
    n = seg if full else max(4, int(seg * abs(a1 - a0) / 360))
    rings = []
    for i in range(n if full else n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        c = Vector((R * math.cos(a), R * math.sin(a), 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(c + r * (math.cos(2 * math.pi * k / rseg) * out
                                             + math.sin(2 * math.pi * k / rseg) * Vector((0, 0, 1))))
                      for k in range(rseg)])
    pairs = list(zip(rings, rings[1:] + ([rings[0]] if full else [])))
    for ra, rb in pairs:
        for k in range(rseg):
            m = (k + 1) % rseg
            bm.faces.new((ra[k], ra[m], rb[m], rb[k]))
    if isinstance(scale, (int, float)):
        scale = (scale,) * 3
    ob = _finish(bm, color, loc, rot, scale, **kw)
    if not full:  # round the open ends
        M = xform(loc, rot, scale)
        for a in (a0, a1):
            p = M @ Vector((R * math.cos(math.radians(a)), R * math.sin(math.radians(a)), 0))
            sphere(tuple(p), r * scale[0], color, seg=24, **kw)
    return ob


def _curve_bm(cu):
    """mesh a curve datablock into a bmesh"""
    tmp = bpy.data.objects.new("tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return bm


def prism(pts, depth, color, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), bevel=0.06, **kw):
    """2D outline in the XZ plane (x, z), extruded along Y (towards the camera) with rounded edges.
    Built as a filled curve: Blender fills concave outlines cleanly that way."""
    pts = [p for i, p in enumerate(pts) if (Vector(p) - Vector(pts[i - 1])).length > 1e-6]
    b = min(bevel, depth * 0.45)
    cu = bpy.data.curves.new("shape", "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = max(depth / 2 - b, 0.0)
    cu.bevel_depth = b
    cu.bevel_resolution = 4
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for pt, (x, z) in zip(sp.points, pts):
        pt.co = (x, z, 0, 1)
    sp.use_cyclic_u = True
    bm = _curve_bm(cu)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.radians(90), 4, "X"), verts=bm.verts)
    if isinstance(scale, (int, float)):
        scale = (scale,) * 3
    return _finish(bm, color, loc, rot, scale, sharp=35, **kw)


def tube(points, r, color, smooth_path=True, **kw):
    """rod along a path with round ends"""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 6
    cu.resolution_u = 10
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO" if smooth_path else "VECTOR"
    tmp = bpy.data.objects.new("tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for p in (points[0], points[-1]):
        cap = bmesh.new()
        bmesh.ops.create_uvsphere(cap, u_segments=24, v_segments=12, radius=r)
        bmesh.ops.translate(cap, vec=Vector(p), verts=cap.verts)
        tmpme = bpy.data.meshes.new("cap")
        cap.to_mesh(tmpme)
        cap.free()
        bm.from_mesh(tmpme)
        bpy.data.meshes.remove(tmpme)
    return _finish(bm, color, (0, 0, 0), (0, 0, 0), (1, 1, 1), **kw)


def text(s, loc, size, color, depth=0.18, rot=(0, 0, 0), **kw):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = s
    if os.path.exists(FONT):
        cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    cu.size = size
    cu.extrude = depth / 2
    cu.bevel_depth = size * 0.03
    cu.bevel_resolution = 3
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new("tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    rx, ry, rz = rot
    return _finish(bm, color, loc, (rx + 90, ry, rz), (1, 1, 1), sharp=35, **kw)


# ---------------------------------------------------------------- 2D outlines for prism()

def star_pts(n, r1, r2, rot=90, cx=0, cz=0):
    out = []
    for i in range(2 * n):
        a = math.radians(rot) + math.pi * i / n
        r = r1 if i % 2 == 0 else r2
        out.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return out


def circle_pts(r, n=48, cx=0, cz=0, rz=None):
    rz = r if rz is None else rz
    return [(cx + r * math.cos(2 * math.pi * i / n), cz + rz * math.sin(2 * math.pi * i / n)) for i in range(n)]


BOLT = [(0.18, 1.0), (-0.5, -0.05), (-0.05, -0.05), (-0.28, -1.0), (0.5, 0.15), (0.05, 0.15), (0.42, 1.0)]


def sparkle(loc, s, color=WHT, **kw):
    return prism(star_pts(4, s, s * 0.28), s * 0.35, color, loc=loc, bevel=s * 0.08, emit=1.5, hull=HULL * 0.6, **kw)


def lines_burst(c, r1, r2, n, color=YEL, a0=0, a1=360, w=0.05):
    """impact lines radiating around point c (in the XZ plane)"""
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * (i + 0.5) / n)
        d = Vector((math.cos(a), 0, math.sin(a)))
        tube([tuple(Vector(c) + d * r1), tuple(Vector(c) + d * r2)], w, color, smooth_path=False, emit=0.6)


# ---------------------------------------------------------------- shared pieces

def on_sphere(c, r, x, z, lift=0.0):
    """point on the camera-facing side of a sphere (centre c, radius r) under screen offset (x, z)"""
    y = -math.sqrt(max(r * r - x * x - z * z, 0.0))
    p = Vector((x, y, z)).normalized() * (r + lift)
    return tuple(Vector(c) + p)


def patch(c, r, d, size, color, flat=0.28, **kw):
    """a flattened blob lying on a sphere's surface in direction d (continents, craters, spots)"""
    d = Vector(d).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    return sphere(tuple(Vector(c) + d * r * 0.95), r * size, color, scale=(1.0, 0.8, flat),
                  rot=tuple(math.degrees(a) for a in q.to_euler()), hull=HULL * 0.6, **kw)


def latlon(lat, lon):
    return Euler((math.radians(-lat), 0, math.radians(lon)), "XYZ").to_matrix() @ Vector((0, -1, 0))


def hand(side=1, loc=(0, 0, 0), tilt=0.0, skin=SKIN, sleeve=NAVY, cuff=WHT):
    """an open cartoon hand pointing up with its palm towards the middle (side=1 is the left hand)"""
    M = xform(loc, (0, tilt, 0))

    def P(x, y, z):
        return tuple(M @ Vector((x * side, y, z)))

    sphere(P(0, 0, 0), 0.46, skin, scale=(0.6, 1.0, 1.1), rot=(0, tilt, 0))
    for y, h in ((-0.27, 0.6), (-0.09, 0.7), (0.09, 0.66), (0.26, 0.52)):
        capsule(P(0, y, 0.25), P(0.03, y * 1.12, 0.25 + h), 0.125, skin)
    capsule(P(-0.05, -0.38, -0.05), P(-0.12, -0.6, 0.3), 0.12, skin)
    capsule(P(0, 0, -0.55), P(0, 0, -1.05), 0.33, sleeve)
    torus(P(0, 0, -0.5), 0.3, 0.08, cuff, rot=(0, tilt, 0))


def globe(loc, r, ocean=BLU, land=GRN, clouds=True):
    sphere(loc, r, ocean, rough=0.25)
    for lat, lon, s in ((25, -30, 0.42), (-20, -60, 0.32), (10, 40, 0.38), (45, 15, 0.25), (-35, 20, 0.3), (-10, -5, 0.22)):
        patch(loc, r, latlon(lat, lon), s, land)
    if clouds:
        for lat, lon in ((40, -55), (-30, 35)):
            patch(loc, r * 1.05, latlon(lat, lon), 0.2, WHT, flat=0.35)


def cloud(loc, s, color=WHT, **kw):
    x, y, z = loc
    for dx, dz, r in ((0, 0.15, 0.45), (-0.45, -0.05, 0.34), (0.45, -0.02, 0.38), (-0.2, 0.3, 0.3)):
        sphere((x + dx * s, y, z + dz * s), r * s, color, **kw)
    box((x, y, z - 0.18 * s), (1.35 * s, 0.6 * s, 0.4 * s), color, bevel=0.18 * s, **kw)


def mountain(loc, s, color, snow=WHT, seg=7):
    x, y, z = loc
    lathe([(0, -0.7), (1.1, -0.7), (0.12, 0.78), (0, 0.8)], color, loc=loc, scale=s, seg=seg, smooth=False)
    lathe([(0, 0.18), (0.52, 0.18), (0.12, 0.78), (0, 0.84)], snow, loc=(x, y, z + 0.02 * s), scale=s * 1.04, seg=seg,
          smooth=False)


def wave(loc=(0, 0, 0), s=1.0, color=BLU):
    pts = [(-1, -0.75), (1, -0.75), (1, 0.0), (0.8, 0.5), (0.4, 0.8), (-0.1, 0.82), (-0.5, 0.62), (-0.7, 0.3),
           (-0.62, 0.05), (-0.42, 0.2), (-0.15, 0.3), (0.08, 0.18), (0.12, -0.1), (-0.1, -0.38), (-0.6, -0.52), (-1, -0.52)]
    prism([(x * s, z * s) for x, z in pts], 0.6 * s, color, loc=loc, bevel=0.08 * s)
    x0, y0, z0 = loc
    for (x, z), r in (((0.45, 0.8), 0.15), ((0.0, 0.86), 0.17), ((-0.45, 0.66), 0.15), ((-0.68, 0.34), 0.12)):
        for dy in (-0.22, 0.12):
            sphere((x0 + x * s, y0 + dy * s, z0 + z * s), r * s, WHT)


def crescent(r=0.45):
    outer = [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))) for a in range(50, 311, 10)]
    inner = [(0.2 * r / 0.45 + 0.8 * r * math.cos(math.radians(a)), 0.8 * r * math.sin(math.radians(a)))
             for a in range(285, 74, -10)]
    return outer + inner


def person(loc, s, shirt, skin=SKIN, hair="#3a2a20"):
    x, y, z = loc
    lathe([(0, -0.95), (0.62, -0.95), (0.66, -0.62), (0.5, -0.35), (0.2, -0.27), (0, -0.27)], shirt, loc=loc, scale=s)
    sphere((x, y, z + 0.2 * s), 0.48 * s, skin)
    sphere((x, y + 0.1 * s, z + 0.36 * s), 0.5 * s, hair, scale=(1.02, 0.95, 0.82))
    for e in (-1, 1):
        sphere((x + 0.17 * e * s, y - 0.43 * s, z + 0.18 * s), 0.065 * s, INK, scale=(1, 0.5, 1.4), hull=False)
        sphere((x + 0.3 * e * s, y - 0.36 * s, z + 0.03 * s), 0.07 * s, PINK, scale=(1.3, 0.5, 0.8), hull=False, emit=0.2)
    torus((x, y - 0.44 * s, z + 0.06 * s), 0.11 * s, 0.025 * s, INK, rot=(90, 0, 0), a0=200, a1=340, hull=False)


def house(x, y, w, wall, roof, h=0.8):
    box((x, y, -0.75 + h / 2), (w, 0.8, h), wall, bevel=0.05)
    prism([(-w / 2 - 0.12, 0), (w / 2 + 0.12, 0), (0, 0.5)], 0.95, roof, loc=(x, y, -0.75 + h), bevel=0.05)
    box((x - w * 0.18, y - 0.4, -0.75 + 0.22), (0.22, 0.06, 0.42), DBRN, bevel=0.03, hull=False)
    box((x + w * 0.2, y - 0.4, -0.75 + h * 0.6), (0.24, 0.06, 0.22), CYA, bevel=0.03, hull=False, emit=0.3)


# ---------------------------------------------------------------- icons

VIEW = {}  # per-icon (tilt, turn, roll) in degrees


def view(name, tilt=0, turn=-20, roll=0):
    VIEW[name] = (tilt, turn, roll)


# techniques

def i_polite():
    sphere((-0.3, 0, -0.55), 0.36, PINK, scale=(1.3, 0.8, 0.9), rot=(0, 25, 0))
    box((0.1, 0, 0.12), (0.15, 0.18, 1.35), PINK, bevel=0.05)
    flag = [(0.02, 0.79), (0.17, 0.79), (0.3, 0.62), (0.5, 0.45), (0.58, 0.18), (0.48, -0.02), (0.44, 0.2), (0.33, 0.36),
            (0.15, 0.44), (0.02, 0.44)]
    prism(flag, 0.18, PINK, bevel=0.04)
    sparkle((0.68, -0.1, 0.78), 0.2, YEL)
    sparkle((-0.68, -0.1, 0.3), 0.14, WHT)


def i_firm():
    prism(star_pts(12, 1.0, 0.72), 0.3, RED, bevel=0.05)
    prism(star_pts(12, 0.74, 0.54, rot=105), 0.3, YEL, loc=(0, -0.12, 0), bevel=0.05)
    text("!", (0, -0.34, -0.02), 1.45, WHT, depth=0.2)


def i_cupped():
    sphere((-0.75, 0, 0), 0.24, YEL, emit=0.4)
    for R, c in ((0.55, CYA), (0.9, BLU), (1.25, PUR)):
        torus((-0.75, 0, 0), R, 0.1, c, rot=(90, 0, 0), a0=-48, a1=48)


def i_thunder():
    prism(BOLT, 0.32, YEL, bevel=0.07, emit=0.4)


def i_sonic():
    capsule((-0.75, 0, 0), (0.6, 0, 0), 0.2, WHT, r2=0.14)
    cyl((0.85, 0, 0), 0.14, 0.42, RED, r2=0.0, rot=(0, 90, 0), bevel=0.02)
    prism([(0.25, 0), (-0.45, 0.8), (-0.25, 0), (-0.45, -0.8)], 0.07, BLU, rot=(90, 0, 0), bevel=0.03)
    prism([(-0.78, 0), (-0.35, 0), (-0.72, 0.48)], 0.07, BLU, bevel=0.03)
    sphere((0.32, -0.1, 0.1), 0.11, CYA, scale=(1.6, 1, 0.8))
    for x, r in ((-1.0, 0.36), (-1.35, 0.5)):
        torus((x, 0, 0), r, 0.05, CYA, rot=(0, 90, 0), emit=1.2)


def i_shockwave():
    prism(star_pts(16, 1.0, 0.75), 0.18, ORA, bevel=0.03)
    torus((0, -0.12, 0), 0.62, 0.09, YEL, rot=(90, 0, 0), emit=0.5)
    sphere((0, -0.12, 0), 0.45, "#FFF6C8", emit=1.5)


def i_seismic():
    box((0, 0, 0.05), (1.9, 0.4, 1.35), DGRY, bevel=0.1)
    box((0, -0.18, 0.07), (1.6, 0.1, 1.05), WHT, bevel=0.04, hull=False)
    tube([(-0.7, -0.26, 0.05), (-0.4, -0.26, 0.05), (-0.25, -0.26, 0.42), (-0.1, -0.26, -0.33), (0.05, -0.26, 0.35),
          (0.2, -0.26, -0.15), (0.35, -0.26, 0.05), (0.7, -0.26, 0.05)], 0.05, RED, smooth_path=False, emit=0.6, hull=False)
    box((0, 0, -0.78), (0.7, 0.35, 0.22), DGRY, bevel=0.05)


def i_tectonic():
    for s, dz in ((-1, 0.0), (1, -0.22)):
        box((0.53 * s, 0, dz - 0.15), (0.98, 1.0, 0.6), BRN, bevel=0.06)
        box((0.53 * s, 0, dz + 0.22), (0.98, 1.0, 0.16), GRN, bevel=0.05)
    for x, z, r in ((-0.15, 0.55, 0.09), (0.12, 0.7, 0.07), (0.0, 0.4, 0.06)):
        sphere((x, -0.3, z), r, GRY)
    lines_burst((0, 0, 0.25), 0.55, 0.85, 3, a0=60, a1=120)


def i_volcanic():
    lathe([(0, -0.7), (1.05, -0.7), (0.98, -0.55), (0.38, 0.4), (0.3, 0.45), (0.25, 0.38), (0, 0.36)], BRN, seg=12,
          smooth=False)
    sphere((0, 0, 0.38), 0.3, LAVA, scale=(1, 1, 0.35), emit=2.5)
    capsule((0.12, -0.32, 0.32), (0.25, -0.62, -0.1), 0.08, LAVA, emit=2.5)
    capsule((-0.15, -0.3, 0.3), (-0.33, -0.45, 0.05), 0.07, LAVA, emit=2.5)
    for x, z, r in ((0, 0.72, 0.22), (0.22, 0.95, 0.28), (-0.15, 1.12, 0.2)):
        sphere((x, 0, z), r, "#8c8a94")


def i_avalanche():
    mountain((0, 0, 0), 1.0, "#8fa6c8")
    for x, z, r in ((-0.75, -0.55, 0.22), (-0.4, -0.62, 0.15), (0.65, -0.58, 0.2), (0.95, -0.62, 0.13)):
        sphere((x, -0.35, z), r, WHT)


def i_hurricane():
    for i in range(6):
        sphere((0.06 * math.sin(i * 1.4), 0, -0.8 + i * 0.3), 1, "#a9bcd8" if i % 2 else "#cdd9ee",
               scale=(0.16 + i * 0.14, 0.16 + i * 0.14, 0.17))
    for x, z in ((-0.9, 0.4), (0.85, 0.0), (-0.7, -0.4)):
        box((x, -0.2, z), (0.14, 0.14, 0.14), BRN, rot=(30, 20, 40), bevel=0.02)


def i_earthquake():
    box((-0.5, 0, -0.32), (0.95, 1.0, 0.75), BRN, rot=(0, -10, 0), bevel=0.06)
    box((-0.5, 0, 0.1), (0.95, 1.0, 0.16), GRN, rot=(0, -10, 0), bevel=0.05)
    box((0.52, 0, -0.45), (0.95, 1.0, 0.75), BRN, rot=(0, 12, 0), bevel=0.06)
    box((0.52, 0, -0.03), (0.95, 1.0, 0.16), GRN, rot=(0, 12, 0), bevel=0.05)
    lines_burst((0, 0, 0.1), 0.45, 0.85, 5, a0=30, a1=150)


def i_tsunami():
    wave()


def i_mountain():
    mountain((0.45, 0.35, -0.15), 0.75, DGRN)
    mountain((-0.2, 0, 0), 1.0, GRN)


def i_supercell():
    cloud((0, 0, 0.35), 1.0, "#6d7487")
    prism(BOLT, 0.22, YEL, loc=(0.05, -0.15, -0.45), scale=0.55, bevel=0.05, emit=1.0)
    for x in (-0.55, -0.3, 0.45):
        capsule((x, -0.1, -0.25), (x - 0.08, -0.1, -0.55), 0.045, CYA, emit=0.5)


def i_continental():
    globe((0, 0, 0), 0.85)
    torus((0, 0, 0), 1.08, 0.07, YEL, rot=(12, 0, 0), emit=0.8)


def i_tidal():
    wave(loc=(0.12, 0, -0.25), s=0.8)
    prism(crescent(0.45), 0.2, YEL, loc=(-0.55, -0.05, 0.62), bevel=0.05, emit=0.8)


def i_atmospheric():
    cloud((0, 0, 0.15), 1.0, WHT)
    for z, x0, x1 in ((-0.4, -0.9, 0.5), (-0.6, -0.4, 0.95), (0.55, 0.6, 1.1)):
        tube([(x0, -0.35, z), ((x0 + x1) / 2, -0.35, z + 0.06), (x1, -0.35, z)], 0.045, CYA, emit=0.6)


def i_stratospheric():
    lathe([(0, -0.7), (0.25, -0.7), (0.33, -0.4), (0.35, 0.1), (0.3, 0.45), (0.17, 0.75), (0, 0.9)], WHT)
    lathe([(0, 0.42), (0.32, 0.42), (0.18, 0.75), (0, 0.93)], RED)
    torus((0, -0.32, 0.1), 0.13, 0.045, GRY, rot=(90, 0, 0))
    sphere((0, -0.3, 0.1), 0.12, CYA, scale=(1, 0.5, 1))
    for s in (1, -1):
        prism([(0.25 * s, -0.65), (0.62 * s, -0.88), (0.56 * s, -0.4), (0.3 * s, -0.2)][::s], 0.08, RED, bevel=0.03)
    lathe([(0, -0.66), (0.22, -0.7), (0.15, -0.98), (0, -1.25)], ORA, emit=2.0, hull=False)
    lathe([(0, -0.66), (0.13, -0.7), (0.08, -0.9), (0, -1.05)], YEL, loc=(0, -0.05, 0), emit=3.0, hull=False)


def i_meteor():
    capsule((-0.3, 0.2, -0.3), (0.8, 0.2, 0.8), 0.5, ORA, r2=0.05, emit=1.6, hull=False)
    capsule((-0.3, 0.05, -0.3), (0.55, 0.05, 0.55), 0.36, YEL, r2=0.04, emit=2.0, hull=False)
    c, r = (-0.35, -0.1, -0.35), 0.55
    sphere(c, r, "#8a5a3c")
    for lat, lon, s in ((20, -20, 0.28), (-25, 15, 0.2), (5, 40, 0.16), (-10, -50, 0.15)):
        patch(c, r, latlon(lat, lon), s, "#5e3b25", flat=0.25)


def i_extinction():
    sphere((0, 0, -0.15), 0.5, GRN, scale=(1.3, 0.9, 1))
    capsule((0.4, 0, 0.0), (0.62, 0, 0.55), 0.2, GRN)
    sphere((0.78, 0, 0.68), 0.3, GRN, scale=(1.35, 0.9, 1))
    capsule((-0.55, 0, -0.2), (-1.15, 0, -0.5), 0.25, GRN, r2=0.05)
    for x in (-0.32, 0.3):
        for y in (-0.22, 0.22):
            capsule((x, y, -0.4), (x, y, -0.82), 0.12, DGRN)
    for i, x in enumerate((-0.4, -0.1, 0.2)):
        cyl((x, 0, 0.32 - abs(x) * 0.25), 0.1, 0.25, ORA, r2=0.0, rot=(0, -15, 0), bevel=0.02)
    sphere((0.88, -0.2, 0.8), 0.09, WHT)
    sphere((0.9, -0.27, 0.81), 0.045, INK, hull=False)
    for x, z in ((-0.1, -0.05), (0.25, 0.05)):
        patch((0, 0, -0.15), 0.48, (x, -1, z), 0.18, DGRN, flat=0.2)


def i_mantle():
    c = cutter(box((0.6, -0.6, 0.6), (1.2, 1.2, 1.2), WHT, bevel=0))
    c2 = cutter(box((0.68, -0.68, 0.68), (1.2, 1.2, 1.2), WHT, bevel=0))
    sphere((0, 0, 0), 1.0, BLU, cut=[c])
    for lat, lon, s in ((25, -50, 0.4), (-30, -40, 0.3), (-10, 30, 0.25)):
        patch((0, 0, 0), 1.0, latlon(lat, lon), s, GRN)
    sphere((0, 0, 0), 0.8, ORA, cut=[c2], emit=0.6)
    sphere((0, 0, 0), 0.42, YEL, emit=1.8)


def i_core():
    prism(star_pts(14, 1.0, 0.78), 0.16, RED, bevel=0.03)
    torus((0, -0.1, 0), 0.68, 0.1, ORA, rot=(90, 0, 0), emit=0.6)
    torus((0, -0.1, 0), 0.68, 0.06, YEL, rot=(70, 30, 0), emit=0.6)
    sphere((0, -0.1, 0), 0.42, YEL, emit=2.2)


def i_magma():
    prof = [(0.62 * math.cos(math.radians(a)), -0.1 + 0.62 * math.sin(math.radians(a))) for a in range(-90, 31, 10)]
    prof[0] = (0, prof[0][1])
    lathe(prof + [(0.2, 0.62), (0, 0.98)], LAVA, emit=0.9)
    for x, z, r in ((-0.2, -0.05, 0.1), (0.15, -0.3, 0.13), (0.22, 0.12, 0.07)):
        sphere(on_sphere((0, 0, -0.1), 0.6, x, z, 0.0), r, YEL, emit=2.0, hull=HULL * 0.5)


def i_crustbreaker():
    capsule((-0.6, 0, -0.9), (0.22, 0, 0.42), 0.1, BRN)
    box((0.3, 0, 0.52), (1.0, 0.52, 0.48), GRY, rot=(0, 32, 0), bevel=0.08, metal=0.4)
    box((0.3, 0, 0.52), (0.3, 0.56, 0.52), DGRY, rot=(0, 32, 0), bevel=0.04, metal=0.4)
    lines_burst((0.78, 0, 0.2), 0.3, 0.6, 4, a0=-90, a1=10)


def i_planetcracker():
    globe((0, 0, 0), 1.0, clouds=False)
    pts = [(-0.75, 0.4), (-0.4, 0.2), (-0.25, 0.45), (0.05, 0.05), (0.2, 0.25), (0.45, -0.2), (0.7, -0.1)]
    tube([on_sphere((0, 0, 0), 1.0, x, z, 0.02) for x, z in pts], 0.06, LAVA, smooth_path=False, emit=3.0, hull=False)
    sparkle((0.85, -0.3, 0.85), 0.25, YEL)


def i_gravity():
    torus((0, 0, 0), 0.95, 0.2, ORA, rot=(14, 0, 0), scale=(1, 1, 0.3), emit=1.5)
    torus((0, 0, 0), 0.72, 0.12, PINK, rot=(14, 0, 0), scale=(1, 1, 0.3), emit=1.5)
    sphere((0, 0, 0), 0.52, "#141020", rough=0.15)
    torus((0, 0.15, 0), 0.6, 0.05, PUR, rot=(90, 0, 0), emit=1.5, hull=False)
    sparkle((0.9, -0.2, 0.7), 0.18)
    sparkle((-0.85, -0.2, -0.6), 0.14)


def i_orbital():
    box((0, 0, 0), (0.5, 0.5, 0.65), GOLD, bevel=0.05, metal=0.4, rough=0.25)
    for s in (1, -1):
        capsule((0.25 * s, 0, 0), (0.42 * s, 0, 0), 0.04, GRY)
        box((0.85 * s, 0, 0), (0.85, 0.06, 0.48), BLU, bevel=0.02)
        for k in (-0.2, 0.0, 0.2):
            box((0.85 * s + k, -0.035, 0), (0.025, 0.02, 0.46), "#1e3f8c", bevel=0, hull=False)
    lathe([(0, 0.0), (0.12, 0.01), (0.25, 0.12), (0.3, 0.2), (0, 0.15)], WHT, loc=(0, 0, 0.4))
    capsule((0, 0, 0.5), (0, 0, 0.8), 0.03, GRY)
    sphere((0, 0, 0.82), 0.06, RED, emit=1.0)


def i_cosmic():
    sphere((0, 0, 0), 1.0, PUR, scale=(1.0, 1.0, 0.18), rot=(-62, 0, 0), emit=0.4)
    tilt = Euler((math.radians(-62), 0, 0)).to_matrix()
    for arm, col in ((0, PINK), (math.pi, CYA)):
        pts = []
        for i in range(14):
            t = i / 13
            a = arm + t * 3.2
            r = 0.15 + 0.85 * t
            pts.append(tuple(tilt @ Vector((r * math.cos(a), r * math.sin(a), -0.17))))
        tube(pts, 0.07, col, emit=1.2, hull=False)
    sphere((0, 0, 0), 0.3, "#FFF0B8", scale=(1, 1, 0.7), emit=2.5)
    sparkle((0.85, -0.3, 0.7), 0.16)
    sparkle((-0.9, -0.3, -0.5), 0.13)


# crowd

def i_classmate():
    person((0, 0, 0), 1.0, NAVY)
    box((0, -0.32, -0.4), (0.18, 0.05, 0.22), WHT, rot=(15, 0, 0), bevel=0.02, hull=False)


def i_teacher():
    for (z, w, c, r) in ((-0.72, 1.35, BLU, 0), (-0.47, 1.22, RED, 7), (-0.22, 1.28, GRN, -5)):
        box((0, 0, z), (w, 0.85, 0.25), c, rot=(0, 0, r), bevel=0.04)
        box((0.0, -0.03, z), (w - 0.08, 0.85, 0.16), CREAM, rot=(0, 0, r), bevel=0.02, hull=False)
    sphere((0.05, 0, 0.28), 0.36, RED, scale=(1.05, 1, 0.92))
    capsule((0.05, 0, 0.55), (0.1, 0, 0.75), 0.04, DBRN)
    sphere((0.26, 0, 0.72), 0.14, GRN, scale=(1.4, 0.4, 0.7), rot=(0, -30, 0))


def i_band():
    lathe([(0.06, -0.1), (0.08, 0.2), (0.15, 0.42), (0.3, 0.6), (0.48, 0.7), (0.0, 0.66)], GOLD, loc=(0.3, 0, 0),
          rot=(0, 90, 0), metal=0.35, rough=0.2)
    capsule((-0.9, 0, 0), (0.3, 0, 0), 0.075, GOLD, metal=0.35, rough=0.2)
    capsule((-0.55, 0, -0.3), (0.1, 0, -0.3), 0.075, GOLD, metal=0.35, rough=0.2)
    torus((0.1, 0, -0.15), 0.15, 0.075, GOLD, rot=(90, 0, 0), a0=-90, a1=90, metal=0.35, rough=0.2)
    for x in (-0.35, -0.15, 0.05):
        cyl((x, 0, 0.1), 0.075, 0.5, GOLD, metal=0.35, rough=0.2)
        sphere((x, 0, 0.38), 0.09, WHT, scale=(1, 1, 0.6))
    lathe([(0.04, 0.0), (0.06, 0.12), (0.13, 0.2), (0, 0.19)], GOLD, loc=(-0.85, 0, 0), rot=(0, -90, 0), metal=0.35)


def i_cheer():
    lathe([(0, -0.75), (0.13, -0.75), (0.2, -0.55), (0.58, 0.45), (0.65, 0.56), (0, 0.5)], RED, rot=(0, 75, 0))
    torus((0.53, 0, 0.14), 0.62, 0.07, WHT, rot=(0, 75, 0))
    capsule((-0.25, 0, -0.1), (-0.3, 0, -0.5), 0.09, DGRY)
    lines_burst((0.6, 0, 0.15), 0.85, 1.2, 3, a0=-30, a1=50)


def i_school():
    box((0, 0, -0.32), (2.0, 0.8, 0.9), CREAM, bevel=0.05)
    box((0, 0, 0.13), (2.1, 0.88, 0.08), GRY, bevel=0.03)
    box((0, 0, 0.42), (0.62, 0.72, 0.6), CREAM, bevel=0.05)
    prism([(-0.42, 0), (0.42, 0), (0, 0.38)], 0.8, RED, loc=(0, 0, 0.72), bevel=0.04)
    cyl((0, -0.38, 0.45), 0.18, 0.06, WHT, rot=(90, 0, 0))
    capsule((0, -0.42, 0.45), (0, -0.42, 0.57), 0.02, INK, hull=False)
    capsule((0, -0.42, 0.45), (0.09, -0.42, 0.45), 0.02, INK, hull=False)
    for row in (-0.2, -0.55):
        for x in (-0.8, -0.5, 0.5, 0.8):
            box((x, -0.4, row), (0.2, 0.06, 0.2), BLU, bevel=0.02, hull=False, emit=0.2)
    box((0, -0.4, -0.5), (0.34, 0.06, 0.45), DBRN, bevel=0.03, hull=False)


def i_choir():
    capsule((0, 0, 0.05), (0, 0, -0.95), 0.15, "#2c2a35", r2=0.1)
    torus((0, 0, 0.12), 0.2, 0.06, GRY, metal=0.5)
    sphere((0, 0, 0.45), 0.42, GRY, metal=0.5, rough=0.3)
    for z in (0.3, 0.45, 0.6):
        torus((0, 0, z), math.sqrt(max(0.42 ** 2 - (z - 0.45) ** 2, 0)) + 0.005, 0.015, DGRY, hull=False)
    sparkle((0.62, -0.2, 0.75), 0.15, PINK)


def i_orchestra():
    def w(z):
        return 0.28 + 0.24 * math.exp(-((z + 0.5) / 0.25) ** 2) + 0.15 * math.exp(-((z - 0.2) / 0.18) ** 2)

    zs = [-0.86 + 1.32 * i / 40 for i in range(41)]
    side = [(w(z) * max(0.0, 1 - ((z + 0.2) / 0.66) ** 8) ** 0.5, z) for z in zs]
    pts = [(x, z) for x, z in side] + [(-x, z) for x, z in reversed(side)]
    prism(pts, 0.3, "#C0602A", bevel=0.08)
    box((0, 0, 0.85), (0.13, 0.16, 0.85), DBRN, bevel=0.03)
    sphere((0, 0, 1.3), 0.1, DBRN)
    box((0, -0.16, -0.25), (0.3, 0.05, 0.06), CREAM, bevel=0.01, hull=False)
    for x in (-0.045, -0.015, 0.015, 0.045):
        capsule((x, -0.17, -0.6), (x * 0.6, -0.1, 1.2), 0.008, WHT, hull=False)
    capsule((-0.9, -0.3, -0.85), (0.85, -0.3, 0.75), 0.03, DBRN)


def i_stadium():
    lathe([(0.62, -0.25), (1.0, 0.2), (1.08, 0.2), (1.08, -0.35), (0.62, -0.35)], GRY, scale=(1.35, 1, 1), closed=True)
    cyl((0, 0, -0.3), 0.66, 0.1, GRN, scale=(1.35, 1, 1), bevel=0.02)
    torus((0, 0, -0.24), 0.22, 0.015, WHT, hull=False, emit=0.5)
    for x in (-1.25, 1.25):
        capsule((x, 0.2, 0.15), (x, 0.2, 0.8), 0.04, DGRY)
        box((x, 0.2, 0.85), (0.3, 0.1, 0.16), YEL, bevel=0.03, emit=1.5)


def cloth(w, h, thick, color, loc, amp=0.08, freq=4.5, nx=28, **kw):
    """a waving flag/curtain sheet in the XZ plane"""
    bm = bmesh.new()
    grid = {}
    for side, dy in ((0, -thick / 2), (1, thick / 2)):
        for i in range(nx + 1):
            x = w * i / nx
            y = amp * math.sin(freq * x) + dy
            for j, z in enumerate((0, h)):
                grid[side, i, j] = bm.verts.new((x, y, z))
    for i in range(nx):
        bm.faces.new((grid[0, i, 0], grid[0, i + 1, 0], grid[0, i + 1, 1], grid[0, i, 1]))
        bm.faces.new((grid[1, i, 1], grid[1, i + 1, 1], grid[1, i + 1, 0], grid[1, i, 0]))
        bm.faces.new((grid[0, i, 1], grid[0, i + 1, 1], grid[1, i + 1, 1], grid[1, i, 1]))
        bm.faces.new((grid[1, i, 0], grid[1, i + 1, 0], grid[0, i + 1, 0], grid[0, i, 0]))
    for i in (0, nx):
        bm.faces.new((grid[0, i, 0], grid[0, i, 1], grid[1, i, 1], grid[1, i, 0]))
    return _finish(bm, color, loc, (0, 0, 0), (1, 1, 1), bevel=0.02, **kw)


def i_nation():
    capsule((-0.78, 0, -1.0), (-0.78, 0, 0.95), 0.06, GRY, metal=0.4)
    sphere((-0.78, 0, 1.0), 0.1, GOLD, metal=0.4)
    cloth(1.55, 1.0, 0.06, WHT, (-0.75, 0, -0.05))
    x = 0.78
    sphere((-0.75 + x, 0.08 * math.sin(4.5 * x) - 0.03, 0.45), 0.28, RED, scale=(1, 0.15, 1), hull=False)


def i_global():
    globe((0, 0, 0.2), 0.72)
    torus((0, 0, 0.2), 0.86, 0.05, GOLD, rot=(90, 0, 60), a0=-120, a1=120, metal=0.4)
    capsule((0, 0, -0.66), (0, 0, -0.85), 0.07, GOLD, metal=0.4)
    cyl((0, 0, -0.92), 0.42, 0.14, GOLD, metal=0.4)


def i_drummers():
    cyl((0, 0, -0.15), 0.7, 0.85, RED, bevel=0.04)
    cyl((0, 0, 0.3), 0.7, 0.06, WHT, bevel=0.02)
    for z in (0.27, -0.57):
        torus((0, 0, z), 0.72, 0.06, GOLD, metal=0.4)
    pts = []
    for i in range(9):
        a = math.radians(-160 + 140 * i / 8)
        z = 0.2 if i % 2 == 0 else -0.5
        pts.append((0.725 * math.cos(a), 0.725 * math.sin(a), z))
    tube(pts, 0.025, WHT, smooth_path=False, hull=False)
    for s in (1, -1):
        capsule((0.75 * s, -0.1, 0.95), (-0.15 * s, -0.1, 0.4), 0.05, CREAM)
        sphere((-0.15 * s, -0.1, 0.4), 0.08, CREAM)


def i_cosmos():
    prof = []
    for i in range(25):
        t = math.pi * i / 24
        prof.append((0.75 * math.sin(t) * (0.62 + 0.38 * (1 - math.cos(t)) / 2), -0.75 * math.cos(t)))
    prof[0], prof[-1] = (0, prof[0][1]), (0, prof[-1][1])
    lathe(prof, GRN, scale=(1, 0.9, 1.05))
    for s in (1, -1):
        sphere((0.28 * s, -0.5, 0.05), 0.22, "#101018", scale=(1.3, 0.6, 0.85), rot=(0, -28 * s, 0), rough=0.1)
        sphere((0.22 * s, -0.66, 0.12), 0.05, WHT, emit=1, hull=False)
        capsule((0.25 * s, 0, 0.7), (0.45 * s, 0, 1.05), 0.035, DGRN)
        sphere((0.45 * s, 0, 1.08), 0.09, YEL, emit=1.2)
    torus((0, -0.62, -0.3), 0.08, 0.02, INK, rot=(90, 0, 0), a0=200, a1=340, hull=False)


# stages

def i_ceremony():
    lathe([(0, 0), (0.45, 0), (0.45, 0.35), (0, 0.35)], "#26232e", loc=(0, 0, 0.0))
    box((0, 0, 0.4), (1.25, 1.25, 0.1), "#26232e", rot=(0, 0, 45), bevel=0.02)
    sphere((0, 0, 0.47), 0.07, GOLD)
    capsule((0, 0, 0.47), (0.55, -0.55, 0.42), 0.03, GOLD)
    capsule((0.55, -0.55, 0.42), (0.58, -0.58, 0.0), 0.04, GOLD)
    cyl((0.0, -0.45, -0.5), 0.2, 1.5, CREAM, rot=(0, 90, -15))
    torus((0.0, -0.45, -0.5), 0.21, 0.05, RED, rot=(0, 90, -15))


def i_gym():
    sphere((0, 0, 0), 1.0, ORA, rough=0.6, coat=0.1)
    seam = "#3a1d0b"
    torus((0, 0, 0), 1.0, 0.035, seam, hull=False)
    torus((0, 0, 0), 1.0, 0.035, seam, rot=(0, 90, 0), hull=False)
    for s in (1, -1):
        torus((0.6 * s, 0, 0), 0.8, 0.035, seam, rot=(0, 90, 0), hull=False)


def i_town():
    cyl((0, 0.1, -0.82), 1.3, 0.12, GRN, scale=(1, 0.65, 1), bevel=0.04)
    house(0.55, 0.3, 0.75, "#cfe6ff", BLU, h=0.95)
    house(-0.4, -0.05, 0.9, CREAM, RED)
    capsule((1.05, -0.2, -0.75), (1.05, -0.2, -0.4), 0.06, DBRN)
    sphere((1.05, -0.2, -0.25), 0.25, DGRN)


def i_city():
    box((0, 0, -0.9), (2.0, 0.9, 0.12), GRY, bevel=0.03)
    for x, h, c in ((-0.62, 1.15, BLU), (0.05, 1.75, "#5f7fd8"), (0.66, 1.35, "#4fb8d8")):
        box((x, 0, -0.84 + h / 2), (0.55, 0.55, h), c, bevel=0.04)
        rows = int((h - 0.2) / 0.22)
        for r in range(rows):
            for k in (-0.12, 0.12):
                box((x + k, -0.28, -0.7 + r * 0.22), (0.12, 0.03, 0.12), YEL, bevel=0, hull=False, emit=1.2)
    capsule((0.05, 0, 0.9), (0.05, 0, 1.15), 0.03, GRY)
    sphere((0.05, 0, 1.17), 0.05, RED, emit=1.5)


def i_region():
    sphere((0.55, 0.5, 0.45), 0.45, RED, emit=0.6)
    lathe([(0, -0.7), (1.15, -0.7), (0.3, 0.45), (0, 0.5)], "#4a78d0", seg=10, smooth=False)
    lathe([(0, 0.0), (0.62, 0.0), (0.3, 0.45), (0, 0.52)], WHT, loc=(0, 0, 0.01), scale=1.03, seg=10, smooth=False,
          ribs=5, rib_depth=0.18)


def i_country():
    for s in (1, -1):
        cyl((0.58 * s, 0, -0.25), 0.1, 1.4, RED, bevel=0.03)
        cyl((0.58 * s, 0, -0.92), 0.13, 0.16, "#26232e", bevel=0.03)
    box((0, 0, 0.5), (1.6, 0.22, 0.14), RED, bevel=0.03)
    prism([(-1.0, 0.76), (-0.86, 0.6), (0.86, 0.6), (1.0, 0.76), (0.6, 0.7), (0, 0.69), (-0.6, 0.7)], 0.28, "#26232e",
          bevel=0.03)
    box((0, 0, 0.2), (1.45, 0.16, 0.12), RED, bevel=0.03)
    box((0, -0.03, 0.35), (0.22, 0.2, 0.22), "#26232e", bevel=0.02)


def i_planet():
    globe((0, 0, 0), 1.0)


def i_molten():
    c, r = (0, 0, 0), 1.0
    sphere(c, r, "#4a1d10", rough=0.5)
    cracks = [[(-0.8, 0.3), (-0.4, 0.15), (-0.2, 0.4), (0.15, 0.2), (0.5, 0.45), (0.75, 0.3)],
              [(-0.6, -0.5), (-0.25, -0.25), (0.05, -0.45), (0.35, -0.15), (0.7, -0.35)],
              [(0.15, 0.2), (0.05, -0.05), (0.05, -0.45)]]
    for pts in cracks:
        tube([on_sphere(c, r, x, z, 0.01) for x, z in pts], 0.05, LAVA, smooth_path=False, emit=3.0, hull=False)
    for x, z, s in ((-0.45, -0.05, 0.12), (0.45, 0.05, 0.1)):
        sphere(on_sphere(c, r, x, z), s, ORA, emit=2.5, hull=False)


def i_space():
    sphere((0, 0, 0), 0.72, PUR)
    for z, col in ((0.25, PINK), (-0.2, "#c79bff")):
        torus((0, 0, z), math.sqrt(0.72 ** 2 - z * z) + 0.005, 0.05, col, hull=False)
    torus((0, 0, 0), 1.12, 0.16, GOLD, rot=(-18, -16, 0), scale=(1, 1, 0.2))
    sparkle((0.9, -0.3, 0.7), 0.16)
    sparkle((-0.85, -0.3, -0.65), 0.13)


# event items and currencies

def i_pumpkin():
    hole = "#2a1206"
    cuts = [
        cutter(prism([(-0.55, 0.05), (-0.18, 0.05), (-0.36, 0.38)], 0.8, WHT, loc=(0, -0.75, 0.04), bevel=0)),
        cutter(prism([(0.18, 0.05), (0.55, 0.05), (0.36, 0.38)], 0.8, WHT, loc=(0, -0.75, 0.04), bevel=0)),
        cutter(prism([(-0.6, -0.12), (-0.35, -0.22), (-0.2, -0.14), (0, -0.25), (0.2, -0.14), (0.35, -0.22), (0.6, -0.12),
                      (0.4, -0.45), (0.15, -0.36), (0, -0.5), (-0.15, -0.36), (-0.4, -0.45)], 0.8, WHT, loc=(0, -0.75, 0),
                     bevel=0)),
    ]
    prof = [(math.sin(t) * (1 + 0.08 * math.sin(t)), -0.62 * math.cos(t)) for t in (math.pi * i / 24 for i in range(25))]
    prof[0] = (0, prof[0][1] + 0.08)
    prof[-1] = (0, prof[-1][1] - 0.08)
    lathe(prof, ORA, scale=(1, 0.85, 1), ribs=8, rib_depth=0.1, seg=96, cut=cuts, hull=HULL * 0.7)
    sphere((0, 0, 0), 0.7, YEL, scale=(1, 0.7, 0.7), emit=6, hull=False)
    capsule((0, 0, 0.45), (0.14, 0, 0.88), 0.13, DGRN)
    del hole


def i_boost():
    cyl((0, 0, 0), 0.95, 0.3, PUR, rot=(90, 0, 0), bevel=0.1)
    torus((0, -0.15, 0), 0.8, 0.05, "#c49bff", rot=(90, 0, 0), hull=False)
    prism(BOLT, 0.14, YEL, loc=(-0.12, -0.22, 0.08), scale=0.55, bevel=0.04, emit=0.8)
    text("2x", (0.42, -0.25, -0.45), 0.5, WHT, depth=0.14)


def i_bat():
    body = "#5a3380"
    wing = [(0.2, 0.2), (0.55, 0.5), (0.95, 0.55), (1.25, 0.3), (1.15, -0.05), (1.0, -0.12), (0.88, -0.02), (0.72, -0.12),
            (0.58, -0.02), (0.42, -0.12), (0.3, -0.05), (0.2, -0.1)]
    prism(wing, 0.08, "#3d2260", bevel=0.03)
    prism([(-x, z) for x, z in reversed(wing)], 0.08, "#3d2260", bevel=0.03)
    sphere((0, -0.05, -0.05), 0.4, body, scale=(1, 0.9, 1.05))
    for s in (1, -1):
        prism([(0.12 * s, 0.25), (0.32 * s, 0.25), (0.28 * s, 0.6)][::s], 0.1, body, bevel=0.03)
        sphere((0.15 * s, -0.38, 0.05), 0.08, YEL, emit=2.0, hull=False)
        cyl((0.07 * s, -0.36, -0.22), 0.035, 0.1, WHT, r2=0.0, rot=(180, 0, 0), bevel=0, hull=False)


def i_ghost():
    prof = [(0.6 * math.sin(t), 0.25 + 0.6 * math.cos(t)) for t in (math.pi / 2 * (1 - i / 12) for i in range(13))]
    prof = [(0, 0.85)] + [p for p in reversed(prof)][1:] + [(0.62, -0.5), (0.55, -0.58), (0, -0.55)]
    lathe(prof, WHT, emit=0.25)
    for i in range(8):
        a = 2 * math.pi * i / 8
        sphere((0.58 * math.cos(a), 0.58 * math.sin(a), -0.58), 0.12, WHT, emit=0.25, hull=False)
    for s in (1, -1):
        sphere((0.2 * s, -0.55, 0.3), 0.09, INK, scale=(1, 0.5, 1.5), hull=False)
        sphere((0.36 * s, -0.48, 0.12), 0.08, PINK, scale=(1.3, 0.5, 0.8), hull=False)
        capsule((0.55 * s, 0, -0.05), (0.8 * s, -0.1, 0.12), 0.1, WHT, emit=0.25)
    sphere((0, -0.58, 0.08), 0.07, INK, scale=(1, 0.5, 1.3), hull=False)


def i_santa():
    lathe([(0, -0.2), (0.58, -0.2), (0.48, 0.2), (0.28, 0.55), (0, 0.72)], RED)
    capsule((0.05, 0, 0.66), (0.6, -0.05, 0.42), 0.12, RED, r2=0.07)
    sphere((0.66, -0.05, 0.35), 0.18, WHT, rough=0.8, coat=0)
    torus((0, 0, -0.2), 0.6, 0.18, WHT, rough=0.8, coat=0)


def i_snowflake():
    ice = "#bfefff"
    for k in range(6):
        a = math.radians(90 + 60 * k)
        d = Vector((math.cos(a), 0, math.sin(a)))
        capsule((0, 0, 0), tuple(d * 0.95), 0.075, ice, emit=0.3, rough=0.15)
        mid = d * 0.55
        for b in (-1, 1):
            ab = a + b * math.radians(45)
            capsule(tuple(mid), tuple(mid + Vector((math.cos(ab), 0, math.sin(ab))) * 0.3), 0.06, ice, emit=0.3, rough=0.15)
    prism(circle_pts(0.22, 6), 0.2, WHT, bevel=0.05, emit=0.4)


def i_star():
    prism(star_pts(5, 1.0, 0.48), 0.42, YEL, bevel=0.14, emit=0.3)
    sphere((-0.18, -0.25, 0.08), 0.08, INK, scale=(1, 0.6, 1.4), hull=False)
    sphere((0.18, -0.25, 0.08), 0.08, INK, scale=(1, 0.6, 1.4), hull=False)


def i_candy():
    capsule((0, 0, -1.05), (0, 0, -0.2), 0.07, WHT)
    cyl((0, 0, 0.25), 0.62, 0.22, PINK, rot=(90, 0, 0), bevel=0.1)
    pts = []
    for i in range(70):
        t = i / 69
        a = t * 4.2 * math.pi
        r = 0.08 + 0.46 * t
        pts.append((r * math.cos(a), -0.13, 0.25 + r * math.sin(a)))
    tube(pts, 0.055, WHT, hull=HULL * 0.5)


def i_present():
    box((0, 0, -0.25), (1.3, 1.1, 0.95), RED, bevel=0.06)
    box((0, 0, 0.3), (1.45, 1.25, 0.28), RED, bevel=0.06)
    box((0, 0, -0.1), (0.28, 1.12, 1.3), GOLD, bevel=0.03)
    box((0, 0, -0.12), (1.47, 0.28, 1.0), GOLD, bevel=0.03)
    torus((-0.25, 0, 0.6), 0.25, 0.09, GOLD, rot=(90, -30, 0))
    torus((0.25, 0, 0.6), 0.25, 0.09, GOLD, rot=(90, 30, 0))
    sphere((0, 0, 0.5), 0.13, GOLD)


# menu buttons

def i_hands():
    hand(1, loc=(-0.42, 0, 0.0), tilt=16)
    hand(-1, loc=(0.42, 0, 0.0), tilt=-16)
    lines_burst((0, 0, 0.55), 0.95, 1.25, 5, a0=35, a1=145, w=0.06)


def i_strong():
    capsule((-0.95, 0, -0.55), (-0.55, 0, -0.55), 0.36, NAVY)
    capsule((-0.6, 0, -0.55), (0.3, 0, -0.55), 0.3, SKIN)
    sphere((-0.15, -0.05, -0.32), 0.4, SKIN, scale=(1.2, 0.9, 0.9))
    capsule((0.3, 0, -0.55), (0.48, 0, 0.35), 0.27, SKIN)
    sphere((0.5, 0, 0.55), 0.32, SKIN, scale=(1, 0.9, 1.1))
    lines_burst((-0.15, 0, -0.1), 0.55, 0.85, 3, a0=80, a1=150)


def i_trophy():
    gold = dict(metal=0.35, rough=0.22)
    lathe([(0, 0.05), (0.18, 0.08), (0.45, 0.25), (0.62, 0.6), (0.68, 0.95), (0.6, 0.98), (0, 0.98)], GOLD, **gold)
    for s in (1, -1):
        torus((0.62 * s, 0, 0.62), 0.22, 0.07, GOLD, rot=(90, 0, 0), a0=-90 if s > 0 else 90, a1=90 if s > 0 else 270, **gold)
    cyl((0, 0, -0.1), 0.12, 0.35, GOLD, **gold)
    box((0, 0, -0.42), (0.9, 0.6, 0.32), DBRN, bevel=0.06)
    box((0, 0, -0.27), (0.65, 0.45, 0.12), GOLD, bevel=0.04, **gold)


def i_gear():
    pts = []
    n = 10
    for i in range(n):
        a = 2 * math.pi * i / n
        for da, r in ((-0.2, 0.78), (-0.12, 1.0), (0.12, 1.0), (0.2, 0.78)):
            pts.append((r * math.cos(a + da), r * math.sin(a + da)))
    prism(pts, 0.32, GRY, bevel=0.05, metal=0.4, rough=0.3)
    cyl((0, -0.12, 0), 0.4, 0.2, DGRY, rot=(90, 0, 0), bevel=0.04, metal=0.4)
    cyl((0, -0.2, 0), 0.18, 0.1, INK, rot=(90, 0, 0), bevel=0.02, hull=False)


def i_map():
    panels = ((-0.58, 20, CREAM), (0, -20, "#f0dca6"), (0.58, 20, CREAM))
    for x, a, c in panels:
        box((x, 0, 0), (0.62, 0.05, 1.3), c, rot=(0, 0, a), bevel=0.02)
    pts = []
    for i in range(13):
        x = -0.75 + 1.4 * i / 12
        xi, a, _ = min(panels, key=lambda p: abs(p[0] - x))
        y = math.tan(math.radians(a)) * (x - xi) - 0.06
        pts.append((x, y, -0.35 + 0.5 * math.sin(i * 0.7) * (i / 12)))
    for i in range(0, len(pts) - 1, 2):
        tube([pts[i], pts[i + 1]], 0.035, RED, smooth_path=False, hull=False)
    sphere((0.68, -0.25, 0.45), 0.13, RED)
    cyl((0.68, -0.25, 0.25), 0.1, 0.3, RED, r2=0.0, rot=(180, 0, 0), bevel=0)


def i_walk():
    box((0, 0, -0.5), (1.75, 0.75, 0.2), WHT, bevel=0.09)
    box((-0.28, 0, -0.12), (1.1, 0.68, 0.6), RED, bevel=0.22)
    sphere((0.42, 0, -0.27), 0.4, RED, scale=(1.2, 0.85, 0.55))
    torus((-0.52, 0, 0.17), 0.22, 0.06, WHT, scale=(1, 1.3, 1))
    for i in range(3):
        x = 0.0 + i * 0.16
        capsule((x, -0.3, 0.12 - i * 0.07), (x + 0.05, 0.3, 0.12 - i * 0.07), 0.035, WHT, hull=False)
    prism([(-0.75, -0.3), (0.2, -0.3), (-0.05, -0.12), (-0.6, -0.15)], 0.7, WHT, bevel=0.02, hull=False)


def i_chair():
    box((0, 0, -0.05), (0.95, 0.88, 0.14), BRN, bevel=0.04)
    for x in (-0.38, 0.38):
        for y in (-0.35, 0.35):
            box((x, y, -0.5), (0.1, 0.1, 0.8), DBRN, bevel=0.02)
        box((x, 0.38, 0.4), (0.1, 0.1, 0.8), DBRN, bevel=0.02)
    box((0, 0.4, 0.62), (0.9, 0.1, 0.35), BRN, bevel=0.04)


def i_crowd():
    person((-0.62, 0.3, 0.12), 0.75, BLU)
    person((0.62, 0.3, 0.12), 0.75, GRN, hair="#6b3a1f")
    person((0, -0.1, -0.05), 0.9, ORA, hair="#2a1c14")


def i_upgrade():
    prism([(-0.36, -0.95), (0.36, -0.95), (0.36, 0.05), (0.78, 0.05), (0, 0.95), (-0.78, 0.05), (-0.36, 0.05)], 0.45, GRN,
          bevel=0.12)


def i_curtain():
    box((0, 0.2, 0.0), (1.8, 0.1, 1.6), "#2a1a3a", bevel=0.03)
    box((0, -0.1, -0.85), (2.0, 0.85, 0.2), BRN, bevel=0.05)
    for s in (1, -1):
        for k in range(4):
            x = s * (0.92 - k * 0.14)
            bottom = -0.75 + k * 0.12
            capsule((x, -0.05, 0.75), (x - s * 0.04 * k, -0.05, bottom), 0.1, RED, r2=0.09)
    box((0, -0.1, 0.8), (2.0, 0.3, 0.26), RED, bevel=0.08)
    for k in range(9):
        sphere((-0.88 + k * 0.22, -0.27, 0.66), 0.06, GOLD, metal=0.4)
    sparkle((0, -0.2, -0.2), 0.3, YEL)


def i_rebirth():
    wing = [(0.15, 0.0), (0.3, 0.35), (0.6, 0.55), (1.0, 0.62), (1.18, 0.5), (1.05, 0.36), (1.14, 0.22), (0.98, 0.13),
            (1.03, -0.02), (0.85, -0.07), (0.86, -0.2), (0.64, -0.18), (0.52, -0.3), (0.32, -0.18)]
    for s in (1, -1):
        prism([(x * s, z) for x, z in wing], 0.14, WHT, loc=(0, 0.1, 0), rot=(0, 0, -15 * s), bevel=0.05, emit=0.15)
    torus((0, 0, 0.72), 0.36, 0.07, GOLD, rot=(70, 0, 0), emit=1.0)
    sphere((0, -0.15, -0.0), 0.26, CYA, emit=1.2)


def i_lock():
    torus((0, 0, 0.2), 0.36, 0.1, GRY, rot=(90, 0, 0), a0=0, a1=180, metal=0.5)
    for s in (1, -1):
        capsule((0.36 * s, 0, 0.2), (0.36 * s, 0, -0.05), 0.1, GRY, metal=0.5)
    box((0, 0, -0.35), (1.15, 0.6, 0.95), GOLD, bevel=0.14, metal=0.3, rough=0.25)
    sphere((0, -0.3, -0.25), 0.11, INK, scale=(1, 0.3, 1), hull=False)
    prism([(-0.07, -0.55), (0.07, -0.55), (0.04, -0.3), (-0.04, -0.3)], 0.06, INK, loc=(0, -0.3, 0), bevel=0, hull=False)


def i_ad():
    for s in (1, -1):
        capsule((0.1 * s, 0, 0.6), (0.4 * s, 0, 0.98), 0.04, DGRY)
    box((0, 0, -0.05), (1.75, 0.6, 1.3), PUR, bevel=0.15)
    box((0, -0.27, -0.05), (1.38, 0.1, 0.98), "#1c2340", bevel=0.06, hull=False)
    prism([(-0.2, -0.28), (0.32, 0), (-0.2, 0.28)], 0.1, GRN, loc=(0, -0.34, -0.05), bevel=0.04, emit=1.2)
    for s in (1, -1):
        box((0.6 * s, 0, -0.78), (0.2, 0.3, 0.16), DGRY, bevel=0.04)


def i_camera():
    box((0, 0, -0.05), (1.7, 0.75, 1.1), "#3b3f52", bevel=0.16)
    box((-0.45, 0, 0.58), (0.5, 0.6, 0.22), "#3b3f52", bevel=0.06)
    cyl((0.55, 0, 0.6), 0.12, 0.14, RED, bevel=0.03, emit=0.4)
    cyl((0.05, -0.42, -0.05), 0.5, 0.3, DGRY, rot=(90, 0, 0), bevel=0.05)
    cyl((0.05, -0.55, -0.05), 0.36, 0.12, "#1c2340", rot=(90, 0, 0), bevel=0.03, hull=False)
    sphere((0.05, -0.6, -0.05), 0.24, CYA, scale=(1, 0.35, 1), emit=0.6, hull=False)
    sphere((-0.05, -0.66, 0.05), 0.07, WHT, emit=1.5, hull=False)
    box((-0.62, -0.38, 0.28), (0.26, 0.04, 0.16), WHT, bevel=0.02, emit=0.8, hull=False)


def i_crown():
    gold = dict(metal=0.35, rough=0.22)
    pts = [(-0.9, -0.5), (0.9, -0.5), (0.98, 0.5), (0.48, 0.05), (0.0, 0.62), (-0.48, 0.05), (-0.98, 0.5)]
    prism(pts, 0.4, GOLD, bevel=0.07, **gold)
    box((0, -0.05, -0.35), (1.95, 0.5, 0.32), GOLD, bevel=0.07, **gold)
    for x, c in ((-0.55, RED), (0, BLU), (0.55, GRN)):
        sphere((x, -0.3, -0.35), 0.12, c, scale=(1, 0.6, 1), rough=0.1)
    for x, z in ((-0.98, 0.5), (0, 0.62), (0.98, 0.5)):
        sphere((x, 0, z), 0.12, GOLD, **gold)


ICONS = {
    "tech_Polite": i_polite, "tech_Firm": i_firm, "tech_Cupped": i_cupped, "tech_Thunder": i_thunder,
    "tech_Sonic": i_sonic, "tech_Shockwave": i_shockwave, "tech_Seismic": i_seismic, "tech_Tectonic": i_tectonic,
    "tech_Volcanic": i_volcanic, "tech_Avalanche": i_avalanche, "tech_Hurricane": i_hurricane, "tech_Earthquake": i_earthquake,
    "tech_Tsunami": i_tsunami, "tech_Mountain": i_mountain, "tech_Supercell": i_supercell, "tech_Continental": i_continental,
    "tech_Tidal": i_tidal, "tech_Atmospheric": i_atmospheric, "tech_Stratospheric": i_stratospheric, "tech_Meteor": i_meteor,
    "tech_Extinction": i_extinction, "tech_Mantle": i_mantle, "tech_Core": i_core, "tech_Magma": i_magma,
    "tech_Crustbreaker": i_crustbreaker, "tech_Planetcracker": i_planetcracker, "tech_Gravity": i_gravity,
    "tech_Orbital": i_orbital, "tech_Cosmic": i_cosmic,

    "crowd_Classmate": i_classmate, "crowd_Teacher": i_teacher, "crowd_Band": i_band, "crowd_Cheer": i_cheer,
    "crowd_School": i_school, "crowd_Choir": i_choir, "crowd_Orchestra": i_orchestra, "crowd_Stadium": i_stadium,
    "crowd_Nation": i_nation, "crowd_Global": i_global, "crowd_Drummers": i_drummers, "crowd_Cosmos": i_cosmos,

    "stage_Ceremony": i_ceremony, "stage_Gym": i_gym, "stage_Town": i_town, "stage_City": i_city,
    "stage_Region": i_region, "stage_Country": i_country, "stage_Planet": i_planet, "stage_Molten": i_molten,
    "stage_Space": i_space,

    "item_pumpkin": i_pumpkin, "item_boost": i_boost, "item_bat": i_bat, "item_ghost": i_ghost,
    "item_santa": i_santa, "item_snowflake": i_snowflake, "item_star": i_star, "cur_candy": i_candy, "cur_present": i_present,

    "ui_hands": i_hands, "ui_strong": i_strong, "ui_trophy": i_trophy, "ui_gear": i_gear, "ui_map": i_map,
    "ui_walk": i_walk, "ui_chair": i_chair, "ui_crowd": i_crowd, "ui_upgrade": i_upgrade,
    "ui_curtain": i_curtain, "ui_rebirth": i_rebirth,
    "ui_lock": i_lock, "ui_ad": i_ad, "ui_crown": i_crown, "ui_camera": i_camera,
}

view("ui_hands", 0, -30)
view("tech_Sonic", 10, -30)
view("tech_Tectonic", 18, -25)
view("tech_Earthquake", 15, -20)
view("tech_Hurricane", 10, -10)
view("tech_Stratospheric", 0, -20, 35)
view("crowd_Stadium", 28, -10)
view("crowd_Orchestra", 0, -15, -28)
view("crowd_Choir", 0, -20, 20)
view("stage_Gym", 20, -30)
view("stage_Town", 15, -25)
view("stage_City", 10, -25)
view("ui_chair", 15, -35)
view("ui_walk", 10, -25)
view("ui_map", 10, -15)
view("ui_crowd", 5, -10)
view("tech_Cosmic", 0, -10)
view("tech_Gravity", 0, -10)
view("tech_Mantle", 10, -25)


# ---------------------------------------------------------------- rendering

def setup_scene():
    sc = bpy.context.scene
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    for ident in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = ident
            break
        except TypeError:
            continue
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"

    world = sc.world or bpy.data.worlds.new("w")
    sc.world = world
    try:
        world.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.62, 0.64, 0.72, 1)
    bg.inputs["Strength"].default_value = 0.6

    def sun(pos, energy, color=(1, 1, 1), angle=8):
        ld = bpy.data.lights.new("sun", "SUN")
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(angle)
        ob = bpy.data.objects.new("sun", ld)
        sc.collection.objects.link(ob)
        ob.rotation_euler = Vector(pos).to_track_quat("Z", "Y").to_euler()
        ob["keep"] = True

    sun((-1.0, -1.4, 1.8), 4.2, (1, 0.97, 0.92))
    sun((1.6, -0.6, 0.2), 0.9, (0.8, 0.88, 1))
    sun((0.4, 1.5, 1.2), 3.5)

    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    d = Vector((0, -1, math.tan(math.radians(14)))).normalized()
    cam.location = d * 30
    cam.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    cd.clip_end = 100
    cam["keep"] = True
    sc.camera = cam
    return cam


def clear_icon():
    for ob in list(bpy.data.objects):
        if "keep" not in ob:
            bpy.data.objects.remove(ob)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def fit_camera(cam):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for ob in bpy.data.objects:
        if ob.type != "MESH" or ob.hide_render:
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            p = inv @ (ob.matrix_world @ v.co)
            xs.append(p.x)
            ys.append(p.y)
        ev.to_mesh_clear()
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    scale = max(w, h) * 1.16
    cam.data.ortho_scale = scale
    cam.data.shift_x = (max(xs) + min(xs)) / 2 / scale
    cam.data.shift_y = (max(ys) + min(ys)) / 2 / scale


def main():
    global _root
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(ICONS)
    os.makedirs(OUT, exist_ok=True)
    cam = setup_scene()
    for name in names:
        clear_icon()
        _root = bpy.data.objects.new("root", None)
        bpy.context.scene.collection.objects.link(_root)
        ICONS[name]()
        tilt, turn, roll = VIEW.get(name, (0, -20, 0))
        _root.rotation_euler = (math.radians(tilt), math.radians(roll), math.radians(turn))
        fit_camera(cam)
        bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", name, flush=True)


main()
