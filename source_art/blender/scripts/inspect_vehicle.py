import bpy

depsgraph = bpy.context.evaluated_depsgraph_get()
triangles = 0
mesh_objects = 0
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    mesh_objects += 1
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    triangles += len(mesh.loop_triangles)
    evaluated.to_mesh_clear()

print(f"VEHICLE_MESH_OBJECTS={mesh_objects}")
print(f"VEHICLE_TRIANGLES={triangles}")
print("MATERIALS=" + ",".join(sorted(material.name for material in bpy.data.materials)))
print("WHEELS=" + ",".join(sorted(obj.name for obj in bpy.context.scene.objects if obj.name.startswith("Wheel_") and obj.name.endswith("_Tire"))))
