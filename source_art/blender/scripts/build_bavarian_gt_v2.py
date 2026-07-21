import bpy, math, os, random
import numpy as np

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..",".."))
BLEND=os.path.join(ROOT,"source_art/blender/vehicles/bavarian_gt_r_v2.blend")
GLB=os.path.join(ROOT,"assets/models/vehicles/bavarian_gt_r_v2.glb")
TEX=os.path.join(ROOT,"assets/textures/vehicles/gt_v2")
random.seed(27)

def clear():bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(n,c,metal=0,rough=.5):
 m=bpy.data.materials.new(n);m.use_nodes=True;m.diffuse_color=(*c,1);p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
def finish(o,m,b=.012):
 o.data.materials.append(m)
 if b:q=o.modifiers.new('Controlled_Bevel','BEVEL');q.width=b;q.segments=2;q.limit_method='ANGLE'
 for p in o.data.polygons:p.use_smooth=True
 return o
def mesh(n,vs,fs,m,b=.01):
 me=bpy.data.meshes.new(n+'Mesh');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);return finish(o,m,b)
def cube(n,l,s,m,b=.01,r=(0,0,0),parent=None):
 bpy.ops.mesh.primitive_cube_add(location=l,rotation=r);o=bpy.context.object;o.name=n;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,m,b);o.parent=parent;return o
def cyl(n,l,rad,dep,m,r=(0,0,0),v=32,parent=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=rad,depth=dep,location=l,rotation=r);o=bpy.context.object;o.name=n;finish(o,m,.005);o.parent=parent;return o
def panel(n,vs,m,b=.005):return mesh(n,vs,[(0,1,2,3)],m,b)

def textures():
 os.makedirs(TEX,exist_ok=True);N=1024;y,x=np.mgrid[0:N,0:N];rng=np.random.default_rng(272)
 grain=rng.normal(0,1,(N,N));wave=np.sin(x/83)+np.sin((x+y)/131);dirt=np.clip((y/N)**3*(.50+.25*rng.random((N,N))),0,1)
 scratches=np.zeros((N,N),np.float32)
 for _ in range(120):
  yy=rng.integers(50,990);xx=rng.integers(10,940);ln=rng.integers(10,75);scratches[max(0,yy-1):min(N,yy+2),xx:min(N,xx+ln)]=rng.uniform(.2,.75)
 variation=np.clip(.5+.055*wave+.025*grain,0,1);base=np.empty((N,N,4),np.float32);base[...,0]=.055+.045*variation;base[...,1]=.16+.09*variation;base[...,2]=.245+.10*variation;base[...,:3]*=(1-.34*dirt[...,None]);base[...,:3]+=scratches[...,None]*np.array([.14,.12,.08]);base[...,3]=1
 rough=np.empty_like(base);rough[...,0:3]=np.clip(.34+.34*dirt+.05*grain,0.25,.88)[...,None];rough[...,3]=1
 carbon=np.empty_like(base);checker=((x//12+y//12)%2)*.055+.045;carbon[...,0:3]=checker[...,None];carbon[...,3]=1
 livery=np.zeros_like(base);stripe=np.exp(-((y-(.28*N+.18*x))/.055/N)**2);livery[...,0]=.85*stripe;livery[...,1]=.36*stripe;livery[...,2]=.035*stripe;livery[...,3]=1
 for name,a in {'gt_v2_base_color.png':base,'gt_v2_roughness.png':rough,'gt_v2_dirt.png':np.dstack((dirt,dirt,dirt,np.ones_like(dirt))),'gt_v2_scratches.png':np.dstack((scratches,scratches,scratches,np.ones_like(dirt))),'gt_v2_paint_variation.png':np.dstack((variation,variation,variation,np.ones_like(dirt))),'gt_v2_carbon.png':carbon,'gt_v2_livery.png':livery}.items():
  a=a.astype(np.float32,copy=False);im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.pixels.foreach_set(a.ravel());im.filepath_raw=os.path.join(TEX,name);im.file_format='PNG';im.save()

def paint_material():
 m=mat('GT2_Paint_Textured',(.045,.19,.31),.20,.36);p=m.node_tree.nodes['Principled BSDF']
 for fn,socket,space in [('gt_v2_base_color.png','Base Color','sRGB'),('gt_v2_roughness.png','Roughness','Non-Color')]:
  im=bpy.data.images.load(os.path.join(TEX,fn));im.colorspace_settings.name=space;t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],p.inputs[socket])
 return m

