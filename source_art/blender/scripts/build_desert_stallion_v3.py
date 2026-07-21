import bpy
import bmesh
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "vehicles", "desert_stallion_v3.blend")

WHEEL_CENTERS = {
    "Wheel_FL": (-0.94, -1.47, 0.51),
    "Wheel_FR": (0.94, -1.47, 0.51),
    "Wheel_RL": (-0.94, 1.47, 0.51),
    "Wheel_RR": (0.94, 1.47, 0.51),
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name, color, metallic=0.0, roughness=0.65, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.6
    return mat


def mesh_object(name, vertices, faces, mat, smooth=True):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    return obj


def add_modifier(obj, name, modifier_type, **values):
    mod = obj.modifiers.new(name, modifier_type)
    for key, value in values.items():
        setattr(mod, key, value)
    return mod


def body_shell(mat):
    # Faceted longitudinal sections deliberately avoid the former capsule-like
    # continuity. The central tub stays narrow enough to expose suspension and
    # lets the separate fender volumes define the vehicle's width.
    stations = [
        (-2.36, 0.57, 0.39, 0.34),
        (-2.22, 0.70, 0.37, 0.47),
        (-1.92, 0.76, 0.36, 0.61),
        (-1.58, 0.78, 0.35, 0.70),
        (-1.16, 0.80, 0.35, 0.77),
        (-0.60, 0.82, 0.36, 0.79),
        (0.10, 0.83, 0.37, 0.78),
        (0.82, 0.81, 0.38, 0.73),
        (1.22, 0.75, 0.39, 0.62),
        (1.52, 0.61, 0.41, 0.48),
        (1.68, 0.45, 0.43, 0.31),
    ]
    profile = [
        (-0.52, 0.00), (-0.94, 0.04), (-1.00, 0.34), (-0.92, 0.72),
        (-0.55, 0.94), (0.0, 1.00), (0.55, 0.94), (0.92, 0.72),
        (1.00, 0.34), (0.94, 0.04), (0.52, 0.00), (0.0, -0.04),
    ]
    vertices = []
    for y, half_width, base, height in stations:
        for px, pz in profile:
            vertices.append((px * half_width, y, base + pz * height))
    count = len(profile)
    faces = []
    for ring in range(len(stations) - 1):
        for index in range(count):
            nxt = (index + 1) % count
            a = ring * count + index
            b = ring * count + nxt
            c = (ring + 1) * count + nxt
            d = (ring + 1) * count + index
            faces.append((a, b, c, d))
    faces.append(tuple(range(count - 1, -1, -1)))
    end = (len(stations) - 1) * count
    faces.append(tuple(end + index for index in range(count)))
    obj = mesh_object("V3_BodyShell", vertices, faces, mat, smooth=False)
    add_modifier(obj, "Body_EdgeRelief", "BEVEL", width=0.025, segments=1, limit_method="ANGLE")
    add_modifier(obj, "Body_WeightedNormals", "WEIGHTED_NORMAL", keep_sharp=True)
    return obj


def canopy_frame_and_glass(body_mat, glass_mat):
    stations = [
        (-0.42, 0.61, 1.03, 1.34),
        (-0.18, 0.64, 1.03, 1.68),
        (0.30, 0.65, 1.03, 1.76),
        (0.82, 0.63, 1.02, 1.73),
        (1.13, 0.56, 1.00, 1.48),
    ]
    section = [-1.0, -0.55, 0.0, 0.55, 1.0]
    vertices = []
    for y, width, sill, roof in stations:
        for xratio in section:
            arc = max(0.0, 1.0 - abs(xratio) ** 1.25)
            vertices.append((xratio * width, y, sill + (roof - sill) * arc))
    faces = []
    count = len(section)
    for ring in range(len(stations) - 1):
        for index in range(count - 1):
            a = ring * count + index
            faces.append((a, a + 1, a + count + 1, a + count))
    canopy = mesh_object("V3_CanopyFrame", vertices, faces, body_mat)
    solid = add_modifier(canopy, "Canopy_Solid", "SOLIDIFY", thickness=0.035)
    solid.offset = 0.0
    add_modifier(canopy, "Canopy_Bevel", "BEVEL", width=0.018, segments=2, limit_method="ANGLE")

    # Glass panels follow the same sloped stations and leave visible structural bands.
    panels = []
    panel_faces = []
    def quad(points):
        start = len(panels)
        panels.extend(points)
        panel_faces.append((start, start + 1, start + 2, start + 3))
    quad([(-0.55, -0.39, 1.08), (0.55, -0.39, 1.08), (0.49, -0.15, 1.62), (-0.49, -0.15, 1.62)])
    quad([(-0.48, 0.87, 1.06), (-0.42, 1.09, 1.38), (0.42, 1.09, 1.38), (0.48, 0.87, 1.06)])
    for side in (-1.0, 1.0):
        x0 = side * 0.625
        x1 = side * 0.585
        quad([(x0, -0.10, 1.07), (x1, 0.06, 1.65), (x1, 0.48, 1.70), (x0, 0.48, 1.06)])
        quad([(x0, 0.54, 1.06), (x1, 0.55, 1.69), (side * 0.49, 1.06, 1.43), (side * 0.51, 1.08, 1.04)])
    glass = mesh_object("V3_Glass", panels, panel_faces, glass_mat, smooth=False)
    add_modifier(glass, "Glass_Solid", "SOLIDIFY", thickness=0.012)
    return canopy, glass


def fender_mesh(mat):
    vertices = []
    faces = []
    segments = 18
    for _, (x, y, z) in WHEEL_CENTERS.items():
        side = -1.0 if x < 0 else 1.0
        base = len(vertices)
        for index in range(segments + 1):
            angle = math.radians(8.0 + 164.0 * index / segments)
            radial_inner = 0.475
            radial_outer = 0.585
            yy_inner = y - math.cos(angle) * radial_inner
            zz_inner = z + math.sin(angle) * radial_inner
            yy_outer = y - math.cos(angle) * radial_outer
            zz_outer = z + math.sin(angle) * radial_outer
            x_inner = side * 0.72
            x_outer = side * (1.085 + 0.005 * math.sin(angle))
            vertices.extend([
                (x_inner, yy_inner, zz_inner),
                (x_outer, yy_inner, zz_inner),
                (x_outer, yy_outer, zz_outer),
                (x_inner, yy_outer, zz_outer),
            ])
        for index in range(segments):
            a = base + index * 4
            b = a + 4
            faces.extend([
                (a, b, b + 1, a + 1),
                (a + 1, b + 1, b + 2, a + 2),
                (a + 2, b + 2, b + 3, a + 3),
                (a + 3, b + 3, b, a),
            ])
        faces.append((base + 3, base + 2, base + 1, base))
        end = base + segments * 4
        faces.append((end, end + 1, end + 2, end + 3))
    obj = mesh_object("V3_MuscularFenders", vertices, faces, mat)
    add_modifier(obj, "Fender_Bevel", "BEVEL", width=0.015, segments=1, limit_method="ANGLE")
    add_modifier(obj, "Fender_WeightedNormals", "WEIGHTED_NORMAL", keep_sharp=True)
    return obj


def join_objects(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    return result


def add_tube(name, start, end, radius, mat, vertices=12):
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    midpoint = (start + end) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def add_box(name, location, scale, mat, rotation=(0.0, 0.0, 0.0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = add_modifier(obj, name + "_Bevel", "BEVEL", width=bevel, segments=1)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def add_helix(name, start, end, coil_radius, wire_radius, turns, mat, points=112):
    start = Vector(start)
    end = Vector(end)
    axis = (end - start).normalized()
    helper = Vector((0.0, 1.0, 0.0)) if abs(axis.y) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    ring_sides = 8
    vertices = []
    faces = []
    for index in range(points):
        t = index / float(points - 1)
        angle = math.tau * turns * t
        center = start.lerp(end, t) + u * math.cos(angle) * coil_radius + v * math.sin(angle) * coil_radius
        for side in range(ring_sides):
            ring_angle = math.tau * side / ring_sides
            offset = u * math.cos(ring_angle) * wire_radius + v * math.sin(ring_angle) * wire_radius
            vertices.append(tuple(center + offset))
    for ring in range(points - 1):
        for side in range(ring_sides):
            nxt = (side + 1) % ring_sides
            a = ring * ring_sides + side
            b = ring * ring_sides + nxt
            c = (ring + 1) * ring_sides + nxt
            d = (ring + 1) * ring_sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(range(ring_sides - 1, -1, -1)))
    last = (points - 1) * ring_sides
    faces.append(tuple(last + side for side in range(ring_sides)))
    return mesh_object(name, vertices, faces, mat)


def wheel_mesh(root_name, center, rubber, metal):
    root = bpy.data.objects.new(root_name, None)
    bpy.context.collection.objects.link(root)
    root.location = center
    parts = []
    x, y, z = center
    bpy.ops.mesh.primitive_torus_add(major_radius=0.325, minor_radius=0.105, major_segments=96, minor_segments=28, location=center, rotation=(0.0, math.pi / 2.0, 0.0))
    tire = bpy.context.object
    tire.name = root_name + "_TireCore"
    # After the 90-degree rotation the torus local Z axis is the tire width.
    tire.scale.z = 1.52
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    tire.data.materials.append(rubber)
    parts.append(tire)
    for bead_side in (-1.0, 1.0):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.305,
            minor_radius=0.024,
            major_segments=64,
            minor_segments=10,
            location=(x + bead_side * 0.145, y, z),
            rotation=(0.0, math.pi / 2.0, 0.0),
        )
        bead = bpy.context.object
        bead.name = root_name + "_SidewallBead"
        bead.data.materials.append(rubber)
        parts.append(bead)
    outer = x + (-0.145 if x < 0 else 0.145)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.245, depth=0.30, location=center, rotation=(0.0, math.pi / 2.0, 0.0))
    rim = bpy.context.object
    rim.name = root_name + "_Rim"
    rim.data.materials.append(metal)
    parts.append(rim)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.175, depth=0.315, location=center, rotation=(0.0, math.pi / 2.0, 0.0))
    brake = bpy.context.object
    brake.name = root_name + "_BrakeDisc"
    brake.data.materials.append(metal)
    parts.append(brake)
    caliper_x = x + (-0.10 if x < 0 else 0.10)
    parts.append(add_box(root_name + "_BrakeCaliper", (caliper_x, y + 0.13, z), (0.025, 0.055, 0.095), metal, bevel=0.010))
    for spoke_index in range(8):
        angle = math.tau * spoke_index / 8.0
        start = (outer, y + math.cos(angle) * 0.055, z + math.sin(angle) * 0.055)
        end = (outer, y + math.cos(angle) * 0.205, z + math.sin(angle) * 0.205)
        parts.append(add_tube(root_name + "_Spoke", start, end, 0.018, metal, 8))
    # Alternating, angled tread lugs make the silhouette readable without textures.
    for lug_index in range(24):
        angle = math.tau * lug_index / 24.0
        yy = y + math.cos(angle) * 0.425
        zz = z + math.sin(angle) * 0.425
        bpy.ops.mesh.primitive_cube_add(location=(x, yy, zz), rotation=(angle + (0.16 if lug_index % 2 == 0 else -0.16), 0.0, 0.0))
        lug = bpy.context.object
        lug.name = root_name + "_TreadLug"
        lug.scale = (0.155, 0.055, 0.025)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        lug.data.materials.append(rubber)
        bevel = add_modifier(lug, "Lug_Bevel", "BEVEL", width=0.012, segments=1)
        bpy.context.view_layer.objects.active = lug
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        parts.append(lug)
    wheel = join_objects(parts, root_name + "_Geometry")
    wheel.parent = root
    wheel.location = Vector((0.0, 0.0, 0.0))
    return root, wheel


