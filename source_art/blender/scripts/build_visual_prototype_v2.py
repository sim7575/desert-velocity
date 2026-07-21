import bpy, math, os, random
import numpy as np
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..",".."))
BLEND=os.path.join(ROOT,"source_art/blender/vehicles/desert_stallion_65_v2.blend")
ENV_BLEND=os.path.join(ROOT,"source_art/blender/environment/desert_prototype_environment_v2.blend")
GLB=os.path.join(ROOT,"assets/models/vehicles/desert_stallion_65_v2.glb")
ENV_GLB=os.path.join(ROOT,"assets/models/environment/desert_prototype_environment_v2.glb")
TEX=os.path.join(ROOT,"assets/textures/vehicles")
random.seed(65)

def clear(): bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.5):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 return m
def use(o,m):o.data.materials.append(m);return o
def bevel(o,w=.02,n=2,weighted=True):
 q=o.modifiers.new('Controlled_Bevel','BEVEL');q.width=w;q.segments=n;q.limit_method='ANGLE'
 if weighted:
  q=o.modifiers.new('Weighted_Normals','WEIGHTED_NORMAL');q.keep_sharp=True
 for p in o.data.polygons:p.use_smooth=True
 return o
def cube(n,l,s,m,w=.02,r=(0,0,0),parent=None):
 bpy.ops.mesh.primitive_cube_add(location=l,rotation=r);o=bpy.context.object;o.name=n;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);use(o,m);bevel(o,w,2)
 if parent:o.parent=parent
 return o
def cyl(n,l,rad,dep,m,r=(0,0,0),v=32,parent=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=rad,depth=dep,location=l,rotation=r);o=bpy.context.object;o.name=n;use(o,m);bevel(o,.008,2)
 if parent:o.parent=parent
 return o
def mesh_obj(name,verts,faces,m,bevel_width=.015):
 me=bpy.data.meshes.new(name+'Mesh');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);use(o,m);bevel(o,bevel_width,2);return o
def quad_panel(name,verts,m): return mesh_obj(name,verts,[(0,1,2,3)],m,.006)

def create_textures():
 os.makedirs(TEX,exist_ok=True);N=1024;y,x=np.mgrid[0:N,0:N];rng=np.random.default_rng(65)
 noise=rng.normal(0,1,(N,N));wave=np.sin(x/49)+np.sin(y/71)+np.sin((x+y)/113);variation=np.clip(.5+.09*wave+.035*noise,0,1)
 dirt=np.clip(((y/N)**3)*(.55+.35*rng.random((N,N))) + .12*(np.sin(x/31)>0.92),0,1)
 scratches=np.zeros((N,N),dtype=np.float32)
 for _ in range(95):
  yy=rng.integers(80,970);xx=rng.integers(20,900);ln=rng.integers(12,100);scratches[max(0,yy-1):min(N,yy+2),xx:min(N,xx+ln)]=rng.uniform(.35,.9)
 base=np.zeros((N,N,4),dtype=np.float32);base[...,0]=.30+.13*variation;base[...,1]=.028+.018*variation;base[...,2]=.014+.008*variation;base[...,:3]*=(1-.48*dirt[...,None]);base[...,:3]=np.maximum(base[...,:3],scratches[...,None]*np.array([.22,.16,.11]));base[...,3]=1
 rough=np.zeros((N,N,4),dtype=np.float32);rv=np.clip(.42+.3*dirt+.14*noise,0.28,.92);rough[...,:3]=rv[...,None];rough[...,3]=1
 def rgba_gray(v):a=np.empty((N,N,4),np.float32);a[...,:3]=v[...,None];a[...,3]=1;return a
 arrays={'stallion_v2_base_color.png':base,'stallion_v2_roughness.png':rough,'stallion_v2_dirt.png':rgba_gray(dirt),'stallion_v2_scratches.png':rgba_gray(scratches),'stallion_v2_paint_variation.png':rgba_gray(variation)}
 for fn,a in arrays.items():
  im=bpy.data.images.get(fn) or bpy.data.images.new(fn,width=N,height=N,alpha=True);im.pixels.foreach_set(a.ravel());im.filepath_raw=os.path.join(TEX,fn);im.file_format='PNG';im.save()
 return arrays.keys()

