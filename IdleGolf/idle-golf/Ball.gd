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
    var ball_data = GameState.balls[GameState.equipped_ball]
    if not _has_peaked and linear_velocity.y < 5.0:
       _has_peaked = true
       if ball_data.get("can_home", false):
           _start_homing()
    
    if _is_homing and _target_flag:
        _home_toward_flag(delta)
    
    if not _has_landed and global_position.y < 0.5 and abs(linear_velocity.y) < 2.0:
        _land()
        
func _start_homing() -> void:
    print("Starting homing")
    var flags = get_tree().get_nodes_in_group("flags")
    print("Flags found: ", flags.size())
    if flags.size() > 0:
        print("Nearest flag position: ", flags[0].global_position)
    var nearest: Node3D = null
    var nearest_dist = INF
    for flag in flags:
        var d = global_position.distance_to(flag.global_position)
        if d < nearest_dist:
            nearest_dist = d
            nearest = flag
    if nearest:
        _target_flag = nearest
        _is_homing = true
        print("Homing toward: ", nearest.global_position)
    else:
        print("No flag found to home toward")

func _home_toward_flag(delta: float) -> void:
    var flat_pos = Vector3(global_position.x, 0, global_position.z)
    var flat_target = Vector3(_target_flag.global_position.x, 0, _target_flag.global_position.z)
    var flat_dist = flat_pos.distance_to(flat_target)
    
    if flat_dist < 5.0:
        _is_homing = false
        _land()
        return
    
    var direction = (flat_target - flat_pos).normalized()
    # speed needed to reach flag in 1 second, clamped so it doesnt go crazy
    var needed_speed = clamp(flat_dist, 5.0, 50.0)
    linear_velocity.x = direction.x * needed_speed
    linear_velocity.z = direction.z * needed_speed
    
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

var _curve := 0.0

    
    # ... rest of your existing _process code
    
func _land() -> void:
    if _has_landed:
        return
    _has_landed = true
    var yards = (global_position.z - _start_z) * 1.094
    print(yards)
    landed.emit(abs(yards))
