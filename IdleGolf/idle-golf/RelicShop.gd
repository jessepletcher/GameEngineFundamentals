extends PanelContainer

@onready var unbox_button: Button = $VBoxContainer/UnboxButton
@onready var spin_container: HBoxContainer = $VBoxContainer/SpinContainer
@onready var spin_strip: Control = $VBoxContainer/SpinContainer/SpinStrip
@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var owned_list: VBoxContainer = $VBoxContainer/OwnedRelicsPanel/OwnedRelicsList

var _is_spinning := false
const CARD_WIDTH := 120.0
const CARD_SPACING := 4.0
const TOTAL_CARDS := 30
const RARITY_WEIGHTS := {"common": 60, "rare": 30, "legendary": 10}
const RARITY_COLORS := {
	"common": Color(0.5, 0.5, 0.5),
	"rare": Color(0.3, 0.5, 1.0),
	"legendary": Color(1.0, 0.84, 0.0),
}

func _ready() -> void:
	unbox_button.pressed.connect(_on_unbox_pressed)
	_update_button()
	_refresh_owned_list()

func _update_button() -> void:
	var cost = GameState.get_unbox_cost()
	unbox_button.text = "Unbox! (%.0f Medals)" % cost
	unbox_button.disabled = GameState.medals < cost or _is_spinning

func _on_unbox_pressed() -> void:
	if _is_spinning:
		return
	var cost = GameState.get_unbox_cost()
	if GameState.medals < cost:
		return

	# check if all relics are owned
	var unowned = _get_unowned_relics()
	if unowned.size() == 0:
		result_label.text = "All relics unlocked!"
		return

	GameState.medals -= cost
	GameState.medals_changed.emit(GameState.medals)
	GameState.unbox_count += 1
	_update_button()

	# determine the winning relic (always unowned)
	var winner_id = _pick_weighted_relic(unowned)
	_spin(winner_id)

func _get_unowned_relics() -> Array:
	var result: Array = []
	for key in GameState.relics:
		if not GameState.relics[key]["owned"]:
			result.append(key)
	return result

func _pick_weighted_relic(pool: Array) -> String:
	# build weighted list from pool
	var weighted: Array = []
	var total_weight := 0
	for key in pool:
		var rarity = GameState.relics[key]["rarity"]
		var weight = RARITY_WEIGHTS.get(rarity, 10)
		weighted.append({"key": key, "weight": weight})
		total_weight += weight

	var roll = randi() % total_weight
	var cumulative := 0
	for entry in weighted:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["key"]
	return pool[0]

func _spin(winner_id: String) -> void:
	_is_spinning = true
	result_label.text = ""
	unbox_button.disabled = true

	# clear previous cards
	for child in spin_strip.get_children():
		child.queue_free()

	# build the strip — place winner at a specific position near the end
	var winner_index = TOTAL_CARDS - 5
	var all_relic_keys = GameState.relics.keys()

	for i in TOTAL_CARDS:
		var relic_id: String
		if i == winner_index:
			relic_id = winner_id
		else:
			# random relic weighted by rarity
			relic_id = _pick_random_display_relic(all_relic_keys)
		var card = _create_card(relic_id)
		spin_strip.add_child(card)
		card.position = Vector2(i * (CARD_WIDTH + CARD_SPACING), 0)

	# wait a frame for layout
	await get_tree().process_frame

	# calculate scroll distance: winner card should land in center of spin_container
	var container_width = spin_container.size.x
	var card_total = CARD_WIDTH + CARD_SPACING
	var target_x = -(winner_index * card_total) + (container_width / 2.0) - (CARD_WIDTH / 2.0)

	# animate the scroll with easing
	spin_strip.position.x = 0
	var tween = create_tween()
	var duration = 3.0
	tween.tween_property(spin_strip, "position:x", target_x, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished

	# reveal result
	var relic = GameState.relics[winner_id]
	relic["owned"] = true
	GameState.save()

	var rarity_text = relic["rarity"].to_upper()
	result_label.text = "%s - %s! (%s)" % [rarity_text, relic["name"], relic["desc"]]
	result_label.modulate = RARITY_COLORS.get(relic["rarity"], Color.WHITE)

	_is_spinning = false
	_update_button()
	_refresh_owned_list()

	# update medals display on parent shop
	var shop = get_parent().get_parent()
	if shop.has_method("_update_medals_label"):
		shop._update_medals_label()

func _pick_random_display_relic(keys: Array) -> String:
	# weighted random for visual variety
	var total_weight := 0
	var weighted: Array = []
	for key in keys:
		var rarity = GameState.relics[key]["rarity"]
		var weight = RARITY_WEIGHTS.get(rarity, 10)
		weighted.append({"key": key, "weight": weight})
		total_weight += weight
	var roll = randi() % total_weight
	var cumulative := 0
	for entry in weighted:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["key"]
	return keys[0]

func _create_card(relic_id: String) -> PanelContainer:
	var relic = GameState.relics[relic_id]
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 80)

	var style = StyleBoxFlat.new()
	style.bg_color = RARITY_COLORS.get(relic["rarity"], Color.GRAY)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = relic["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://balatro.otf")
	if font:
		name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = relic["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	if font:
		desc_label.add_theme_font_override("font", font)
	vbox.add_child(desc_label)

	return card

func _refresh_owned_list() -> void:
	for child in owned_list.get_children():
		child.queue_free()

	var font = load("res://balatro.otf")
	for key in GameState.relics:
		var relic = GameState.relics[key]
		if not relic["owned"]:
			continue
		var label = Label.new()
		label.text = "%s — %s" % [relic["name"], relic["desc"]]
		label.add_theme_color_override("font_color", RARITY_COLORS.get(relic["rarity"], Color.WHITE))
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		owned_list.add_child(label)
