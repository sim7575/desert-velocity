import bpy
import math
import os
import random
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2_blockout.blend")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name, color, roughness=0.86, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


def mesh_object(name, vertices, faces, mat, location=(0.0, 0.0, 0.0), smooth=False):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.data.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    obj["environment_kit_v2"] = True
    return obj


def append_layered_mass(vertices, faces, center, dimensions, seed, segments=12, levels=7, lean=(0.0, 0.0)):
    rng = random.Random(seed)
    start = len(vertices)
    angle_jitter = [rng.uniform(-0.12, 0.12) for _ in range(segments)]
    radial = [rng.uniform(0.78, 1.18) for _ in range(segments)]
    profile = [0.78, 1.00, 0.91, 1.06, 0.84, 0.70, 0.56]
    z_levels = [0.0, 0.10, 0.28, 0.47, 0.66, 0.84, 1.0]
    while len(profile) < levels:
        profile.insert(-1, 0.52)
        z_levels = [i / float(levels - 1) for i in range(levels)]
    for level in range(levels):
        zf = z_levels[level]
        ledge = profile[level]
        shift_x = lean[0] * zf + rng.uniform(-0.025, 0.025) * dimensions[0]
        shift_y = lean[1] * zf + rng.uniform(-0.025, 0.025) * dimensions[1]
        for segment in range(segments):
            angle = math.tau * segment / segments + angle_jitter[segment]
            fracture = 1.0 + 0.08 * math.sin(segment * 2.7 + seed) + rng.uniform(-0.035, 0.035)
            radius = radial[segment] * ledge * fracture
            crest_break = rng.uniform(-0.075, 0.055) * dimensions[2] if level == levels - 1 else 0.0
            vertices.append((
                center[0] + math.cos(angle) * dimensions[0] * 0.5 * radius + shift_x,
                center[1] + math.sin(angle) * dimensions[1] * 0.5 * radius + shift_y,
                center[2] + dimensions[2] * zf + crest_break,
            ))
    for level in range(levels - 1):
        for segment in range(segments):
            a = start + level * segments + segment
            b = start + level * segments + (segment + 1) % segments
            c = start + (level + 1) * segments + (segment + 1) % segments
            d = start + (level + 1) * segments + segment
            faces.append((a, b, c, d))
    faces.append(tuple(start + segment for segment in reversed(range(segments))))
    top = start + (levels - 1) * segments
    faces.append(tuple(top + segment for segment in range(segments)))


def append_geologic_mass(vertices, faces, center, dimensions, seed, segments=28, levels=10,
                          profile=None, lean=(0.0, 0.0), fractures=()):
    """Build an asymmetric, terraced mass with broad planar runs and deep notches."""
    rng = random.Random(seed)
    start = len(vertices)
    if profile is None:
        profile = [0.96, 1.08, 1.03, 1.12, 0.92, 0.98, 0.78, 0.82, 0.66, 0.58]
    outline = []
    angle_offsets = []
    for segment in range(segments):
        quadrant_plane = 0.10 * math.cos(segment * math.tau / segments * 4.0 + seed * 0.01)
        outline.append(1.0 + quadrant_plane + rng.uniform(-0.10, 0.10))
        angle_offsets.append(rng.uniform(-0.055, 0.055))
    for level in range(levels):
        zf = level / float(levels - 1)
        ledge = profile[min(level, len(profile) - 1)]
        level_shift_x = lean[0] * zf + rng.uniform(-0.018, 0.018) * dimensions[0]
        level_shift_y = lean[1] * zf + rng.uniform(-0.018, 0.018) * dimensions[1]
        for segment in range(segments):
            angle = math.tau * segment / segments + angle_offsets[segment]
            radius = outline[segment] * ledge
            for fracture_angle, fracture_width, fracture_depth in fractures:
                delta = abs(math.atan2(math.sin(angle - fracture_angle), math.cos(angle - fracture_angle)))
                if delta < fracture_width:
                    radius *= 1.0 - fracture_depth * (1.0 - delta / fracture_width) * (0.35 + 0.65 * zf)
            crest = rng.uniform(-0.09, 0.06) * dimensions[2] if level == levels - 1 else 0.0
            vertices.append((
                center[0] + math.cos(angle) * dimensions[0] * 0.5 * radius + level_shift_x,
                center[1] + math.sin(angle) * dimensions[1] * 0.5 * radius + level_shift_y,
                center[2] + dimensions[2] * zf + crest,
            ))
    for level in range(levels - 1):
        for segment in range(segments):
            a = start + level * segments + segment
            b = start + level * segments + (segment + 1) % segments
            c = start + (level + 1) * segments + (segment + 1) % segments
            d = start + (level + 1) * segments + segment
            faces.append((a, b, c, d))
    faces.append(tuple(start + segment for segment in reversed(range(segments))))
    top = start + (levels - 1) * segments
    faces.append(tuple(top + segment for segment in range(segments)))


