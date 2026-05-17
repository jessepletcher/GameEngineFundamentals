extends CanvasLayer

@onready var shop_panel = $LeftVBox/LeftMenu/ScrollContainer
@onready var menu_background = $MenuBackground
@onready var upgrades_button: Button = $LeftVBox/LeftMenu/TopBar/UpgradesButton
var rows := {}

func _ready() -> void:
	shop_panel.visible = true
	menu_background.visible = true
	GameState.money_changed.connect(_refresh)
	GameState.medals_changed.connect(_refresh)
	upgrades_button.pressed.connect(toggle)
	_register_rows()

	for key in rows:
		var btn = rows[key].get_node("BuyButton")
		btn.gui_input.connect(_on_buy_input.bind(key))

	_refresh(GameState.money)

func _register_rows() -> void:
	var row_paths := {
		"ball_speed": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/BallSpeedRow",
		"fire_rate": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/FireRateRow",
		"money_mult": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MoneyMultRow",
		"consistency": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/ConsistencyRow",
		"xp_mult": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/XPMultRow",
		"flat_distance": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/FlatDistanceRow",
		"multi_ball": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MultiBallRow",
		"multi_ball_spread": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/MultiBallSpreadRow",
		"consistency_mult": ^"LeftVBox/LeftMenu/ScrollContainer/UpgradesPanel/ConsistencyMultRow",
	}
	rows.clear()
	for key in row_paths:
		var row := get_node_or_null(row_paths[key])
		if row:
			rows[key] = row
		else:
			push_warning("UpgradeShop: missing row for %s" % key)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		_refresh(GameState.money)

func toggle() -> void:
	shop_panel.visible = !shop_panel.visible
	menu_background.visible = shop_panel.visible
	if shop_panel.visible:
		_refresh(GameState.money)

func _refresh(_money: float) -> void:
	for key in rows:
		if not GameState.upgrades.has(key):
			continue
		var upgrade = GameState.upgrades[key]
		var cost = GameState.get_cost(key)
		var level = upgrade["level"]
		rows[key].get_node("VBoxContainer/NameLabel").text = upgrade["label"]
		rows[key].get_node("VBoxContainer/LevelLabel").text = "Lv.%d" % level
		var cost_label = rows[key].get_node("VBoxContainer/CostLabel")
		var btn = rows[key].get_node("BuyButton")
		var refund_mode := Input.is_key_pressed(KEY_SHIFT)
		btn.text = ""
		if upgrade.get("use_medals", false):
			var max_lvl = upgrade.get("max_level", -1)
			if max_lvl >= 0 and level >= max_lvl:
				cost_label.text = "MAX"
				btn.disabled = level <= 0 if refund_mode else true
			else:
				cost_label.text = "  %s" % GameState.format_number(cost)
				btn.disabled = level <= 0 if refund_mode else GameState.medals < cost
				_add_medal_icon(cost_label)
		else:
			cost_label.text = "$%s" % GameState.format_number(cost)
			btn.disabled = level <= 0 if refund_mode else GameState.money < cost

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

	var amount = 5 if event.ctrl_pressed else 1
	var changed := false
	for i in amount:
		if event.shift_pressed:
			changed = _refund_one(key) or changed
		else:
			changed = _buy_one(key) or changed
	if changed:
		AudioManager.play_sfx("button")

func _buy_one(key: String) -> bool:
	var upgrade = GameState.upgrades[key]
	var max_lvl = upgrade.get("max_level", -1)
	if max_lvl >= 0 and upgrade["level"] >= max_lvl:
		return false
	if upgrade.get("use_medals", false):
		var cost = GameState.get_cost(key)
		if GameState.medals >= cost:
			GameState.medals -= cost
			GameState.medals_changed.emit(GameState.medals)
			GameState.upgrades[key]["level"] += 1
			_play_upgrade_burst(rows[key], upgrade["label"])
			_refresh(GameState.money)
			return true
	else:
		if GameState.try_purchase(key):
			_play_upgrade_burst(rows[key], upgrade["label"])
			_refresh(GameState.money)
			return true
	return false

func _refund_one(key: String) -> bool:
	var upgrade = GameState.upgrades[key]
	var level = int(upgrade["level"])
	if level <= 0:
		return false

	var refund = GameState.get_cost_for_level(key, level - 1)
	GameState.upgrades[key]["level"] = level - 1
	if upgrade.get("use_medals", false):
		GameState.medals += refund
		GameState.medals_changed.emit(GameState.medals)
	else:
		GameState.money += refund
		GameState.money_changed.emit(GameState.money)
	_refresh(GameState.money)
	return true

func _on_CloseButton_pressed() -> void:
	shop_panel.visible = false

func _play_upgrade_burst(row: Control, stat_label: String) -> void:
	if not is_instance_valid(row):
		return
	var burst := Control.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burst.z_index = 20
	row.add_child(burst)

	var label := Label.new()
	label.text = "%s Up" % stat_label
	label.add_theme_font_override("font", load("res://balatro.otf"))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = row.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burst.add_child(label)

	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(burst.queue_free)