def mechanical_assemblies(body_mat, dark_mat, metal_mat, light_mat, tail_mat):
    suspension = []
    for name, (x, y, z) in WHEEL_CENTERS.items():
        side = -1.0 if x < 0 else 1.0
        front = y < 0.0
        inner_y = y + (0.16 if front else -0.16)
        suspension.extend([
            add_tube(name + "_UpperArmForward", (side * 0.34, inner_y - 0.18, 0.73), (side * 0.89, y, 0.62), 0.038, metal_mat),
            add_tube(name + "_UpperArmRear", (side * 0.34, inner_y + 0.18, 0.73), (side * 0.89, y, 0.62), 0.038, metal_mat),
            add_tube(name + "_LowerArmForward", (side * 0.31, inner_y - 0.22, 0.35), (side * 0.90, y, 0.40), 0.048, metal_mat),
            add_tube(name + "_LowerArmRear", (side * 0.31, inner_y + 0.22, 0.35), (side * 0.90, y, 0.40), 0.048, metal_mat),
            add_tube(name + "_Damper", (side * 0.49, y + (-0.12 if front else 0.12), 1.08), (side * 0.89, y, 0.49), 0.055, light_mat, 16),
            add_tube(name + "_HubCarrier", (side * 0.89, y, 0.39), (side * 0.89, y, 0.65), 0.048, dark_mat, 12),
        ])
        suspension.append(add_helix(
            name + "_CoilSpring",
            (side * 0.53, y + (-0.10 if front else 0.10), 1.01),
            (side * 0.86, y, 0.52),
            0.070,
            0.014,
            8.0,
            metal_mat,
        ))
    for side in (-1.0, 1.0):
        suspension.extend([
            add_tube("ChassisLowerRail", (side * 0.38, -1.88, 0.34), (side * 0.42, 1.92, 0.35), 0.055, metal_mat, 12),
            add_tube("FrontShockTower", (side * 0.42, -1.58, 0.36), (side * 0.49, -1.56, 1.10), 0.052, metal_mat, 12),
            add_tube("RearShockTower", (side * 0.42, 1.54, 0.36), (side * 0.49, 1.54, 1.03), 0.052, metal_mat, 12),
        ])
    join_objects(suspension, "V3_VisibleSuspension")

    cage = []
    for side in (-1.0, 1.0):
        cage.extend([
            add_tube("Cage_A", (side * 0.57, -0.38, 1.02), (side * 0.53, -0.10, 1.70), 0.050, metal_mat, 16),
            add_tube("Cage_Roof", (side * 0.53, -0.10, 1.70), (side * 0.53, 0.83, 1.70), 0.050, metal_mat, 16),
            add_tube("Cage_B", (side * 0.53, 0.83, 1.70), (side * 0.57, 1.12, 1.02), 0.050, metal_mat, 16),
            add_tube("Cage_RearStay", (side * 0.53, 0.83, 1.70), (side * 0.67, 1.88, 0.62), 0.047, metal_mat, 16),
        ])
    cage.extend([
        add_tube("Cage_FrontCross", (-0.53, -0.10, 1.70), (0.53, -0.10, 1.70), 0.050, metal_mat, 16),
        add_tube("Cage_RearCross", (-0.53, 0.83, 1.70), (0.53, 0.83, 1.70), 0.050, metal_mat, 16),
        add_tube("Cage_RoofDiagonal", (-0.53, 0.83, 1.70), (0.53, -0.10, 1.70), 0.040, metal_mat, 12),
        add_tube("Cage_RearBrace", (-0.67, 1.88, 0.62), (0.67, 1.88, 0.62), 0.050, metal_mat, 16),
    ])
    join_objects(cage, "V3_RollCage")

    # Skid plate is a purpose-built tapered wedge, not a box.
    skid_vertices = [
        (-0.74, -2.35, 0.29), (0.74, -2.35, 0.29), (-0.84, -0.65, 0.28), (0.84, -0.65, 0.28),
        (-0.58, -2.38, 0.43), (0.58, -2.38, 0.43), (-0.78, -0.62, 0.37), (0.78, -0.62, 0.37),
    ]
    skid_faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    skid = mesh_object("V3_UnderbodySkid", skid_vertices, skid_faces, metal_mat, smooth=False)
    add_modifier(skid, "Skid_Bevel", "BEVEL", width=0.025, segments=1)

    details = []
    # The front fascia is made from distinct functional planes: recessed lamp
    # pods, a central intake, bumper rails and hood reinforcement ribs.
    for side in (-1.0, 1.0):
        details.append(add_box("V3_HeadlampRecess", (side * 0.49, -2.345, 0.73), (0.24, 0.035, 0.13), dark_mat, rotation=(math.radians(-5), 0.0, side * math.radians(5)), bevel=0.025))
        details.append(add_box("V3_Headlamp", (side * 0.49, -2.385, 0.73), (0.15, 0.018, 0.065), light_mat, bevel=0.018))
        details.append(add_box("V3_TailLamp", (side * 0.55, 2.34, 0.68), (0.18, 0.025, 0.065), tail_mat, bevel=0.015))
        details.append(add_tube("V3_Exhaust", (side * 0.66, 1.84, 0.42), (side * 0.78, 2.30, 0.46), 0.055, metal_mat, 16))
        details.append(add_tube("V3_HoodRib", (side * 0.36, -2.02, 0.90), (side * 0.42, -0.88, 1.11), 0.030, body_mat, 10))
        details.append(add_tube("V3_FrontBumperSide", (side * 0.72, -2.27, 0.47), (side * 0.48, -2.40, 0.43), 0.052, metal_mat, 12))
        details.append(add_tube("V3_RearFrameRail", (side * 0.44, 1.34, 0.52), (side * 0.68, 2.29, 0.50), 0.052, metal_mat, 12))
    details.append(add_box("V3_CentralIntake", (0.0, -2.375, 0.53), (0.31, 0.028, 0.11), dark_mat, bevel=0.018))
    details.append(add_box("V3_HoodScoop", (0.0, -1.22, 1.105), (0.24, 0.32, 0.055), dark_mat, rotation=(math.radians(9), 0.0, 0.0), bevel=0.025))
    details.append(add_box("V3_RearMechanicalPack", (0.0, 1.92, 0.68), (0.40, 0.20, 0.24), dark_mat, bevel=0.025))
    details.append(add_tube("V3_RearPackBraceA", (-0.46, 1.68, 0.42), (0.46, 2.13, 0.91), 0.036, metal_mat, 12))
    details.append(add_tube("V3_RearPackBraceB", (0.46, 1.68, 0.42), (-0.46, 2.13, 0.91), 0.036, metal_mat, 12))
    details.append(add_tube("V3_FrontBumper", (-0.50, -2.40, 0.43), (0.50, -2.40, 0.43), 0.055, metal_mat, 12))
    details.append(add_tube("V3_RearBumper", (-0.70, 2.31, 0.48), (0.70, 2.31, 0.48), 0.055, metal_mat, 12))
    details.append(add_tube("V3_FrontTowHook", (-0.11, -2.42, 0.38), (0.11, -2.42, 0.38), 0.045, tail_mat, 16))
    details.append(add_tube("V3_RearTowHook", (-0.10, 2.39, 0.43), (0.10, 2.39, 0.43), 0.045, tail_mat, 16))
    join_objects(details, "V3_FunctionalDetails")

    interior_parts = []
    for x in (-0.30, 0.30):
        interior_parts.extend([
            add_box("V3_SeatBase", (x, 0.43, 1.00), (0.21, 0.29, 0.09), dark_mat, rotation=(math.radians(-7), 0.0, 0.0), bevel=0.035),
            add_box("V3_SeatBack", (x, 0.66, 1.27), (0.23, 0.10, 0.34), dark_mat, rotation=(math.radians(-10), 0.0, 0.0), bevel=0.040),
            add_box("V3_HeadRest", (x, 0.74, 1.52), (0.17, 0.09, 0.11), dark_mat, bevel=0.030),
            add_tube("V3_HarnessLeft", (x - 0.10, 0.70, 1.50), (x - 0.07, 0.40, 1.06), 0.018, tail_mat, 8),
            add_tube("V3_HarnessRight", (x + 0.10, 0.70, 1.50), (x + 0.07, 0.40, 1.06), 0.018, tail_mat, 8),
        ])
    interior_parts.append(add_tube("V3_Dashboard", (-0.56, -0.16, 1.08), (0.56, -0.16, 1.08), 0.045, dark_mat, 12))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.135, minor_radius=0.018, major_segments=48, minor_segments=10, location=(-0.30, -0.08, 1.28), rotation=(math.pi / 2.0, 0.0, 0.0))
    steering = bpy.context.object
    steering.name = "V3_SteeringWheel"
    steering.data.materials.append(dark_mat)
    interior_parts.append(steering)
    interior_parts.append(add_tube("V3_SteeringColumn", (-0.30, -0.25, 1.20), (-0.30, -0.07, 1.28), 0.022, metal_mat, 10))
    interior_parts.append(add_box("V3_DigitalDash", (-0.30, -0.20, 1.39), (0.13, 0.025, 0.055), light_mat, bevel=0.012))
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.075, depth=0.30, location=(0.49, 0.54, 1.04), rotation=(math.pi / 2.0, 0.0, 0.0))
    extinguisher = bpy.context.object
    extinguisher.name = "V3_Extinguisher"
    extinguisher.data.materials.append(tail_mat)
    interior_parts.append(extinguisher)
    join_objects(interior_parts, "V3_Interior")


