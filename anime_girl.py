import bpy
import math
import os
import sys

output_path = "/home/user/test/anime_girl_render.png"

# Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for mesh in bpy.data.meshes:
    bpy.data.meshes.remove(mesh)

# ─── Materials ───────────────────────────────────────────────────────────────

def mat(name, color, roughness=0.5, metallic=0.0, emit=None, emit_strength=1.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    p = nodes.new('ShaderNodeBsdfPrincipled')
    p.inputs['Base Color'].default_value = (*color, alpha)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    if emit:
        try:
            p.inputs['Emission Color'].default_value = (*emit, 1.0)
            p.inputs['Emission Strength'].default_value = emit_strength
        except Exception:
            pass
    if alpha < 1.0:
        m.blend_method = 'BLEND'
        p.inputs['Alpha'].default_value = alpha
    links.new(p.outputs['BSDF'], out.inputs['Surface'])
    return m

skin     = mat("Skin",     (1.00, 0.83, 0.72), roughness=0.55)
lip      = mat("Lip",      (0.90, 0.35, 0.40), roughness=0.5)
hair     = mat("Hair",     (0.06, 0.03, 0.12), roughness=0.35)
hair2    = mat("HairShine",(0.25, 0.15, 0.35), roughness=0.2, metallic=0.1)
iris_l   = mat("IrisL",    (0.20, 0.55, 0.95), roughness=0.05, emit=(0.20,0.55,0.95), emit_strength=0.8)
iris_r   = mat("IrisR",    (0.20, 0.55, 0.95), roughness=0.05, emit=(0.20,0.55,0.95), emit_strength=0.8)
pupil_m  = mat("Pupil",    (0.01, 0.01, 0.03), roughness=0.02)
sclera   = mat("Sclera",   (0.98, 0.97, 0.96), roughness=0.5)
eyeline  = mat("Eyeline",  (0.02, 0.01, 0.04), roughness=0.3)
brow_m   = mat("Brow",     (0.07, 0.04, 0.13), roughness=0.6)
blush    = mat("Blush",    (1.00, 0.55, 0.55), roughness=0.9, emit=(1.0,0.6,0.6), emit_strength=0.3)
shirt    = mat("Shirt",    (0.95, 0.95, 1.00), roughness=0.7)
uniform  = mat("Uniform",  (0.18, 0.22, 0.58), roughness=0.65)
skirt    = mat("Skirt",    (0.18, 0.22, 0.58), roughness=0.65)
tie      = mat("Tie",      (0.85, 0.12, 0.20), roughness=0.5)
socks    = mat("Socks",    (0.96, 0.96, 0.98), roughness=0.8)
shoes    = mat("Shoes",    (0.08, 0.06, 0.10), roughness=0.4)
ribbon   = mat("Ribbon",   (0.85, 0.12, 0.20), roughness=0.5)
nail     = mat("Nail",     (0.95, 0.40, 0.55), roughness=0.2)
floor_m  = mat("Floor",    (0.82, 0.80, 0.88), roughness=0.85)
wall_m   = mat("Wall",     (0.88, 0.87, 0.92), roughness=0.9)
shine_m  = mat("Shine",    (1.0, 1.0, 1.0),   roughness=0.0, emit=(1,1,1), emit_strength=3.0)

# ─── Helper: add subdivided object ───────────────────────────────────────────

def subdiv(obj, levels=2):
    mod = obj.modifiers.new("Sub", 'SUBSURF')
    mod.levels = levels
    mod.render_levels = levels
    return obj

def add_sphere(loc, r=1.0, mat=None, scale=(1,1,1), name=""):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, radius=r, location=loc)
    o = bpy.context.active_object
    if name: o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if mat: o.data.materials.append(mat)
    subdiv(o, 1)
    return o

def add_cyl(loc, r, depth, mat=None, scale=(1,1,1), rot=(0,0,0), name=""):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    if name: o.name = name
    o.scale = scale
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    if mat: o.data.materials.append(mat)
    subdiv(o, 1)
    return o

