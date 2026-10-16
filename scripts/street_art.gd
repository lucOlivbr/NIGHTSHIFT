extends Node3D
## Rua 01 / Cais Norte. Static art dressing only: no bodies, triggers or AI rules.
const CHARCOAL := Color("28383c")
const STEEL := Color("556467")
const PAPER := Color("c4bc9d")
const TEAL := Color("4b807b")
const RUST := Color("806347")
var mission: Node3D
var _materials: Dictionary = {}
var _city_materials: Dictionary = {}
var _batches: Dictionary = {}

func material(color: Color, glow := false) -> StandardMaterial3D:
    var key := str(color) + str(glow)
    if not _materials.has(key):
        var result := StandardMaterial3D.new()
        result.albedo_color = color
        result.roughness = 0.78
        if glow:
            result.emission_enabled = true
            result.emission = color
            result.emission_energy_multiplier = 0.7
        _materials[key] = result
    return _materials[key]

func box(size: Vector3, position: Vector3, color: Color, rotation := Vector3.ZERO, glow := false) -> void:
    var key := str(color) + str(glow)
    if not _batches.has(key):
        _batches[key] = {"material": material(color, glow), "transforms": []}
    _batches[key].transforms.append(Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), position))

func label(text: String, position: Vector3, yaw: float, font_size: int, pixel_size: float, color := PAPER, parent: Node = null) -> Label3D:
    var node := Label3D.new()
    node.text = text
    node.font_size = font_size
    node.pixel_size = pixel_size
    node.modulate = color
    node.outline_size = 0
    node.position = position
    node.rotation.y = yaw
    node.visibility_range_end = 36
    node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    (self if parent == null else parent).add_child(node)
    return node

func street_sign(text: String, position: Vector3, yaw: float, dimensions: Vector2, font_size := 46, color := PAPER) -> void:
    var basis := Basis(Vector3.UP, yaw)
    box(Vector3(dimensions.x + 0.12, dimensions.y + 0.12, 0.09), position, Color("17252b"), Vector3(0, yaw, 0))
    box(Vector3(dimensions.x, dimensions.y, 0.10), position, CHARCOAL, Vector3(0, yaw, 0))
    label(text, position + basis.z * 0.06, yaw, font_size, 0.008, color)

func _ready() -> void:
    name = "Rua01ArtDirection"
    _palette()
    # Static floor marks are placed on the actual road/curb height after sync.
    await get_tree().physics_frame
    _warehouse()
    _street_identity()
    _urban_details()
    _final_route_dressing()
    _flush_batches()

func _final_route_dressing() -> void:
    # Wayfinding follows the tested beginner approach and existing escape alley.
    street_sign("07  /  SERVIÇO  →", Vector3(-5.8, 2.55, -32.5), PI, Vector2(2.3, 0.55), 34, Color("d6b17c"))
    street_sign("ARMAZÉM 07  ←", Vector3(-7.4, 2.4, 38.7), PI, Vector2(2.6, 0.55), 37, Color("d6b17c"))
    street_sign("CAIS NORTE  ←\nATALHO DE SERVIÇO", Vector3(2, 2.8, 44.8), PI, Vector2(3.4, 0.95), 40, PAPER)
    street_sign("COMPANHIA DO CAIS\nENTREGAS / 24H", Vector3(37.78, 3.5, 56), -PI / 2, Vector2(4.5, 1.3), 43)
    street_sign("EXTRAÇÃO\nCAIS NORTE", Vector3(46, 3.1, 89.4), PI, Vector2(4.5, 1.4), 60, Color("d6c19b"))
    for x in [42.4, 49.6]:
        box(Vector3(0.14, 3.1, 0.14), Vector3(x, 1.4, 89.4), STEEL)
        box(Vector3(0.22, 0.35, 0.22), Vector3(x, 3.15, 89.4), Color("c6a16e"), Vector3.ZERO, true)
    _pool(Vector3(46, 4, 89), Vector3(46, -0.1, 86), Color("e3bd82"), 2.6, 8)
    # Shipping shelves stay against the far warehouse wall, clear of patrols.
    for z in [16.2, 18.2, 21.4]:
        for y in [0.4, 1.3, 2.2]:
            box(Vector3(0.26, 0.07, 1.35), Vector3(20.72, y, z), STEEL)
            box(Vector3(0.22, 0.45, 0.62), Vector3(20.72, y + 0.25, z - 0.2), Color("716452"))
        for end in [-0.7, 0.7]:
            box(Vector3(0.09, 2.6, 0.07), Vector3(20.72, 1.2, z + end), CHARCOAL)
    label("02 : 17  /  TURNO DA MADRUGADA", Vector3(20.85, 3.35, 18.6), -PI / 2, 30, 0.008, PAPER)
    label("07  /  RETIRADA", Vector3(18.3, 0.36, 19.83), PI, 28, 0.005, PAPER)
    for z in [-24, -12, 0, 12, 30]:
        var y := _ground(Vector3(-7.3, 0, z))
        box(Vector3(0.06, 0.008, 1.5), Vector3(-7.3, y + 0.009, z), Color("8f967f"))