def final_functional_details(body_mat, dark_mat, metal_mat, light_mat, tail_mat):
    parts = []
    for side in (-1.0, 1.0):
        parts.extend([
            add_box("V3_SideServicePanel", (side * 0.835, 0.28, 0.72), (0.022, 0.54, 0.25), body_mat, bevel=0.022),
            add_box("V3_SideProtection", (side * 0.858, 0.18, 0.49), (0.025, 0.68, 0.055), metal_mat, bevel=0.018),
            add_box("V3_CanopyGusset", (side * 0.67, -0.22, 1.06), (0.08, 0.22, 0.10), metal_mat, rotation=(0.0, side * math.radians(18), 0.0), bevel=0.020),
        ])
        for vent_index in range(4):
            z = 0.68 + vent_index * 0.065
            parts.append(add_tube("V3_SideLouver", (side * 0.868, -0.56, z), (side * 0.868, -0.28, z + 0.018), 0.013, dark_mat, 8))
        for y in (-0.18, 0.10, 0.38, 0.66):
            for z in (0.51, 0.93):
                bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=0.020, location=(side * 0.866, y, z))
                rivet = bpy.context.object
                rivet.name = "V3_ServiceFastener"
                rivet.data.materials.append(metal_mat)
                parts.append(rivet)
    for x in (-0.24, -0.16, -0.08, 0.0, 0.08, 0.16, 0.24):
        parts.append(add_tube("V3_FrontGrilleBar", (x, -2.409, 0.44), (x, -2.409, 0.61), 0.012, dark_mat, 8))
    for x in (-0.48, 0.48):
        for y in (-1.82, -1.48, -1.14, -0.80):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4, radius=0.022, location=(x, y, 1.02))
            fastener = bpy.context.object
            fastener.name = "V3_HoodFastener"
            fastener.data.materials.append(metal_mat)
            parts.append(fastener)
    parts.extend([
        add_box("V3_RoofIntake", (0.0, 0.34, 1.765), (0.22, 0.24, 0.025), dark_mat, bevel=0.018),
        add_tube("V3_AntennaMast", (0.38, 0.78, 1.72), (0.40, 0.82, 1.80), 0.010, dark_mat, 8),
        add_box("V3_RearEquipmentLatch", (0.0, 2.135, 0.69), (0.11, 0.018, 0.045), metal_mat, bevel=0.010),
        add_tube("V3_SkidRibLeft", (-0.36, -2.34, 0.35), (-0.45, -0.72, 0.33), 0.018, metal_mat, 8),
        add_tube("V3_SkidRibRight", (0.36, -2.34, 0.35), (0.45, -0.72, 0.33), 0.018, metal_mat, 8),
    ])
    join_objects(parts, "V3_FinalFunctionalDetail")