def add_cone(loc, r1, r2, depth, mat=None, scale=(1,1,1), rot=(0,0,0), name=""):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc)
    o = bpy.context.active_object
    if name: o.name = name
    o.scale = scale
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    if mat: o.data.materials.append(mat)
    subdiv(o, 1)
    return o

# ─── Body proportions ────────────────────────────────────────────────────────
# Y = forward (camera direction), Z = up, X = right

# HEAD
add_sphere((0, 0, 1.72), r=0.50, mat=skin, scale=(1.00, 0.86, 1.05), name="Head")

# Cheeks (subtle blush discs)
for sx in [-1, 1]:
    add_sphere((sx*0.25, -0.42, 1.67), r=0.095, mat=blush, scale=(1.4, 0.15, 0.9), name=f"Blush{sx}")

# NECK
add_cyl((0, 0, 1.29), r=0.115, depth=0.30, mat=skin, name="Neck")

# TORSO – anime hourglass
add_sphere((0, 0, 0.95), r=1.0, mat=shirt, scale=(0.38, 0.28, 0.46), name="TorsoUpper")
add_sphere((0, 0, 0.64), r=1.0, mat=shirt, scale=(0.32, 0.25, 0.28), name="TorsoMid")
add_sphere((0, 0, 0.44), r=1.0, mat=uniform, scale=(0.40, 0.30, 0.20), name="TorsoLower")

# Collar
add_cyl((0, -0.07, 1.17), r=0.19, depth=0.06, mat=shirt, scale=(1,0.65,1), name="Collar")

# Tie
add_cone((0, -0.27, 1.06), r1=0.06, r2=0.025, depth=0.28, mat=tie,
         rot=(math.radians(10),0,0), name="Tie")

# Bust (subtle, school-girl proportions)
for sx in [-1, 1]:
    add_sphere((sx*0.15, -0.26, 1.00), r=0.10, mat=shirt, scale=(1.0, 0.6, 0.85), name=f"Bust{sx}")

# HIPS + PELVIS
add_sphere((0, 0, 0.30), r=1.0, mat=uniform, scale=(0.42, 0.30, 0.18), name="Hips")

# SKIRT – pleated cone approximation
add_cone((0, 0, 0.04), r1=0.52, r2=0.42, depth=0.50, mat=skirt, name="SkirtOuter")
add_cone((0, 0, 0.04), r1=0.46, r2=0.38, depth=0.45, mat=shirt, name="SkirtInner")

# ARMS
arm_configs = [
    # (side, shoulder_x, upper_y_offset)
    (-1, -0.46, 0),
    ( 1,  0.46, 0),
]
for sx, ax, _ in arm_configs:
    # Shoulder cap
    add_sphere((ax, 0, 1.02), r=0.10, mat=shirt, scale=(1,0.85,1), name=f"Shoulder{sx}")
    # Upper arm
    add_cyl((ax + sx*0.13, 0, 0.86), r=0.075, depth=0.36, mat=skin,
            rot=(0, sx*0.25, 0), name=f"UAarm{sx}")
    # Elbow
    add_sphere((ax + sx*0.24, 0, 0.72), r=0.075, mat=skin, name=f"Elbow{sx}")
    # Forearm
    add_cyl((ax + sx*0.30, 0, 0.56), r=0.060, depth=0.32, mat=skin,
            rot=(0, sx*0.15, 0), name=f"FAarm{sx}")
    # Wrist
    add_sphere((ax + sx*0.36, 0, 0.44), r=0.060, mat=skin, name=f"Wrist{sx}")
    # Hand (palm)
    add_sphere((ax + sx*0.40, -0.04, 0.36), r=0.068, mat=skin,
               scale=(0.9, 0.65, 0.75), name=f"Palm{sx}")
    # Fingers (simplified)
    for fi in range(4):
        fz = 0.28 - fi*0.015
        add_sphere((ax + sx*0.40, -0.06 - fi*0.02, fz), r=0.022, mat=skin,
                   scale=(0.6,0.7,1.5), name=f"Finger{sx}{fi}")
    # Nail
    for fi in range(4):
        fz = 0.265 - fi*0.015
        add_sphere((ax + sx*0.40, -0.09 - fi*0.02, fz), r=0.016, mat=nail,
                   scale=(0.7,0.3,1.2), name=f"Nail{sx}{fi}")

