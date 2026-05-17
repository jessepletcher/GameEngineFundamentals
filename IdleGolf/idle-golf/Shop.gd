extends Control

signal shop_closed

const ShopItem = preload("res://ShopItem.tscn")

@onready var medals_label: Label = $MedalAndExitTexture/MedalsLabel
@onready var back_button: Button = $BackButton
@onready var balls_panel = $BallsPanel
@onready var golfers_panel = $ClubsPanel
@onready var courses_panel = $CoursesPanel
@onready var ball_list = $BallsPanel/BallList
@onready var golfer_list = $ClubsPanel/ClubList
@onready var course_list = $CoursesPanel/CourseList
@onready var balls_tab: Button = $Panel/VBoxContainer/TabBar/BallsTabBtn
@onready var golfers_tab: Button = $Panel/VBoxContainer/TabBar/ClubsTabBtn
@onready var courses_tab: Button = $Panel/VBoxContainer/TabBar/CoursesTabBtn

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	balls_tab.pressed.connect(_show_balls)
	golfers_tab.pressed.connect(_show_golfers)
	courses_tab.pressed.connect(_show_courses)
	_update_medals_label()
	_populate_shop()
	_show_balls()  # default tab

func _update_medals_label() -> void:
	medals_label.text = GameState.format_number(GameState.medals)

func _hide_all_panels() -> void:
	balls_panel.visible = false
	golfers_panel.visible = false
	courses_panel.visible = false

func _show_balls() -> void:
	_hide_all_panels()
	balls_panel.visible = true

func _show_golfers() -> void:
	_hide_all_panels()
	golfers_panel.visible = true

func _show_courses() -> void:
	_hide_all_panels()
	courses_panel.visible = true

func _populate_shop() -> void:
	for child in ball_list.get_children():
		child.queue_free()
	for child in golfer_list.get_children():
		child.queue_free()
	for child in course_list.get_children():
		child.queue_free()

	for id in GameState.balls:
		var data = GameState.balls[id]
		var item = ShopItem.instantiate()
		ball_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, data.get("texture", null), data["owned"], GameState.equipped_ball == id, data.get("medal_cost", 0), data.get("unlock_level", 1))
		item.purchase_requested.connect(_on_ball_purchase)

	for id in GameState.golfers:
		var data = GameState.golfers[id]
		var item = ShopItem.instantiate()
		golfer_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, data.get("texture", null), data["owned"], GameState.equipped_golfer == id, data.get("medal_cost", 0), data.get("unlock_level", 1))
		item.purchase_requested.connect(_on_golfer_purchase)

	for id in GameState.courses:
		var data = GameState.courses[id]
		var item = ShopItem.instantiate()
		course_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, data.get("texture", null), data["owned"], GameState.equipped_course == id, data.get("medal_cost", 0), data.get("unlock_level", 1))
		item.purchase_requested.connect(_on_course_purchase)

func _on_ball_purchase(id: String) -> void:
	var data = GameState.balls[id]
	if not data["owned"] and GameState.level < data.get("unlock_level", 1):
		return
	var was_owned: bool = data["owned"]
	if data["owned"]:
		GameState.equipped_ball = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.balls[id]["owned"] = true
		GameState.equipped_ball = id
	if not was_owned and data["owned"]:
		_play_unlock_animation(data.get("texture", null), data.get("name", ""))
	_update_medals_label()
	_populate_shop()

func _on_golfer_purchase(id: String) -> void:
	var data = GameState.golfers[id]
	if not data["owned"] and GameState.level < data.get("unlock_level", 1):
		return
	var was_owned: bool = data["owned"]
	if data["owned"]:
		GameState.equipped_golfer = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.golfers[id]["owned"] = true
		GameState.equipped_golfer = id
	if not was_owned and data["owned"]:
		_play_unlock_animation(data.get("texture", null), data.get("name", ""))
	GameState.golfer_changed.emit()
	_update_medals_label()
	_populate_shop()


func _on_course_purchase(id: String) -> void:
	var data = GameState.courses[id]
	if not data["owned"] and GameState.level < data.get("unlock_level", 1):
		return
	var was_owned: bool = data["owned"]
	if data["owned"]:
		GameState.equipped_course = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.courses[id]["owned"] = true
		GameState.equipped_course = id
	if not was_owned and data["owned"]:
		_play_unlock_animation(data.get("texture", null), data.get("name", ""))
	GameState.course_changed.emit()
	_update_medals_label()
	_populate_shop()

func _play_unlock_animation(item_texture: Texture2D, item_name: String = "") -> void:
	var screen := get_viewport().get_visible_rect().size
	var center := screen / 2.0

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	add_child(overlay)

	var glow := Sprite2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.5, 0.55))
	gradient.set_color(1, Color(1.0, 0.85, 0.3, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = gradient
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 512
	glow_tex.height = 512
	glow.texture = glow_tex
	glow.position = center
	glow.scale = Vector2.ZERO
	glow.z_index = 0
	overlay.add_child(glow)

	var glow_intro := overlay.create_tween()
	glow_intro.tween_interval(0.48)
	glow_intro.tween_property(glow, "scale", Vector2(1.4, 1.4), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	glow_intro.tween_property(glow, "scale", Vector2(1.7, 1.7), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_intro.tween_property(glow, "scale", Vector2(1.4, 1.4), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var burst := Sprite2D.new()
	burst.texture = load("res://ItemUnlocked.png")
	burst.hframes = 4
	burst.frame = 0
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.position = center
	burst.scale = Vector2.ONE
	burst.z_index = 10
	overlay.add_child(burst)

	var frame_cycle := burst.create_tween().set_loops()
	for f in 4:
		frame_cycle.tween_property(burst, "frame", f, 0.0)
		frame_cycle.tween_interval(0.32)

	if item_texture:
		var item_sprite := Sprite2D.new()
		item_sprite.texture = item_texture
		item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item_sprite.position = center
		item_sprite.scale = Vector2.ZERO
		item_sprite.z_index = 20
		overlay.add_child(item_sprite)

		var item_tween := item_sprite.create_tween()
		item_tween.tween_interval(0.48)
		item_tween.tween_property(item_sprite, "scale", Vector2(16, 16), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if item_name != "":
		var name_label := Label.new()
		name_label.text = item_name
		name_label.add_theme_font_override("font", load("res://balatro.otf"))
		name_label.add_theme_font_size_override("font_size", 64)
		name_label.add_theme_color_override("font_color", Color(1, 1, 1))
		name_label.add_theme_constant_override("outline_size", 0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.z_index = 30
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(name_label)
		await get_tree().process_frame
		if not is_instance_valid(name_label):
			return
		var label_size: Vector2 = name_label.size
		name_label.position = Vector2(center.x - label_size.x / 2.0, center.y + 200.0)
		name_label.modulate.a = 0.0

		var label_tween := name_label.create_tween()
		label_tween.tween_interval(0.6)
		label_tween.tween_property(name_label, "modulate:a", 1.0, 0.4)

	var dismissed := [false]
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if dismissed[0]:
			return
		if event is InputEventMouseButton and event.pressed:
			dismissed[0] = true
			var fade := overlay.create_tween()
			fade.tween_property(overlay, "modulate:a", 0.0, 0.3)
			fade.tween_callback(overlay.queue_free)
	)

func _on_back_pressed() -> void:
	GameState.save()
	shop_closed.emit()
