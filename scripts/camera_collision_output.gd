extends Camera3D
## Runs after SpringArm3D has completed its collision sweep for this tick.
@onready var rig: Node3D = get_node("../../..")

func _physics_process(delta: float) -> void:
    rig.resolve_camera_distance(delta)