def textured_paint():
 m=mat('V2_Paint_Textured',(.32,.025,.012),0.08,.48);nt=m.node_tree;p=nt.nodes.get('Principled BSDF')
 img=bpy.data.images.load(os.path.join(TEX,'stallion_v2_base_color.png'),check_existing=True);t=nt.nodes.new('ShaderNodeTexImage');t.image=img;t.label='Original 1024 Base Color';nt.links.new(t.outputs['Color'],p.inputs['Base Color'])
 rimg=bpy.data.images.load(os.path.join(TEX,'stallion_v2_roughness.png'),check_existing=True);rimg.colorspace_settings.name='Non-Color';r=nt.nodes.new('ShaderNodeTexImage');r.image=rimg;r.label='Original 1024 Roughness';nt.links.new(r.outputs['Color'],p.inputs['Roughness'])
 return m

def loft_body(paint):
 # 4.72 m long; angular cross sections form one continuous muscle-car lower shell.
 stations=[(-2.36,.78,.63),(-2.18,.94,.72),(-1.62,1.00,.88),(-.82,1.00,.94),(-.22,.98,.96),(.42,.99,.98),(1.20,1.00,.93),(1.78,.96,.86),(2.20,.89,.76),(2.36,.78,.68)]
 profile=[(-1,0),(-1,.42),(-.86,.78),(-.52,.94),(.52,.94),(.86,.78),(1,.42),(1,0),(.72,-.08),(-.72,-.08)]
 vs=[]
 for y,w,h in stations:
  for x,z in profile:vs.append((x*w,y,.38+z*h*.62))
 n=len(profile);fs=[]
 for s in range(len(stations)-1):
  for i in range(n):j=(i+1)%n;fs.append((s*n+i,s*n+j,(s+1)*n+j,(s+1)*n+i))
 fs += [tuple(range(n-1,-1,-1)),tuple((len(stations)-1)*n+i for i in range(n))]
 o=mesh_obj('Body_Continuous',vs,fs,paint,.025);mir=o.modifiers.new('Body_Mirror','MIRROR');mir.use_axis[0]=True;return o

def cabin(paint,glass):
 # Low, rearward trapezoidal greenhouse; no ellipsoids.
 y0,y1=-.22,1.55;z0,z1=.94,1.36;xb,xt=.80,.62
 vs=[(-xb,y0,z0),(xb,y0,z0),(-xb,y1,z0),(xb,y1,z0),(-xt,y0+.30,z1),(xt,y0+.30,z1),(-xt,y1-.24,z1),(xt,y1-.24,z1)]
 fs=[(0,1,5,4),(4,5,7,6),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
 mesh_obj('Cabin_Frame',vs,fs,paint,.018)
 quad_panel('Windshield',[(-.59,.075,1.335),(.59,.075,1.335),(.76,-.205,.98),(-.76,-.205,.98)],glass)
 quad_panel('Rear_Window',[(-.59,1.305,1.335),(-.75,1.535,.98),(.75,1.535,.98),(.59,1.305,1.335)],glass)
 for side in (-1,1):
  x=side*.805
  quad_panel('Side_Window_Front',[(x,-.12,.98),(x,.12,1.325),(x,.67,1.325),(x,.67,.98)],glass)
  quad_panel('Side_Window_Rear',[(x,.72,.98),(x,.72,1.325),(x,1.25,1.31),(x,1.48,.98)],glass)

def arch(name,side,yc,paint):
 # Integrated angular wheel-arch ribbon in the body side (y-z semicircle).
 seg=18;outer=.445;inner=.365;x0=side*.965;x1=side*1.015;vs=[]
 for x in (x0,x1):
  for r in (inner,outer):
   for i in range(seg+1):
    a=math.radians(8+164*i/seg);vs.append((x,yc-r*math.cos(a),.47+r*math.sin(a)))
 ring=seg+1;fs=[]
 for layer in range(2):
  off=layer*2*ring
  for i in range(seg):fs.append((off+i,off+i+1,off+ring+i+1,off+ring+i))
 for band in range(2):
  a=band*ring;b=2*ring+band*ring
  for i in range(seg):fs.append((a+i,b+i,b+i+1,a+i+1))
 return mesh_obj(name,vs,fs,paint,.012)

def wheel(root_name,x,y,rubber,alloy,steel):
 root=bpy.data.objects.new(root_name,None);bpy.context.collection.objects.link(root);root.location=(0,0,0)
 bpy.ops.mesh.primitive_torus_add(major_radius=.245,minor_radius=.105,major_segments=48,minor_segments=16,location=(x,y,.47));t=bpy.context.object;t.name=root_name+'_Tire';t.rotation_euler.y=math.pi/2;bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);t.scale.x=.28/.21;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);use(t,rubber);bevel(t,.006,1);t.parent=root
 def axle_cylinder(n,l,rad,dep,m,v):
  o=cyl(n,l,rad,dep,m,(0,0,0),v,root);o.rotation_euler.y=math.pi/2;bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);o.select_set(False);return o
 axle_cylinder(root_name+'_Rim',(x,y,.47),.235,.26,alloy,40);axle_cylinder(root_name+'_BrakeDisc',(x+(.012 if x>0 else -.012),y,.47),.17,.275,steel,32);axle_cylinder(root_name+'_Hub',(x+(.14 if x>0 else -.14),y,.47),.055,.035,steel,24)
 sx=x+(.14 if x>0 else -.14)
 for i in range(6):
  a=math.tau*i/6;cube(root_name+'_Spoke',(sx,y+.105*math.cos(a),.47+.105*math.sin(a)),(.012,.115,.025),alloy,.008,(a,0,0),root)
 for i in range(24):
  a=math.tau*i/24;cube(root_name+'_Tread',(x,y+.34*math.cos(a),.47+.34*math.sin(a)),(.135,.035,.014),rubber,.004,(a,0,0),root)
 return root

