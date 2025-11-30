extends Control

@onready var player_list_container = $HBoxContainer2/PlayerListContainer
@onready var resume_btn = $HBoxContainer/VBoxContainer/Resume
@onready var main_menu_btn = $HBoxContainer/VBoxContainer/Quit 

func _ready():
	visible = false
	resume_btn.pressed.connect(toggle_menu)
	main_menu_btn.pressed.connect(return_to_lobby)
	
	get_tree().node_added.connect(_on_node_change)
	get_tree().node_removed.connect(_on_node_change)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()

func toggle_menu():
	visible = not visible
	
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		update_player_list()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_node_change(node):
	if node.is_in_group("player") and visible:
		update_player_list()

func update_player_list():
	if not is_inside_tree() or get_tree() == null: return

	for child in player_list_container.get_children():
		child.queue_free()
	
	var players = get_tree().get_nodes_in_group("player")
	
	for p in players:
		var row = HBoxContainer.new()
		var id = p.name.to_int()
		var p_name = "Unknown"
		if p.has_node("Label3D"):
			p_name = p.get_node("Label3D").text
		
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
	if world.has_method("kick_player"):
		world.kick_player(target_id)

# ---RETURN TO LOBBY FUNCTION ---
func return_to_lobby():
	# 1. Close Network
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# 2. Reset Global Data (So the next game starts fresh)
	GameManager.player_names.clear()
	GameManager.player_spawn_indices.clear()
	
	# 3. Unlock Mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 4. Swap Scene
	get_tree().change_scene_to_file("res://scene/Lobby.tscn")
