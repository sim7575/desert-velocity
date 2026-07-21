import bpy, math, os

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..",".."))
VB=os.path.join(ROOT,"source_art/blender/vehicles/desert_stallion_65.blend")
EB=os.path.join(ROOT,"source_art/blender/environment/desert_prototype_environment.blend")
VG=os.path.join(ROOT,"assets/models/vehicles/desert_stallion_65.glb")
EG=os.path.join(ROOT,"assets/models/environment/desert_prototype_environment.glb")

def material(name,c,metal=0.0,rough=.5,emit=None):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get("Principled BSDF"); p.inputs["Base Color"].default_value=(*c,1); p.inputs["Metallic"].default_value=metal; p.inputs["Roughness"].default_value=rough
 if emit: p.inputs["Emission Color"].default_value=(*emit,1); p.inputs["Emission Strength"].default_value=.65
 return m
def use(o,m): o.data.materials.append(m); return o
def smooth(o):
 for p in o.data.polygons:p.use_smooth=True
def bev(o,w=.05,n=3):
 q=o.modifiers.new("Bevel","BEVEL");q.width=w;q.segments=n;smooth(o);return o
def cube(n,l,s,m,w=.04,r=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(location=l,rotation=r);o=bpy.context.object;o.name=n;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);use(o,m);return bev(o,w)
def sphere(n,l,s,m,seg=24,rings=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=l);o=bpy.context.object;o.name=n;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);use(o,m);smooth(o);return o
def cylinder(n,l,rad,dep,m,r=(0,0,0),v=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=rad,depth=dep,location=l,rotation=r);o=bpy.context.object;o.name=n;use(o,m);return bev(o,.02,2)
def clear(): bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def body(m):
 st=[(-2.3,.69,.59),(-2.0,.82,.72),(-1.35,.9,.88),(-.55,.95,1.02),(.2,.96,1.16),(.92,.91,1.26),(1.5,.86,1.12),(2.05,.8,.82),(2.3,.72,.62)]
 pr=[(-1,.18),(-.94,.52),(-.72,.84),(-.38,1),(.38,1),(.72,.84),(.94,.52),(1,.18),(.76,0),(0,-.08),(-.76,0)]
 vs=[(x*w,y,.48+z*h) for y,w,h in st for x,z in pr]; n=len(pr);fs=[]
 for a in range(len(st)-1):
  for i in range(n):j=(i+1)%n;fs.append((a*n+i,a*n+j,(a+1)*n+j,(a+1)*n+i))
 fs += [tuple(range(n-1,-1,-1)),tuple((len(st)-1)*n+i for i in range(n))]
 me=bpy.data.meshes.new('ContinuousBodyMesh');me.from_pydata(vs,[],fs);o=bpy.data.objects.new('Body_Shell',me);bpy.context.collection.objects.link(o);use(o,m);bev(o,.07,3)
 sub=o.modifiers.new('Body_Subdivision','SUBSURF');sub.levels=2;sub.render_levels=2
 return o
def save_export(blend,glb):
 os.makedirs(os.path.dirname(blend),exist_ok=True);os.makedirs(os.path.dirname(glb),exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=blend);bpy.ops.export_scene.gltf(filepath=glb,export_format='GLB',export_apply=True,export_yup=True)

def vehicle():
 clear(); paint=material('Paint_Burnt_Coral',(.38,.035,.015),.15,.3);dust=material('Dust_Ochre',(.25,.08,.018),0,.94);glass=material('Glass_Smoke',(.018,.045,.055),.15,.1);rubber=material('Rubber',(.01,.012,.01),0,.9);metal=material('Metal_Dark',(.045,.05,.05),.8,.24);alloy=material('Wheel_Alloy',(.2,.16,.1),.85,.28);black=material('Plastic_Black',(.012,.014,.012),0,.7);lamp=material('Lamp_Warm',(.75,.55,.22),0,.14,(1,.55,.12));tail=material('Tail_Red',(.5,.005,.003),0,.16,(1,.01,.005));cream=material('Livery_Cream',(.78,.52,.22),0,.5)
 body(paint);sphere('Cabin_Roof',(0,.48,1.69),(.77,1.0,.38),paint,32,16);w=sphere('Windshield',(0,-.2,1.61),(.72,.045,.36),glass,28,12);w.rotation_euler.x=math.radians(-18);w=sphere('Rear_Glass',(0,1.15,1.57),(.65,.045,.3),glass,28,12);w.rotation_euler.x=math.radians(18)
 for side in (-1,1):
  sphere('Side_Glass', (side*.73,.48,1.59),(.035,.59,.28),glass,24,12);sphere('Front_Fender',(side*.86,-1.25,.76),(.31,.63,.45),paint,28,12);sphere('Rear_Fender',(side*.86,1.28,.77),(.33,.59,.47),paint,28,12)
  cube('Mudflap',(side*.83,1.85,.34),(.25,.035,.29),rubber,.02);cube('Mirror',(side*.94,-.12,1.54),(.14,.21,.1),black,.06);cylinder('Side_Exhaust',(side*.92,1.0,.31),.06,1.12,metal,(math.pi/2,0,0),24);cube('Lower_Dust',(side*.956,.35,.65),(.012,1.44,.13),dust,.01);cube('Door_Livery',(side*.955,.52,1.03),(.012,.47,.27),cream,.01)
 cube('Hood_Scoop',(0,-1.34,1.30),(.34,.44,.12),black,.08,(math.radians(-5),0,0));cube('Front_Bumper',(0,-2.3,.56),(.94,.09,.13),metal,.06);cube('Rear_Bumper',(0,2.3,.55),(.88,.09,.12),metal,.06);cube('Grille',(0,-2.38,.82),(.55,.04,.21),black,.025);cube('Skidplate',(0,-1.8,.29),(.73,.58,.04),metal,.018,(math.radians(8),0,0));cube('Spoiler',(0,2.08,1.17),(.76,.2,.05),paint,.04);cube('Hood_Livery',(0,-1.42,1.42),(.17,.6,.01),cream,.008,(math.radians(-5),0,0));cube('Rear_Dust',(0,2.398,.67),(.68,.01,.1),dust,.008)
 for x in (-.48,-.16,.16,.48):cylinder('Aux_Lamp',(x,-2.46,.9),.14,.11,lamp,(math.pi/2,0,0),32)
 for x in (-.61,.61):cylinder('Headlamp',(x,-2.25,1.01),.17,.11,lamp,(math.pi/2,0,0),32);cube('Tail_Lamp',(x,2.39,.82),(.18,.02,.1),tail,.02)
 for x in (-.57,.57):cylinder('Rollbar',(x,.52,1.43),.035,1.12,alloy,(0,0,0),16)
 cylinder('Rollbar_Cross',(0,.52,1.86),.035,1.14,alloy,(0,math.pi/2,0),16)
 for i,(x,y) in enumerate([(-.92,-1.25),(.92,-1.25),(-.92,1.28),(.92,1.28)]):
  bpy.ops.mesh.primitive_torus_add(major_radius=.34,minor_radius=.135,major_segments=40,minor_segments=12,location=(x,y,.55),rotation=(math.pi/2,0,0));o=bpy.context.object;o.name=f'Wheel_{i}_Tire';use(o,rubber);smooth(o);cylinder(f'Wheel_{i}_Rim',(x,y,.55),.245,.2,alloy,(math.pi/2,0,0),28);cylinder(f'Wheel_{i}_Hub',(x,y,.55),.075,.23,metal,(math.pi/2,0,0),16)
 save_export(VB,VG)

