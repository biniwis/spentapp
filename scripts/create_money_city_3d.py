import bpy
import math

# Clear default scene
bpy.ops.wm.read_factory_settings(use_empty=True)

def create_mat(name, color, roughness=0.4, metallic=0.0, emission_color=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission_color:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission_color
                bsdf.inputs["Emission Strength"].default_value = emission_strength
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = emission_color
    return mat

# High-Fidelity Colors & Materials
mat_pedestal = create_mat("Pedestal", (0.04, 0.06, 0.09, 1.0), roughness=0.25, metallic=0.3)
mat_neon = create_mat("NeonRim", (1.0, 1.0, 1.0, 1.0), roughness=0.1, emission_color=(0.9, 0.98, 1.0, 1.0), emission_strength=15.0)
mat_grass = create_mat("Grass", (0.12, 0.48, 0.22, 1.0), roughness=0.75)
mat_road = create_mat("Road", (0.10, 0.12, 0.15, 1.0), roughness=0.85)
mat_road_lines = create_mat("RoadLines", (0.9, 0.9, 0.9, 1.0), roughness=0.5)

mat_brick_coffee = create_mat("CoffeeBrick", (0.62, 0.32, 0.18, 1.0), roughness=0.6)
mat_brick_nest = create_mat("NestBrick", (0.68, 0.24, 0.18, 1.0), roughness=0.6)
mat_boutique = create_mat("BoutiqueWall", (0.18, 0.24, 0.35, 1.0), roughness=0.45)
mat_residence = create_mat("ResidenceWall", (0.28, 0.26, 0.46, 1.0), roughness=0.4)
mat_roof_dark = create_mat("RoofDark", (0.12, 0.12, 0.15, 1.0), roughness=0.5)

mat_awning_cream = create_mat("AwningCream", (0.96, 0.94, 0.86, 1.0), roughness=0.6)
mat_awning_amber = create_mat("AwningAmber", (0.92, 0.46, 0.12, 1.0), roughness=0.6)
mat_window_glow = create_mat("WindowGlow", (1.0, 0.86, 0.50, 1.0), roughness=0.2, emission_color=(1.0, 0.82, 0.40, 1.0), emission_strength=12.0)

mat_water = create_mat("Water", (0.15, 0.62, 0.85, 0.9), roughness=0.08, metallic=0.4, emission_color=(0.1, 0.45, 0.75, 1.0), emission_strength=3.0)
mat_sand = create_mat("Sand", (0.78, 0.70, 0.52, 1.0), roughness=0.85)
mat_trunk = create_mat("Trunk", (0.38, 0.22, 0.12, 1.0), roughness=0.8)
mat_foliage_pink = create_mat("CherryBlossom", (0.96, 0.50, 0.70, 1.0), roughness=0.65)
mat_foliage_green = create_mat("TreeGreen", (0.14, 0.46, 0.20, 1.0), roughness=0.65)
mat_taxi_yellow = create_mat("TaxiYellow", (1.0, 0.80, 0.05, 1.0), roughness=0.25, metallic=0.2)
mat_car_black = create_mat("CarBlack", (0.05, 0.05, 0.05, 1.0), roughness=0.3)

def add_box(name, size, loc, mat, bevel=0.0, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = bevel
        bev.segments = 3
    obj.data.materials.append(mat)
    return obj

# 1. Base Pedestal with Neon Rim
add_box("BasePedestal", (12.0, 12.0, 1.2), (0, 0, -0.6), mat_pedestal, bevel=0.4)
add_box("NeonRim", (12.3, 12.3, 0.28), (0, 0, -1.0), mat_neon, bevel=0.12)
add_box("GrassSurface", (11.6, 11.6, 0.2), (0, 0, 0.1), mat_grass, bevel=0.1)

# 2. Paved Roads
add_box("RoadMainH", (11.6, 2.4, 0.22), (0, -0.6, 0.11), mat_road)
add_box("RoadMainV", (2.4, 11.6, 0.22), (0.2, 0, 0.11), mat_road)

# Road Dashes (White Markings)
for rx in [-4.5, -3.0, 2.5, 4.0]:
    add_box(f"RoadDashH_{rx}", (0.8, 0.15, 0.23), (rx, -0.6, 0.12), mat_road_lines)

# 3. The Coffee House (Back-Left)
coffee_x, coffee_y = -3.4, 3.2
add_box("Coffee_Body", (2.5, 2.3, 1.9), (coffee_x, coffee_y, 1.05), mat_brick_coffee, bevel=0.06)
add_box("Coffee_Roof", (2.7, 2.5, 0.4), (coffee_x, coffee_y, 2.15), mat_roof_dark, bevel=0.05)
# Striped Awning Segments
add_box("Coffee_Awning1", (2.1, 0.8, 0.12), (coffee_x, coffee_y - 1.25, 1.2), mat_awning_amber, rot=(math.radians(-15), 0, 0))
add_box("Coffee_Window", (1.8, 0.1, 1.0), (coffee_x, coffee_y - 1.16, 0.95), mat_window_glow)
add_box("Coffee_Chimney", (0.45, 0.45, 0.9), (coffee_x + 0.8, coffee_y + 0.6, 2.5), mat_brick_coffee)

# 4. The Nest Dining (Back-Right, 2-Story Luxury Bistro)
nest_x, nest_y = 3.3, 3.2
add_box("Nest_Floor1", (2.7, 2.7, 1.9), (nest_x, nest_y, 1.05), mat_brick_nest, bevel=0.06)
add_box("Nest_Floor2", (2.6, 2.6, 1.6), (nest_x, nest_y, 2.75), mat_brick_nest, bevel=0.06)
add_box("Nest_Roof", (2.8, 2.8, 0.35), (nest_x, nest_y, 3.68), mat_roof_dark, bevel=0.05)
add_box("Nest_Awning", (2.3, 0.75, 0.12), (nest_x, nest_y - 1.45, 1.2), mat_awning_cream, rot=(math.radians(-15), 0, 0))
add_box("Nest_WinF1", (2.0, 0.1, 0.9), (nest_x, nest_y - 1.36, 0.95), mat_window_glow)
add_box("Nest_WinF2", (2.0, 0.1, 0.8), (nest_x, nest_y - 1.31, 2.8), mat_window_glow)
add_box("Nest_Balcony", (2.2, 0.3, 0.1), (nest_x, nest_y - 1.35, 2.05), mat_roof_dark)

# 5. Boutique Shop (Right)
boutique_x, boutique_y = 4.3, -3.3
add_box("Boutique_Body", (2.3, 2.3, 2.1), (boutique_x, boutique_y, 1.15), mat_boutique, bevel=0.06)
add_box("Boutique_Roof", (2.5, 2.5, 0.35), (boutique_x, boutique_y, 2.32), mat_roof_dark, bevel=0.05)
add_box("Boutique_Window", (1.8, 0.1, 1.2), (boutique_x, boutique_y + 1.16, 0.95), mat_window_glow)
add_box("Boutique_Awning", (2.0, 0.7, 0.12), (boutique_x, boutique_y + 1.25, 1.3), mat_awning_cream, rot=(math.radians(15), 0, 0))

# 6. Residence Tower (Front-Center, Multi-Story Skyscraper)
tower_x, tower_y = 1.6, -3.3
add_box("Tower_Body", (2.1, 2.1, 4.4), (tower_x, tower_y, 2.3), mat_residence, bevel=0.06)
add_box("Tower_Roof", (2.3, 2.3, 0.4), (tower_x, tower_y, 4.65), mat_roof_dark, bevel=0.05)
for tz in [1.2, 2.3, 3.4]:
    add_box(f"Tower_Win_{tz}", (1.5, 0.1, 0.6), (tower_x, tower_y + 1.06, tz), mat_window_glow)

# 7. Savings Park (Left: Organic Pond & Blossom Forest)
park_x, park_y = -3.4, -3.3
bpy.ops.mesh.primitive_cylinder_add(radius=1.9, depth=0.15, location=(park_x, park_y, 0.22))
sand = bpy.context.active_object
sand.data.materials.append(mat_sand)

bpy.ops.mesh.primitive_cylinder_add(radius=1.55, depth=0.17, location=(park_x, park_y, 0.24))
water = bpy.context.active_object
water.data.materials.append(mat_water)

def add_tree(loc, is_blossom=False):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.11, depth=0.9, location=(loc[0], loc[1], loc[2] + 0.45))
    t = bpy.context.active_object
    t.data.materials.append(mat_trunk)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.65, subdivisions=2, location=(loc[0], loc[1], loc[2] + 1.2))
    f = bpy.context.active_object
    f.data.materials.append(mat_foliage_pink if is_blossom else mat_foliage_green)

