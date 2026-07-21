import bpy
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "vehicles", "desert_stallion_v3.blend")
GLB_PATH = os.path.join(ROOT, "assets", "models", "vehicles", "desert_stallion_v3.glb")
WHEELS = ("Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR")


def evaluated_metrics():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    mesh_objects = 0
    minimum = Vector((1e9, 1e9, 1e9))
    maximum = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        mesh_objects += 1
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        for corner in evaluated.bound_box:
            point = evaluated.matrix_world @ Vector(corner)
            minimum.x = min(minimum.x, point.x)
            minimum.y = min(minimum.y, point.y)
            minimum.z = min(minimum.z, point.z)
            maximum.x = max(maximum.x, point.x)
            maximum.y = max(maximum.y, point.y)
            maximum.z = max(maximum.z, point.z)
        evaluated.to_mesh_clear()
    materials = sorted(material.name for material in bpy.data.materials if material.users)
    dimensions = maximum - minimum
    return triangles, mesh_objects, materials, dimensions, minimum, maximum


def validate():
    triangles, mesh_objects, materials, dimensions, minimum, maximum = evaluated_metrics()
    missing = [name for name in WHEELS if bpy.data.objects.get(name) is None]
    if missing:
        raise RuntimeError("Missing wheel pivots: " + ", ".join(missing))
    if triangles < 40000 or triangles > 68000:
        raise RuntimeError("LOD0 triangle budget invalid: %d" % triangles)
    if mesh_objects > 16:
        raise RuntimeError("Mesh object budget exceeded: %d" % mesh_objects)
    if len(materials) > 8:
        raise RuntimeError("Material budget exceeded: %d" % len(materials))
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if (obj.scale - Vector((1.0, 1.0, 1.0))).length > 0.0001:
            raise RuntimeError("Unapplied scale on " + obj.name)
        if Vector(obj.rotation_euler).length > 0.0001:
            raise RuntimeError("Unapplied rotation on " + obj.name)
    length, width, height = dimensions.y, dimensions.x, dimensions.z
    if not (4.65 <= length <= 4.91 and 2.10 <= width <= 2.22 and 1.65 <= height <= 1.82):
        raise RuntimeError("Dimensions outside target: %.3f x %.3f x %.3f" % (length, width, height))
    expected = {
        "Wheel_FL": Vector((-0.94, -1.47, 0.51)),
        "Wheel_FR": Vector((0.94, -1.47, 0.51)),
        "Wheel_RL": Vector((-0.94, 1.47, 0.51)),
        "Wheel_RR": Vector((0.94, 1.47, 0.51)),
    }
    for name, center in expected.items():
        pivot = bpy.data.objects[name]
        pivot["desired_center"] = tuple(center)
        pivot["vehicle_wheel"] = True
        pivot["front_wheel"] = name in ("Wheel_FL", "Wheel_FR")
        if pivot.type != "EMPTY" or len(pivot.children) != 1 or (pivot.location - center).length > 0.001:
            raise RuntimeError("Invalid pivot hierarchy for " + name)
    if expected["Wheel_FL"].y >= expected["Wheel_RL"].y:
        raise RuntimeError("Vehicle orientation is invalid: front axle must use negative Y")
    print("V3_TRIANGLES=%d" % triangles)
    print("V3_MESH_OBJECTS=%d" % mesh_objects)
    print("V3_MATERIALS=%d" % len(materials))
    print("V3_DIMENSIONS=%.3f,%.3f,%.3f" % (length, width, height))
    print("V3_BOUNDS_MIN=%.3f,%.3f,%.3f" % tuple(minimum))
    print("V3_BOUNDS_MAX=%.3f,%.3f,%.3f" % tuple(maximum))
    for name, center in expected.items():
        print("V3_PIVOT_%s=%.3f,%.3f,%.3f" % (name, center.x, center.y, center.z))
    return triangles, mesh_objects, len(materials), dimensions


def export():
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    validate()
    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="PLACEHOLDER",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    print("STALLION_V3_BLOCKOUT_EXPORT_OK", GLB_PATH)


if __name__ == "__main__":
    export()