# LEGS
for sx in [-1, 1]:
    lx = sx * 0.20
    # Thigh
    add_cyl((lx, 0, -0.08), r=0.115, depth=0.44, mat=skin, name=f"Thigh{sx}")
    # Knee
    add_sphere((lx, 0, -0.33), r=0.105, mat=skin, name=f"Knee{sx}")
    # Shin
    add_cyl((lx, 0.01, -0.57), r=0.095, depth=0.44, mat=skin, name=f"Shin{sx}")
    # Ankle
    add_sphere((lx, 0.01, -0.80), r=0.085, mat=skin, name=f"Ankle{sx}")
    # Foot
    add_sphere((lx, 0.08, -0.88), r=0.085, mat=shoes, scale=(1.0, 1.9, 0.55), name=f"Foot{sx}")
    # Heel
    add_sphere((lx, -0.05, -0.86), r=0.072, mat=shoes, scale=(1.0,0.9,0.65), name=f"Heel{sx}")
    # Sock
    add_cyl((lx, 0.01, -0.68), r=0.098, depth=0.20, mat=socks, name=f"Sock{sx}")

# EARS
for sx in [-1, 1]:
    add_sphere((sx*0.49, -0.05, 1.70), r=0.072, mat=skin, scale=(0.35,0.75,1.0), name=f"Ear{sx}")

# ─── EYES ────────────────────────────────────────────────────────────────────
for sx in [-1, 1]:
    ex = sx * 0.175

    # Sclera (eye white)
    add_sphere((ex, -0.415, 1.725), r=0.092, mat=sclera,
               scale=(1.15, 0.22, 1.4), name=f"Sclera{sx}")
    # Iris
    add_sphere((ex, -0.424, 1.725), r=0.070, mat=iris_l if sx < 0 else iris_r,
               scale=(1.05, 0.18, 1.25), name=f"Iris{sx}")
    # Pupil
    add_sphere((ex, -0.432, 1.725), r=0.038, mat=pupil_m,
               scale=(0.90, 0.15, 0.95), name=f"Pupil{sx}")
    # Upper eyelid / eyeline
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.092, minor_radius=0.010,
        major_segments=32, minor_segments=8,
        location=(ex, -0.415, 1.725))
    lid = bpy.context.active_object
    lid.name = f"Eyelid{sx}"
    lid.scale = (1.15, 0.22, 1.40)
    bpy.ops.object.transform_apply(scale=True)
    lid.data.materials.append(eyeline)
    # Eye shine highlight
    add_sphere((ex + sx*0.028, -0.435, 1.752), r=0.016, mat=shine_m,
               scale=(1.0,0.5,1.2), name=f"Shine{sx}")
    add_sphere((ex - sx*0.012, -0.435, 1.737), r=0.009, mat=shine_m, name=f"Shine2{sx}")

# Eyebrows
for sx in [-1, 1]:
    add_sphere((sx*0.175, -0.430, 1.810), r=0.010, mat=brow_m,
               scale=(5.5, 0.4, 1.0), name=f"Brow{sx}")
    # Arch: inner end higher
    add_sphere((sx*0.095, -0.425, 1.822), r=0.008, mat=brow_m,
               scale=(2.0, 0.5, 1.0), name=f"BrowInner{sx}")

# NOSE – tiny elegant anime nose
add_sphere((0, -0.452, 1.648), r=0.026, mat=skin, scale=(0.7,0.4,0.55), name="Nose")
# Nostrils
for sx in [-1, 1]:
    add_sphere((sx*0.018, -0.454, 1.637), r=0.012, mat=skin,
               scale=(0.8,0.5,0.6), name=f"Nostril{sx}")

