import bpy
import os
import sys

sys.dont_write_bytecode = True

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SCRIPT_DIR = os.path.dirname(__file__)
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2_blockout.blend")

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from export_environment_kit_v2 import validate


if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLEND_PATH):
    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

triangles = validate()
print("ENVIRONMENT_KIT_V2_STANDALONE_VALIDATION PASS triangles=%d" % triangles)
