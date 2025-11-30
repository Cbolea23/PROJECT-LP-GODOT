extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points = $SpawnPoints
@onready var message_label = $HUD/MessageLabel
# Reference the spawner in the floor scene
@onready var player_spawner = $MultiplayerSpawner 

func _ready():
	# 1. SETUP SPAWNER FUNCTION
	player_spawner.spawn_function = _spawn_player_setup
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Register Host
		_register_new_player(1, GameManager.local_player_name)
	else:
		# Client tells Server its name
		_server_receive_name.rpc_id(1, GameManager.local_player_name)

func _on_peer_connected(id):
	pass

func _on_peer_disconnected(id):
	show_message.rpc("Player " + str(id) + " Left!")
	if get_node_or_null(str(id)):
		get_node(str(id)).queue_free()

@rpc("any_peer", "call_remote", "reliable")
func _server_receive_name(p_name):
	var sender_id = multiplayer.get_remote_sender_id()
	_register_new_player(sender_id, p_name)

func _register_new_player(id, p_name):
	GameManager.player_names[id] = p_name
	show_message.rpc(p_name + " Joined!")
	
	# --- SERVER SPAWNS PLAYER ---
	player_spawner.spawn([id, p_name])

# --- THIS RUNS ON ALL CLIENTS AUTOMATICALLY ---
func _spawn_player_setup(data):
	var id = data[0]
	var p_name = data[1]
	
	var player = player_scene.instantiate()
	player.name = str(id)
	
	# --- CALCULATE SPAWN POSITION HERE ---
	var spawn_index = GameManager.get_spawn_index(id)
	
	# Find the spawn marker
	# We use get_node because 'spawn_points' variable might not be ready on clients yet
	var points_node = get_node_or_null("SpawnPoints")
	
	if points_node and points_node.get_child_count() > spawn_index:
		var point = points_node.get_child(spawn_index)
		
		# FIX: Use LOCAL position/rotation. 
		# Since the player will be a child of Floor, and SpawnPoints is a child of Floor,
		# their local positions relative to Floor are what matters.
		player.position = point.position
		player.rotation = point.rotation
	else:
		# Fallback if spawn points are missing
		player.position = Vector3(0, 1, 0)
	
	# Set the name
	player.set_player_name(p_name)
	
	return player # The spawner automatically adds this to the scene

@rpc("authority", "call_local", "reliable")
func show_message(text):
	if message_label:
		message_label.text = text
		await get_tree().create_timer(3.0).timeout
		message_label.text = ""
