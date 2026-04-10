extends Node3D

@onready var label: Label3D = $Label3D
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var _fade_tween: Tween

func setup(money: float, yards: float, flag_hit: bool = false, direct_hit: bool = false) -> void:
	label.text = "$%.0f | %.0f yds" % [money, yards]
	if direct_hit:
		label.modulate = Color(1.0, 0.84, 0.0)  # gold
	elif flag_hit:
		label.modulate = Color(0.3, 1.0, 0.3)  # green
	else:
		label.modulate = Color.WHITE

	_fade_tween = create_tween()
	_fade_tween.tween_interval(1.0)
	_fade_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(queue_free)

func force_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	var distance = global_position.distance_to(camera.global_position)
	var scale_factor = max(pow(distance * 0.05, 1.5), 0.8)
	label.scale = Vector3(scale_factor, scale_factor, scale_factor)
