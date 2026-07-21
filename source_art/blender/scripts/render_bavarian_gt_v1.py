import bpy, os, math, random
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..",".."))
OUT=os.path.join(ROOT,"screenshots/gt_v1")
os.makedirs(OUT,exist_ok=True)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.world.color=(.045,.025,.016)

def look(camera, target):camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
def material(name,color,rough=.8):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=rough;return m
def cube(name,loc,scale,mat):
 bpy.ops.mesh.primitive_cube_add(location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat);q=o.modifiers.new('Soft','BEVEL');q.width=.08;q.segments=2;return o

sand=material('RenderSand',(.31,.15,.055),.95);rock=material('RenderRock',(.22,.065,.025),.9)
bpy.ops.mesh.primitive_plane_add(size=40,location=(0,0,.0));bpy.context.object.data.materials.append(sand)
camera_data=bpy.data.cameras.new('RenderCamera');camera=bpy.data.objects.new('RenderCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=55
sun_data=bpy.data.lights.new('Sun','SUN');sun=bpy.data.objects.new('Sun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(math.radians(42),0,math.radians(-38));sun.data.energy=3.2;sun.data.color=(1.0,.63,.34)
fill_data=bpy.data.lights.new('Fill','AREA');fill=bpy.data.objects.new('Fill',fill_data);scene.collection.objects.link(fill);fill.location=(-4,-3,6);fill.data.energy=1100;fill.data.shape='DISK';fill.data.size=5

def render(name,pos,target=(0,0,.65)):
 camera.location=pos;look(camera,target);scene.render.filepath=os.path.join(OUT,name+'.png');bpy.ops.render.render(write_still=True)

render('gt_neutral_front',(5.8,-6.3,3.0));render('gt_neutral_rear',(-5.6,6.2,2.8))
random.seed(707)
for i in range(18):
 x=random.choice((-1,1))*random.uniform(3.3,9);y=random.uniform(-8,8);o=cube('Rock_%02d'%i,(x,y,random.uniform(.15,.5)),(random.uniform(.3,1.0),random.uniform(.25,.8),random.uniform(.25,.9)),rock);o.rotation_euler=(random.random(),random.random(),random.random())
for side in (-1,1):
 for i in range(5):cube('Canyon',((side*(7+i*.7)),3+i*1.2,1.5+i*.25),(1.4,1.2,1.8+i*.35),rock)
render('gt_ambient_front',(6.6,-7.2,3.2));render('gt_ambient_wide',(-9.5,-10.5,5.8),(0,1,.75))
print('GT_RENDER_OK '+OUT)
