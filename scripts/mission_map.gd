extends Control
var mission: Node3D
const EXTENT := Rect2(-27, -47, 102, 149)

func point(position: Vector3) -> Vector2:
    var uv := (Vector2(position.x, position.z) - EXTENT.position) / EXTENT.size
    return Vector2(14, 32) + uv * (size - Vector2(28, 54))

func _draw() -> void:
    if not is_instance_valid(mission):
        return
    draw_style_box(get_theme_stylebox("panel", "Panel"), Rect2(Vector2.ZERO, size))
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.055, 0.075, 0.95))
    draw_string(get_theme_default_font(), Vector2(12, 20), "RUA 01 + CAIS / NORTE ↓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d5d9d9"))
    for road in [Rect2(-4,-42,8,137), Rect2(-20,67,80,10), Rect2(41,39,10,56), Rect2(0,39,46,8)]:
        var a := point(Vector3(road.position.x,0,road.position.y))
        var b := point(Vector3(road.end.x,0,road.end.y))
        draw_rect(Rect2(a,b-a),Color("536064"))
    for block in [Rect2(22,51,16,14),Rect2(54,51,15,14),Rect2(54,82,15,13),Rect2(11,82,18,10)]:
        var a := point(Vector3(block.position.x,0,block.position.y))
        var b := point(Vector3(block.end.x,0,block.end.y))
        draw_rect(Rect2(a,b-a),Color("303b47"))
    draw_circle(point(mission.alternate_exit),7,Color("8eafc9"),false,1)
    var recommended: Array[Vector3] = [Vector3(-7.8,0,-37),Vector3(-7.8,0,38),Vector3(7.5,0,38),mission.entry_point]
    if mission.has_package:
        recommended = [mission.entry_point,Vector3(0,0,43),Vector3(46,0,43),mission.alternate_exit]
    var service_route := PackedVector2Array()
    for waypoint in recommended:
        service_route.append(point(waypoint))
    draw_polyline(service_route,Color("92b2a0"),1.2,true)
    for z in [-50, -25, 0, 25, 50]:
        for x in [-22.0, 7.5]:
            var a := point(Vector3(x, 0, z))
            var b := point(Vector3(x + (12.46 if x < 0 else 15), 0, z + 12))
            var bounds := Rect2(a, b - a).intersection(Rect2(8, 30, size.x - 16, size.y - 44))
            draw_rect(bounds, Color("303b47"))
    draw_rect(Rect2(point(Vector3(9, 0, 14)), point(Vector3(21, 0, 23)) - point(Vector3(9, 0, 14))), Color("536054"))
    for cover in mission.cover_positions:
        draw_circle(point(cover), 3.5, Color("aa8a60"))
    for guard in mission.guards:
        var center := point(guard.global_position)
        var color := Color("ff7768") if guard.state == "CHASE" else Color("e8b16b")
        draw_circle(center, 4, color)
        var forward: Vector3 = guard.global_position + guard.global_basis.z * 4
        draw_line(center, point(forward), color, 2)
    var objective: Vector3 = mission.alternate_exit if mission.has_package else (mission.package_point if mission.door_open else mission.entry_point)
    draw_circle(point(objective), 6, Color("77ddbf"), false, 2)
    draw_circle(point(mission.exit_point), 7, Color("8eafc9"), false, 1)
    var player_point := point(mission.player.global_position)
    draw_circle(player_point, 4, Color.WHITE)
    var facing: Vector3 = mission.player.global_position + Basis(Vector3.UP, mission.player.get_facing_yaw()) * Vector3.BACK * 3
    draw_line(player_point, point(facing), Color.WHITE, 2)
    draw_string(get_theme_default_font(), Vector2(12, size.y - 7), "● você  ● vigias  ○ objetivo", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c4d3da"))
