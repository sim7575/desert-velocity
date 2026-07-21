import bpy
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "vehicles", "desert_stallion_v3.blend")
OUT_DIR = os.path.join(ROOT, "assets", "models", "vehicles")


def triangle_count():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return total


def decimate(obj, ratio):
    if ratio >= 0.999:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("ManualPartAwareLOD", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def part_ratio(name, level):
    if name == "V3_Glass":
        return 1.0
    if level == 1:
        if name.startswith("Wheel_"):
            return 0.50
        if name == "V3_VisibleSuspension":
            return 0.52
        if name == "V3_FinalFunctionalDetail":
            return 0.42
        if name == "V3_Interior":
            return 0.42
        if name == "V3_RollCage":
            return 0.72
        if name in ("V3_MuscularFenders", "V3_FunctionalDetails"):
            return 0.62
        return 0.72
    if name.startswith("Wheel_"):
        return 0.19
    if name == "V3_VisibleSuspension":
        return 0.21
    if name == "V3_RollCage":
        return 0.48
    if name in ("V3_MuscularFenders", "V3_FunctionalDetails"):
        return 0.34
    return 0.38


def build_lod(level, filename, minimum, maximum):
    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    # Manual LOD policy: small cabin/service parts are removed only at LOD2;
    # silhouette-defining fenders, wheels, cage and open rear remain present.
    if level == 2:
        for name in ("V3_Interior", "V3_FinalFunctionalDetail"):
            obj = bpy.data.objects.get(name)
            if obj is not None:
                bpy.data.objects.remove(obj, do_unlink=True)
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            decimate(obj, part_ratio(obj.name, level))
    triangles = triangle_count()
    if not minimum <= triangles <= maximum:
        raise RuntimeError("LOD%d triangles outside target: %d" % (level, triangles))
    for wheel_name in ("Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"):
        wheel = bpy.data.objects.get(wheel_name)
        if wheel is None or len(wheel.children) != 1:
            raise RuntimeError("LOD%d lost pivot %s" % (level, wheel_name))
    bpy.context.scene["stallion_v3_lod"] = level
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="PLACEHOLDER",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    print("STALLION_V3_LOD%d_OK triangles=%d path=%s" % (level, triangles, path))
    return triangles


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    lod1 = build_lod(1, "desert_stallion_v3_lod1.glb", 26000, 34000)
    lod2 = build_lod(2, "desert_stallion_v3_lod2.glb", 10000, 14000)
    print("STALLION_V3_LODS_OK lod1=%d lod2=%d" % (lod1, lod2))


if __name__ == "__main__":
    main()
