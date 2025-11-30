extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points = $SpawnPoints
@onready var message_label = $HUD/MessageLabel
@onready var player_spawner = $MultiplayerSpawner 

func _ready():
	player_spawner.spawn_function = _spawn_player_setup
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Server registers itself
		_register_new_player(1, GameManager.local_player_name)
	else:
		# Client sends name to server
		_server_receive_name.rpc_id(1, GameManager.local_player_name)

func _on_peer_connected(id):
	pass

func _on_peer_disconnected(id):
	show_message.rpc("Player " + str(id) + " Left!")
	if get_node_or_null(str(id)):
		get_node(str(id)).queue_free()
		# OPTIONAL: Free up the spawn index in GameManager so new players can reuse it
		# GameManager.release_spawn_index(id) 

@rpc("any_peer", "call_remote", "reliable")
func _server_receive_name(p_name):
	var sender_id = multiplayer.get_remote_sender_id()
	_register_new_player(sender_id, p_name)

func _register_new_player(id, p_name):
	GameManager.player_names[id] = p_name
	show_message.rpc(p_name + " Joined!")
	
	# --- SERVER CALCULATES SPAWN INDEX ---
	# We calculate it HERE, on the authority, so there is no guessing.
	var spawn_index = GameManager.get_spawn_index(id)
	
	# --- PASS INDEX TO SPAWNER ---
	# We add 'spawn_index' to the data array so the Client receives it too.
	player_spawner.spawn([id, p_name, spawn_index])

# --- THIS RUNS ON ALL CLIENTS ---
func _spawn_player_setup(data):
	var id = data[0]
	var p_name = data[1]
	var spawn_index = data[2] # Client reads the Server's decision
	
	var player = player_scene.instantiate()
	player.name = str(id)
	
	# --- APPLY SPAWN POSITION ---
	var points_node = get_node_or_null("SpawnPoints")
	
	if points_node and points_node.get_child_count() > spawn_index:
		var point = points_node.get_child(spawn_index)
		player.position = point.position
		player.rotation = point.rotation
	else:
		# Fallback to prevent crash
		player.position = Vector3(0, 1, 0)
	
	player.set_player_name(p_name)
	
	return player 

@rpc("authority", "call_local", "reliable")
func show_message(text):
	if message_label:
		message_label.text = text
		await get_tree().create_timer(3.0).timeout
		message_label.text = ""