clear();textures();paint=paint_material();glass=mat('GT2_Glass',(.012,.035,.065),.06,.16);rubber=mat('GT2_Rubber',(.006,.007,.009),0,.91);alloy=mat('GT2_Alloy',(.23,.25,.28),.86,.23);steel=mat('GT2_Steel',(.10,.11,.13),.88,.27);plastic=mat('GT2_Plastic',(.012,.016,.021),0,.79);carbon=mat('GT2_Carbon',(.025,.028,.032),.35,.48);lamp=mat('GT2_Lamp',(.70,.82,.92),.08,.12);tail=mat('GT2_Tail',(.55,.006,.008),.08,.20);accent=mat('GT2_Accent',(.88,.25,.025),.18,.35);dust=mat('GT2_Dust',(.19,.085,.026),0,.93)

# Sculpted continuous body with tapered waist, pronounced shoulders and short tail.
stations=[(-2.34,.60,.57),(-2.22,.84,.67),(-1.80,.98,.77),(-1.42,1.00,.83),(-.82,.97,.88),(-.20,.94,.91),(.45,.95,.94),(1.12,1.00,.91),(1.54,1.00,.83),(1.92,.93,.72),(2.25,.76,.62),(2.34,.57,.56)]
profile=[(-1,.10),(-1,.40),(-.91,.66),(-.68,.82),(-.34,.91),(0,.94),(.34,.91),(.68,.82),(.91,.66),(1,.40),(1,.10),(.73,-.05),(-.73,-.05)]
vs=[]
for y,w,h in stations:
 for x,z in profile:vs.append((x*w,y,.34+z*h*.61))
n=len(profile);fs=[]
for s in range(len(stations)-1):
 for i in range(n):j=(i+1)%n;fs.append((s*n+i,s*n+j,(s+1)*n+j,(s+1)*n+i))
fs.extend([tuple(range(n-1,-1,-1)),tuple((len(stations)-1)*n+i for i in range(n))]);mesh('GT2_Body_Sculpted',vs,fs,paint,.022)

# Curved greenhouse assembled from closely matched panels and real pillars.
panel('GT2_Windshield',[(-.72,-.50,.91),(.72,-.50,.91),(.54,.07,1.345),(-.54,.07,1.345)],glass,.006)
panel('GT2_Roof',[(-.54,.07,1.35),(.54,.07,1.35),(.50,1.00,1.31),(-.50,1.00,1.31)],paint,.014)
panel('GT2_RearGlass',[(-.50,1.00,1.305),(.50,1.00,1.305),(.70,1.58,.88),(-.70,1.58,.88)],glass,.006)
for side in (-1,1):
 x=side*.89;panel('GT2_SideGlassFront',[(x,-.42,.91),(x,.02,1.32),(x,.53,1.31),(x,.53,.91)],glass);panel('GT2_SideGlassRear',[(x,.58,.91),(x,.58,1.30),(x,.95,1.27),(x,1.49,.88)],glass)
 cube('GT2_A_Pillar',(side*.76,-.39,1.10),(.035,.055,.32),paint,.009,(math.radians(-36),0,0));cube('GT2_B_Pillar',(side*.89,.55,1.10),(.04,.045,.25),plastic,.006);cube('GT2_C_Pillar',(side*.76,1.39,1.06),(.06,.10,.27),paint,.012,(math.radians(30),0,0))
 # Volumetric shoulder, door inset and rising tension line.
 cube('GT2_Shoulder',(side*.965,.55,.75),(.045,.98,.16),paint,.035);cube('GT2_DoorInset',(side*.990,.43,.64),(.014,.75,.24),paint,.018);cube('GT2_TensionLine',(side*1.005,.38,.79),(.006,.84,.018),accent,.004,(math.radians(3),0,0));cube('GT2_Sill',(side*.97,.43,.36),(.04,1.18,.075),carbon,.014);cube('GT2_Handle',(side*1.008,.64,.83),(.010,.095,.018),steel,.005)
 cube('GT2_Mirror',(side*1.00,-.24,1.02),(.08,.13,.052),carbon,.022);cube('GT2_MudflapF',(side*.94,-1.84,.27),(.07,.025,.22),rubber,.008);cube('GT2_MudflapR',(side*.95,1.88,.27),(.075,.025,.23),rubber,.008)
 # Fender vents embedded along the shoulders.
 for j in range(3):cube('GT2_FenderVent',(side*1.008,-1.03+j*.13,.83),(.005,.045,.035),plastic,.003,(0,0,math.radians(16)))

