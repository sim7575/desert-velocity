import bpy
import os
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2_blockout.blend")
GLB_PATH = os.path.join(ROOT, "assets", "models", "environment", "environment_kit_v2_blockout.glb")

EXPECTED_FAMILIES = {
    "rock": 20,
    "rock_arch": 1,
    "canyon_wall": 2,
    "distant_mesa": 2,
    "cactus": 3,
    "dry_bush": 3,
    "sign": 2,
    "barrier": 1,
    "narrative_wreck": 1,
    "dune": 3,
    "road_edge": 2,
}


def validate():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    families = Counter(obj.get("asset_family", "") for obj in meshes)
    triangles = 0
    degenerate = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for tri in obj.data.loop_triangles:
            a, b, c = (obj.data.vertices[index].co for index in tri.vertices)
            if (b - a).cross(c - a).length_squared < 1e-12:
                degenerate += 1
        if any(abs(value - 1.0) > 0.0001 for value in obj.scale):
            raise RuntimeError("Unapplied scale: " + obj.name)
    materials = sorted(mat.name for mat in bpy.data.materials if mat.users)
    for family, expected in EXPECTED_FAMILIES.items():
        if families[family] != expected:
            raise RuntimeError("%s count %d != %d" % (family, families[family], expected))
    if len(meshes) != 40:
        raise RuntimeError("Mesh asset count must be 40, got %d" % len(meshes))
    if len(materials) != 7:
        raise RuntimeError("Material count must be 7, got %d" % len(materials))
    if triangles < 22000 or triangles > 32000:
        raise RuntimeError("Blockout triangle budget invalid: %d" % triangles)
    if degenerate:
        raise RuntimeError("Degenerate triangles: %d" % degenerate)
    for name in ("HeroRock_A_SplitCrown", "HeroRock_B_LeaningStack", "HeroRock_C_BrokenButte",
                 "RockArch_01", "CanyonWall_A_Concave", "CanyonWall_B_Stepped",
                 "DistantMesa_A", "DistantMesa_B", "NarrativeWreck_SurveyRover"):
        if bpy.data.objects.get(name) is None:
            raise RuntimeError("Required asset missing: " + name)
    per_asset = {}
    for obj in meshes:
        obj.data.calc_loop_triangles()
        per_asset[obj.name] = len(obj.data.loop_triangles)
    for name in ("HeroRock_A_SplitCrown", "HeroRock_B_LeaningStack", "HeroRock_C_BrokenButte"):
        if per_asset[name] < 1600:
            raise RuntimeError("Revised hero topology too low: %s=%d" % (name, per_asset[name]))
    for name in ("CanyonWall_A_Concave", "CanyonWall_B_Stepped"):
        if per_asset[name] < 4000:
            raise RuntimeError("Revised canyon topology too low: %s=%d" % (name, per_asset[name]))
    if per_asset["RockArch_01"] < 2000:
        raise RuntimeError("Revised arch topology too low: %d" % per_asset["RockArch_01"])
    print("EKV2_TRIANGLES=%d" % triangles)
    print("EKV2_MESH_ASSETS=%d" % len(meshes))
    print("EKV2_MATERIALS=%d" % len(materials))
    print("EKV2_DEGENERATE_TRIANGLES=%d" % degenerate)
    print("EKV2_REVISED_ASSETS=" + ",".join("%s:%d" % (name, per_asset[name]) for name in (
        "HeroRock_A_SplitCrown", "HeroRock_B_LeaningStack", "HeroRock_C_BrokenButte",
        "CanyonWall_A_Concave", "CanyonWall_B_Stepped", "RockArch_01")))
    print("EKV2_FAMILIES=" + ",".join("%s:%d" % (key, families[key]) for key in sorted(families)))
    return triangles


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
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    print("ENVIRONMENT_KIT_V2_BLOCKOUT_EXPORT_OK", GLB_PATH)


if __name__ == "__main__":
    export()
