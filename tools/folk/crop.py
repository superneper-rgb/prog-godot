## Cuts one figure out of a concept sheet and enlarges it (nearest neighbour), to study a face or a costume closely.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/folk/crop.py -- <image> <x0> <y0> <x1> <y1> <scale> <out.png>
# Box in pixels, top-left origin, as in tools/folk/README.md's roster. Writes out.png (put it in F:/prog-godot-cache/folk/<id>/, never in the project).
import bpy, sys
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
src, x0, y0, x1, y1, scale, out = a[0], int(a[1]), int(a[2]), int(a[3]), int(a[4]), int(a[5]), a[6]
im = bpy.data.images.load(src)
W, H = im.size
px = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1]      # top row first
c = px[y0:y1, x0:x1]
c = np.repeat(np.repeat(c, scale, 0), scale, 1)
h, w = c.shape[:2]
o = bpy.data.images.new("o", w, h, alpha=True)
o.pixels[:] = c[::-1].ravel()
o.filepath_raw = out
o.file_format = "PNG"
o.save()
print("CROP", out, w, h)
