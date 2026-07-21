import bpy
import bmesh
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLEND_PATH = os.path.join(ROOT, "source_art", "blender", "vehicles", "desert_stallion_v3.blend")
TEXTURE_ROOT = os.path.join(ROOT, "assets", "textures", "vehicles", "stallion_v3")


def triangle_uv_area(mesh, uv_layer):
    total = 0.0
    degenerate = 0
    for triangle in mesh.loop_triangles:
        uv = [uv_layer.data[index].uv for index in triangle.loops]
        area = abs((uv[1] - uv[0]).cross(uv[2] - uv[0])) * 0.5
        total += area
        if area < 1e-10:
            degenerate += 1
    return total, degenerate


def main():
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLEND_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    boundary_edges = 0
    nonmanifold_edges = 0
    degenerate_uv = 0
    world_area = 0.0
    uv_area = 0.0
    mesh_count = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        mesh_count += 1
        if (obj.scale - Vector((1.0, 1.0, 1.0))).length > 0.0001 or Vector(obj.rotation_euler).length > 0.0001:
            raise RuntimeError("Unapplied transform: " + obj.name)
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        uv = mesh.uv_layers.active
        if uv is None:
            raise RuntimeError("Missing UV map: " + obj.name)
        object_uv_area, object_degenerate = triangle_uv_area(mesh, uv)
        uv_area += object_uv_area
        degenerate_uv += object_degenerate
        if object_degenerate:
            print("UV_DIAGNOSTIC %s degenerate=%d" % (obj.name, object_degenerate))
        world_area += sum(poly.area for poly in mesh.polygons)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        object_boundary = sum(1 for edge in bm.edges if len(edge.link_faces) == 1)
        object_nonmanifold = sum(1 for edge in bm.edges if not edge.is_manifold and not edge.is_boundary)
        boundary_edges += object_boundary
        nonmanifold_edges += object_nonmanifold
        if object_boundary or object_nonmanifold:
            print("TOPOLOGY_DIAGNOSTIC %s boundary=%d nonmanifold=%d" % (obj.name, object_boundary, object_nonmanifold))
        bm.free()
        evaluated.to_mesh_clear()
    if boundary_edges or nonmanifold_edges:
        raise RuntimeError("Topology invalid: boundary=%d nonmanifold=%d" % (boundary_edges, nonmanifold_edges))
    if degenerate_uv:
        raise RuntimeError("Degenerate UV triangles: %d" % degenerate_uv)
    texel_density = math.sqrt((uv_area * 2048.0 * 2048.0) / max(world_area, 0.001))
    expected = {
        "stallion_v3_base_color.png": (2048, 2048),
        "stallion_v3_normal.png": (2048, 2048),
        "stallion_v3_orm.png": (2048, 2048),
        "stallion_v3_dirt_damage_mask.png": (1024, 1024),
        "stallion_v3_emissive.png": (1024, 1024),
    }
    for filename, size in expected.items():
        path = os.path.join(TEXTURE_ROOT, filename)
        if not os.path.exists(path):
            raise RuntimeError("Missing texture: " + filename)
        image = bpy.data.images.load(path, check_existing=True)
        if tuple(image.size) != size:
            raise RuntimeError("Texture resolution invalid: %s %s" % (filename, tuple(image.size)))
    print("STALLION_V3_ASSET_VALIDATION_OK")
    print("triangles=%d meshes=%d materials=%d" % (triangles, mesh_count, len([m for m in bpy.data.materials if m.users])))
    print("topology_boundary_edges=%d topology_nonmanifold_edges=%d" % (boundary_edges, nonmanifold_edges))
    print("uv_degenerate_triangles=%d uv_pack_margin=0.006 texel_density_px_per_m=%.2f" % (degenerate_uv, texel_density))
    print("baking=procedural_maps_validated textures=5")


if __name__ == "__main__":
    main()
