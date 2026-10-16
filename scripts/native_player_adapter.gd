extends "res://scripts/player_controller.gd"
## Character 2.2 adapter reused from character22_city: original gameplay physics.
## Native foot animation and one offline-authored, stable skate stance.
var _native_clip := ""
func _ready() -> void:
    var library := animation_player.get_animation_library("").duplicate(true) as AnimationLibrary
    animation_player.remove_animation_library("")
    animation_player.add_animation_library("",library)
    for pair in [["Run","Sprint"],["JumpStart","Jump_Start"],["JumpLoop","Jump"],["JumpLand","Jump_Land"]]:
        assert(library.has_animation(pair[1]), "Missing native clip " + pair[1])
        library.add_animation(pair[0],library.get_animation(pair[1]))
    for name in ["Idle","Walk","Run","Crouch_Idle","Crouch_Fwd","SkateCoast"]:
        assert(library.has_animation(name),"Missing native clip "+name)
        library.get_animation(name).loop_mode=Animation.LOOP_LINEAR
    animation_tree.active=false
    animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
    animation_player.active=true
    collider.shape=collider.shape.duplicate()
    var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
    assert(skeleton.get_bone_count()==53)
    skate_pose=preload("res://scripts/native_noop_modifier.gd").new()
    crouch_stance=preload("res://scripts/native_noop_modifier.gd").new()
    skeleton.add_child(skate_pose)
    skeleton.add_child(crouch_stance)
    skate_pose.influence=0
    crouch_stance.influence=0
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        mesh.extra_cull_margin=.35
        _meshes.append(mesh)
    board.visible=false
    camera_rig.snap_to_target()
    animation_player.play("Idle")
    _native_clip="Idle"
func reset_motion_state() -> void:
    super.reset_motion_state()
    animation_tree.active=false
    animation_player.active=true
    animation_player.speed_scale=1
    _native_clip=""
func set_gameplay_paused(paused: bool) -> void:
    super.set_gameplay_paused(paused)
    animation_tree.active=false
    animation_player.active=true
    animation_player.speed_scale=0 if paused else 1
func toggle_skate() -> bool:
    var changed := super.toggle_skate()
    if changed and get_parent().get("night_audio") != null:
        get_parent().night_audio.play_event("mount")
    return changed
func _set_air_state(state: String, _restart := false) -> void:
    _air_state=state
func _animate(delta: float) -> void:
    _takeoff_time=maxf(0,_takeoff_time-delta)
    _landing_time=maxf(0,_landing_time-delta)
    var clip := "Idle"
    var moving := horizontal_speed>.12
    if is_skating:
        clip="SkateCoast"
    elif not is_on_floor():
        clip="JumpStart" if _takeoff_time>0 else "JumpLoop"
    elif _landing_time>0:
        clip="JumpLand"
    elif is_crouching:
        clip="Crouch_Fwd" if moving else "Crouch_Idle"
    elif moving:
        clip="Run" if horizontal_speed>walk_speed+.6 else "Walk"
    if clip!=_native_clip:
        animation_player.play(clip,.12)
        _native_clip=clip
    locomotion_state="Skate" if is_skating else clip

