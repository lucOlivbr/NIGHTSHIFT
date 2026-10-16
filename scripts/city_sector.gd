extends Node3D
## Static city extension. Shared meshes/materials, batched details, existing lights budget.
const EXTRACTION := Vector3(46, -0.15, 87)
var batches: Dictionary = {}
var materials: Dictionary = {}
var solid: StaticBody3D
var world: Node3D

func _ready() -> void:
    name = "Setor02"
    world = get_parent()
    solid = StaticBody3D.new()
    solid.name = "UrbanCollision"
    add_child(solid)
    _roads()
    _blocks()
    _details()
    _flush()

func _material(color: Color) -> StandardMaterial3D:
    if not materials.has(color):
        var m := StandardMaterial3D.new()
        m.albedo_color = color
        m.roughness = 0.82
        if color == Color("303b40"):
            m.roughness = 0.28
            m.metallic = 0.08
        materials[color] = m
    return materials[color]

func box(size: Vector3, pos: Vector3, color: Color, collision := false, yaw := 0.0) -> void:
    if not batches.has(color):
        batches[color] = []
    batches[color].append(Transform3D(Basis(Vector3.UP,yaw).scaled(size),pos))
    if collision:
        var shape := CollisionShape3D.new()
        var geometry := BoxShape3D.new()
        geometry.size = size
        shape.shape = geometry
        shape.position = pos
        shape.rotation.y = yaw
        solid.add_child(shape)

func sign_text(text: String, pos: Vector3, yaw := PI, size := 36) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = pos
    label.rotation.y = yaw
    label.font_size = size
    label.pixel_size = 0.012
    label.modulate = Color("c9c5ac")
    label.outline_modulate = Color("15202a")
    label.visibility_range_end = 48
    add_child(label)

func _roads() -> void:
    # Every road top is -0.15, matching Rua 01. Crossings have no curb across lanes.
    box(Vector3(98,0.4,64),Vector3(23,-0.40,67),Color("242e32"),true)
    for spec in [[Vector3(10,0.12,54),Vector3(0,-0.21,66)],
            [Vector3(80,0.12,10),Vector3(20,-0.21,72)],
            [Vector3(10,0.12,52),Vector3(46,-0.21,67)],
            [Vector3(46,0.12,8),Vector3(23,-0.21,43)]]:
        box(spec[0],spec[1],Color("303b40"),true)
    # Low walks with generous open corners and dropped access to the alley.
    for x in [-6.5,6.5]:
        box(Vector3(3,0.12,24),Vector3(x,-0.09,55),Color("596363"),true)
    for z in [65.5,78.5]:
        box(Vector3(28,0.12,3),Vector3(26,-0.09,z),Color("596363"),true)
    for x in [39.5,52.5]:
        box(Vector3(3,0.12,15),Vector3(x,-0.09,54.5),Color("596363"),true)
        box(Vector3(3,0.12,12),Vector3(x,-0.09,87),Color("596363"),true)
    # Road markings stop before junctions.
    for z in [48,54,60,84,90]:
        box(Vector3(.12,.008,2),Vector3(0,-.145,z),Color("b0a88c"))
    for x in [-12,-6,10,16,22,28,34]:
        box(Vector3(2,.008,.12),Vector3(x,-.145,72),Color("b0a88c"))
    for z in [50,56,62,81]:
        box(Vector3(.12,.008,2),Vector3(46,-.145,z),Color("b0a88c"))
    for x in [-3,-1.8,-.6,.6,1.8,3]:
        box(Vector3(.65,.009,2.2),Vector3(x,-.144,65.8),Color("9fa798"))
    # Northern freight court: enough room to turn, exit painted onto existing floor.
    box(Vector3(24,.12,15),Vector3(46,-.21,88),Color("303b40"),true)
    box(Vector3(7,.015,5),Vector3(46,-.135,87),Color("476f75"))
    sign_text("SAÍDA / CAIS NORTE",Vector3(46,2.5,89))
    # Physical edges, never an invisible wall across the route.
    box(Vector3(98,1.1,.4),Vector3(23,.4,98),Color("56615f"),true)
    box(Vector3(.4,1.1,60),Vector3(71,.4,68),Color("56615f"),true)
    box(Vector3(.4,1.1,56),Vector3(-25,.4,70),Color("56615f"),true)

func building(asset: String, position: Vector3, yaw: float) -> void:
    world.asset(asset,position,1.0,yaw)
    var node := world.get_child(world.get_child_count()-1) as Node3D
    for mesh in node.find_children("*","MeshInstance3D",true,false):
        mesh.visibility_range_end = 95
        mesh.visibility_range_end_margin = 8

