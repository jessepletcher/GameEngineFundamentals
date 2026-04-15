extends Control

signal shop_closed

const ShopItem = preload("res://ShopItem.tscn")

@onready var medals_label: Label = $MedalsLabel
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

var _medal_icon: TextureRect

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	balls_tab.pressed.connect(_show_balls)
	golfers_tab.pressed.connect(_show_golfers)
	courses_tab.pressed.connect(_show_courses)
	_setup_medal_icon()
	_update_medals_label()
	_populate_shop()
	_show_balls()  # default tab

func _setup_medal_icon() -> void:
	_medal_icon = TextureRect.new()
	_medal_icon.texture = preload("res://MedalIcon.png")
	_medal_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_medal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal_icon.custom_minimum_size = Vector2(48, 48)
	medals_label.clip_contents = false
	medals_label.add_child(_medal_icon)
	_medal_icon.set_deferred("position", Vector2(0, (medals_label.size.y - 48) / 2))

func _update_medals_label() -> void:
	medals_label.text = "       %.0f" % GameState.medals

func _show_balls() -> void:
	balls_panel.visible = true
	golfers_panel.visible = false
	courses_panel.visible = false

func _show_golfers() -> void:
	balls_panel.visible = false
	golfers_panel.visible = true
	courses_panel.visible = false

func _show_courses() -> void:
	balls_panel.visible = false
	golfers_panel.visible = false
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
		item.setup(id, data["name"], data["desc"], 0.0, null, data["owned"], GameState.equipped_golfer == id, data.get("medal_cost", 0), data.get("unlock_level", 1))
		item.purchase_requested.connect(_on_golfer_purchase)

	for id in GameState.courses:
		var data = GameState.courses[id]
		var item = ShopItem.instantiate()
		course_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, null, data["owned"], GameState.equipped_course == id, data.get("medal_cost", 0), data.get("unlock_level", 1))
		item.purchase_requested.connect(_on_course_purchase)

func _on_ball_purchase(id: String) -> void:
	var data = GameState.balls[id]
	if not data["owned"] and GameState.level < data.get("unlock_level", 1):
		return
	if data["owned"]:
		GameState.equipped_ball = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.balls[id]["owned"] = true
		GameState.equipped_ball = id
	_update_medals_label()
	_populate_shop()

func _on_golfer_purchase(id: String) -> void:
	var data = GameState.golfers[id]
	if not data["owned"] and GameState.level < data.get("unlock_level", 1):
		return
	if data["owned"]:
		GameState.equipped_golfer = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.golfers[id]["owned"] = true
		GameState.equipped_golfer = id
	GameState.golfer_changed.emit()
	_update_medals_label()
	_populate_shop()


func _on_course_purchase(id: String) -> void:
	var data = GameState.courses[id]
	if not data["owned"] and GameState.level < data.get("unlock_level", 1):
		return
	if data["owned"]:
		GameState.equipped_course = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.courses[id]["owned"] = true
		GameState.equipped_course = id
	GameState.course_changed.emit()
	_update_medals_label()
	_populate_shop()

func _on_back_pressed() -> void:
	GameState.save()
	shop_closed.emit()
