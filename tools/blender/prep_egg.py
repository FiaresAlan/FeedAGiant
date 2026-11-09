# prep_egg.py — prepara um ovo do pacote "50 Stylized Eggs" para o Roblox SEM mudar as cores.
#
# O pacote traz em cada .glb o ovo branco-base + a variante, com 3 a 24 materiais de cor lisa (sem
# textura, sem UV). No Roblox cada MeshPart tem 1 textura, então um ovo com 12 materiais viraria 12
# peças. Solução sem perda: PALETA. Cada material vira uma célula de cor numa imagem pequena e cada
# face recebe a UV do centro da sua célula. Resultado: 1 malha, 1 textura, cores originais exatas.
#
# Uso: blender -b --factory-startup -P tools/blender/prep_egg.py -- <entrada.glb> <saida.glb> <preview.png>
#      [--height 1.0]
# A licença do pacote proíbe redistribuir os arquivos: a saída fica em assets/optimized (local) e sobe
# ao Roblox como asset PRIVADO.
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_png = argv[0], argv[1], argv[2]
HEIGHT = 1.0
if "--height" in argv:
    HEIGHT = float(argv[argv.index("--height") + 1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
stem = os.path.splitext(os.path.basename(src))[0]
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# a variante é o objeto que NÃO é o ovo branco-base (exceto no próprio Egg_01)
keep = [o for o in meshes if not o.name.startswith("Egg_01_White")] or meshes[:1]
for o in list(bpy.context.scene.objects):
    if o not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
obj = keep[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# centraliza: base em z=0, centro em x/y=0, altura = HEIGHT
me = obj.data
xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
cx, cy, z0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
h = max(zs) - z0
k = HEIGHT / h
for v in me.vertices:
    v.co = Vector(((v.co.x - cx) * k, (v.co.y - cy) * k, (v.co.z - z0) * k))
obj.location = (0, 0, 0)

# paleta: 1 célula de 16 px por material, 8 por linha
mats = [s.material for s in obj.material_slots]
CELL, PER_ROW = 16, 8
rows = max(1, math.ceil(len(mats) / PER_ROW))
W, H = CELL * PER_ROW, CELL * max(rows, 1)
H = max(H, CELL)
img = bpy.data.images.new(f"{stem}_palette", W, H, alpha=False)
px = [0.0] * (W * H * 4)

def to_srgb(c):
    c = max(0.0, min(1.0, c))
    return c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055

def base_color(m):
    if m and m.node_tree:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            return list(bsdf.inputs["Base Color"].default_value)[:3]
    return list(m.diffuse_color)[:3] if m else [0.8, 0.8, 0.8]

centers = []
for i, m in enumerate(mats):
    col = [to_srgb(c) for c in base_color(m)]
    cxp, cyp = (i % PER_ROW) * CELL, (i // PER_ROW) * CELL
    for y in range(cyp, cyp + CELL):
        for x in range(cxp, cxp + CELL):
            j = (y * W + x) * 4
            px[j:j + 4] = [col[0], col[1], col[2], 1.0]
    centers.append(((cxp + CELL / 2) / W, (cyp + CELL / 2) / H))
img.pixels = px
img.filepath_raw = os.path.splitext(out_glb)[0] + "_palette.png"
img.file_format = "PNG"
img.save()

uv = me.uv_layers.new(name="UVMap")
for poly in me.polygons:
    u, v = centers[poly.material_index] if poly.material_index < len(centers) else (0.5, 0.5)
    for li in poly.loop_indices:
        uv.data[li].uv = (u, v)

# material único com a paleta, rugosidade alta, sem metal (estilo pintado do briefing)
mat = bpy.data.materials.new(f"{stem}_mat")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.8
bsdf.inputs["Metallic"].default_value = 0.0
me.materials.clear()
me.materials.append(mat)
for poly in me.polygons:
    poly.material_index = 0
obj.name = stem

tris = sum(len(p.vertices) - 2 for p in me.polygons)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_apply=True)

# prévia
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
bpy.context.scene.collection.objects.link(cam)
cam.location = Vector((HEIGHT * 1.6, -HEIGHT * 1.6, HEIGHT * 1.1))
cam.rotation_euler = (Vector((0, 0, HEIGHT * 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
bpy.context.scene.collection.objects.link(sun)
sun.rotation_euler = (0.8, 0.2, 0.6)
w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs[1].default_value = 1.2
s = bpy.context.scene
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        s.render.engine = eng
        break
    except TypeError:
        pass
s.render.resolution_x = s.render.resolution_y = 320
s.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print(f"[prep_egg] {stem}: {tris} tris, {len(mats)} cores -> paleta {W}x{H}")