def hero_rock(name, location, mat, seed, style):
    vertices, faces = [], []
    if style == "heavy":
        append_geologic_mass(vertices, faces, (-0.8, 0.0, 0.0), (12.4, 8.8, 5.7), seed, 32, 11,
                             [1.04, 1.12, 1.08, 1.16, 0.98, 1.02, 0.84, 0.88, 0.72, 0.68, 0.62],
                             (-0.35, 0.18), ((0.35, 0.20, 0.34), (3.45, 0.16, 0.26)))
        append_geologic_mass(vertices, faces, (4.1, 0.7, 0.0), (7.1, 6.0, 4.4), seed + 31, 28, 10,
                             lean=(0.45, -0.20), fractures=((2.7, 0.22, 0.30),))
        for index, spec in enumerate(((-4.8, -3.1, 3.8, 3.2, 2.2), (-1.9, 3.3, 3.2, 2.8, 1.8), (4.8, -2.7, 3.5, 3.0, 2.0))):
            append_geologic_mass(vertices, faces, (spec[0], spec[1], 0.0), (spec[2], spec[3], spec[4]),
                                 seed + 80 + index * 19, 18, 7, lean=(0.15 * (index - 1), 0.0))
    elif style == "terraced":
        append_geologic_mass(vertices, faces, (0.0, 0.0, 0.0), (14.2, 7.0, 6.2), seed, 36, 11,
                             [1.06, 1.13, 1.10, 1.18, 0.96, 1.08, 0.86, 0.94, 0.72, 0.76, 0.68],
                             (0.55, -0.20), ((0.05, 0.18, 0.30), (3.25, 0.14, 0.22)))
        append_geologic_mass(vertices, faces, (-3.0, 0.1, 3.6), (9.3, 5.4, 3.4), seed + 37, 32, 10,
                             [1.05, 1.14, 1.08, 1.18, 0.94, 1.04, 0.82, 0.88, 0.70, 0.65],
                             (-0.55, 0.15), ((2.8, 0.17, 0.28),))
        append_geologic_mass(vertices, faces, (4.9, -0.4, 1.1), (6.6, 5.1, 2.5), seed + 71, 24, 8,
                             lean=(0.30, 0.10), fractures=((0.2, 0.20, 0.22),))
        append_geologic_mass(vertices, faces, (-5.4, 1.5, 0.0), (5.0, 4.2, 2.8), seed + 93, 24, 8,
                             lean=(-0.20, -0.12))
    else:
        append_geologic_mass(vertices, faces, (0.0, 0.0, 0.0), (10.8, 8.4, 9.4), seed, 34, 12,
                             [1.10, 1.16, 1.08, 1.12, 0.94, 1.00, 0.84, 0.88, 0.73, 0.78, 0.64, 0.56],
                             (-0.85, 0.25), ((1.65, 0.28, 0.48), (4.85, 0.16, 0.25)))
        append_geologic_mass(vertices, faces, (2.8, -0.4, 0.0), (8.2, 7.2, 4.1), seed + 41, 30, 9,
                             lean=(0.55, -0.20), fractures=((1.55, 0.24, 0.36),))
        append_geologic_mass(vertices, faces, (-2.2, 0.4, 6.8), (6.8, 5.2, 3.2), seed + 79, 26, 8,
                             lean=(-0.65, 0.12), fractures=((4.7, 0.22, 0.34),))
        append_geologic_mass(vertices, faces, (4.7, 2.0, 1.4), (4.8, 4.0, 4.5), seed + 113, 24, 9,
                             lean=(0.35, -0.50), fractures=((2.9, 0.20, 0.25),))
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "rock"
    obj["geology_revision"] = "E1.1_" + style
    obj["unique_seed"] = seed
    return obj


