extends Node
## Simple arcade inertia on the existing CharacterBody; no extra rigid bodies.

@export var top_speed := 9.0
@export var push_acceleration := 3.8
@export var rolling_drag := 0.38
@export var foot_brake := 5.5
@export var hard_brake := 8.5
@export var grip := 5.0

var heading := PI
var lean := 0.0
var momentum := Vector3.ZERO

func start(current_velocity: Vector3, facing: float) -> void:
    momentum = current_velocity.limit_length(top_speed)
    heading = atan2(momentum.x, momentum.z) if momentum.length() > 0.4 else facing
    lean = 0.0

func drive(delta: float, steer: float, pushing: bool, braking: float, active_input: bool) -> Vector3:
    var speed := momentum.length()
    var turn_rate := lerpf(2.6, 1.45, clampf(speed / top_speed, 0.0, 1.0))
    heading = wrapf(heading - steer * turn_rate * clampf(speed / 1.2, 0.25, 1.0) * delta, -PI, PI)
    if not active_input:
        speed = move_toward(speed, 0.0, hard_brake * delta)
    elif braking > 0.0:
        speed = move_toward(speed, 0.0, braking * delta)
    elif pushing:
        speed = minf(top_speed, speed + push_acceleration * delta)
    else:
        speed = move_toward(speed, 0.0, (rolling_drag + 0.012 * speed * speed) * delta)
    var forward := Basis(Vector3.UP, heading) * Vector3.BACK
    var travel := forward
    if momentum.length() > 0.1:
        travel = momentum.normalized().slerp(forward, clampf(grip * delta, 0.0, 1.0)).normalized()
    momentum = travel * speed
    lean = lerpf(lean, -steer * clampf(speed / top_speed, 0.0, 1.0) * 0.14, 1.0 - exp(-8.0 * delta))
    return momentum

func reconcile(sliding_velocity: Vector3) -> void:
    # Commit the velocity remaining after collision; never restore speed lost to
    # a wall on the next tick. Head-on impacts stop; glancing hits slide along it.
    momentum = sliding_velocity.limit_length(top_speed)
    if momentum.length() < 0.005:
        momentum = Vector3.ZERO
