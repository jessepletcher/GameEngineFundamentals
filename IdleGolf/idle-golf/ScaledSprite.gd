extends Node3D

@export var texture: Texture2D
@export var flip_h: bool = false
@export var pixel_offset: Vector2 = Vector2(0, -12)

@onready var sprite: Sprite3D = $Sprite3D
@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _ready() -> void:
	if texture:
		sprite.texture = texture
	sprite.flip_h = flip_h
	sprite.offset = pixel_offset

func _process(_delta: float) -> void:
	var distance = global_position.distance_to(camera.global_position)
	var fov_rad = deg_to_rad(camera.fov)
	var visible_height = 2.0 * distance * tan(fov_rad / 2.0)
	var sprite_height = 216.0 * sprite.pixel_size
	var scale_factor = visible_height / sprite_height
	sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)
