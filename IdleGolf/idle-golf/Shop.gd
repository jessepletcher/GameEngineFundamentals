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

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	balls_tab.pressed.connect(_show_balls)
	golfers_tab.pressed.connect(_show_golfers)
	courses_tab.pressed.connect(_show_courses)
	medals_label.text = "🏅 %.0f" % GameState.medals
	_populate_shop()
	_show_balls()  # default tab

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
		item.setup(id, data["name"], data["desc"], 0.0, data.get("texture", null), data["owned"], GameState.equipped_ball == id, data.get("medal_cost", 0))
		item.purchase_requested.connect(_on_ball_purchase)

	for id in GameState.golfers:
		var data = GameState.golfers[id]
		var item = ShopItem.instantiate()
		golfer_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, null, data["owned"], GameState.equipped_golfer == id, data.get("medal_cost", 0))
		item.purchase_requested.connect(_on_golfer_purchase)

	for id in GameState.courses:
		var data = GameState.courses[id]
		var item = ShopItem.instantiate()
		course_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, null, data["owned"], GameState.equipped_course == id, data.get("medal_cost", 0))
		item.purchase_requested.connect(_on_course_purchase)

func _on_ball_purchase(id: String) -> void:
	var data = GameState.balls[id]
	if data["owned"]:
		GameState.equipped_ball = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.balls[id]["owned"] = true
		GameState.equipped_ball = id
	_populate_shop()

func _on_golfer_purchase(id: String) -> void:
	var data = GameState.golfers[id]
	if data["owned"]:
		GameState.equipped_golfer = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.golfers[id]["owned"] = true
		GameState.equipped_golfer = id
	GameState.golfer_changed.emit()
	_populate_shop()


func _on_course_purchase(id: String) -> void:
	var data = GameState.courses[id]
	if data["owned"]:
		GameState.equipped_course = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.courses[id]["owned"] = true
		GameState.equipped_course = id
	GameState.course_changed.emit()
	_populate_shop()

func _on_back_pressed() -> void:
	GameState.save()
	shop_closed.emit()
