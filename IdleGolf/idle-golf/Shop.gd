extends Control

const ShopItem = preload("res://ShopItem.tscn")

@onready var medals_label: Label = $MedalsLabel
@onready var back_button: Button = $BackButton
@onready var balls_panel = $BallsPanel
@onready var clubs_panel = $ClubsPanel
@onready var courses_panel = $CoursesPanel
@onready var ball_list = $BallsPanel/BallList
@onready var club_list = $ClubsPanel/ClubList
@onready var course_list = $CoursesPanel/CourseList
@onready var balls_tab: Button = $VBoxContainer/TabBar/BallsTabBtn
@onready var clubs_tab: Button = $VBoxContainer/TabBar/ClubsTabBtn
@onready var courses_tab: Button = $VBoxContainer/TabBar/CoursesTabBtn

func _ready() -> void:
	print("ball_list: ", ball_list)
	print("club_list: ", club_list)
	print("course_list: ", course_list)
	print("balls_panel: ", balls_panel)
	print("clubs_panel: ", clubs_panel)
	print("courses_panel: ", courses_panel)
	back_button.pressed.connect(_on_back_pressed)
	balls_tab.pressed.connect(_show_balls)
	clubs_tab.pressed.connect(_show_clubs)
	courses_tab.pressed.connect(_show_courses)
	medals_label.text = "🏅 %.0f" % GameState.medals
	_populate_shop()
	_show_balls()  # default tab

func _show_balls() -> void:
	balls_panel.visible = true
	clubs_panel.visible = false
	courses_panel.visible = false

func _show_clubs() -> void:
	balls_panel.visible = false
	clubs_panel.visible = true
	courses_panel.visible = false

func _show_courses() -> void:
	balls_panel.visible = false
	clubs_panel.visible = false
	courses_panel.visible = true

func _populate_shop() -> void:
	for child in ball_list.get_children():
		child.queue_free()
	for child in club_list.get_children():
		child.queue_free()
	for child in course_list.get_children():
		child.queue_free()

	for id in GameState.balls:
		var data = GameState.balls[id]
		var item = ShopItem.instantiate()
		ball_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, null, data["owned"], GameState.equipped_ball == id, data.get("medal_cost", 0))
		item.purchase_requested.connect(_on_ball_purchase)

	for id in GameState.clubs:
		var data = GameState.clubs[id]
		var item = ShopItem.instantiate()
		club_list.add_child(item)
		item.setup(id, data["name"], data["desc"], 0.0, null, data["owned"], GameState.equipped_club == id, data.get("medal_cost", 0))
		item.purchase_requested.connect(_on_club_purchase)

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

func _on_club_purchase(id: String) -> void:
	var data = GameState.clubs[id]
	if data["owned"]:
		GameState.equipped_club = id
	elif GameState.medals >= data["medal_cost"]:
		GameState.medals -= data["medal_cost"]
		GameState.medals_changed.emit(GameState.medals)
		GameState.clubs[id]["owned"] = true
		GameState.equipped_club = id
	_populate_shop()


func _on_back_pressed() -> void:
	GameState.save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
