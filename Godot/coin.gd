extends Area3D

func _ready() -> void:
	# Connect the built-in signal to our handler function.
	# This means: whenever something enters this Area3D, _on_body_entered will run.
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Only react if the thing that entered is the Player (recommended sanity check).
	# Easiest approach: put your Player in a group named "Player".
	if not body.is_in_group("Player"):
		return

	print("Coin collected!")
	# Optional: remove the coin so it can’t be collected twice.
	# queue_free()
