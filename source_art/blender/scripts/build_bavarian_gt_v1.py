import bpy, math, os, random
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),"..","..",".."))
BLEND=os.path.join(ROOT,"source_art/blender/vehicles/bavarian_gt_r_v1.blend")
GLB=os.path.join(ROOT,"assets/models/vehicles/bavarian_gt_r_v1.glb")
random.seed(707)

def mat(n,c,metal=0,rough=.5):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
def finish(o,m,b=.015):
 o.data.materials.append(m)
 if b:
  q=o.modifiers.new('EdgeSoftness','BEVEL');q.width=b;q.segments=2;q.limit_method='ANGLE'
 for p in o.data.polygons:p.use_smooth=True
 return o
def cube(n,l,s,m,b=.015,r=(0,0,0),parent=None):
 bpy.ops.mesh.primitive_cube_add(location=l,rotation=r);o=bpy.context.object;o.name=n;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,m,b);o.parent=parent;return o
def cyl(n,l,rad,dep,m,r=(0,0,0),v=32,parent=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=rad,depth=dep,location=l,rotation=r);o=bpy.context.object;o.name=n;finish(o,m,.006);o.parent=parent;return o
def mesh(n,vs,fs,m,b=.01):
 me=bpy.data.meshes.new(n+'Mesh');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);return finish(o,m,b)
def clear():bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

paint=mat('GT_Paint_Ochre',(.34,.095,.025),.18,.38);carbon=mat('GT_Carbon',(.012,.014,.016),.15,.72);glass=mat('GT_Glass',(.012,.028,.045),.08,.18);rubber=mat('GT_Rubber',(.006,.007,.008),0,.92);alloy=mat('GT_Alloy',(.22,.23,.24),.84,.25);steel=mat('GT_Steel',(.10,.11,.12),.9,.25);lamp=mat('GT_Lamp',(.72,.70,.55),.12,.15);tail=mat('GT_Tail',(.52,.006,.003),.08,.24);accent=mat('GT_Accent',(.72,.28,.025),.15,.42);cabinmat=mat('GT_Cabin',(.018,.02,.021),0,.82)

def loft():
 # X width, Y length, Z height. Continuous compact fastback shell: 4.62 x 1.96 x 1.36 m.
 stations=[(-2.31,.70,.61),(-2.18,.93,.70),(-1.55,.98,.79),(-.72,.97,.86),(.10,.96,.91),(.92,.95,.88),(1.62,.91,.77),(2.18,.79,.66),(2.31,.65,.59)]
 profile=[(-1,.05),(-1,.40),(-.84,.72),(-.48,.91),(.48,.91),(.84,.72),(1,.40),(1,.05),(.70,-.06),(-.70,-.06)]
 vs=[]
 for y,w,h in stations:
  for x,z in profile:vs.append((x*w,y,.34+z*h*.64))
 n=len(profile);fs=[]
 for s in range(len(stations)-1):
  for i in range(n):j=(i+1)%n;fs.append((s*n+i,s*n+j,(s+1)*n+j,(s+1)*n+i))
 fs.extend([tuple(range(n-1,-1,-1)),tuple((len(stations)-1)*n+i for i in range(n))])
 return mesh('GT_Body_Continuous',vs,fs,paint,.025)

def panel(n,vs,m):return mesh(n,vs,[(0,1,2,3)],m,.004)
def arch(n,side,yc):
 seg=20;vs=[]
 for x in (side*.925,side*1.005):
  for r in (.355,.435):
   for i in range(seg+1):a=math.radians(8+164*i/seg);vs.append((x,yc-r*math.cos(a),.43+r*math.sin(a)))
 ring=seg+1;fs=[]
 for layer in range(2):
  off=layer*2*ring
  for i in range(seg):fs.append((off+i,off+i+1,off+ring+i+1,off+ring+i))
 for band in range(2):
  a=band*ring;b=2*ring+band*ring
  for i in range(seg):fs.append((a+i,b+i,b+i+1,a+i+1))
 return mesh(n,vs,fs,paint,.01)
def wheel(n,x,y):
 root=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(root)
 bpy.ops.mesh.primitive_torus_add(major_radius=.25,minor_radius=.105,major_segments=40,minor_segments=12,location=(x,y,.43),rotation=(0,math.pi/2,0));t=bpy.context.object;t.name=n+'_Tire';finish(t,rubber,.004);t.parent=root
 cyl(n+'_Rim',(x,y,.43),.225,.25,alloy,(0,math.pi/2,0),32,root);cyl(n+'_Hub',(x+(.14 if x>0 else -.14),y,.43),.052,.04,steel,(0,math.pi/2,0),20,root)
 sx=x+(.145 if x>0 else -.145)
 for i in range(8):
  a=math.tau*i/8;cube(n+'_Spoke',(sx,y+.105*math.cos(a),.43+.105*math.sin(a)),(.012,.115,.018),alloy,.004,(a,0,0),root)
 return root

