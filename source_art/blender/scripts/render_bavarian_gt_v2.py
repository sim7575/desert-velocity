import bpy, os, math, random
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..",".."));OUT=os.path.join(ROOT,"screenshots/gt_v2");os.makedirs(OUT,exist_ok=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False;scene.render.image_settings.color_mode='RGBA';scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.image_settings.color_depth='8';scene.world.color=(.055,.075,.095)
def mat(n,c,r=.8):
 m=bpy.data.materials.get(n) or bpy.data.materials.new(n);m.use_nodes=True;m.diffuse_color=(*c,1);p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=r;return m
def cube(n,l,s,m,b=.06):
 bpy.ops.mesh.primitive_cube_add(location=l);o=bpy.context.object;o.name=n;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if b:q=o.modifiers.new('Soft','BEVEL');q.width=b;q.segments=2
 return o
def look(pos,target=(0,0,.65),lens=55):camera.location=pos;camera.data.lens=lens;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
def render(name,pos,target=(0,0,.65),lens=55):look(pos,target,lens);scene.render.filepath=os.path.join(OUT,name+'.png');bpy.ops.render.render(write_still=True)

sand=mat('StudioGround',(.19,.22,.25),.78);bpy.ops.mesh.primitive_plane_add(size=45);ground=bpy.context.object;ground.data.materials.append(sand)
camdata=bpy.data.cameras.new('EvaluationCamera');camera=bpy.data.objects.new('EvaluationCamera',camdata);scene.collection.objects.link(camera);scene.camera=camera
sun_data=bpy.data.lights.new('KeySun','SUN');sun=bpy.data.objects.new('KeySun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(math.radians(38),0,math.radians(-35));sun.data.energy=2.5;sun.data.color=(1,.82,.65)
area_data=bpy.data.lights.new('StudioFill','AREA');area=bpy.data.objects.new('StudioFill',area_data);scene.collection.objects.link(area);area.location=(-4,-4,6);area.data.energy=1000;area.data.size=5

# Twelve neutral review views.
render('01_neutral_front_three_quarter',(5.8,-6.5,2.8));render('02_neutral_rear_three_quarter',(-5.7,6.3,2.7));render('03_neutral_side',(7.4,0,1.65),(0,0,.67),62);render('04_neutral_front',(0,-7.7,1.55),(0,0,.64),62);render('05_neutral_rear',(0,7.7,1.55),(0,0,.64),62);render('06_neutral_top',(-4.8,-5.3,6.2),(0,.1,.45),58);render('07_neutral_low',(4.8,-6.4,.72),(0,-.15,.58),48);render('08_detail_front',(2.0,-5.0,1.25),(0,-1.55,.66),72);render('09_detail_rear',(-2.0,5.0,1.20),(0,1.65,.66),72);render('10_detail_wheel',(2.9,-2.6,.75),(.90,-1.43,.43),82);render('11_detail_side',(4.0,.5,1.15),(1.0,.45,.70),72)
# Silhouette: black materials, bright background.
original=[]
black=mat('Silhouette',(0,0,0),1)
for o in bpy.context.scene.objects:
 if o.type=='MESH' and o!=ground:
  original.append((o,list(o.data.materials)));o.data.materials.clear();o.data.materials.append(black)
scene.world.color=(.82,.88,.93);ground.data.materials.clear();ground.data.materials.append(mat('SilhouetteGround',(.72,.80,.86),1));render('12_neutral_silhouette',(6.2,-7.0,2.4),(0,0,.70),58)
for o,mats in original:o.data.materials.clear();[o.data.materials.append(m) for m in mats]

# Moderately varied desert review set, separate from gameplay environment.
scene.world.color=(.19,.09,.045);ground.data.materials.clear();ground.data.materials.append(mat('DesertSand',(.30,.14,.045),.94));sun.data.color=(1,.52,.25);sun.data.energy=3.0
rock=mat('DesertRock',(.23,.055,.018),.91);road=mat('ReviewRoad',(.105,.075,.055),.88);cube('ReviewRoad',(0,0,.035),(2.9,13,.035),road,.01)
random.seed(272)
for i in range(30):
 side=random.choice((-1,1));o=cube('Rock_%02d'%i,(side*random.uniform(3.4,9),random.uniform(-11,11),random.uniform(.12,.55)),(random.uniform(.25,1.1),random.uniform(.25,.9),random.uniform(.25,1.0)),rock);o.rotation_euler=(random.random(),random.random(),random.random())
for side in (-1,1):
 for i in range(6):cube('Canyon_%s_%d'%(side,i),(side*(8+i*.55),4+i*1.25,1.6+i*.32),(1.4,1.3,1.8+i*.38),rock)
render('13_desert_road',(6.5,-7.2,2.7));render('14_desert_curve',(-6.0,-5.8,2.4),(0,.25,.65),54)
sun.rotation_euler=(math.radians(76),0,math.radians(-80));sun.data.color=(1,.25,.07);scene.world.color=(.12,.025,.025);render('15_desert_sunset',(5.8,6.5,2.5),(0,.2,.68),52)
render('16_gameplay_rear',(0,6.0,2.25),(0,-.7,.67),60);render('17_desert_wide',(-10,-11,5.7),(0,1,.65),58)
print('GT_V2_RENDER_OK count=17 '+OUT)