def rock_asset(name, location, dimensions, mat, seed, lobes=1, segments=12):
    vertices, faces = [], []
    for lobe in range(lobes):
        rng = random.Random(seed * 31 + lobe)
        offset = (
            rng.uniform(-0.18, 0.18) * dimensions[0],
            rng.uniform(-0.16, 0.16) * dimensions[1],
            rng.uniform(-0.02, 0.08) * dimensions[2],
        )
        scale = 1.0 if lobe == 0 else rng.uniform(0.48, 0.74)
        append_layered_mass(
            vertices, faces, offset,
            (dimensions[0] * scale, dimensions[1] * scale, dimensions[2] * scale),
            seed + lobe * 97, segments, 7,
            (rng.uniform(-0.20, 0.20) * dimensions[0], rng.uniform(-0.12, 0.12) * dimensions[1]),
        )
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "rock"
    obj["unique_seed"] = seed
    return obj


def canyon_wall(name, location, length, depth, height, mat, seed):
    rng = random.Random(seed)
    fractured = "_B_" in name
    stations, levels = 41, 11
    vertices, faces = [], []
    front = [[0] * stations for _ in range(levels)]
    back = [[0] * stations for _ in range(levels)]
    for level in range(levels):
        zf = level / float(levels - 1)
        ledge_profile = [0.0, 0.30, 0.18, 0.66, 0.50, 0.92, 0.58, 1.02, 0.76, 1.14, 0.92]
        ledge = ledge_profile[level]
        for station in range(stations):
            xf = station / float(stations - 1)
            x = (xf - 0.5) * length
            crest_wave = (0.06 if not fractured else 0.14) * math.sin(xf * (7.0 if not fractured else 13.0) + seed)
            crest_break = (0.04 if not fractured else 0.09) * math.sin(xf * 31.0 + seed * 0.2)
            crest = height * (1.0 + crest_wave + crest_break)
            broad_plane = 0.10 * math.sin(station * 0.48 + level * 0.35 + seed)
            recess = 0.0
            if fractured:
                recess = 0.85 * math.exp(-((xf - 0.34) / 0.10) ** 2) + 0.55 * math.exp(-((xf - 0.73) / 0.08) ** 2)
            y_front = -depth * 0.5 + ledge + broad_plane + recess * (0.30 + 0.70 * zf)
            y_back = depth * 0.5 - ledge * 0.72 + 0.22 * math.sin(station * 1.3 + seed + level)
            z = crest * zf
            front[level][station] = len(vertices)
            vertices.append((x, y_front, z))
            back[level][station] = len(vertices)
            vertices.append((x, y_back, z + rng.uniform(-0.04, 0.04) * height))
    for level in range(levels - 1):
        for station in range(stations - 1):
            faces.append((front[level][station], front[level][station + 1], front[level + 1][station + 1], front[level + 1][station]))
            faces.append((back[level][station + 1], back[level][station], back[level + 1][station], back[level + 1][station + 1]))
    for station in range(stations - 1):
        faces.append((front[0][station + 1], front[0][station], back[0][station], back[0][station + 1]))
        faces.append((front[-1][station], front[-1][station + 1], back[-1][station + 1], back[-1][station]))
    for level in range(levels - 1):
        faces.append((front[level][0], front[level + 1][0], back[level + 1][0], back[level][0]))
        faces.append((front[level + 1][-1], front[level][-1], back[level][-1], back[level + 1][-1]))
    buttress_x = (-length * 0.37, -length * 0.06, length * 0.31) if not fractured else (-length * 0.40, -length * 0.18, length * 0.16, length * 0.39)
    for index, x in enumerate(buttress_x):
        width = (5.6 + index * 0.35) if not fractured else (4.4 + (index % 2) * 1.25)
        append_geologic_mass(vertices, faces, (x, -depth * 0.48, 0.0),
                             (width, 4.8 + (index % 2) * 0.8, height * (0.62 + (index % 3) * 0.10)),
                             seed + 300 + index * 29, 30, 10,
                             lean=(0.35 * (-1 if index % 2 == 0 else 1), -0.35),
                             fractures=((1.5 + index, 0.16, 0.26),))
    # Volumetric end shoulders preserve the modular length while preventing the
    # closed end caps from reading as exposed rectangular slabs in oblique views.
    for end_index, x in enumerate((-length * 0.48, length * 0.48)):
        append_geologic_mass(vertices, faces, (x, -depth * 0.42, 0.0),
                             (5.4 if not fractured else 4.8, 5.6 + end_index * 0.5, height * (0.72 + end_index * 0.06)),
                             seed + 520 + end_index * 43, 30, 10,
                             lean=(0.45 * (-1 if end_index == 0 else 1), -0.28),
                             fractures=((0.9 + end_index * 2.4, 0.18, 0.30),))
    for index, x in enumerate((-length * 0.32, 0.0, length * 0.34)):
        append_geologic_mass(vertices, faces, (x, -depth * 0.92, -0.12),
                             (5.8, 4.6, 1.55 + 0.25 * index), seed + 700 + index * 17,
                             20, 7, lean=(0.18 * (index - 1), -0.10))
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "canyon_wall"
    obj["module_length"] = length
    obj["modular_end_height"] = height
    obj["geology_revision"] = "E1.1_fractured" if fractured else "E1.1_massive"
    return obj


