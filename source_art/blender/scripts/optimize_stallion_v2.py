import bpy, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND = os.path.join(ROOT, "source_art/blender/vehicles/desert_stallion_65_v2.blend")
GLB = os.path.join(ROOT, "assets/models/vehicles/desert_stallion_65_v2.glb")
WHEELS = ("Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR")

def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for modifier in list(obj.modifiers):
        try: bpy.ops.object.modifier_apply(modifier=modifier.name)
        except RuntimeError: pass
    obj.select_set(False)

def wheel_owner(obj):
    parent = obj.parent
    while parent:
        if parent.name in WHEELS: return parent.name
        parent = parent.parent
    return None

def join_group(objects, name, parent=None):
    if not objects: return None
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        apply_modifiers(obj); obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = name
    merged.parent = parent
    return merged

# One static mesh per material; each wheel remains an independent animated pivot,
# with at most one child mesh per material.
groups = {}
for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH': continue
    owner = wheel_owner(obj)
    material = obj.data.materials[0].name if obj.data.materials else "NoMaterial"
    groups.setdefault((owner or "STATIC", material), []).append(obj)

for (owner, material), objects in groups.items():
    parent = bpy.data.objects.get(owner) if owner != "STATIC" else None
    join_group(objects, "%s_%s" % (owner, material), parent)

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', export_apply=True, export_yup=True)
mesh_count = len([o for o in bpy.context.scene.objects if o.type == 'MESH'])
print("STALLION_OPTIMIZED mesh_objects=%d materials=%d" % (mesh_count, len([m for m in bpy.data.materials if m.users])))
