extends RigidBody3D

signal landed(distance_yards: float)

var _start_z: float
var _has_landed := false
var _speed: float
var _spread: float
var _aim: float = 0.0  # -1.0 to 1.0
var _is_homing := false
var _target_flag: Node3D = null
var _has_peaked := false
var _homing_time := 0.0
var _launch_modifier := Vector2.ZERO  # x = curve, y = launch angle
@onready var sprite: Sprite3D = $Sprite3D
@onready var trail: GPUParticles3D = $GPUParticles3D

func launch(speed: float, angle_spread_deg: float, start_z: float) -> void:
    _start_z = start_z
    _speed = speed
    _spread = angle_spread_deg

func _physics_process(delta: float) -> void:
    if not _has_landed and global_position.y > 0.2:
        apply_central_force(Vector3(_curve * .5, 0, 0))
    
    # scale sprite
    var distance = abs(global_position.z - _start_z)
    var scale_factor = pow(distance * 0.05, 1.0)
    sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)
    
    # homing
    if _is_homing and _target_flag:
        _homing_time += delta
        _home_toward_flag(delta)
    
    if not _has_landed and global_position.y < 0.5 and abs(linear_velocity.y) < 2.0:
        _land()
        
func _start_homing() -> void:
    var flags = get_tree().get_nodes_in_group("flags")
    if flags.size() == 0:
        return

    # estimate landing Z based on current speed
    var forward_speed = abs(linear_velocity.z)
    var time_to_land = 0.0
    if linear_velocity.y > 0:
        time_to_land = (linear_velocity.y * 2.0) / 9.8
    var estimated_landing_z = global_position.z + forward_speed * time_to_land

    # sort flags by Z distance (furthest first)
    var sorted_flags = flags.duplicate()
    sorted_flags.sort_custom(func(a, b): return a.global_position.z > b.global_position.z)

    # pick the furthest flag the ball can realistically reach
    var best_flag: Node3D = null
    for flag in sorted_flags:
        if flag.global_position.z <= estimated_landing_z * 1.2:
            best_flag = flag
            break

    # fallback to closest flag if none are reachable
    if not best_flag:
        best_flag = sorted_flags[sorted_flags.size() - 1]

    _target_flag = best_flag
    _is_homing = true

func _home_toward_flag(delta: float) -> void:
    var flat_pos = Vector3(global_position.x, 0, global_position.z)
    var flat_target = Vector3(_target_flag.global_position.x, 0, _target_flag.global_position.z)
    var flat_dist = flat_pos.distance_to(flat_target)

    if flat_dist < 3.0:
        _is_homing = false
        _land()
        return

    # steer toward flag — starts gentle, gets stronger over time
    var direction = (flat_target - flat_pos).normalized()
    var current_flat_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
    var desired_vel = direction * current_flat_vel.length()
    var strength = clamp(_homing_time * 0.3, 0.05, 2.0)
    var steer = (desired_vel - current_flat_vel) * strength
    apply_central_force(steer)
    
func _ready() -> void:
    _start_z = global_position.z
    
    var ball_data = GameState.balls[GameState.equipped_ball]
    var mat = trail.draw_pass_1.material.duplicate()
    mat.albedo_color = ball_data["trail_color"]
    trail.draw_pass_1.material = mat
    var ball_speed_mult = ball_data["speed_mult"]
    
    var spread_rad = deg_to_rad(randf_range(-_spread, _spread))
    var aim_angle = _aim * deg_to_rad(45.0)
    var distance_mult = randf_range(1.0 - (1.0 / GameState.get_consistency()), 1.0)
    var horizontal_offset = abs(_launch_modifier.x)
    var distance_mult_from_curve = lerp(1.0, 0.5, horizontal_offset)
    var launch_angle = 0.38 + (_launch_modifier.y * -0.15)
    launch_angle = clamp(launch_angle, 0.1, 0.6)
    
    # convert flat yards to extra speed
    var flat_bonus = GameState.get_flat_distance()
    var curve = -_launch_modifier.x

    linear_velocity = Vector3(
        sin(aim_angle) * _speed * 0.5,
        _speed * launch_angle * ball_speed_mult,
        cos(aim_angle) * (_speed) * distance_mult * ball_speed_mult * distance_mult_from_curve + flat_bonus
    )
    
    # store curve for _process
    _curve = curve

    # start homing immediately if ball supports it
    if ball_data.get("can_home", false):
        _start_homing()

var _curve := 0.0

    
    # ... rest of your existing _process code
    
func _land() -> void:
    if _has_landed:
        return
    _has_landed = true
    var yards = (global_position.z - _start_z) * 1.094
    print(yards)
    landed.emit(abs(yards))
