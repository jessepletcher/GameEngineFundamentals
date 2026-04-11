extends Node3D

@export var texture: Texture2D
@export var flip_h: bool = false
@export var pixel_offset: Vector2 = Vector2(0, -12)
@export var sprite_scale: float = 1.0

## Animation settings
@export var animated: bool = false
@export var spritesheet: Texture2D  # spritesheet texture (overrides texture when animated)
@export var h_frames: int = 1  # columns in the spritesheet
@export var v_frames: int = 1  # rows in the spritesheet
@export var total_frames: int = 0  # total frames to use (0 = use all h_frames * v_frames)
@export var fps: float = 8.0  # animation speed
@export var loop: bool = true

@onready var sprite: Sprite3D = $Sprite3D
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var _anim_time := 0.0
var _current_frame := 0
var _frame_count := 0

func _ready() -> void:
	sprite.flip_h = flip_h
	sprite.offset = pixel_offset

	if animated and spritesheet:
		sprite.texture = spritesheet
		sprite.hframes = h_frames
		sprite.vframes = v_frames
		_frame_count = total_frames if total_frames > 0 else h_frames * v_frames
		sprite.frame = 0
	elif texture:
		sprite.texture = texture

func _process(delta: float) -> void:
	# scaling — use camera-space Z depth for correct perspective
	var cam_space = camera.global_transform.affine_inverse() * global_position
	var depth = max(-cam_space.z, 0.01)
	var fov_rad = deg_to_rad(camera.fov)
	var visible_height = 2.0 * depth * tan(fov_rad / 2.0)
	var sprite_height = 216.0 * sprite.pixel_size
	var scale_factor = visible_height / sprite_height
	var final_scale = scale_factor * sprite_scale
	sprite.scale = Vector3(final_scale, final_scale, final_scale)

	# animation
	if animated and _frame_count > 0:
		_anim_time += delta * fps
		if _anim_time >= 1.0:
			_anim_time -= 1.0
			_current_frame += 1
			if _current_frame >= _frame_count:
				_current_frame = 0 if loop else _frame_count - 1
			sprite.frame = _current_frame
