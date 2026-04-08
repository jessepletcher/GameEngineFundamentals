extends Control

@onready var drag_point: Control = $DragPoint

var dragging := false
var normalized_pos := Vector2.ZERO  # -1 to 1 on both axes

func _ready() -> void:
	drag_point.position = size / 2 - drag_point.size / 2  # center it

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed

	if event is InputEventMouseMotion and dragging:
		var local_pos = get_local_mouse_position()
		
		# clamp within box
		local_pos.x = clamp(local_pos.x, 0, size.x)
		local_pos.y = clamp(local_pos.y, 0, size.y)
		
		# move the dot
		drag_point.position = local_pos - drag_point.size / 2
		
		# normalize to -1 to 1
		normalized_pos.x = (local_pos.x / size.x) * 2.0 - 1.0
		normalized_pos.y = (local_pos.y / size.y) * 2.0 - 1.0

func get_launch_modifier() -> Vector2:
	return normalized_pos  # x = curve, y = launch angle