# MOUTH
add_sphere((0, -0.450, 1.595), r=0.010, mat=skin, scale=(5.0, 0.5, 1.0), name="UpperLip")
add_sphere((0, -0.449, 1.581), r=0.014, mat=lip, scale=(3.5, 0.45, 0.85), name="LowerLip")
# Lip gloss shine
add_sphere((0.018, -0.452, 1.578), r=0.006, mat=shine_m, scale=(1.5,0.4,0.8), name="LipShine")

# ─── HAIR ────────────────────────────────────────────────────────────────────

# Main hair volume (cap)
add_sphere((0, 0.04, 1.80), r=0.545, mat=hair, scale=(1.0, 0.96, 1.02), name="HairCap")

# Side long strands
for sx in [-1, 1]:
    add_cyl((sx*0.44, -0.05, 1.26), r=0.105, depth=0.92, mat=hair,
            scale=(1,0.50,1), rot=(sx*0.08, sx*0.05, 0), name=f"SideStrand{sx}")
    add_cone((sx*0.44, -0.06, 0.75), r1=0.105, r2=0.028, depth=0.35, mat=hair,
             scale=(1,0.50,1), rot=(sx*0.08, sx*0.04, 0), name=f"SideStrandTip{sx}")

# Back hair curtain (long)
add_cyl((0, 0.32, 0.72), r=0.48, depth=1.55, mat=hair,
        scale=(1, 0.25, 1), name="BackHair")
add_cone((0, 0.33, -0.12), r1=0.48, r2=0.05, depth=0.45, mat=hair,
         scale=(1, 0.25, 1), name="BackHairTip")

# Fringe / bangs – 7 cone spikes
bang_positions = [
    (-0.26, -0.46, 1.57), (-0.14, -0.47, 1.55), (0.0, -0.48, 1.54),
    ( 0.14, -0.47, 1.55), ( 0.26, -0.46, 1.57),
    (-0.38, -0.43, 1.62), ( 0.38, -0.43, 1.62),
]
bang_scales = [
    (0.8,0.22,1), (0.8,0.22,1), (0.8,0.22,1),
    (0.8,0.22,1), (0.8,0.22,1),
    (0.6,0.20,1), (0.6,0.20,1),
]
for (bx, by, bz), bsc in zip(bang_positions, bang_scales):
    tilt_x = math.radians(25 + abs(bx)*15)
    tilt_z = math.radians(-bx * 12)
    add_cone((bx, by, bz), r1=0.07, r2=0.01, depth=0.30, mat=hair,
             scale=bsc, rot=(tilt_x, 0, tilt_z), name=f"Bang{bx:.2f}")

# Ahoge (single cute cowlick)
add_cone((0.07, 0.02, 2.25), r1=0.03, r2=0.005, depth=0.22, mat=hair,
         rot=(math.radians(-30), math.radians(20), math.radians(15)), name="Ahoge")

# Hair ribbon / bow on side
bow_loc = (-0.40, -0.15, 2.00)
# Left lobe
add_sphere((-0.50, -0.15, 2.00), r=0.09, mat=ribbon, scale=(2.2,0.30,1.5), name="BowLeft")
# Right lobe
add_sphere((-0.30, -0.15, 2.00), r=0.09, mat=ribbon, scale=(2.2,0.30,1.5), name="BowRight")
# Center knot
add_sphere((-0.40, -0.16, 2.00), r=0.045, mat=ribbon, name="BowKnot")
# Ribbon tails
add_cone((-0.44, -0.14, 1.93), r1=0.025, r2=0.008, depth=0.14, mat=ribbon,
         rot=(math.radians(-25), 0, math.radians(15)), name="RibbonTail1")
add_cone((-0.36, -0.14, 1.93), r1=0.025, r2=0.008, depth=0.14, mat=ribbon,
         rot=(math.radians(-25), 0, math.radians(-15)), name="RibbonTail2")

# ─── SCHOOL UNIFORM DETAILS ───────────────────────────────────────────────────

# Jacket lapels
for sx in [-1, 1]:
    add_cone((sx*0.10, -0.27, 1.13), r1=0.06, r2=0.02, depth=0.22, mat=uniform,
             scale=(1.8, 0.28, 1), rot=(math.radians(15), 0, sx*math.radians(20)),
             name=f"Lapel{sx}")