def environment():
 clear();sand=material('Sand_Ochre',(.35,.13,.025),0,.95);road=material('Road_Gravel',(.15,.065,.025),0,.88);edge=material('Road_Edge_Dust',(.48,.2,.045),0,.97);ra=material('Rock_Red',(.3,.055,.015),0,.88);rb=material('Rock_Ochre',(.5,.17,.03),0,.92);green=material('Cactus_Mottled',(.04,.15,.055),0,.84);marks=material('Tire_Marks',(.03,.018,.012),0,.8)
 cube('Terrain',(0,0,-.16),(12,15,.18),sand,.02);cube('Road',(0,0,.04),(2.65,14,.075),road,.025)
 for x in (-2.48,2.48):cube('Dusty_Road_Edge',(x,0,.125),(.22,14,.025),edge,.01)
 for x in (-.62,.62):cube('Tire_Track',(x,0,.13),(.055,13.5,.008),marks,.006)
 layers=[((5.2,-1.2,.35),(1.65,1.35,.35),0),((5.15,-1.1,.82),(1.38,1.12,.24),8),((5.3,-1,1.18),(1.1,.88,.2),-6),((5.08,-.95,1.48),(.78,.66,.16),10)]
 for i,(l,s,z) in enumerate(layers):o=sphere(f'Stratified_Rock_{i}',l,s,ra if i%2==0 else rb,24,12);o.rotation_euler.z=math.radians(z)
 # One continuous canyon module with an irregular eroded crest and real depth.
 xs=[-9,-7.4,-5.8,-4.2,-2.6,-1,.6,2.2,3.8]
 tops=[3.4,4.1,3.65,4.55,3.8,4.35,3.55,4.25,3.7]
 vs=[]
 for y in (4.6,6.0):
  for x,z in zip(xs,tops):vs += [(x,y,0),(x,y,z)]
 n=len(xs);fs=[]
 for side in range(2):
  off=side*n*2
  for i in range(n-1):
   a=off+i*2;fs.append((a,a+2,a+3,a+1) if side==0 else (a+1,a+3,a+2,a))
 for i in range(n-1):
  a=i*2;b=2*n+i*2;fs += [(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)]
 fs += [(0,1,2*n+1,2*n),(2*n-2,4*n-2,4*n-1,2*n-1)]
 me=bpy.data.meshes.new('CanyonWallMesh');me.from_pydata(vs,[],fs);wall=bpy.data.objects.new('Canyon_Wall',me);bpy.context.collection.objects.link(wall);use(wall,ra);bev(wall,.12,3)
 for i,z in enumerate((.75,1.45,2.15,2.85)):
  cube(f'Canyon_Strata_{i}',(-2.6,4.48,z),(6.2,.13,.055),rb,.035,(0,0,math.radians((i%2)*2-1)))
 def cp(n,l,r1,r2,d,r=(0,0,0)):
  bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r1,radius2=r2,depth=d,location=l,rotation=r);o=bpy.context.object;o.name=n;use(o,green);bev(o,.03,2)
 cp('Cactus_Trunk',(-5.2,-2.4,1.12),.25,.16,2.25);cp('Cactus_Arm_L',(-5.62,-2.4,1.12),.17,.13,.85,(0,math.radians(65),0));cp('Cactus_Arm_L_Up',(-5.93,-2.4,1.48),.15,.10,.78);cp('Cactus_Arm_R',(-4.82,-2.4,1.42),.16,.12,.72,(0,math.radians(-65),0));cp('Cactus_Arm_R_Up',(-4.58,-2.4,1.73),.14,.09,.63)
 save_export(EB,EG)

vehicle();environment();print('VISUAL_PROTOTYPE_BUILD_OK')
