extends PanelContainer

signal purchase_requested(item_id: String)

@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $HBoxContainer/VBoxContainer/DescLabel
@onready var buy_button: Button = $HBoxContainer/BuyButton
@onready var icon: TextureRect = $HBoxContainer/ItemIcon

var item_id: String
var medal_cost: int = 0

func setup(id: String, item_name: String, desc: String, cost: float, texture: Texture2D, owned: bool, equipped: bool, p_medal_cost: int = 0) -> void:
	medal_cost = p_medal_cost
	item_id = id
	name_label.text = item_name
	desc_label.text = desc
	if texture:
		icon.texture = texture
	if equipped:
		buy_button.text = "Equipped"
		buy_button.disabled = true
	elif owned:
		buy_button.text = "Equip"
		buy_button.disabled = false
	else:
		buy_button.text = "$%.0f" % cost
		buy_button.disabled = GameState.money < cost
	buy_button.pressed.connect(func(): purchase_requested.emit(item_id))
	
	if not owned and medal_cost > 0:
		buy_button.text = "🏅 %d" % medal_cost
		buy_button.disabled = GameState.medals < medal_cost
