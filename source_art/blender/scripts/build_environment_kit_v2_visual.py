import bpy
import math
import os


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BLOCKOUT_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2_blockout.blend")
FINAL_PATH = os.path.join(ROOT, "source_art", "blender", "environment", "environment_kit_v2.blend")
TEXTURE_ROOT = os.path.join(ROOT, "assets", "textures", "environment", "environment_v2")

MATERIAL_SPECS = {
    "ENV2_RockRed": ("natural", 0, 5, 0.88, 0.0),
    "ENV2_RockOchre": ("natural", 1, 5, 0.90, 0.0),
    "ENV2_RockDark": ("natural", 2, 5, 0.92, 0.0),
    "ENV2_Sand": ("natural", 3, 5, 0.96, 0.0),
    "ENV2_GroundCompact": ("natural", 4, 5, 0.91, 0.0),
    "ENV2_Road": ("road", 0, 4, 0.82, 0.0),
    "ENV2_Vegetation": ("vegetation", 0, 4, 0.88, 0.0),
    "ENV2_PaintedMetal": ("props", 0, 4, 0.62, 0.58),
    "ENV2_OxidizedMetalGlass": ("props", 2, 4, 0.82, 0.52),
}


def load_image(name, colorspace):
    path = os.path.join(TEXTURE_ROOT, name)
    image = bpy.data.images.load(path, check_existing=True)
    image.colorspace_settings.name = colorspace
    return image


def create_material(name, atlas, zone, zone_count, roughness, metallic):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    material["shared_environment_v2"] = True
    material["atlas"] = atlas
    material["atlas_zone"] = zone
    material["atlas_zone_count"] = zone_count
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (620, 0)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.location = (330, 0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    base = nodes.new("ShaderNodeTexImage")
    base.name = "ENV2_BaseColor"
    base.image = load_image(f"{atlas}_base_color.png", "sRGB")
    base.location = (-620, 180)
    normal = nodes.new("ShaderNodeTexImage")
    normal.name = "ENV2_Normal"
    normal.image = load_image(f"{atlas}_normal.png", "Non-Color")
    normal.location = (-620, -60)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.48 if "Rock" in name else 0.34
    normal_map.location = (-100, -60)
    orm = nodes.new("ShaderNodeTexImage")
    orm.name = "ENV2_ORM"
    orm.image = load_image(f"{atlas}_orm.png", "Non-Color")
    orm.location = (-620, -320)
    separate = nodes.new("ShaderNodeSeparateColor")
    separate.mode = "RGB"
    separate.location = (-300, -300)
    links.new(base.outputs["Color"], shader.inputs["Base Color"])
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    links.new(orm.outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Green"], shader.inputs["Roughness"])
    links.new(separate.outputs["Blue"], shader.inputs["Metallic"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def material_for_object(obj, old):
    name = obj.name
    if name.startswith(("Cactus_", "DryBush_")):
        return "ENV2_Vegetation"
    if name.startswith("RoadSign_"):
        return "ENV2_PaintedMetal"
    if name.startswith(("SafetyBarrier_", "NarrativeWreck_")):
        return "ENV2_OxidizedMetalGlass"
    if name.startswith(("Dune_", "RoadEdge_")):
        return "ENV2_Sand"
    if name.startswith("DebrisGravel"):
        return "ENV2_GroundCompact"
    if "RockDark" in old:
        return "ENV2_RockDark"
    if "RockOchre" in old:
        return "ENV2_RockOchre"
    return "ENV2_RockRed"


def smart_uv_to_zone(obj, zone, zone_count):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(58.0), island_margin=0.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    uv_layer = obj.data.uv_layers.active
    padding = 0.012
    zone_width = 1.0 / zone_count
    for loop in uv_layer.data:
        loop.uv.x = zone * zone_width + padding + loop.uv.x * (zone_width - padding * 2.0)
        loop.uv.y = padding + loop.uv.y * (1.0 - padding * 2.0)
    obj.select_set(False)


def triangle_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def duplicate_lod(source, collection, level):
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    duplicate.name = f"{source.name}_LOD{level}"
    collection.objects.link(duplicate)
    duplicate["lod_level"] = level
    duplicate["source_asset"] = source.name
    if level > 0 and triangle_count(duplicate) > 40:
        important = source.name.startswith(("HeroRock_", "CanyonWall_", "RockArch_", "DistantMesa_", "NarrativeWreck_"))
        if level == 1:
            ratio = 0.58 if important else (0.66 if source.name.startswith("MediumRock_") else 0.76)
        else:
            ratio = 0.30 if important else (0.42 if source.name.startswith("MediumRock_") else 0.56)
        modifier = duplicate.modifiers.new(f"ENV2_LOD{level}_Controlled", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = duplicate
        duplicate.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        duplicate.select_set(False)
    return duplicate


def build():
    if os.path.abspath(bpy.data.filepath) != os.path.abspath(BLOCKOUT_PATH):
        bpy.ops.wm.open_mainfile(filepath=BLOCKOUT_PATH)
    source_objects = [obj for obj in list(bpy.context.scene.objects) if obj.type == "MESH"]
    original_materials = {
        obj.name: (obj.data.materials[0].name if obj.data.materials and obj.data.materials[0] else "")
        for obj in source_objects
    }
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)
    materials = {name: create_material(name, *spec) for name, spec in MATERIAL_SPECS.items()}
    lod0 = bpy.data.collections.get("ENV2_LOD0") or bpy.data.collections.new("ENV2_LOD0")
    if lod0 not in list(bpy.context.scene.collection.children):
        bpy.context.scene.collection.children.link(lod0)
    for obj in source_objects:
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        lod0.objects.link(obj)
        material_name = material_for_object(obj, original_materials[obj.name])
        obj.data.materials.clear()
        obj.data.materials.append(materials[material_name])
        atlas, zone, zone_count, _, _ = MATERIAL_SPECS[material_name]
        smart_uv_to_zone(obj, zone, zone_count)
        obj["environment_v2_visual"] = True
        obj["material_category"] = material_name
        obj["atlas"] = atlas
        obj["lod_level"] = 0
    lod1 = bpy.data.collections.new("ENV2_LOD1")
    lod2 = bpy.data.collections.new("ENV2_LOD2")
    bpy.context.scene.collection.children.link(lod1)
    bpy.context.scene.collection.children.link(lod2)
    for source in source_objects:
        duplicate_lod(source, lod1, 1)
        duplicate_lod(source, lod2, 2)
    lod1.hide_viewport = True
    lod1.hide_render = True
    lod2.hide_viewport = True
    lod2.hide_render = True
    bpy.context.scene["environment_v2_visual"] = True
    bpy.context.scene["source_checkpoint"] = "4fd44d3815031f3ace6d027fbea1fe2acc6a0620"
    bpy.context.scene["silhouette_frozen"] = True
    bpy.context.scene["shared_material_count"] = 9
    os.makedirs(os.path.dirname(FINAL_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=FINAL_PATH)
    for collection in (lod0, lod1, lod2):
        total = sum(triangle_count(obj) for obj in collection.objects if obj.type == "MESH")
        print(f"ENVIRONMENT_V2_{collection.name}_TRIANGLES={total}")
    print("ENVIRONMENT_KIT_V2_VISUAL_BUILD PASS", FINAL_PATH)


if __name__ == "__main__":
    build()
