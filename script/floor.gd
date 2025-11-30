extends Node3D

@export var player_scene: PackedScene
@onready var spawn_points = $SpawnPoints
@onready var message_label = $HUD/MessageLabel
@onready var player_spawner = $MultiplayerSpawner 

func _ready():
	player_spawner.spawn_function = _spawn_player_setup
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_register_new_player(1, GameManager.local_player_name)
	else:
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
	
	var spawn_index = GameManager.get_spawn_index(id)
	player_spawner.spawn([id, p_name, spawn_index])

func _spawn_player_setup(data):
	var id = data[0]
	var p_name = data[1]
	var spawn_index = data[2]
	
	var player = player_scene.instantiate()
	player.name = str(id)
	
	var points_node = get_node_or_null("SpawnPoints")
	if points_node and points_node.get_child_count() > spawn_index:
		var point = points_node.get_child(spawn_index)
		player.position = point.position
		player.rotation = point.rotation
	else:
		player.position = Vector3(0, 1, 0) # Fallback
	
	player.set_player_name(p_name)
	return player 

@rpc("authority", "call_local", "reliable")
func show_message(text):
	if message_label:
		message_label.text = text
		await get_tree().create_timer(3.0).timeout
		message_label.text = ""

func kick_player(target_id):
	if not multiplayer.is_server(): return
	
	print("Kicking player: " + str(target_id))
	show_message.rpc("Player " + str(target_id) + " was kicked!")
	multiplayer.multiplayer_peer.disconnect_peer(target_id)
	
func _on_server_disconnected():
	print("Host disconnected. Returning to Lobby...")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	GameManager.player_names.clear()
	GameManager.player_spawn_indices.clear()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	get_tree().change_scene_to_file("res://scene/Lobby.tscn")
