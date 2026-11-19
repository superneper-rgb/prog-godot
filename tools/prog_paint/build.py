## Prog's model, step 1 without a live Blender: head_swap + limbs + jorts + tank + boots + glb_out in one headless run.
##   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/prog_paint/build.py -- <v1_original.glb> <prog3.glb> <out prog_head.glb>
import bpy, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import head_swap, limbs, jorts, tank, boots, glb_out

v1, v3, out = sys.argv[sys.argv.index("--") + 1:][:3]
for o in list(bpy.data.objects):
	bpy.data.objects.remove(o)
ob, info = head_swap.run(v1, v3, "Prog")
print("build: head", info)
print("build: limbs", limbs.run(ob, v1))
print("build: jorts", jorts.run(ob))
print("build: tank", tank.run(ob))
print("build: boots", boots.run(ob))
print("build: wrote", glb_out.write(ob, v1, out)["bytes"], "bytes")
