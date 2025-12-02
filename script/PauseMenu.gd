extends Control

# --- CONTAINERS ---
@onready var main_container = $ColorRect/HBoxContainer
@onready var settings_container = $SettingsContainer
@onready var player_list_container = $ColorRect/HBoxContainer2/PlayerListContainer

# --- BUTTONS ---
@onready var resume_btn = %Resume
@onready var settings_btn = %Settings
@onready var main_menu_btn = %Quit 

# --- GAMEPLAY TAB ---
@onready var camera_check = %CameraBtn
@onready var fullscreen_check = %FullscreenBtn

# --- CONTROLS TAB ---
@onready var sens_slider = %SensSlider
@onready var invert_y_check = %InvertYBtn
@onready var invert_x_check = %InvertXBtn

@onready var back_btn = %BackBtn

func _ready():
	visible = false
	settings_container.visible = false
	main_container.visible = true
	
	resume_btn.pressed.connect(toggle_menu)
	settings_btn.pressed.connect(open_settings)
	main_menu_btn.pressed.connect(return_to_lobby)
	
	camera_check.toggled.connect(_on_camera_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	sens_slider.value_changed.connect(_on_sensitivity_changed)
	invert_y_check.toggled.connect(_on_invert_y_toggled)
	invert_x_check.toggled.connect(_on_invert_x_toggled)
	
	back_btn.pressed.connect(close_settings)
	
	get_tree().node_added.connect(_on_node_change)
	get_tree().node_removed.connect(_on_node_change)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_container.visible:
			close_settings()
		else:
			toggle_menu()
		
		# CRITICAL FIX: Tell Godot we handled the ESC key so it doesn't unlock the mouse
		get_viewport().set_input_as_handled()

func toggle_menu():
	visible = not visible
	
	if visible:
		# Menu OPEN: Mouse must be visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		main_container.visible = true
		settings_container.visible = false
		update_player_list()
	else:
		# Menu CLOSED: Check if Inventory is still open!
		# We look for the sibling node named "Inventory"
		var inventory = get_node_or_null("../Inventory")
		
		if inventory and inventory.visible:
			# If Inventory is open, KEEP mouse visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			# Otherwise, lock the mouse for gameplay
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_settings():
	main_container.visible = false
	settings_container.visible = true
	update_settings_ui()

func close_settings():
	settings_container.visible = false
	main_container.visible = true

func update_settings_ui():
	var mode = DisplayServer.window_get_mode()
	var is_fs = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.set_pressed_no_signal(is_fs)
	
	var player = _get_my_player()
	if player:
		camera_check.set_pressed_no_signal(player.is_first_person)
		sens_slider.set_value_no_signal(player.mouse_sensitivity)
		invert_y_check.set_pressed_no_signal(player.invert_y)
		invert_x_check.set_pressed_no_signal(player.invert_x)

# --- GAMEPLAY LOGIC ---
func _on_fullscreen_toggled(is_on):
	if is_on: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_camera_toggled(is_on):
	var player = _get_my_player()
	if player and player.is_first_person != is_on:
		player.toggle_camera_mode()

# --- CONTROLS LOGIC ---
func _on_sensitivity_changed(value):
	var player = _get_my_player()
	if player: player.mouse_sensitivity = value

func _on_invert_y_toggled(is_on):
	var player = _get_my_player()
	if player: player.invert_y = is_on

func _on_invert_x_toggled(is_on):
	var player = _get_my_player()
	if player: player.invert_x = is_on

# --- HELPERS ---
func _get_my_player():
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.is_multiplayer_authority(): return p
	return null

func _on_node_change(node):
	if node.is_in_group("player") and visible: update_player_list()

func update_player_list():
	if not is_inside_tree() or get_tree() == null: return
	for child in player_list_container.get_children(): child.queue_free()
	
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		var row = HBoxContainer.new()
		var id = p.name.to_int()
		var p_name = "Unknown"
		if p.has_node("Label3D"): p_name = p.get_node("Label3D").text
		
		var label = Label.new()
		label.text = p_name + (" (You)" if id == multiplayer.get_unique_id() else "")
		label.custom_minimum_size.x = 200
		row.add_child(label)
		
		if multiplayer.is_server() and id != 1:
			var kick_btn = Button.new()
			kick_btn.text = "KICK"
			kick_btn.modulate = Color(1, 0.3, 0.3)
			kick_btn.pressed.connect(_on_kick_pressed.bind(id))
			row.add_child(kick_btn)
		player_list_container.add_child(row)

func _on_kick_pressed(target_id):
	var world = get_tree().current_scene
	if world.has_method("kick_player"): world.kick_player(target_id)

func return_to_lobby():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	GameManager.player_names.clear()
	GameManager.player_spawn_indices.clear() 
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scene/Lobby.tscn")
