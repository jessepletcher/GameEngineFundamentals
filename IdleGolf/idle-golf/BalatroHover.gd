extends Control

## Balatro-style hover effect: idle bob, tilt on hover, scale punch on click

@export var bob_enabled := true
@export var bob_speed := 2.0
@export var bob_amount := 3.0  # pixels
@export var hover_scale := 1.08
@export var tilt_strength := 5.0  # degrees
@export var transition_speed := 8.0

var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _hovered := false
var _time := 0.0
var _target_scale := 1.0
var _target_rotation := 0.0

func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	mouse_entered.connect(func(): _hovered = true)
	mouse_exited.connect(func():
		_hovered = false
		_target_rotation = 0.0
	)
	pivot_offset = size / 2.0

func _process(delta: float) -> void:
	_time += delta

	# idle bob
	if bob_enabled:
		var bob = sin(_time * bob_speed) * bob_amount
		position.y = _base_position.y + bob

	# hover scale
	_target_scale = hover_scale if _hovered else 1.0
	var current_s = scale.x
	var new_s = lerp(current_s, _target_scale, delta * transition_speed)
	scale = Vector2(new_s, new_s)

	# tilt based on mouse position relative to center
	if _hovered:
		var center = global_position + size * 0.5
		var mouse_offset = get_global_mouse_position() - center
		var normalized_x = clamp(mouse_offset.x / (size.x * 0.5), -1.0, 1.0)
		_target_rotation = deg_to_rad(-normalized_x * tilt_strength)

	rotation = lerp(rotation, _base_rotation + _target_rotation, delta * transition_speed)
