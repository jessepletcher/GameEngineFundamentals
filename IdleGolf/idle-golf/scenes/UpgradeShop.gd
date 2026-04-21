extends CanvasLayer

@onready var shop_panel = $LeftVBox/LeftMenu/ScrollContainer
@onready var menu_background = $MenuBackground
@onready var upgrades_button: Button = $LeftVBox/LeftMenu/TopBar/UpgradesButton
@onready var rows = {
	"ball_speed":  $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/BallSpeedRow,
	"fire_rate":   $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/FireRateRow,
	"money_mult":  $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MoneyMultRow,
	"consistency": $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/ConsistencyRow,
	"xp_mult":     $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/XPMultRow,
	"flat_distance": $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/FlatDistanceRow,
	"multi_ball":  $LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MultiBallRow,
}

func _ready() -> void:
	shop_panel.visible = true
	menu_background.visible = true
	GameState.money_changed.connect(_refresh)
	upgrades_button.pressed.connect(toggle)

	for key in rows:
		var btn = rows[key].get_node("BuyButton")
		btn.gui_input.connect(_on_buy_input.bind(key))

	_refresh(GameState.money)

func toggle() -> void:
	shop_panel.visible = !shop_panel.visible
	menu_background.visible = shop_panel.visible
	if shop_panel.visible:
		_refresh(GameState.money)

func _refresh(_money: float) -> void:
	for key in rows:
		var upgrade = GameState.upgrades[key]
		var cost = GameState.get_cost(key)
		var level = upgrade["level"]
		rows[key].get_node("VBoxContainer/NameLabel").text = upgrade["label"]
		rows[key].get_node("VBoxContainer/LevelLabel").text = "Lv.%d" % level
		var cost_label = rows[key].get_node("VBoxContainer/CostLabel")
		var btn = rows[key].get_node("BuyButton")
		btn.text = ""
		if upgrade.get("use_medals", false):
			var max_lvl = upgrade.get("max_level", -1)
			if max_lvl >= 0 and level >= max_lvl:
				cost_label.text = "MAX"
				btn.disabled = true
			else:
				cost_label.text = "  %s" % GameState.format_number(cost)
				btn.disabled = GameState.medals < cost
				_add_medal_icon(cost_label)
		else:
			cost_label.text = "$%s" % GameState.format_number(cost)
			btn.disabled = GameState.money < cost

func _add_medal_icon(label: Label) -> void:
	# remove existing medal icons to avoid duplicates on refresh
	for child in label.get_children():
		if child is TextureRect:
			child.queue_free()
	var medal_icon = TextureRect.new()
	medal_icon.texture = preload("res://MedalIcon.png")
	medal_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	medal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal_icon.custom_minimum_size = Vector2(16, 16)
	label.add_child(medal_icon)
	medal_icon.position = Vector2(0, (label.size.y - 16) / 2)

func _on_buy_input(event: InputEvent, key: String) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	AudioManager.play_sfx("button")
	var amount = 5 if event.ctrl_pressed else 1
	for i in amount:
		_buy_one(key)

func _buy_one(key: String) -> void:
	var upgrade = GameState.upgrades[key]
	var max_lvl = upgrade.get("max_level", -1)
	if max_lvl >= 0 and upgrade["level"] >= max_lvl:
		return
	if upgrade.get("use_medals", false):
		var cost = GameState.get_cost(key)
		if GameState.medals >= cost:
			GameState.medals -= cost
			GameState.medals_changed.emit(GameState.medals)
			GameState.upgrades[key]["level"] += 1
			_refresh(GameState.money)
	else:
		GameState.try_purchase(key)

func _on_CloseButton_pressed() -> void:
	shop_panel.visible = false