def create_shared_uv_atlas():
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.006, area_weight=0.25, correct_aspect=True)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")


def attach_pbr_textures(paint_mat, opaque_materials):
    texture_root = os.path.join(ROOT, "assets", "textures", "vehicles", "stallion_v3")
    paths = {
        "base": os.path.join(texture_root, "stallion_v3_base_color.png"),
        "normal": os.path.join(texture_root, "stallion_v3_normal.png"),
        "orm": os.path.join(texture_root, "stallion_v3_orm.png"),
    }
    missing = [path for path in paths.values() if not os.path.exists(path)]
    if missing:
        raise RuntimeError("Generate V3 textures before building Blender asset: " + ", ".join(missing))
    images = {key: bpy.data.images.load(path, check_existing=True) for key, path in paths.items()}
    images["normal"].colorspace_settings.name = "Non-Color"
    images["orm"].colorspace_settings.name = "Non-Color"
    for mat in opaque_materials:
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        normal_tex = nodes.new("ShaderNodeTexImage")
        normal_tex.name = "V3_Normal"
        normal_tex.image = images["normal"]
        normal_node = nodes.new("ShaderNodeNormalMap")
        normal_node.inputs["Strength"].default_value = 0.42 if mat == paint_mat else 0.28
        links.new(normal_tex.outputs["Color"], normal_node.inputs["Color"])
        links.new(normal_node.outputs["Normal"], bsdf.inputs["Normal"])
        orm_tex = nodes.new("ShaderNodeTexImage")
        orm_tex.name = "V3_ORM"
        orm_tex.image = images["orm"]
        separate = nodes.new("ShaderNodeSeparateColor")
        links.new(orm_tex.outputs["Color"], separate.inputs["Color"])
        links.new(separate.outputs["Green"], bsdf.inputs["Roughness"])
        if mat == paint_mat:
            base_tex = nodes.new("ShaderNodeTexImage")
            base_tex.name = "V3_BaseColor"
            base_tex.image = images["base"]
            links.new(base_tex.outputs["Color"], bsdf.inputs["Base Color"])


