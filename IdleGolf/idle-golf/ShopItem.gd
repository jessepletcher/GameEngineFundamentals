extends PanelContainer

signal purchase_requested(item_id: String)

@onready var name_label: Label = $HBoxContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $HBoxContainer/VBoxContainer/DescLabel
@onready var buy_button: Button = $HBoxContainer/BuyButton
@onready var icon: TextureRect = $HBoxContainer/ItemIcon
@onready var medal_icon: TextureRect = $Control2/MedalIcon

const LOCKED_ICON := preload("res://LockedIcon.png")
const LOCKED_ICON_SCALE := 1.0

var item_id: String
var medal_cost: int = 0
var unlock_level: int = 1
var demo_locked := false

func _ready() -> void:
	if not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)

func setup(id: String, item_name: String, desc: String, cost: float, texture: Texture2D, owned: bool, equipped: bool, p_medal_cost: int = 0, p_unlock_level: int = 1, p_demo_locked: bool = false, p_lock_text: String = "Full Game", p_icon_scale: float = 5.0) -> void:
	medal_cost = p_medal_cost
	unlock_level = p_unlock_level
	demo_locked = p_demo_locked
	item_id = id
	name_label.text = item_name
	desc_label.text = desc
	desc_label.visible = true
	_set_icon_texture(texture, p_icon_scale)

	medal_icon.visible = false
	modulate = Color.WHITE
	if demo_locked:
		_set_icon_texture(LOCKED_ICON, LOCKED_ICON_SCALE)
		desc_label.text = ""
		desc_label.visible = false
		buy_button.text = p_lock_text
		buy_button.disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.7)
		return

	# check if locked by level
	var locked = GameState.level < unlock_level and not owned
	if locked:
		buy_button.text = "Lvl %d" % unlock_level
		buy_button.disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	elif equipped:
		buy_button.text = "Equipped"
		buy_button.disabled = true
	elif owned:
		buy_button.text = "Equip"
		buy_button.disabled = false
	else:
		buy_button.text = "$%s" % GameState.format_number(cost)
		buy_button.disabled = GameState.money < cost

		if medal_cost > 0:
			buy_button.text = "%s" % GameState.format_number(medal_cost)
			buy_button.disabled = GameState.medals < medal_cost
			medal_icon.visible = true

func _on_buy_button_pressed() -> void:
	if demo_locked:
		return
	purchase_requested.emit(item_id)

func _set_icon_texture(item_texture: Texture2D, icon_scale: float) -> void:
	if item_texture == null:
		return
	icon.texture = item_texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = item_texture.get_size() * icon_scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
