# front_view.py — prévia de FRENTE (câmera em -Y olhando +Y) para conferir a orientação.
# No Blender a frente do personagem é -Y; o importador do Roblox converte isso para a frente
# (LookVector) do modelo (skill fwjelaa-asset-import, "Characters face -Y in Blender").
# Uso: blender -b --factory-startup -P tools/blender/front_view.py -- <entrada.glb> <saida.png>
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
for o in scene.objects:
    if o.type == "MESH":
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
center = (mn + mx) / 2
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(mx.x - mn.x, mx.z - mn.z) * 1.15
scene.collection.objects.link(cam)
cam.location = Vector((center.x, mn.y - 20, center.z))
cam.rotation_euler = (math.radians(90), 0, 0)  # olha para +Y
scene.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 4
sun.rotation_euler = (math.radians(60), 0, math.radians(20))
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
scene.render.resolution_x = 320; scene.render.resolution_y = 320
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("FRONT_OK")