def rock_arch(name, location, mat, seed):
    rng = random.Random(seed)
    segments = 36
    depth_sections = 5
    vertices, faces = [], []
    for depth_index in range(depth_sections):
        depth_factor = depth_index / float(depth_sections - 1)
        depth = -2.25 + depth_factor * 4.5
        for i in range(segments + 1):
            angle = math.pi - math.pi * i / segments
            irregular = 0.30 * math.sin(i * 1.73 + seed) + 0.18 * math.sin(i * 3.17)
            outer_x = math.cos(angle) * (8.5 + irregular) + 0.45 * math.sin(angle * 2.0)
            outer_z = math.sin(angle) * (10.2 + 0.35 * math.sin(i * 1.1))
            inner_x = math.cos(angle) * (5.15 + 0.16 * math.sin(i * 2.3)) + 0.30
            inner_z = math.sin(angle) * (6.55 + 0.22 * math.cos(i * 1.9)) + 0.20
            depth_warp = 0.22 * math.sin(i * 0.9 + depth_index * 1.7 + seed)
            vertices.extend(((outer_x, depth + depth_warp, outer_z), (inner_x, depth * 0.92 + depth_warp, inner_z)))
    stride = (segments + 1) * 2
    for depth_index in range(depth_sections - 1):
        a_base = depth_index * stride
        b_base = (depth_index + 1) * stride
        for i in range(segments):
            faces.append((a_base + i * 2, b_base + i * 2, b_base + (i + 1) * 2, a_base + (i + 1) * 2))
            faces.append((a_base + i * 2 + 1, a_base + (i + 1) * 2 + 1, b_base + (i + 1) * 2 + 1, b_base + i * 2 + 1))
    for depth_index in (0, depth_sections - 1):
        base = depth_index * stride
        reverse = depth_index == 0
        for i in range(segments):
            quad = (base + i * 2, base + (i + 1) * 2, base + (i + 1) * 2 + 1, base + i * 2 + 1)
            faces.append(tuple(reversed(quad)) if reverse else quad)
    for depth_index in range(depth_sections - 1):
        a_base = depth_index * stride
        b_base = (depth_index + 1) * stride
        faces.append((a_base, a_base + 1, b_base + 1, b_base))
        end = segments * 2
        faces.append((a_base + end, b_base + end, b_base + end + 1, a_base + end + 1))
    append_geologic_mass(vertices, faces, (-7.0, 0.0, 0.0), (6.4, 7.0, 7.1), seed + 51, 32, 10,
                         lean=(-0.50, 0.15), fractures=((0.4, 0.20, 0.30),))
    append_geologic_mass(vertices, faces, (7.2, 0.1, 0.0), (7.2, 7.4, 7.8), seed + 77, 32, 10,
                         lean=(0.65, -0.20), fractures=((2.8, 0.23, 0.34),))
    append_geologic_mass(vertices, faces, (-1.1, 0.0, 8.2), (10.5, 5.2, 3.1), seed + 109, 28, 9,
                         lean=(0.45, 0.12), fractures=((4.7, 0.18, 0.28),))
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "rock_arch"
    return obj


