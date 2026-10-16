extends RefCounted
## Static collision grids: preserve original path choices inside Rua 01.
const ORIGIN := Vector2(-24.75, -45)
const CELL := 0.75
const SIZE := Vector2i(130, 193)
var grid := AStarGrid2D.new()
var original_grid := AStarGrid2D.new()
var expanded_grid: AStarGrid2D
var space: PhysicsDirectSpaceState3D
var probe := CapsuleShape3D.new()

func bake(world: Node3D) -> void:
    space = world.get_world_3d().direct_space_state
    grid = AStarGrid2D.new()
    grid.region = Rect2i(Vector2i.ZERO, SIZE)
    grid.cell_size = Vector2.ONE * CELL
    grid.offset = ORIGIN
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    original_grid.region = Rect2i(0,0,66,118)
    original_grid.cell_size = grid.cell_size
    original_grid.offset = ORIGIN
    original_grid.diagonal_mode = grid.diagonal_mode
    original_grid.update()
    probe.radius = 0.39
    probe.height = 1.6
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = probe
    query.collision_mask = 1
    for x in SIZE.x:
        for z in SIZE.y:
            var point := ORIGIN + Vector2(x, z) * CELL
            query.transform.origin = Vector3(point.x, 1.0, point.y)
            var blocked := not space.intersect_shape(query, 1).is_empty()
            grid.set_point_solid(Vector2i(x,z),blocked)
            if x<66 and z<118:
                original_grid.set_point_solid(Vector2i(x,z),blocked)
    expanded_grid = grid
    grid = original_grid

func cell(point: Vector3) -> Vector2i:
    var result := Vector2i(((Vector2(point.x, point.z) - ORIGIN) / CELL).round())
    return result.clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)

func nearest(point: Vector3) -> Vector2i:
    var center := cell(point)
    if not grid.is_point_solid(center):
        return center
    for radius in range(1, 7):
        var best := Vector2i(-1, -1)
        var distance := INF
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                var candidate := center + Vector2i(dx, dz)
                if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
                    continue
                var position := grid.get_point_position(candidate)
                var score := position.distance_squared_to(Vector2(point.x, point.z))
                if score < distance:
                    distance = score
                    best = candidate
        if best.x >= 0:
            return best
    return Vector2i(-1, -1)

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
    var old_bounds := Rect2(-24.75,-45,48.75,87.75)
    grid = original_grid if old_bounds.has_point(Vector2(from.x,from.z)) and old_bounds.has_point(Vector2(to.x,to.z)) else expanded_grid
    var start := nearest(from)
    var end := nearest(to)
    var result := PackedVector3Array()
    if start.x < 0 or end.x < 0:
        return result
    for point in grid.get_point_path(start, end):
        result.append(Vector3(point.x, -0.15, point.y))
    return result

func move_actor(body: CharacterBody3D, delta: float) -> void:
    # Guards need the same small curb clearance as the existing player.
    var horizontal := Vector3(body.velocity.x, 0, body.velocity.z) * delta
    if body.is_on_floor() and horizontal.length_squared() > 0.000001:
        # After a curb impact the slide velocity can be zero. Look ahead far
        # enough to reach the rounded contact instead of repeatedly testing only
        # the coplanar asphalt seam during the next acceleration frame.
        horizontal = horizontal.normalized() * maxf(horizontal.length(), 0.04)
        var query := PhysicsTestMotionParameters3D.new()
        query.from = body.global_transform
        query.motion = horizontal
        query.margin = 0.001
        var hit := PhysicsTestMotionResult3D.new()
        if PhysicsServer3D.body_test_motion(body.get_rid(), query, hit):
            query.motion = Vector3.UP * 0.22
            if not PhysicsServer3D.body_test_motion(body.get_rid(), query):
                query.from.origin += query.motion
                query.motion = horizontal
                if not PhysicsServer3D.body_test_motion(body.get_rid(), query):
                    query.from.origin += horizontal
                    query.motion = Vector3.DOWN * 0.24
                    if PhysicsServer3D.body_test_motion(body.get_rid(), query, hit):
                        var destination := query.from.origin + hit.get_travel()
                        var rise := destination.y - body.position.y
                        var walkable := hit.get_collision_normal().y > 0.7
                        if not walkable:
                            # A rounded capsule first touches the curb's edge,
                            # producing a diagonal normal even over a flat top.
                            var point := hit.get_collision_point() + horizontal.normalized() * 0.04
                            var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.05, point - Vector3.UP * 0.05, 1)
                            var surface := space.intersect_ray(ray)
                            walkable = not surface.is_empty() and surface.normal.y > 0.7
                        if walkable and rise > 0.005 and rise <= 0.221:
                            body.global_position = destination
                            body.velocity.y = 0
                            return
    body.move_and_slide()