func _palette() -> void:
    for node in get_parent().get_children():
        if not node.scene_file_path.ends_with(".gltf"):
            continue
        for mesh in node.find_children("*", "MeshInstance3D", true, false):
            for surface in mesh.mesh.get_surface_count():
                var original := mesh.get_active_material(surface) as StandardMaterial3D
                if original == null:
                    continue
                if not _city_materials.has(original):
                    var styled := original.duplicate() as StandardMaterial3D
                    # Source COLOR_0 contains saturated red paint/masks. Preserve
                    # geometry, textures, normals and original files; stop using
                    # that channel as visible albedo on local material copies.
                    styled.vertex_color_use_as_albedo = false
                    if original.resource_name == "MI_Asphalt":
                        styled.roughness = 0.28
                        styled.metallic = 0.08
                        styled.albedo_color = Color("889a9b")
                    elif node.scene_file_path.ends_with("Street_2Lane.gltf") and original.resource_name == "MI_Trim_MetalConcrete":
                        styled.albedo_color = Color("78817e")
                        styled.roughness = 0.58
                    if original.resource_name == "MI_FakeInterior_1":
                        styled.emission_enabled = true
                        styled.emission_texture = original.albedo_texture
                        styled.emission = Color("b68b58")
                        styled.emission_energy_multiplier = 0.5
                    elif original.resource_name == "MI_FakeInterior_3":
                        styled.emission_enabled = true
                        styled.emission_texture = original.albedo_texture
                        styled.emission = Color("487175")
                        styled.emission_energy_multiplier = 0.3
                    _city_materials[original] = styled
                mesh.set_surface_override_material(surface, _city_materials[original])
    var world = get_parent()
    var environment := world.get_node("NoirEnvironment").environment.duplicate() as Environment
    environment.background_color = Color("0d1b23")
    environment.ambient_light_color = Color("70958e")
    environment.ambient_light_energy = 0.30
    environment.fog_light_color = Color("183039")
    environment.fog_density = 0.008
    environment.fog_light_energy = 0.55
    world.get_node("NoirEnvironment").environment = environment
    world.get_node("MoonFill").light_energy = 0.24
    for light in world._street_lights:
        light.light_color = Color("efc18a")
        light.light_energy = 3.5
        light.spot_angle = 51