def apply_all_transforms():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")


def apply_all_modifiers():
    for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)


def clean_topology_and_normals():
    for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00001)
        bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.000001)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        obj.data.update()
        bm.free()


def build():
    clear_scene()
    clay = material("V3_PaintedBody", (0.58, 0.50, 0.36), roughness=0.62)
    dark = material("V3_MattePlasticInterior", (0.055, 0.065, 0.072), roughness=0.82)
    rubber = material("V3_Rubber", (0.018, 0.021, 0.022), roughness=0.96)
    metal = material("V3_StructureMetal", (0.18, 0.20, 0.21), metallic=0.70, roughness=0.44)
    glass = material("V3_Glass", (0.025, 0.075, 0.095), metallic=0.05, roughness=0.25)
    light = material("V3_HeadlampEmissive", (0.75, 0.70, 0.48), roughness=0.28, emission=(0.50, 0.44, 0.25))
    tail = material("V3_TailHarnessAccent", (0.42, 0.018, 0.012), roughness=0.35, emission=(0.38, 0.01, 0.005))

    body_shell(clay)
    canopy_frame_and_glass(clay, glass)
    fender_mesh(clay)
    for root_name, center in WHEEL_CENTERS.items():
        wheel_mesh(root_name, center, rubber, metal)
    mechanical_assemblies(clay, dark, metal, light, tail)
    final_functional_details(clay, dark, metal, light, tail)
    apply_all_transforms()
    apply_all_modifiers()
    clean_topology_and_normals()
    create_shared_uv_atlas()
    attach_pbr_textures(clay, [clay, dark, rubber, metal])

    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print("STALLION_V3_BLOCKOUT_BUILD_OK", BLEND_PATH)


if __name__ == "__main__":
    build()