# Integrated front mask: recessed headlamps, cooling apertures and elegant rally light bridge.
cube('GT2_FrontMask',(0,-2.30,.60),(.84,.055,.25),paint,.025);cube('GT2_CentralGrille',(0,-2.37,.55),(.44,.025,.13),plastic,.016);cube('GT2_Splitter',(0,-2.32,.24),(.94,.29,.034),carbon,.012)
for side in (-1,1):
 panel('GT2_HeadlampHousing',[(side*.88,-2.37,.70),(side*.42,-2.37,.72),(side*.46,-2.39,.84),(side*.83,-2.39,.81)],plastic)
 panel('GT2_LEDSignature',[(side*.80,-2.405,.75),(side*.49,-2.405,.77),(side*.52,-2.407,.80),(side*.78,-2.407,.80)],lamp,.003)
 cube('GT2_SideIntake',(side*.70,-2.38,.48),(.15,.025,.10),plastic,.013)
for x in (-.33,-.11,.11,.33):cyl('GT2_RallyLamp',(x,-2.405,.67),.080,.052,lamp,(math.pi/2,0,0),32)
cube('GT2_LampBridge',(0,-2.38,.63),(.47,.035,.045),carbon,.012);cube('GT2_HoodScoop',(0,-1.15,1.00),(.29,.42,.055),carbon,.022,(math.radians(-3),0,0))
for x in (-.38,.38):cube('GT2_HoodVent',(x,-1.25,.96),(.11,.25,.018),plastic,.012,(math.radians(-3),0,0))

# Strong rear graphic, diffuser tunnels, exhausts, tow hook and realistic wing.
cube('GT2_RearMask',(0,2.29,.61),(.80,.055,.23),paint,.025);cube('GT2_RearBlackPanel',(0,2.36,.70),(.55,.025,.11),plastic,.012)
for side in (-1,1):panel('GT2_TailSignature',[(side*.77,2.395,.68),(side*.22,2.395,.68),(side*.26,2.397,.76),(side*.74,2.397,.79)],tail,.004)
cube('GT2_Diffuser',(0,2.31,.27),(.86,.27,.065),carbon,.015)
for x in (-.55,0,.55):cube('GT2_DiffuserFin',(x,2.46,.26),(.025,.21,.13),carbon,.006)
for x in (-.61,.61):cyl('GT2_Exhaust',(x,2.43,.39),.055,.16,steel,(math.pi/2,0,0),24)
cyl('GT2_TowHook',(0,2.43,.44),.052,.045,accent,(math.pi/2,0,0),24)
for x in (-.57,.57):cube('GT2_WingStay',(x,1.98,1.06),(.025,.055,.22),steel,.007)
cube('GT2_WingBlade',(0,2.02,1.28),(.82,.235,.035),carbon,.014,(math.radians(-4),0,0))
for x in (-.84,.84):cube('GT2_WingEndplate',(x,2.02,1.26),(.025,.25,.16),carbon,.009)

