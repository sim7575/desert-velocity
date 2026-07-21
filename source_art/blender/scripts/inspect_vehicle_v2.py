import bpy
from mathutils import Vector

depsgraph=bpy.context.evaluated_depsgraph_get();triangles=0;mesh_objects=0
mins=Vector((1e9,1e9,1e9));maxs=Vector((-1e9,-1e9,-1e9))
body_mins=Vector((1e9,1e9,1e9));body_maxs=Vector((-1e9,-1e9,-1e9))
body_names={'Body_Continuous','Cabin_Frame','Hood_Plane','Rear_Deck','Front_Integrated_Arch','Rear_Integrated_Arch'}
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 mesh_objects+=1;e=obj.evaluated_get(depsgraph);me=e.to_mesh();me.calc_loop_triangles();triangles+=len(me.loop_triangles)
 for corner in e.bound_box:
  p=e.matrix_world@Vector(corner);mins.x=min(mins.x,p.x);mins.y=min(mins.y,p.y);mins.z=min(mins.z,p.z);maxs.x=max(maxs.x,p.x);maxs.y=max(maxs.y,p.y);maxs.z=max(maxs.z,p.z)
  if any(obj.name.startswith(n) for n in body_names):
   body_mins.x=min(body_mins.x,p.x);body_mins.y=min(body_mins.y,p.y);body_mins.z=min(body_mins.z,p.z);body_maxs.x=max(body_maxs.x,p.x);body_maxs.y=max(body_maxs.y,p.y);body_maxs.z=max(body_maxs.z,p.z)
 e.to_mesh_clear()
print('TRIANGLES='+str(triangles));print('MESH_OBJECTS='+str(mesh_objects));print('MATERIALS='+str(len([m for m in bpy.data.materials if m.users])));print('BODY_DIMS='+','.join(f'{v:.3f}' for v in (body_maxs.y-body_mins.y,body_maxs.x-body_mins.x,body_maxs.z-body_mins.z)));print('OVERALL_DIMS='+','.join(f'{v:.3f}' for v in (maxs.y-mins.y,maxs.x-mins.x,maxs.z-mins.z)))
for name in ('Wheel_FL','Wheel_FR','Wheel_RL','Wheel_RR'):
 root=bpy.data.objects.get(name);t=bpy.data.objects.get(name+'_Tire');print(f'{name}_ROOT={root is not None} TIRE_DIMS='+','.join(f'{v:.3f}' for v in t.dimensions))
print('WHEELBASE=2.820')
extents=[]
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':
  points=[obj.matrix_world@Vector(c) for c in obj.bound_box];extents.append((max(abs(p.x) for p in points),obj.name,min(p.x for p in points),max(p.x for p in points)))
for item in sorted(extents,reverse=True)[:10]:print('X_EXTENT='+str(item))