clear();loft()
# Advanced low greenhouse and modeled glazing.
panel('GT_Windshield',[(-.68,-.45,.92),(.68,-.45,.92),(.55,.15,1.34),(-.55,.15,1.34)],glass)
panel('GT_Roof',[(-.55,.15,1.35),(.55,.15,1.35),(.54,1.08,1.29),(-.54,1.08,1.29)],paint)
panel('GT_RearGlass',[(-.54,1.08,1.29),(.54,1.08,1.29),(.70,1.62,.87),(-.70,1.62,.87)],glass)
for side in (-1,1):
 x=side*.91;panel('GT_SideGlass_F',[(x,-.37,.91),(x,.12,1.32),(x,.56,1.31),(x,.56,.91)],glass);panel('GT_SideGlass_R',[(x,.61,.91),(x,.61,1.30),(x,1.05,1.25),(x,1.48,.89)],glass)
 arch('GT_Arch_F',side,-1.42);arch('GT_Arch_R',side,1.43)
 cube('GT_Door_Sill',(side*.985,.42,.38),(.035,1.02,.07),carbon,.012);cube('GT_Door_FrontGap',(side*.993,-.37,.69),(.006,.008,.31),cabinmat,.002,(math.radians(-8),0,0));cube('GT_Door_RearGap',(side*.993,1.10,.68),(.006,.008,.30),cabinmat,.002,(math.radians(6),0,0));cube('GT_Door_Handle',(side*1.005,.66,.84),(.012,.10,.018),steel,.004)
 cube('GT_Mirror',(side*1.00,-.24,1.02),(.075,.12,.045),carbon,.018);cube('GT_Mudflap_F',(side*.93,-1.84,.28),(.065,.025,.20),rubber,.008);cube('GT_Mudflap_R',(side*.93,1.84,.28),(.065,.025,.20),rubber,.008)
cube('GT_Splitter',(0,-2.31,.25),(.91,.26,.035),carbon,.012);cube('GT_FrontBumper',(0,-2.25,.53),(.92,.11,.15),paint,.022);cube('GT_LowerIntake',(0,-2.37,.46),(.48,.025,.10),cabinmat,.012)
for x in (-.67,.67):cube('GT_Headlamp',(x,-2.34,.72),(.19,.025,.075),lamp,.012);cube('GT_TailLamp',(x,2.29,.71),(.20,.022,.065),tail,.01)
for x in (-.35,-.12,.12,.35):cyl('GT_AuxLamp',(x,-2.39,.66),.082,.055,lamp,(math.pi/2,0,0),24)
cube('GT_RearDiffuser',(0,2.29,.31),(.82,.22,.06),carbon,.012);cube('GT_WingBlade',(0,1.98,1.20),(.83,.22,.035),carbon,.012)
for x in (-.56,.56):cube('GT_WingStay',(x,1.93,1.02),(.025,.035,.18),steel,.006)
for x in (-.55,.55):cyl('GT_Rollbar_A',(x,.40,1.05),.025,.63,steel,(0,0,0),12);cyl('GT_Rollbar_B',(x,1.00,1.02),.025,.56,steel,(0,0,0),12)
cyl('GT_Rollbar_Cross',(0,.70,1.23),.025,1.10,steel,(0,math.pi/2,0),12)
for n,x,y in [('Wheel_FL',-.87,-1.42),('Wheel_FR',.87,-1.42),('Wheel_RL',-.87,1.43),('Wheel_RR',.87,1.43)]:wheel(n,x,y)
# Separate simplified collision proxy, disabled from render in Godot import by name convention.
proxy=cube('CollisionProxy',(0,0,.67),(.93,2.22,.48),cabinmat,0);proxy.display_type='WIRE';proxy.hide_render=True

# Consolidate static and per-wheel meshes by material while preserving pivots.
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

os.makedirs(os.path.dirname(BLEND),exist_ok=True);os.makedirs(os.path.dirname(GLB),exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND);bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',export_apply=True,export_yup=True)
deps=bpy.context.evaluated_depsgraph_get();tris=0
for o in bpy.context.scene.objects:
 if o.type=='MESH' and not o.hide_render:
  me=o.evaluated_get(deps).to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles);o.evaluated_get(deps).to_mesh_clear()
print('GT_BUILD_OK triangles=%d materials=%d dimensions=4.620x1.960x1.360 wheelbase=2.850' %(tris,len([m for m in bpy.data.materials if m.users])))