def car():
 clear();create_textures();paint=textured_paint();glass=mat('V2_Glass_Windshield',(.018,.035,.05),.05,.22);rubber=mat('V2_Rubber',(.008,.009,.008),0,.92);alloy=mat('V2_Alloy',(.19,.20,.21),.82,.28);steel=mat('V2_Steel',(.10,.11,.12),.88,.22);plastic=mat('V2_Plastic',(.016,.018,.019),0,.82);lamp=mat('V2_Lamp',(.78,.69,.48),.12,.20);red=mat('V2_Tail',(.45,.006,.004),.05,.28);cream=mat('V2_Livery_Cream',(.72,.49,.18),0,.58);dark=mat('V2_Door_Gap',(.015,.012,.01),0,.85);dust=mat('V2_Dust',(.24,.11,.035),0,.94)
 loft_body(paint);cabin(paint,glass)
 # Long hood, central ribs, short deck and integrated arches.
 cube('Hood_Plane',(0,-1.23,.985),(.91,.94,.028),paint,.018,(math.radians(-2),0,0));cube('Hood_Rib_L',(-.30,-1.28,1.025),(.035,.76,.025),paint,.012);cube('Hood_Rib_R',(.30,-1.28,1.025),(.035,.76,.025),paint,.012);cube('Hood_Scoop',(0,-1.34,1.08),(.30,.40,.09),plastic,.035,(math.radians(-3),0,0));cube('Rear_Deck',(0,1.84,.91),(.84,.36,.035),paint,.018)
 for side in (-1,1):
  arch('Front_Integrated_Arch',side,-1.41,paint);arch('Rear_Integrated_Arch',side,1.41,paint)
  # Door cut line is modeled as thin inset geometry, not a colored panel.
  x=side*1.002;cube('Door_Sill_Line',(x,.55,.55),(.007,.70,.009),dark,.003);cube('Door_Front_Gap',(x,-.16,.74),(.007,.008,.32),dark,.003,(math.radians(-8),0,0));cube('Door_Rear_Gap',(x,1.25,.73),(.007,.008,.31),dark,.003,(math.radians(7),0,0));cube('Door_Handle',(side*1.018,.84,.87),(.018,.105,.022),steel,.007)
  cube('Side_Skirt',(side*.98,.42,.40),(.040,1.23,.075),plastic,.018);cyl('Side_Exhaust',(side*.98,.80,.30),.045,1.15,steel,(math.pi/2,0,0),24);cube('Mudflap',(side*.94,1.84,.31),(.08,.025,.24),rubber,.012);cube('Mirror',(side*1.02,-.04,1.05),(.09,.12,.055),plastic,.025)
 cube('Front_Bumper',(0,-2.34,.55),(.94,.075,.105),plastic,.025);cube('Rear_Bumper',(0,2.31,.57),(.88,.075,.10),plastic,.025);cube('Grille',(0,-2.405,.76),(.57,.025,.17),dark,.015);cube('Skidplate',(0,-1.86,.27),(.70,.52,.035),steel,.012,(math.radians(7),0,0));cube('Spoiler',(0,2.10,.99),(.76,.19,.035),paint,.016)
 for x in (-.48,-.16,.16,.48):cyl('Auxiliary_Lamp',(x,-2.39,.79),.125,.08,lamp,(math.pi/2,0,0),28)
 for x in (-.68,.68):cube('Inset_Headlamp',(x,-2.39,.84),(.18,.025,.12),lamp,.018);cube('Rear_Lamp',(x,2.37,.77),(.19,.020,.085),red,.015)
 # Roll cage, towing hooks, antenna and original number plate.
 for x in (-.57,.57):cyl('Roll_Cage',(x,.58,1.12),.028,.66,steel,(0,0,0),16)
 cyl('Roll_Cage_Cross',(0,.58,1.30),.028,1.14,steel,(0,math.pi/2,0),16);cyl('Antenna',(0.52,1.47,1.56),.009,.45,steel,(0,0,0),10);cyl('Tow_Hook',(0,-2.38,.43),.055,.05,red,(math.pi/2,0,0),20)
 def seven_segment_number(side):
  x=side*1.031;segments={'a':(0,.105,True),'b':(.055,.052,False),'c':(.055,-.052,False),'d':(0,-.105,True),'e':(-.055,-.052,False),'f':(-.055,.052,False),'g':(0,0,True)}
  for digit,active,offset in [('6','afgecd',-.075),('5','afgcd',.075)]:
   for key in active:
    yy,zz,horizontal=segments[key];cube('Number_'+digit+'_'+key,(x,.58+offset+yy,.77+zz),(.006,.038,.010) if horizontal else (.006,.010,.040),dark,.003)
 for side in (-1,1):
  cube('Original_Livery_Stripe',(side*1.011,.48,.68),(.008,1.05,.055),cream,.005);cube('Race_Number_Plate',(side*1.020,.58,.77),(.008,.24,.17),cream,.005);seven_segment_number(side)
 wheels=[('Wheel_FL',-.88,-1.41),('Wheel_FR',.88,-1.41),('Wheel_RL',-.88,1.41),('Wheel_RR',.88,1.41)]
 for n,x,y in wheels:wheel(n,x,y,rubber,alloy,steel)
 # Dirt accents limited to lower body and rear.
 for side in (-1,1):cube('Lower_Dirt',(side*1.014,.25,.47),(.008,1.45,.035),dust,.004)
 cube('Rear_Dirt',(0,2.405,.63),(.66,.008,.035),dust,.004)
 os.makedirs(os.path.dirname(BLEND),exist_ok=True);os.makedirs(os.path.dirname(GLB),exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=BLEND);bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',export_apply=True,export_yup=True)

