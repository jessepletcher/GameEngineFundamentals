extends PanelContainer

signal purchase_requested(item_id: String)

@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $HBoxContainer/VBoxContainer/DescLabel
@onready var buy_button: Button = $HBoxContainer/BuyButton
@onready var icon: TextureRect = $HBoxContainer/ItemIcon

var item_id: String
var medal_cost: int = 0
var unlock_level: int = 1

func setup(id: String, item_name: String, desc: String, cost: float, texture: Texture2D, owned: bool, equipped: bool, p_medal_cost: int = 0, p_unlock_level: int = 1) -> void:
	medal_cost = p_medal_cost
	unlock_level = p_unlock_level
	item_id = id
	name_label.text = item_name
	desc_label.text = desc
	if texture:
		icon.texture = texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = texture.get_size() * 5
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	# check if locked by level
	var locked = GameState.level < unlock_level and not owned
	if locked:
		buy_button.text = "🔒 Lvl %d" % unlock_level
		buy_button.disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	elif equipped:
		buy_button.text = "Equipped"
		buy_button.disabled = true
	elif owned:
		buy_button.text = "Equip"
		buy_button.disabled = false
	else:
		buy_button.text = "$%.0f" % cost
		buy_button.disabled = GameState.money < cost

		if medal_cost > 0:
			buy_button.text = "   %d" % medal_cost
			buy_button.disabled = GameState.medals < medal_cost
			var medal_icon = TextureRect.new()
			medal_icon.texture = preload("res://medalicon.png")
			medal_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			medal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			medal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			medal_icon.custom_minimum_size = Vector2(16, 16)
			medal_icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			medal_icon.position.x = 4
			medal_icon.position.y = -8
			buy_button.add_child(medal_icon)

	buy_button.pressed.connect(func(): purchase_requested.emit(item_id))