# Buttons on shirt
for bz in [0.98, 0.87, 0.76]:
    add_sphere((0, -0.275, bz), r=0.012, mat=uniform, scale=(1,0.4,1), name=f"Button{bz:.2f}")

# Pocket on jacket breast
add_sphere((-0.22, -0.27, 0.96), r=0.045, mat=uniform, scale=(2.0,0.25,1.4), name="Pocket")

# Cuffs
for sx in [-1, 1]:
    ax = sx * 0.46
    add_cyl((ax + sx*0.30, -0.02, 0.65), r=0.065, depth=0.06, mat=uniform,
            rot=(0, sx*0.15, 0), name=f"Cuff{sx}")

# ─── SCENE ────────────────────────────────────────────────────────────────────

# Floor
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -1.0))
fl = bpy.context.active_object
fl.name = "Floor"
fl.data.materials.append(floor_m)

# Back wall
bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 2.5, 2.5))
wl = bpy.context.active_object
wl.name = "Wall"
wl.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.transform_apply(rotation=True)
wl.data.materials.append(wall_m)

# ─── CAMERA ──────────────────────────────────────────────────────────────────
bpy.ops.object.camera_add(location=(0.0, -3.2, 1.55))
cam = bpy.context.active_object
cam.name = "Camera"
cam.rotation_euler = (math.radians(82), 0, 0)
cam.data.lens = 55
bpy.context.scene.camera = cam

# ─── LIGHTS ───────────────────────────────────────────────────────────────────
# Key (warm)
bpy.ops.object.light_add(type='AREA', location=(2.2, -1.8, 3.2))
kl = bpy.context.active_object
kl.name = "KeyLight"
kl.data.energy = 450
kl.data.size = 2.5
kl.data.color = (1.0, 0.96, 0.88)
kl.rotation_euler = (math.radians(55), 0, math.radians(40))

# Fill (cool)
bpy.ops.object.light_add(type='AREA', location=(-2.0, -1.0, 2.0))
fl2 = bpy.context.active_object
fl2.name = "FillLight"
fl2.data.energy = 180
fl2.data.size = 3.0
fl2.data.color = (0.85, 0.90, 1.0)

# Rim / backlight
bpy.ops.object.light_add(type='SPOT', location=(0.0, 2.5, 3.5))
rl = bpy.context.active_object
rl.name = "RimLight"
rl.data.energy = 300
rl.data.spot_size = math.radians(40)
rl.data.color = (0.90, 0.85, 1.0)
rl.rotation_euler = (math.radians(-50), 0, 0)

# Hair light
bpy.ops.object.light_add(type='AREA', location=(0, 1.5, 3.0))
hl = bpy.context.active_object
hl.name = "HairLight"
hl.data.energy = 120
hl.data.size = 1.5
hl.data.color = (0.95, 0.92, 1.0)
hl.rotation_euler = (math.radians(-60), 0, 0)

# Ambient / bottom bounce
bpy.ops.object.light_add(type='AREA', location=(0, 0, -0.8))
al = bpy.context.active_object
al.name = "Ambient"
al.data.energy = 60
al.data.size = 6.0
al.data.color = (0.88, 0.88, 0.95)

# ─── WORLD ───────────────────────────────────────────────────────────────────
world = bpy.context.scene.world
world.use_nodes = True
bg = world.node_tree.nodes.get('Background') or world.node_tree.nodes.new('ShaderNodeBackground')
bg.inputs['Color'].default_value = (0.06, 0.06, 0.10, 1.0)
bg.inputs['Strength'].default_value = 0.4

# ─── RENDER ──────────────────────────────────────────────────────────────────
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.filepath = output_path
scene.render.image_settings.file_format = 'PNG'
scene.cycles.device = 'CPU'

print("=== Rendering anime girl... ===")
bpy.ops.render.render(write_still=True)
print(f"=== Done: {output_path} ===")