def mesa(name, location, dimensions, mat, seed):
    vertices, faces = [], []
    append_layered_mass(vertices, faces, (0, 0, 0), dimensions, seed, 16, 7, (0.15, -0.08))
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "distant_mesa"
    return obj


def append_tube(vertices, faces, start, end, radius_start, radius_end, sides=8):
    start_v, end_v = Vector(start), Vector(end)
    direction = (end_v - start_v).normalized()
    axis = direction.cross(Vector((0, 0, 1)))
    if axis.length < 0.01:
        axis = Vector((1, 0, 0))
    axis.normalize()
    other = direction.cross(axis).normalized()
    base = len(vertices)
    for point, radius in ((start_v, radius_start), (end_v, radius_end)):
        for i in range(sides):
            angle = math.tau * i / sides
            p = point + axis * math.cos(angle) * radius + other * math.sin(angle) * radius
            vertices.append(tuple(p))
    for i in range(sides):
        faces.append((base + i, base + (i + 1) % sides, base + sides + (i + 1) % sides, base + sides + i))
    faces.append(tuple(base + i for i in reversed(range(sides))))
    faces.append(tuple(base + sides + i for i in range(sides)))


def cactus(name, location, mat, seed):
    rng = random.Random(seed)
    vertices, faces = [], []
    height = rng.uniform(2.2, 3.4)
    append_tube(vertices, faces, (0, 0, 0), (0.06, 0.0, height), 0.25, 0.15, 10)
    for side in (-1, 1):
        z = rng.uniform(0.75, 1.55)
        reach = rng.uniform(0.65, 0.95)
        append_tube(vertices, faces, (0, 0, z), (side * reach, 0.06, z + 0.16), 0.13, 0.11, 8)
        append_tube(vertices, faces, (side * reach, 0.06, z + 0.16), (side * reach * 1.02, 0.08, z + rng.uniform(0.75, 1.15)), 0.11, 0.065, 8)
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "cactus"
    return obj


def dry_bush(name, location, mat, seed):
    rng = random.Random(seed)
    vertices, faces = [], []
    for branch in range(18):
        angle = math.tau * branch / 18 + rng.uniform(-0.18, 0.18)
        radius = rng.uniform(0.52, 1.05)
        end = (math.cos(angle) * radius, math.sin(angle) * radius, rng.uniform(0.35, 0.95))
        append_tube(vertices, faces, (0, 0, 0.05), end, 0.035, 0.008, 5)
        if branch % 3 == 0:
            twig = (end[0] * 1.12, end[1] * 0.92, end[2] + 0.28)
            append_tube(vertices, faces, end, twig, 0.012, 0.004, 5)
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = "dry_bush"
    return obj


def append_box(vertices, faces, center, size):
    x, y, z = center
    sx, sy, sz = size
    base = len(vertices)
    vertices.extend([
        (x - sx, y - sy, z - sz), (x + sx, y - sy, z - sz), (x + sx, y + sy, z - sz), (x - sx, y + sy, z - sz),
        (x - sx, y - sy, z + sz), (x + sx, y - sy, z + sz), (x + sx, y + sy, z + sz), (x - sx, y + sy, z + sz),
    ])
    faces.extend([(base, base + 3, base + 2, base + 1), (base + 4, base + 5, base + 6, base + 7),
                  (base, base + 1, base + 5, base + 4), (base + 1, base + 2, base + 6, base + 5),
                  (base + 2, base + 3, base + 7, base + 6), (base + 3, base, base + 4, base + 7)])