add_tree((park_x - 1.4, park_y + 1.4, 0.2), is_blossom=True)
add_tree((park_x + 1.4, park_y + 1.4, 0.2), is_blossom=True)
add_tree((park_x - 1.5, park_y - 1.2, 0.2), is_blossom=False)
add_tree((park_x + 1.4, park_y - 1.2, 0.2), is_blossom=False)
add_tree((-5.1, 1.4, 0.2), is_blossom=False)
add_tree((5.1, 1.4, 0.2), is_blossom=False)

# 8. Yellow Taxi
add_box("Taxi_Body", (0.6, 1.2, 0.4), (0.2, 1.4, 0.42), mat_taxi_yellow, bevel=0.04)
add_box("Taxi_Roof", (0.5, 0.6, 0.25), (0.2, 1.35, 0.68), mat_taxi_yellow, bevel=0.03)

# 9. Lighting Setup
bpy.ops.object.light_add(type='SUN', location=(14, -14, 20))
sun = bpy.context.active_object
sun.data.energy = 6.5
sun.data.color = (1.0, 0.97, 0.92)

bpy.ops.object.light_add(type='POINT', location=(-3.4, 2.0, 2.8))
point_coffee = bpy.context.active_object
point_coffee.data.energy = 120.0
point_coffee.data.color = (1.0, 0.85, 0.45)

