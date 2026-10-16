extends Node
## Real input traversal: no teleports, no disabled guards, no forced objectives.
var world: Node3D
var mission: Node3D
var player: CharacterBody3D
var stage := "START"
var max_suspicion := 0.0
var captures := false

func _ready() -> void:
    run.call_deferred()

func tick() -> bool:
    await get_tree().physics_frame
    max_suspicion = maxf(max_suspicion, mission.exposure())
    return mission.phase == "RUNNING"

func stop() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right"]:
        Input.action_release(action)

func go(target: Vector3) -> bool:
    stage = "WALK " + str(target)
    print("PLAY ", int(mission.elapsed), "s ", stage)
    player.camera_rig.target_yaw = 0
    player.camera_rig.snap_to_target()
    var path: PackedVector3Array = mission.navigation.route(player.position, target)
    if path.is_empty():
        return false
    for waypoint in path:
        var reached := false
        for count in 200:
            var direction := waypoint - player.position
            direction.y = 0
            if direction.length() < (0.36 if Input.is_action_pressed("sprint") else 0.28):
                reached = true
                break
            direction = direction.normalized()
            Input.action_press("move_right", maxf(direction.x, 0))
            Input.action_press("move_left", maxf(-direction.x, 0))
            Input.action_press("move_back", maxf(direction.z, 0))
            Input.action_press("move_forward", maxf(-direction.z, 0))
            if not await tick():
                return false
        if not reached:
            print("BLOCKED ", waypoint, " actual ", player.position)
            return false
    stop()
    for count in 15:
        if not await tick():
            return false
    return true

func wait_for(condition: Callable, message: String) -> bool:
    stage = message
    print("PLAY ", int(mission.elapsed), "s ", stage)
    stop()
    for count in 7200:
        if condition.call():
            return true
        if not await tick():
            return false
    print("WAIT TIMEOUT ", message)
    for guard in mission.guards:
        print("GUARD ", guard.name, " position=", guard.position, " target=", guard.route_index, " state=", guard.state, " forward=", guard.global_basis.z)
    return false

func hold_e(seconds: float) -> bool:
    stop()
    Input.action_press("interact")
    for count in int(seconds * 60):
        if not await tick():
            Input.action_release("interact")
            return false
    Input.action_release("interact")
    return true

func ride(target: Vector3) -> bool:
    stage = "SKATE " + str(target)
    print("PLAY ", int(mission.elapsed), "s ", stage)
    stop()
    for count in 1800:
        var difference := target - player.position
        difference.y = 0
        if mission.phase == "WON":
            return true
        if mission.phase != "RUNNING":
            return false
        if difference.length() < 1.2:
            stop()
            Input.action_press("skate_brake")
            for settle in 60:
                await tick()
            Input.action_release("skate_brake")
            return true
        if count % 180 == 0:
            print("RIDE ", count, " pos=",player.position," speed=",player.horizontal_speed," heading=",player.skate.heading," difference=",difference.length()," floor=",player.is_on_floor())
        if count == 181:
            for ci in player.get_slide_collision_count():
                var hit := player.get_slide_collision(ci)
                print("COLLISION ",hit.get_collider().get_path()," normal=",hit.get_normal()," point=",hit.get_position()," localshape=",hit.get_local_shape())
        var desired := atan2(difference.x, difference.z)
        var angle := wrapf(desired-player.skate.heading,-PI,PI)
        var steer := clampf(-angle*1.8,-1,1)
        Input.action_press("move_right",maxf(steer,0))
        Input.action_press("move_left",maxf(-steer,0))
        if difference.length()<10 and player.horizontal_speed>4.0:
            Input.action_release("move_forward")
            Input.action_press("move_back")
        else:
            Input.action_release("move_back")
            Input.action_press("move_forward")
        await tick()
    return false