def road_prop(name, location, mat, kind):
    vertices, faces = [], []
    if kind == "sign":
        append_tube(vertices, faces, (-0.7, 0, 0), (-0.7, 0, 1.9), 0.045, 0.04, 8)
        append_tube(vertices, faces, (0.7, 0, 0), (0.7, 0, 1.9), 0.045, 0.04, 8)
        append_box(vertices, faces, (0, 0, 1.65), (1.15, 0.08, 0.42))
    elif kind == "barrier":
        for x in (-1.75, 0, 1.75):
            append_tube(vertices, faces, (x, 0, 0), (x, 0, 0.85), 0.07, 0.06, 8)
        append_box(vertices, faces, (0, 0, 0.68), (2.35, 0.12, 0.16))
        append_box(vertices, faces, (0, 0, 0.28), (2.35, 0.10, 0.10))
    obj = mesh_object(name, vertices, faces, mat, location)
    obj["asset_family"] = kind
    return obj


def narrative_wreck(name, location, metal_mat):
    vertices, faces = [], []
    append_box(vertices, faces, (0, 0, 0.42), (1.55, 2.1, 0.18))
    append_box(vertices, faces, (0, -0.45, 1.05), (1.18, 0.95, 0.55))
    append_box(vertices, faces, (0.65, 1.35, 0.92), (0.44, 0.55, 0.52))
    for x in (-1.35, 1.35):
        for y in (-1.35, 1.35):
            append_tube(vertices, faces, (x, y, 0.28), (x, y, 0.72), 0.30, 0.30, 10)
    append_tube(vertices, faces, (-1.0, -1.1, 1.62), (1.0, 0.70, 1.85), 0.055, 0.045, 8)
    append_tube(vertices, faces, (1.0, -1.1, 1.62), (-1.0, 0.70, 1.85), 0.055, 0.045, 8)
    obj = mesh_object(name, vertices, faces, metal_mat, location)
    obj["asset_family"] = "narrative_wreck"
    return obj


def dune(name, location, size, mat, seed):
    rng = random.Random(seed)
    count = 10
    vertices, faces = [], []
    for y in range(count):
        for x in range(count):
            xf = x / (count - 1)
            yf = y / (count - 1)
            px = (xf - 0.5) * size[0]
            py = (yf - 0.5) * size[1]
            ridge = math.exp(-((xf - 0.58 - 0.12 * math.sin(yf * math.pi)) ** 2) / 0.045)
            taper = math.sin(yf * math.pi) ** 0.7
            pz = ridge * taper * size[2] + rng.uniform(-0.025, 0.025)
            vertices.append((px, py, pz))
    for y in range(count - 1):
        for x in range(count - 1):
            a = y * count + x
            faces.append((a, a + 1, a + count + 1, a + count))
    obj = mesh_object(name, vertices, faces, mat, location, smooth=True)
    obj["asset_family"] = "dune"
    return obj


def road_edge(name, location, length, side, mat, seed):
    rng = random.Random(seed)
    stations = 14
    vertices, faces = [], []
    for i in range(stations):
        y = (i / (stations - 1) - 0.5) * length
        jitter = rng.uniform(-0.18, 0.18)
        inner = side * (2.6 + jitter)
        outer = side * (4.2 + jitter * 1.8)
        crown = 0.10 + 0.08 * math.sin(i * 1.7 + seed)
        vertices.extend(((inner, y, 0.02), (outer, y, crown)))
    for i in range(stations - 1):
        a = i * 2
        faces.append((a, a + 2, a + 3, a + 1))
    obj = mesh_object(name, vertices, faces, mat, location, smooth=True)
    obj["asset_family"] = "road_edge"
    return obj


