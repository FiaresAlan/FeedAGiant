# prep_creature.py — Fase 2: prepara uma criatura para o Roblox (Blender sem interface).
#
# Uso:
#   blender -b --factory-startup -P tools/blender/prep_creature.py -- <entrada> <saida.glb> <preview.png>
#           [--tris 8000] [--height 6] [--tex 1024] [--yaw 0]
#
# O que faz (vault: "Retopology and Decimation", "Modeling Fundamentals for Games";
# skill fwjelaa-asset-import, tabela de orçamentos "Enemy (several on screen) 3k-10k, 512-1024"):
#   1. importa (glb/gltf/fbx/obj) e junta as malhas numa só (1 material, 1 UV: limite do Roblox);
#   2. "merge by distance" e decimação Collapse até o alvo de triângulos (busca binária na razão);
#   3. textura de cor reduzida (padrão 1024 px); normal/rugosidade/metal removidos: estilo pintado,
#      rugosidade 1, metal 0 (vault "Hand-Painted and Stylized Texturing");
#   4. escala para a altura alvo em studs (1 unidade = 1 stud), pés em Z = 0, centro em X/Y = 0,
#      frente para -Y (girar com --yaw se o modelo vier virado), transformações aplicadas;
#   5. exporta GLB (metros = studs no importador do Roblox) e uma prévia renderizada.
# Esqueleto e animações são preservados quando existem (troll, goblin). Malha que deforma deveria
# ser retopologizada (vault); a decimação aqui é a primeira versão e precisa de teste de pose.
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_png = argv[0], argv[1], argv[2]
opts = {"--tris": 8000, "--height": 6.0, "--tex": 1024, "--yaw": 0.0, "--merge": 0.0001}
for i, a in enumerate(argv):
    if a in opts:
        opts[a] = type(opts[a])(argv[i + 1])
TARGET = int(opts["--tris"]); HEIGHT = float(opts["--height"]); TEX = int(opts["--tex"]); YAW = float(opts["--yaw"])
# --merge: distância de solda RELATIVA à altura do modelo (0,0001 = 0,01%). Malhas com muitas
# peças soltas (troll) só reduzem depois de soldar as costuras.
MERGE = float(opts["--merge"])

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
meshes = [o for o in scene.objects if o.type == "MESH"]
arm = next((o for o in scene.objects if o.type == "ARMATURE"), None)
assert meshes, "sem malha"

# 1) uma malha só
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active

def tri_count(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    m = ev.to_mesh()
    n = sum(len(p.vertices) - 2 for p in m.polygons)
    ev.to_mesh_clear()
    return n

src_tris = tri_count(mesh)

# Malha inválida (o exportador do troll avisava "Mesh is not valid") atrapalha a decimação: valida e limpa.
mesh.data.validate(clean_customdata=False)
# Rig: no máximo 4 ossos por vértice, pesos normalizados (vault "Exporting FBX vs GLB" / "Rigging in Blender").
if arm is not None and mesh.vertex_groups:
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
# Shape keys impedem aplicar a decimação; criaturas do jogo não usam (só rig).
if mesh.data.shape_keys:
    mesh.shape_key_clear()

# 2) merge by distance + decimação até o alvo
# tamanho em coordenadas LOCAIS (a solda trabalha nelas; FBX pode trazer escala de objeto)
_xs = [v.co for v in mesh.data.vertices]
_h = max(max(c[i] for c in _xs) - min(c[i] for c in _xs) for i in range(3)) or 1.0
# --merge 0 pula a solda: no troll, soldar até vértices idênticos travava a redução em ~31 mil
if MERGE > 0:
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=MERGE * _h)
    bpy.ops.object.mode_set(mode="OBJECT")
# Com o modificador de armadura na pilha a decimação para cedo (medido no troll: piso de ~32 mil).
# Tira a armadura, decima a malha em pose de repouso (grupos de pesos ficam) e recoloca depois.
saved_arm = [m.object for m in mesh.modifiers if m.type == "ARMATURE"]
for m in [m for m in mesh.modifiers if m.type == "ARMATURE"]:
    mesh.modifiers.remove(m)
mod = mesh.modifiers.new("DecimateToBudget", "DECIMATE")
mod.decimate_type = "COLLAPSE"
mod.use_collapse_triangulate = True
lo, hi = 0.0, 1.0
for _ in range(18):
    mod.ratio = (lo + hi) / 2
    if tri_count(mesh) > TARGET:
        hi = mod.ratio
    else:
        lo = mod.ratio
mod.ratio = lo
bpy.ops.object.modifier_apply(modifier=mod.name)
for a in saved_arm:
    am = mesh.modifiers.new("Armature", "ARMATURE")
    am.object = a
final_tris = tri_count(mesh)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))

# 3) material simplificado: só a cor, textura reduzida
color_img = None
for slot in mesh.material_slots:
    mat = slot.material
    if not mat or not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        continue
    link = bsdf.inputs["Base Color"].links
    if link and link[0].from_node.type == "TEX_IMAGE":
        color_img = color_img or link[0].from_node.image
    for name in ("Normal", "Roughness", "Metallic", "Specular IOR Level", "Emission Color"):
        if name in bsdf.inputs:
            for l in list(bsdf.inputs[name].links):
                mat.node_tree.links.remove(l)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
if color_img and max(color_img.size) > TEX:
    color_img.scale(TEX, TEX)
# um material só (limite do Roblox): todos os slots passam a usar o primeiro
if len(mesh.material_slots) > 1:
    first = mesh.material_slots[0].material
    for s in mesh.material_slots:
        s.material = first

# 4) orientação, escala e pivô
root = arm if arm else mesh
if YAW:
    root.rotation_euler.z += math.radians(YAW)
bpy.context.view_layer.update()
def bounds():
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(deps)
    for v in ev.to_mesh().vertices:
        w = mesh.matrix_world @ v.co
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    ev.to_mesh_clear()
    return mn, mx
mn, mx = bounds()
k = HEIGHT / max(mx.z - mn.z, 1e-6)
root.scale = root.scale * k
bpy.context.view_layer.update()
mn, mx = bounds()
root.location -= Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
for o in scene.objects:
    if o.type in ("MESH", "ARMATURE"):
        o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mn, mx = bounds()

# 5) exporta GLB e prévia
os.makedirs(os.path.dirname(out_glb), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=out_glb,
    export_format="GLB",
    export_apply=True,
    export_animations=arm is not None,
    export_skins=arm is not None,
)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
center = (mn + mx) / 2
size = (mx - mn).length
# vista 3/4 de frente (a frente é -Y)
cam.location = center + Vector((size * 0.7, -size * 1.2, size * 0.45))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 4
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("w"); scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.4, 0.4, 0.45, 1); bg.inputs[1].default_value = 0.9
for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
scene.render.resolution_x = 480; scene.render.resolution_y = 480
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)

print("PREP_RESULT", {
    "fonte": os.path.basename(src), "tris_origem": src_tris, "tris_final": final_tris,
    "tamanho_studs": [round(mx[i] - mn[i], 2) for i in range(3)],
    "textura": (list(color_img.size) if color_img else None),
    "esqueleto": arm is not None, "acoes": [a.name for a in bpy.data.actions],
})