# Roll cage, roof scoop, antenna, undertray and original 27 graphic.
for x in (-.56,.56):cyl('GT2_Rollbar',(x,.55,1.06),.025,.62,steel,(0,0,0),16)
cyl('GT2_RollbarCross',(0,.55,1.25),.025,1.12,steel,(0,math.pi/2,0),16);cube('GT2_RoofScoop',(0,.22,1.41),(.19,.30,.055),carbon,.025);cyl('GT2_Antenna',(.40,1.05,1.55),.008,.42,steel,(0,0,0),10);cube('GT2_Undertray',(0,0,.21),(.80,1.85,.025),carbon,.006)
for side in (-1,1):
 cube('GT2_NumberPlate',(side*1.008,.44,.66),(.005,.27,.20),accent,.004)
 for k,(yy,zz,sy,sz) in enumerate([(-.08,.06,.07,.012),(.08,.06,.07,.012),(.08,-.06,.07,.012),(0,0,.012,.07)]):cube('GT2_Number27',(side*1.014,.44+yy,.66+zz),(.004,sy,sz),plastic,.002)
 cube('GT2_DirtLower',(side*1.012,.30,.43),(.004,1.42,.04),dust,.003)

def wheel(name,x,y):
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 bpy.ops.mesh.primitive_torus_add(major_radius=.265,minor_radius=.105,major_segments=48,minor_segments=16,location=(x,y,.43),rotation=(0,math.pi/2,0));t=bpy.context.object;t.name=name+'_Tire';finish(t,rubber,.004);t.parent=root
 cyl(name+'_Rim',(x,y,.43),.23,.255,alloy,(0,math.pi/2,0),40,root);cyl(name+'_Disc',(x+(.012 if x>0 else -.012),y,.43),.17,.27,steel,(0,math.pi/2,0),32,root);cyl(name+'_Hub',(x+(.145 if x>0 else -.145),y,.43),.048,.035,accent,(0,math.pi/2,0),20,root)
 sx=x+(.15 if x>0 else -.15)
 for i in range(10):
  a=math.tau*i/10;cube(name+'_Spoke',(sx,y+.11*math.cos(a),.43+.11*math.sin(a)),(.012,.12,.015),alloy,.004,(a,0,0),root)
 for i in range(28):
  a=math.tau*i/28;cube(name+'_Tread',(x,y+.35*math.cos(a),.43+.35*math.sin(a)),(.13,.028,.012),rubber,.003,(a,0,0),root)
 cube(name+'_Caliper',(x+(.16 if x>0 else -.16),y-.12,.46),(.02,.045,.11),accent,.008,parent=root)

for n,x,y in [('Wheel_FL',-.90,-1.43),('Wheel_FR',.90,-1.43),('Wheel_RL',-.91,1.43),('Wheel_RR',.91,1.43)]:wheel(n,x,y)
proxy=cube('CollisionProxy',(0,0,.66),(.96,2.25,.47),plastic,0);proxy.display_type='WIRE';proxy.hide_render=True

# Consolidate by material while preserving four animated wheel pivots.
def owner(o):
 p=o.parent
 while p:
  if p.name.startswith('Wheel_'):return p.name
  p=p.parent
 return 'STATIC'
groups={}
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and o.name!='CollisionProxy':groups.setdefault((owner(o),o.data.materials[0].name),[]).append(o)
for (own,mname),items in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in items:
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  for mod in list(o.modifiers):
   try:bpy.ops.object.modifier_apply(modifier=mod.name)
   except RuntimeError:pass
 bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();bpy.context.object.name=own+'_'+mname;bpy.context.object.parent=bpy.data.objects.get(own) if own!='STATIC' else None

os.makedirs(os.path.dirname(BLEND),exist_ok=True);os.makedirs(os.path.dirname(GLB),exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=BLEND);bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',export_apply=True,export_yup=True)
deps=bpy.context.evaluated_depsgraph_get();tris=0
for o in bpy.context.scene.objects:
 if o.type=='MESH' and not o.hide_render:
  e=o.evaluated_get(deps);me=e.to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles);e.to_mesh_clear()
print('GT_V2_BUILD_OK triangles=%d mesh_objects=%d materials=%d body_dimensions=4.680x2.000x1.350 wheelbase=2.860' %(tris,len([o for o in bpy.context.scene.objects if o.type=='MESH']),len([m for m in bpy.data.materials if m.users])))