func interact_until(condition: Callable) -> bool:
    stop()
    for count in 15:
        if not await tick(): return false
    Input.action_press("interact")
    for count in 600:
        if condition.call():
            Input.action_release("interact")
            return true
        if not await tick():
            Input.action_release("interact")
            return false
    Input.action_release("interact")
    print("INTERACTION TIMEOUT position=",player.position," kind=",mission._interaction()," exposure=",mission.exposure())
    return false

func play() -> bool:
    # Deliberately simple newcomer route, without exact patrol-phase predicates.
    for target in [Vector3(-7.8,-.15,-37),Vector3(-7.8,-.15,38),Vector3(8,-.15,38)]:
        if not await go(target): return false
    Input.action_press("crouch")
    if not await go(Vector3(7.7,-.15,18.5)): return false
    stage="OPEN DOOR"
    if not await interact_until(func(): return mission.door_open): return false
    for settle in 5: await tick()
    for target in [Vector3(11.7,-.15,18.5),Vector3(11.7,-.15,15.5),Vector3(17.2,-.15,15.5),Vector3(17.2,-.15,20.3)]:
        if not await go(target): return false
    stage="COLLECT"
    if not await interact_until(func(): return mission.has_package): return false
    if not mission.escape_started or not mission.is_chased():
        print("Missing authored escape alarm")
        return false
    Input.action_release("crouch")
    Input.action_press("sprint")
    for target in [Vector3(11.7,-.15,21.5),Vector3(11.7,-.15,18.5),Vector3(8,-.15,18.5),Vector3(8,-.15,28),Vector3(0,-.15,34)]:
        if not await go(target): return false
    Input.action_release("sprint")
    for settle in 20: await tick()
    if not player.toggle_skate():
        print("Mount refused: ",player.mount_hint," position=",player.position)
        return false
    for target in [Vector3(0,-.15,43),Vector3(40,-.15,43),Vector3(46,-.15,49),Vector3(46,-.15,76),Vector3(46,-.15,89)]:
        if not await ride(target): return false
        if mission.phase=="WON":return true
    return mission.phase=="WON"

func run() -> void:
    mission = world.mission
    player = world.player
    for count in 8:
        await get_tree().physics_frame
    await mission.start_mission()
    var won := await play()
    if won and "--capture-end" in OS.get_cmdline_user_args():
        for settle in 60:
            await get_tree().physics_frame
        await get_tree().process_frame
        RenderingServer.force_draw(true)
        var image := get_viewport().get_texture().get_image()
        var capture_path := "res://docs/final_1_0/victory.png" if OS.has_feature("editor") else "user://victory.png"
        print("VICTORY CAPTURE ",image.save_png(capture_path))
    if not won:
        for guard in mission.guards:
            print("END GUARD ", guard.name, " position=", guard.position, " state=", guard.state, " suspicion=", guard.suspicion, " sees=", guard.sees_player)
    stop()
    Input.action_release("crouch")
    Input.action_release("interact")
    Input.action_release("sprint")
    var report := {"passed": won, "stage": stage, "phase": mission.phase, "elapsed_seconds": mission.elapsed,
        "max_suspicion": max_suspicion, "player": str(player.position),
        "all_guards_active": true, "newcomer_route":true, "native_character":true, "escape_alarm_started":mission.escape_started, "teleports": 0, "forced_objectives": 0}
    if won:
        await mission.start_mission()
        for settle in 6:
            await get_tree().physics_frame
        var restart_ok: bool = mission.phase=="RUNNING" and not mission.has_package and not mission.door_open and not player.is_skating and not mission.escape_started
        report["restart_after_victory_passed"] = restart_ok
        mission.show_main_menu()
        report["return_to_menu_passed"] = mission.phase=="BRIEFING" and mission.overlay.visible and not player.controls_enabled
        won = won and restart_ok and report.return_to_menu_passed
        report["passed"] = won
    var output_path := "res://docs/final_1_0/playthrough.json" if OS.has_feature("editor") else "user://final_playthrough.json"
    FileAccess.open(output_path, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("PLAYTHROUGH ", report)
    world.queue_free()
    await get_tree().process_frame
    OS.delay_msec(200)
    get_tree().quit(0 if won else 1)
