extends Node3D
@export var receiver: Node


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Calling")
	receiver.OnCalled()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