func _warehouse() -> void:
    for node in mission.get_children():
        if node is Label3D:
            node.text = ""
        elif node is MeshInstance3D and node.name.begins_with("Warehouse") and node != mission.shutter:
            node.material_override = material(Color("445356") if node.name.contains("Front") else Color("354449"))
        elif node is OmniLight3D:
            node.light_color = Color("e8c490")
            node.light_energy = 2.3
        elif node is MeshInstance3D and node.name.begins_with("CargoCover"):
            node.material_override = material(Color("514f42"))
            var dimensions: Vector3 = node.mesh.size
            var center: Vector3 = node.position
            # Slats and shipping marks stay inside the existing cover footprint.
            for height in [-0.33, -0.12, 0.09, 0.30]:
                box(Vector3(dimensions.x - 0.04, 0.018, dimensions.z + 0.005), center + Vector3.UP * height, Color("3d443f"))
            label("CAIS 07  /  CARGA", center + Vector3(0, -0.08, -dimensions.z * 0.5 - 0.01), PI, 23, 0.004, PAPER)
    mission.shutter.material_override = material(Color("566763"))
    # Shared ribs follow the actual shutter's visibility when it opens.
    var ribs := MultiMeshInstance3D.new()
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    var rib := BoxMesh.new()
    rib.size = Vector3(0.02, 0.028, 2.7)
    rib.material = material(Color("394d4c"))
    multimesh.mesh = rib
    multimesh.instance_count = 18
    for index in 18:
        multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(-0.09, -1.45 + index * 0.17, 0)))
    ribs.multimesh = multimesh
    ribs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mission.shutter.add_child(ribs)
    street_sign("07", Vector3(8.82, 2.43, 15.55), -PI / 2, Vector2(2.75, 2.6), 172)
    label("COMPANHIA DO CAIS", Vector3(8.75, 3.45, 15.55), -PI / 2, 22, 0.007, TEAL)
    label("ARMAZÉM  /  CARGA NOTURNA", Vector3(8.75, 1.38, 15.55), -PI / 2, 21, 0.006)
    street_sign("ACESSO RESTRITO", Vector3(8.82, 3.75, 18.55), -PI / 2, Vector2(2.75, 0.4), 27)
    box(Vector3(0.03, 0.13, 2.72), Vector3(8.72, 4.12, 18.55), Color("d5b27d"), Vector3.ZERO, true)
    box(Vector3(0.2, 0.65, 0.46), Vector3(8.69, 1.1, 17), CHARCOAL)
    box(Vector3(0.02, 0.06, 0.28), Vector3(8.57, 1.25, 17), Color("85aaa0"), Vector3.ZERO, true)
    label("07", Vector3(8.56, 1.02, 17), -PI / 2, 25, 0.006)
    # The old solid extraction rectangle becomes four short road-paint corners.
    mission.exit_marker.visible = false
    for x in [-3.3, 3.3]:
        for z in [-42.3, -37.7]:
            var y := _ground(Vector3(x, 0, z))
            box(Vector3(0.7, 0.008, 0.07), Vector3(x, y + 0.008, z), Color("7c8679"))
            box(Vector3(0.07, 0.008, 0.6), Vector3(x, y + 0.008, z + (0.25 if z < -40 else -0.25)), Color("7c8679"))
    # The objective remains a small hollow mark rather than a glowing disk.
    var ring := TorusMesh.new()
    ring.inner_radius = 0.16
    ring.outer_radius = 0.19
    ring.rings = 24
    ring.ring_segments = 6
    mission.entry_marker.mesh = ring
    mission.entry_marker.material_override = material(Color("688c7f"))
    mission.entry_marker.position.y = _ground(mission.entry_point) + 0.016
    mission.parcel.material_override = material(Color("99866b"))
    var strap := MeshInstance3D.new()
    var strap_mesh := BoxMesh.new()
    strap_mesh.size = Vector3(0.12, 0.404, 0.405)
    strap_mesh.material = material(PAPER)
    strap.mesh = strap_mesh
    mission.parcel.add_child(strap)
    label("07\nENTREGA", Vector3(-0.28, 0.02, 0), -PI / 2, 25, 0.003, Color("253735"), mission.parcel)
    street_sign("ENTREGAS\n07 — 18", Vector3(20.84, 2.5, 20.2), -PI / 2, Vector2(2.5, 0.85), 39)
    for z in [15.2, 21.8]:
        box(Vector3(2.2, 0.045, 0.1), Vector3(15, 4.55, z), Color("c6c3a0"), Vector3.ZERO, true)
    _pool(Vector3(8, 3.8, 18.5), Vector3(6, -0.1, 18.5), Color("e7c086"), 2.7, 9)
    _pool(Vector3(18.3, 3.7, 20.3), Vector3(18.3, 0.5, 20.3), Color("e9d3a9"), 2.4, 4.7)
    label("07", Vector3(15, 2.6, 14.12), 0, 190, 0.012, Color("889287"))
    label("COMPANHIA DO CAIS", Vector3(15, 1.52, 14.12), 0, 28, 0.006, Color("889287"))
    for x in [10.2, 19.9]:
        box(Vector3(0.055, 0.005, 7.3), Vector3(x, -0.144, 18.5), Color("746f54"))
    for x in [10.5, 12.5, 14.5, 16.5, 18.5, 20.5]:
        for z in [14.13, 22.87]:
            box(Vector3(0.045, 4.6, 0.05), Vector3(x, 2.3, z), Color("53615b"))