func _blocks() -> void:
    building("Building_Medium_2_001",Vector3(30,0,64),0)
    building("Building_Small_1",Vector3(61,0,52),PI)
    building("Building_Medium_2_001",Vector3(61,0,83),PI)
    building("Building_Small_1",Vector3(-16,0,88),0)
    # Taller workshop at the end of the west arm, doors facing the crossing.
    box(Vector3(18,5.5,10),Vector3(20,2.6,87),Color("414d4d"),true)
    box(Vector3(19,.3,11),Vector3(20,5.5,87),Color("273537"))
    for x in [15,23]:
        box(Vector3(5,3.6,.10),Vector3(x,1.65,81.94),Color("667373"))
        for y in [.4,1,1.6,2.2,2.8]:
            box(Vector3(5,.025,.12),Vector3(x,y,81.87),Color("3f4e52"))
    box(Vector3(10,.85,.15),Vector3(20,4.35,81.83),Color("283b3b"))
    sign_text("OFICINA NORTE / 24H",Vector3(20,4.35,81.72),PI,34)
    # Rooftop water tank, visible from both streets.
    var tank := MeshInstance3D.new()
    var geometry := CylinderMesh.new()
    geometry.top_radius = 1.7
    geometry.bottom_radius = 1.7
    geometry.height = 3.0
    geometry.radial_segments = 16
    tank.mesh = geometry
    tank.material_override = _material(Color("455459"))
    tank.position = Vector3(24,9,88)
    tank.visibility_range_end = 100
    add_child(tank)
    for x in [22.8,25.2]:
        for z in [86.8,89.2]:
            box(Vector3(.15,2,.15),Vector3(x,6.7,z),Color("313d42"))
    box(Vector3(3.8,.22,3.8),Vector3(24,7.6,88),Color("313d42"))

func lamp(pos: Vector3) -> void:
    box(Vector3(.16,5.8,.16),pos+Vector3(0,2.75,0),Color("424f50"),true)
    box(Vector3(.7,.14,.45),pos+Vector3(0,5.6,0),Color("b19d75"))
    var light := SpotLight3D.new()
    light.position = pos+Vector3(0,5.5,0)
    light.light_color = Color("efc18a")
    light.light_energy = 3.5
    light.spot_range = 14
    light.spot_angle = 55
    light.spot_attenuation = .8
    light.shadow_enabled = false
    light.distance_fade_enabled = true
    light.distance_fade_begin = 26
    light.distance_fade_length = 12
    add_child(light)
    light.look_at(pos+Vector3(2,-.15,1),Vector3.FORWARD)
    world._street_lights.append(light)

func _details() -> void:
    for p in [Vector3(-6,0,48),Vector3(-6,0,64),Vector3(12,0,78),Vector3(31,0,78),Vector3(52,0,68),Vector3(52,0,49),Vector3(52,0,87),Vector3(24,0,47)]:
        lamp(p)
    sign_text("RUA 01  /  CAIS NORTE →",Vector3(0,2.6,63),PI,32)
    sign_text("TRAVESSA DA OFICINA",Vector3(38,2.7,78),PI,28)
    sign_text("ATALHO / RUA 01 ←",Vector3(39,2.4,46.5),PI,26)
    sign_text("CAIS NORTE ↑",Vector3(6.2,1.9,41),-PI/2,26)
    # Peripheral crates/bins/bollards leave a >6 m skating corridor clear.
    for p in [Vector3(37,0,53),Vector3(37,0,57),Vector3(54,0,59),Vector3(54,0,85),Vector3(11,0,80),Vector3(29,0,81),Vector3(21,0,48)]:
        box(Vector3(1.4,1.1,1.1),p+Vector3(0,.4,0),Color("605747"),true)
        box(Vector3(1.43,.1,1.13),p+Vector3(0,.75,0),Color("899080"))
    for x in [9,11,29,31]:
        box(Vector3(.18,.85,.18),Vector3(x,.28,80),Color("a49a72"),true)
    # Wall-mounted service boxes and pipes facing the parallel road.
    for z in [52,56,60]:
        box(Vector3(.30,1.2,.8),Vector3(38,1.3,z),Color("626e6d"))
        box(Vector3(.12,4,.12),Vector3(37.8,2,z+1),Color("4b5858"))
    # Alley loading shelter with readable edge, outside the clear lane.
    box(Vector3(10,.15,2),Vector3(28,3.2,48.4),Color("344548"))
    for x in [23.3,32.7]:
        box(Vector3(.10,3.3,.10),Vector3(x,1.45,48),Color("58615c"),true)
    # Drain grilles, utility covers and asphalt repairs are flat visual details.
    for p in [Vector3(4,-.14,55),Vector3(42,-.14,59),Vector3(28,-.14,68),Vector3(19,-.14,43)]:
        box(Vector3(.7,.008,1.2),p,Color("17252a"))
        for d in [-.4,-.2,0,.2,.4]:
            box(Vector3(.65,.009,.035),p+Vector3(0,.004,d),Color("616b67"))
    for p in [Vector3(10,-.143,43),Vector3(45,-.143,55),Vector3(20,-.143,73)]:
        box(Vector3(2.7,.005,1.4),p,Color("29353b"))
    # Corner refuge: benches and a low planter, all outside racing lines.
    box(Vector3(5,.65,2.4),Vector3(-13,.175,63),Color("4a5754"),true)
    for x in [-14.5,-13,-11.5]:
        box(Vector3(.9,.6,.9),Vector3(x,.8,63),Color("334b41"))
    for x in [-12,-8]:
        box(Vector3(2,.15,.6),Vector3(x,.45,79),Color("79654e"),true)
        box(Vector3(2,.6,.12),Vector3(x,.75,79.3),Color("79654e"),true)

func _flush() -> void:
    for color in batches:
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = BoxMesh.new()
        mm.mesh.size = Vector3.ONE
        mm.instance_count = batches[color].size()
        for index in mm.instance_count:
            mm.set_instance_transform(index,batches[color][index])
        var node := MultiMeshInstance3D.new()
        node.multimesh = mm
        node.material_override = _material(color)
        add_child(node)
