import bpy
import os
import sys


sys.dont_write_bytecode = True
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SCRIPT_DIR = os.path.dirname(__file__)
FINAL_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2.blend")
OUTPUT_ROOT = os.path.join(ROOT, "assets", "models", "environment")
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from validate_environment_kit_v2_visual import validate


def export():
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(FINAL_PATH):
        bpy.ops.wm.open_mainfile(filepath=FINAL_PATH)
    totals = validate()
    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    for level in range(3):
        bpy.ops.object.select_all(action="DESELECT")
        collection = bpy.data.collections[f"ENV2_LOD{level}"]
        collection.hide_viewport = False
        for obj in collection.objects:
            if obj.type == "MESH":
                obj.hide_set(False)
                obj.select_set(True)
        path = os.path.join(OUTPUT_ROOT, f"environment_v2_lod{level}.glb")
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            # Godot's isolated wrapper owns the nine shared PBR materials.
            # Keeping them out of the GLB prevents duplicate atlas extraction.
            export_materials="NONE",
            export_cameras=False,
            export_lights=False,
            export_extras=True,
        )
        collection.hide_viewport = level != 0
        print(f"ENVIRONMENT_V2_EXPORT LOD{level} triangles={totals[level]} path={path}")
    print("ENVIRONMENT_KIT_V2_VISUAL_EXPORT PASS")


if __name__ == "__main__":
    export()