def irregular_rock(name,loc,scale,m,seed):
 random.seed(seed);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object;o.name=name
 for v in o.data.vertices:
  f=random.uniform(.72,1.20);v.co.x*=f*scale[0];v.co.y*=random.uniform(.78,1.12)*scale[1];v.co.z*=random.uniform(.70,1.22)*scale[2]
 use(o,m);bevel(o,.03,2);return o

def environment():
 clear();sand=mat('V2_Sand',(.30,.16,.065),0,.95);sand2=mat('V2_Sand_Dark',(.18,.085,.035),0,.97);road=mat('V2_Gravel_Road',(.12,.09,.065),0,.89);rock=mat('V2_Rock_Red',(.25,.075,.032),0,.90);rock2=mat('V2_Rock_Ochre',(.40,.16,.055),0,.93);green=mat('V2_Cactus',(.035,.12,.052),0,.88)
 # Gently varied terrain grid.
 N=18;size=24;vs=[]
 for j in range(N+1):
  y=-size/2+size*j/N
  for i in range(N+1):
   x=-size/2+size*i/N;z=-.08+.06*math.sin(x*.7)*math.cos(y*.45)+.018*random.random();vs.append((x,y,z))
 fs=[]
 for j in range(N):
  for i in range(N):a=j*(N+1)+i;fs.append((a,a+1,a+N+2,a+N+1))
 terrain=mesh_obj('Terrain_Varied',vs,fs,sand,.0);terrain.data.materials.append(sand2)
 for p in terrain.data.polygons:
  if random.random()<.18:p.material_index=1
 cube('Road_V2',(0,0,.035),(2.7,11.8,.045),road,.012)
 # Three genuinely irregular rocks plus scattered stones.
 irregular_rock('Rock_A',(-5.8,-1.8,.45),(1.4,1.0,.75),rock,11);irregular_rock('Rock_B',(5.3,1.5,.32),(.9,1.2,.55),rock2,22);irregular_rock('Rock_C',(4.6,-5.2,.25),(.65,.55,.42),rock,33)
 for i in range(28):irregular_rock('Small_Stone',(random.uniform(-8,8),random.uniform(-9,9),.03),(random.uniform(.05,.16),random.uniform(.05,.14),random.uniform(.03,.09)),rock2,100+i)
 # Deep canyon with front/back offsets, buttresses, ledges and a broken crest.
 xs=[-10,-8.4,-7,-5.5,-4,-2.4,-.8,.9,2.7,4.5,6.2,8];top=[3.1,4.4,3.7,5.0,4.0,4.75,3.6,4.6,3.8,4.9,3.5,4.1];front=[7.7,7.4,7.9,7.2,7.8,7.1,7.6,7.0,7.7,7.2,7.8,7.4];vs=[]
 for x,z,y in zip(xs,top,front):vs += [(x,y,0),(x,y,z)]
 for x,z,y in zip(xs,top,front):vs += [(x,y+2.2,0),(x,y+2.2,z*.88)]
 n=len(xs);fs=[]
 for layer in range(2):
  off=layer*n*2
  for i in range(n-1):a=off+i*2;fs.append((a,a+2,a+3,a+1) if layer==0 else (a+1,a+3,a+2,a))
 for i in range(n-1):a=i*2;b=2*n+i*2;fs += [(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)]
 wall=mesh_obj('Canyon_Deep',vs,fs,rock,.06);wall.location.y=2.5
 for i in range(7):irregular_rock('Canyon_Buttress',(-8+i*2.5,front[min(i+1,n-1)]-.5,1.25),(1.0,.75,1.8+random.random()*.6),rock2,300+i)
 # Organic tapered cactus with angled branches.
 def cone(n,l,r1,r2,d,r=(0,0,0)):
  bpy.ops.mesh.primitive_cone_add(vertices=18,radius1=r1,radius2=r2,depth=d,location=l,rotation=r);o=bpy.context.object;o.name=n;use(o,green);bevel(o,.025,2)
 cone('Cactus_Trunk',(-4.2,-4.5,1.15),.23,.13,2.3);cone('Cactus_Left',(-4.58,-4.5,1.18),.15,.10,.85,(0,math.radians(60),0));cone('Cactus_Left_Up',(-4.88,-4.5,1.55),.13,.07,.78);cone('Cactus_Right',(-3.85,-4.5,1.45),.14,.09,.68,(0,math.radians(-58),0));cone('Cactus_Right_Up',(-3.62,-4.5,1.78),.12,.065,.62)
 os.makedirs(os.path.dirname(ENV_BLEND),exist_ok=True);os.makedirs(os.path.dirname(ENV_GLB),exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=ENV_BLEND);bpy.ops.export_scene.gltf(filepath=ENV_GLB,export_format='GLB',export_apply=True,export_yup=True)

car();environment();print('VISUAL_PROTOTYPE_V2_BUILD_OK')
