# rebake_creature.py — refaz uma criatura com aparência fiel ao original (correção de 08/11/2026).
#
# Problema (pedido do usuário: Troll, Hidra e Fênix "quebrados"): os originais têm 185 a 400 mil
# triângulos e eram reduzidos direto para 8 a 11 mil com a decimação Collapse. O troll é uma "sopa de
# triângulos" (15.831 pedaços soltos): sem solda, cada triângulo encolhe sozinho e a superfície vira
# cacos; penas/escamas soltas da Hidra e da Fênix também perdiam forma.
#
# Solução (vault "Retopology and Decimation": malha leve nova + bake da textura da alta):
#   1. importa o original (alta) e mede a altura;
#   2. cria a baixa a partir de uma cópia: Remesh por voxel (malha fechada, sem cacos), suaviza e
#      decima até o alvo (padrão 16 mil, abaixo do limite de 20 mil por MeshPart do Roblox);
#   3. abre UV nova (Smart UV Project) e faz bake da COR (Diffuse, só cor) da alta para a baixa no
#      Cycles, com distância de projeção relativa ao tamanho;
#   4. escala para a altura em studs, pés no chão, frente para -Y (--yaw), exporta GLB + prévia.
# Esqueleto: estas três criaturas são estáticas no jogo (sem rig no Roblox); o troll perde o rig de
# andar/correr do FBX, que o jogo não usava (as animações dos gigantes são procedurais, GiantAnim).
#
# Uso:
#   blender -b --factory-startup -P tools/blender/rebake_creature.py -- <entrada> <saida.glb> <preview.png>
#           [--tris 16000] [--height 6] [--tex 1024] [--yaw 0] [--voxel 0.006]
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_png = argv[0], argv[1], argv[2]
opts = {"--tris": 16000, "--height": 6.0, "--tex": 1024, "--yaw": 0.0, "--voxel": 0.006}
for i, a in enumerate(argv):
    if a in opts:
        opts[a] = type(opts[a])(argv[i + 1])
TARGET = int(opts["--tris"])
HEIGHT = float(opts["--height"])
TEX = int(opts["--tex"])
YAW = float(opts["--yaw"])
VOXEL_REL = float(opts["--voxel"])

bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(src)[1].lower()
if ext in (".glb", ".gltf"):
    bpy.ops.import_scene.gltf(filepath=src)
elif ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=src)
elif ext == ".obj":
    bpy.ops.wm.obj_import(filepath=src)
else:
    raise SystemExit("formato não suportado: " + ext)

scene = bpy.context.scene
for o in list(scene.objects):
    if o.type == "ARMATURE":
        # Aplica a pose de descanso nas malhas e remove o esqueleto (o jogo usa a criatura estática).
        for child in [c for c in scene.objects if c.type == "MESH"]:
            for m in list(child.modifiers):
                if m.type == "ARMATURE":
                    bpy.context.view_layer.objects.active = child
                    bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in scene.objects if o.type == "MESH"]
assert meshes, "sem malha"
for o in list(scene.objects):
    if o.type not in ("MESH",):
        bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
high = bpy.context.view_layer.objects.active
high.name = "HIGH"
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bbox(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def tri_count(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    me = ev.to_mesh()
    n = sum(len(p.vertices) - 2 for p in me.polygons)
    ev.to_mesh_clear()
    return n


mn, mx = bbox(high)
size = mx - mn
largest = max(size.x, size.y, size.z)
print("ALTA tris", tri_count(high), "tamanho", tuple(round(v, 3) for v in size))

# Material da alta: imagem de cor (base color) do original.
src_mat = high.active_material
src_img = None
if src_mat and src_mat.use_nodes:
    bsdf = next((n for n in src_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf and bsdf.inputs["Base Color"].is_linked:
        node = bsdf.inputs["Base Color"].links[0].from_node
        if node.type == "TEX_IMAGE":
            src_img = node.image
print("textura original:", src_img.name if src_img else None)

# 2) baixa: remesh por voxel + decimação
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
bpy.context.view_layer.objects.active = high
bpy.ops.object.duplicate()
low = bpy.context.view_layer.objects.active
low.name = "LOW"
low.data.materials.clear()
rm = low.modifiers.new("Remesh", "REMESH")
rm.mode = "VOXEL"
rm.voxel_size = largest * VOXEL_REL
rm.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier=rm.name)
print("remesh tris", tri_count(low))
dec = low.modifiers.new("Dec", "DECIMATE")
dec.decimate_type = "COLLAPSE"
current = tri_count(low)
dec.ratio = min(1.0, TARGET / max(current, 1))
bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.shade_smooth()
print("BAIXA tris", tri_count(low))

# 3) UV nova + bake da cor
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")

img = bpy.data.images.new("baked_color", TEX, TEX, alpha=False)
mat = bpy.data.materials.new("Baked")
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 1.0
bsdf.inputs["Metallic"].default_value = 0.0
nt.nodes.active = tex
low.data.materials.append(mat)

scene.render.engine = "CYCLES"
scene.cycles.samples = 1
scene.cycles.device = "CPU"
bake = scene.render.bake
bake.use_selected_to_active = True
bake.use_cage = False
bake.cage_extrusion = largest * 0.02
bake.max_ray_distance = largest * 0.06
bake.margin = 8
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
img.filepath_raw = os.path.splitext(out_glb)[0] + "_color.png"
img.file_format = "PNG"
img.save()
bpy.data.objects.remove(high, do_unlink=True)

# 4) escala, pés no chão, frente
low.rotation_euler[2] = math.radians(YAW)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
mn, mx = bbox(low)
k = HEIGHT / max(mx.z - mn.z, 1e-6)
low.scale = (k, k, k)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
mn, mx = bbox(low)
low.location -= Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_yup=True)
print("EXPORTADO", out_glb, "tris", tri_count(low))

# Prévia
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [
    e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "CYCLES"
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (HEIGHT * 1.1, -HEIGHT * 1.6, HEIGHT * 0.7)
direction = Vector((0, 0, HEIGHT * 0.45)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
light = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
light.data.energy = 4
light.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(light)
world = bpy.data.worlds.new("w")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[1].default_value = 1.0
scene.world = world
scene.render.resolution_x = 512
scene.render.resolution_y = 512
if scene.render.engine == "CYCLES":
    scene.cycles.samples = 16
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print("PREVIA", out_png)
