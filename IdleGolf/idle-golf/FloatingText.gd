extends Node3D

@onready var label: Label3D = $Label3D
@onready var camera: Camera3D = get_viewport().get_camera_3d()

func setup(money: float, yards: float) -> void:
	label.text = "$%.2f | %.0f yds" % [money, yards]
	
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 3.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	var distance = global_position.distance_to(camera.global_position)
	var scale_factor = pow(distance * 0.05, 1.5)
	label.scale = Vector3(scale_factor, scale_factor, scale_factor)