bpy.ops.object.light_add(type='POINT', location=(3.3, 2.0, 3.0))
point_nest = bpy.context.active_object
point_nest.data.energy = 120.0
point_nest.data.color = (1.0, 0.85, 0.45)

# 10. Camera Setup (Isometric 45-deg angle)
bpy.ops.object.camera_add(location=(22, -22, 18))
cam = bpy.context.active_object
cam.rotation_euler = (math.radians(58), 0, math.radians(45))
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 16.5
bpy.context.scene.camera = cam

# Render Settings
scene = bpy.context.scene
scene.render.resolution_x = 1080
scene.render.resolution_y = 1080
scene.render.film_transparent = True
scene.render.filepath = "/Users/bnymynwysmn/Desktop/אפליקציה תואר/כסף/assets/blender_rendered_city.png"

print("Rendering enhanced 3D diorama from Blender...")
bpy.ops.render.render(write_still=True)

# Export 3D Models
export_glb = "/Users/bnymynwysmn/Desktop/אפליקציה תואר/כסף/models/money_city.glb"
export_usdc = "/Users/bnymynwysmn/Desktop/אפליקציה תואר/כסף/models/money_city.usdc"
export_obj = "/Users/bnymynwysmn/Desktop/אפליקציה תואר/כסף/models/money_city.obj"

print("Exporting GLB...")
bpy.ops.export_scene.gltf(filepath=export_glb, export_format='GLB')

print("Exporting OBJ...")
try:
    bpy.ops.wm.obj_export(filepath=export_obj)
except Exception as e:
    print(f"OBJ export note: {e}")

print("Exporting USD...")
try:
    bpy.ops.wm.usd_export(filepath=export_usdc)
    print("USD exported successfully!")
except Exception as e:
    print(f"USD export note: {e}")

print("Blender 3D Enhanced City Complete!")