def build():
    clear_scene()
    rock_red = material("EKV2_RockRed_Clay", (0.38, 0.16, 0.10), 0.90)
    rock_ochre = material("EKV2_RockOchre_Clay", (0.49, 0.28, 0.14), 0.91)
    rock_dark = material("EKV2_RockDark_Clay", (0.20, 0.15, 0.14), 0.94)
    sand = material("EKV2_Sand_Clay", (0.30, 0.17, 0.08), 0.96)
    vegetation = material("EKV2_Vegetation_Clay", (0.19, 0.26, 0.16), 0.92)
    metal = material("EKV2_WeatheredMetal_Clay", (0.16, 0.18, 0.18), 0.82, 0.16)
    safety = material("EKV2_SafetyOrange_Clay", (0.76, 0.24, 0.06), 0.67)

    hero_rock("HeroRock_A_SplitCrown", (-15, -1, 0), rock_red, 1101, "heavy")
    hero_rock("HeroRock_B_LeaningStack", (0, -1, 0), rock_ochre, 1207, "terraced")
    hero_rock("HeroRock_C_BrokenButte", (15, -1, 0), rock_dark, 1321, "buttress")

    for index in range(6):
        x = -14 + index * 5.6
        rock_asset("MediumRock_%02d" % (index + 1), (x, 11, 0),
                   (3.2 + (index % 3) * 0.45, 2.5 + (index % 2) * 0.55, 2.6 + (index % 4) * 0.42),
                   rock_red if index % 2 == 0 else rock_ochre, 2100 + index * 73, 1 + (index % 2), 12)
    for index in range(10):
        x = -15.5 + index * 3.45
        rock_asset("SmallRock_%02d" % (index + 1), (x, 17.5 + (index % 2) * 1.2, 0),
                   (1.15 + (index % 4) * 0.18, 0.9 + (index % 3) * 0.16, 0.72 + (index % 5) * 0.17),
                   rock_dark if index % 3 == 0 else rock_ochre, 3100 + index * 41, 1, 9)

    rock_arch("RockArch_01", (0, -15, 0), rock_red, 4011)
    canyon_wall("CanyonWall_A_Concave", (-12.5, -29, 0), 22.0, 6.4, 10.0, rock_red, 5011)
    canyon_wall("CanyonWall_B_Stepped", (12.5, -29, 0), 22.0, 7.2, 11.0, rock_ochre, 5099)
    mesa("DistantMesa_A", (-17, -42, 0), (15.0, 9.0, 6.2), rock_dark, 6011)
    mesa("DistantMesa_B", (17, -42, 0), (18.0, 10.5, 7.0), rock_red, 6079)

    for index, x in enumerate((-10.0, -6.0, -2.0)):
        cactus("Cactus_%02d" % (index + 1), (x, 25, 0), vegetation, 7100 + index * 31)
    for index, x in enumerate((2.5, 6.0, 9.5)):
        dry_bush("DryBush_%02d" % (index + 1), (x, 25, 0), vegetation, 7200 + index * 37)
    road_prop("RoadSign_Direction", (-7.0, 31, 0), safety, "sign")
    road_prop("RoadSign_Hazard", (-2.5, 31, 0), safety, "sign")
    road_prop("SafetyBarrier_01", (4.0, 31, 0), metal, "barrier")
    narrative_wreck("NarrativeWreck_SurveyRover", (11.5, 31, 0), metal)
    for index in range(3):
        dune("Dune_%02d" % (index + 1), (-11 + index * 11, 38, 0), (8.0, 5.0, 1.4 + index * 0.2), sand, 8100 + index)
    road_edge("RoadEdge_BrokenShoulder_A", (-4.5, 48, 0), 11.0, 1.0, sand, 9101)
    road_edge("RoadEdge_BrokenShoulder_B", (4.5, 48, 0), 11.0, -1.0, sand, 9199)
    rock_asset("DebrisGravelCluster", (0, 55, 0), (3.8, 2.2, 0.55), rock_dark, 9901, 5, 8)

    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            obj.select_set(False)

    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print("ENVIRONMENT_KIT_V2_BLOCKOUT_BUILD_OK", BLEND_PATH)
    print("ASSETS hero=3 medium=6 small=10 arch=1 canyon=2 mesa=2 cactus=3 bush=3 signs=2 barrier=1 wreck=1 dunes=3 road_edges=2 debris=1")


if __name__ == "__main__":
    build()