func _street_identity() -> void:
    street_sign("MARÉ", Vector3(-9.88, 3.15, -5.5), PI / 2, Vector2(3.1, 0.9), 92, Color("8ab3a5"))
    label("CAFÉ  /  ABERTO ATÉ TARDE", Vector3(-9.79, 2.53, -5.5), PI / 2, 26, 0.006)
    box(Vector3(0.11, 0.06, 3.2), Vector3(-9.69, 3.75, -5.5), Color("649e91"), Vector3.ZERO, true)
    _pool(Vector3(-9.2, 3.5, -5.5), Vector3(-7.5, 0, -5.5), Color("9fc6b0"), 1.9, 5)
    street_sign("RUA 01\nCAIS NORTE", Vector3(-4.88, 2.85, -35.8), 0, Vector2(1.25, 0.62), 33)
    street_sign("SAÍDA\nDO CAIS  →", Vector3(-4.65, 2.3, -40), 0, Vector2(1.8, 0.7), 38, Color("acbdb0"))
    box(Vector3(0.045, 2.9, 0.045), Vector3(-4.65, 1.3, -40), STEEL)
    street_sign("CARGA\nNOTURNA", Vector3(7.45, 2.3, 5.5), -PI / 2, Vector2(2.1, 1.15), 48)
    label("ENTRADA 07   →", Vector3(7.36, 1.46, 5.5), -PI / 2, 27, 0.007, TEAL)
    street_sign("DEPOIS\nDA MEIA-NOITE", Vector3(-9.91, 1.7, -31.5), PI / 2, Vector2(1.1, 1.6), 34, Color("d0b68a"))
    label("MARÉ  /  SESSÕES DE RUA", Vector3(-9.8, 1.05, -31.5), PI / 2, 14, 0.004)
    street_sign("LINHA 01", Vector3(-9.92, 1.9, -9), PI / 2, Vector2(0.65, 0.85), 20, Color("9ca99b"))
    for index in 7:
        # Sparse maintenance plates on the original posts, not world-space hints.
        z_plate(-5, 1.6, index * 12.0 - 36, "%02d" % (index + 1))

func z_plate(x: float, y: float, z: float, text: String) -> void:
    box(Vector3(0.21, 0.28, 0.025), Vector3(x, y, z + 0.078), CHARCOAL)
    label(text, Vector3(x, y, z + 0.094), 0, 18, 0.004)

