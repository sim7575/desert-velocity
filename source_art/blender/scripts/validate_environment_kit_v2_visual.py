import bpy
import math
import os
from collections import Counter


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FINAL_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2.blend")
TEXTURE_ROOT = os.path.join(ROOT, "assets", "textures", "environment", "environment_v2")
REQUIRED_MANUAL = (
    "HeroRock_A_SplitCrown", "HeroRock_B_LeaningStack", "HeroRock_C_BrokenButte",
    "CanyonWall_A_Concave", "CanyonWall_B_Stepped", "RockArch_01",
    "DistantMesa_A", "DistantMesa_B", "NarrativeWreck_SurveyRover",
)


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def combined_bounds(objects):
    minimum = [float("inf")] * 3
    maximum = [float("-inf")] * 3
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ mathutils.Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
    return minimum, maximum


def validate():
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(FINAL_PATH):
        bpy.ops.wm.open_mainfile(filepath=FINAL_PATH)
    collections = [bpy.data.collections.get(f"ENV2_LOD{level}") for level in range(3)]
    if any(collection is None for collection in collections):
        raise RuntimeError("Manual LOD collections missing")
    totals = []
    for level, collection in enumerate(collections):
        objects = [obj for obj in collection.objects if obj.type == "MESH"]
        if len(objects) != 40:
            raise RuntimeError(f"LOD{level} mesh count {len(objects)} != 40")
        total = sum(triangles(obj) for obj in objects)
        totals.append(total)
        for obj in objects:
            if not obj.data.uv_layers or len(obj.data.uv_layers.active.data) == 0:
                raise RuntimeError("Missing UV: " + obj.name)
            for loop in obj.data.uv_layers.active.data:
                if not (-0.0001 <= loop.uv.x <= 1.0001 and -0.0001 <= loop.uv.y <= 1.0001):
                    raise RuntimeError("UV outside atlas: " + obj.name)
            if any(not math.isfinite(component) for vertex in obj.data.vertices for component in vertex.normal):
                raise RuntimeError("Invalid normal: " + obj.name)
            if any(abs(value - 1.0) > 0.0001 for value in obj.scale):
                raise RuntimeError("Unapplied scale: " + obj.name)
    if totals[0] != 26982 or not (13000 <= totals[1] < totals[0]) or not (6500 <= totals[2] < totals[1]):
        raise RuntimeError("LOD triangle budgets invalid: " + repr(totals))
    lod0_names = {obj.name for obj in collections[0].objects}
    for required in REQUIRED_MANUAL:
        if required not in lod0_names:
            raise RuntimeError("Required LOD0 asset missing: " + required)
        for level in (1, 2):
            if bpy.data.objects.get(f"{required}_LOD{level}") is None:
                raise RuntimeError(f"Manual LOD missing: {required} LOD{level}")
    used_materials = {material.name for obj in collections[0].objects for material in obj.data.materials if material}
    shared_materials = {material.name for material in bpy.data.materials if material.get("shared_environment_v2", False)}
    # Eight atlas materials are embedded in the GLB; the ninth shared road
    # material is constructed by the isolated Godot wrapper from Road Atlas.
    if len(shared_materials) != 8 or len(used_materials) > 8:
        raise RuntimeError(f"Shared material budget invalid: shared={len(shared_materials)} used={len(used_materials)}")
    expected_textures = {
        "natural": 2048, "road": 2048, "props": 1024, "vegetation": 1024,
    }
    texture_count = 0
    for atlas, resolution in expected_textures.items():
        for suffix in ("base_color", "normal", "orm"):
            path = os.path.join(TEXTURE_ROOT, f"{atlas}_{suffix}.png")
            if not os.path.exists(path):
                raise RuntimeError("Texture missing: " + path)
            image = bpy.data.images.load(path, check_existing=True)
            if tuple(image.size) != (resolution, resolution):
                raise RuntimeError("Texture resolution invalid: " + path)
            texture_count += 1
    print("ENV2_LOD_TRIANGLES=" + ",".join(str(value) for value in totals))
    print(f"ENV2_MATERIALS_SHARED={len(shared_materials)} used={len(used_materials)}")
    print(f"ENV2_TEXTURES={texture_count}")
    print("ENV2_UV_VALIDATION=PASS range_0_1=true")
    print("ENV2_NORMAL_VALIDATION=PASS finite=true")
    print("ENVIRONMENT_KIT_V2_VISUAL_VALIDATION PASS")
    return totals


if __name__ == "__main__":
    import mathutils
    validate()