func _urban_details() -> void:
    # Props hug existing walls; nothing adds collision or changes a cover route.
    for z in [-33.7, -8.6]:
        box(Vector3(0.58, 0.84, 0.65), Vector3(-9.32, 0.28, z), Color("344b49"))
        box(Vector3(0.66, 0.10, 0.71), Vector3(-9.3, 0.73, z), Color("485955"))
        box(Vector3(0.06, 0.13, 0.22), Vector3(-8.99, 0.40, z), Color("202d30"))
        for side in [-0.23, 0.23]:
            box(Vector3(0.1, 0.16, 0.11), Vector3(-9.32, -0.09, z + side), Color("1c2a2c"))
    for z in [-35, -10, 15]:
        box(Vector3(0.05, 3.0, 0.08), Vector3(-9.82, 1.35, z), STEEL)
        box(Vector3(0.22, 0.6, 0.45), Vector3(-9.7, 1.3, z - 0.5), CHARCOAL)
        for slat in 5:
            box(Vector3(0.024, 0.025, 0.34), Vector3(-9.575, 1.1 + slat * 0.08, z - 0.5), STEEL)
    for z in [-29, -5, 19, 31]:
        var x := 2.65 if z > 0 else -2.65
        var y := _ground(Vector3(x, 0, z)) + 0.005
        box(Vector3(0.62, 0.008, 0.35), Vector3(x, y, z), Color("182728"))
        for slot in 7:
            box(Vector3(0.025, 0.009, 0.3), Vector3(x - 0.25 + slot * 0.08, y + 0.005, z), STEEL)
    var random := RandomNumberGenerator.new()
    random.seed = 701
    for index in 12:
        var point := Vector3(random.randf_range(-4.5, 4.5), 0, random.randf_range(-35, 32))
        point.y = _ground(point) + 0.008
        box(Vector3(random.randf_range(0.09, 0.18), 0.002, random.randf_range(0.12, 0.25)), point, Color("7a7f70"), Vector3(0, random.randf_range(0, PI), 0))
    for point in [Vector3(-1.7, 0, -32), Vector3(0.4, 0, -8), Vector3(-2, 0, 11), Vector3(1.2, 0, 28)]:
        _puddle(point)
    var wire := ImmediateMesh.new()
    var dark := material(Color("17282b"))
    for z in [-16.0, 9.0, 34.0]:
        wire.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, dark)
        for index in 13:
            var t := float(index) / 12
            wire.surface_add_vertex(Vector3(lerpf(-10, 7.5, t), 7.5 - sin(t * PI) * 1.25, z + t * 0.9))
        wire.surface_end()
    var cables := MeshInstance3D.new()
    cables.mesh = wire
    cables.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(cables)

func _ground(point: Vector3) -> float:
    var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 2, 1)
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.position.y if not hit.is_empty() else -0.15

func _puddle(point: Vector3) -> void:
    point.y = _ground(point) + 0.004
    var vertices := PackedVector3Array()
    for index in 14:
        var a := float(index) / 14 * TAU
        var b := float(index + 1) / 14 * TAU
        var ra := 1 + 0.18 * sin(a * 5)
        var rb := 1 + 0.18 * sin(b * 5)
        vertices.append(Vector3.ZERO)
        vertices.append(Vector3(cos(b) * rb, 0, sin(b) * rb * 0.42))
        vertices.append(Vector3(cos(a) * ra, 0, sin(a) * ra * 0.42))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var normals := PackedVector3Array()
    normals.resize(vertices.size())
    normals.fill(Vector3.UP)
    arrays[Mesh.ARRAY_NORMAL] = normals
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var puddle := MeshInstance3D.new()
    puddle.mesh = mesh
    puddle.position = point
    var surface := material(Color("334545")).duplicate() as StandardMaterial3D
    surface.roughness = 0.12
    surface.metallic = 0.22
    puddle.material_override = surface
    puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(puddle)

func _pool(position: Vector3, target: Vector3, color: Color, energy: float, radius: float) -> void:
    var lamp := SpotLight3D.new()
    lamp.position = position
    lamp.light_color = color
    lamp.light_energy = energy
    lamp.spot_range = radius
    lamp.spot_angle = 48
    lamp.spot_attenuation = 1.0
    lamp.shadow_enabled = false
    lamp.distance_fade_enabled = true
    lamp.distance_fade_begin = 20
    lamp.distance_fade_length = 10
    add_child(lamp)
    var vertical := absf((target - position).normalized().dot(Vector3.UP)) > 0.98
    lamp.look_at(target, Vector3.FORWARD if vertical else Vector3.UP)

func _flush_batches() -> void:
    for key in _batches:
        var batch: Dictionary = _batches[key]
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        var cube := BoxMesh.new()
        cube.size = Vector3.ONE
        cube.material = batch.material
        multimesh.mesh = cube
        multimesh.instance_count = batch.transforms.size()
        for index in batch.transforms.size():
            multimesh.set_instance_transform(index, batch.transforms[index])
        var instance := MultiMeshInstance3D.new()
        instance.name = "StreetDetails"
        instance.multimesh = multimesh
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(instance)
