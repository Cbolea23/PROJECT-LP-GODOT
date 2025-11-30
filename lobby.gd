extends Control

@onready var name_input = %NameInput
@onready var ip_input = %IpInput

const PORT = 7777
const MAX_PLAYERS = 5

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	
	if has_node("VBoxContainer/HostButton"):
		$VBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	if has_node("VBoxContainer/JoinButton"):
		$VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	if has_node("VBoxContainer/QuitButton"):
		$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
		
	# Show IP on start
	if has_node("IpLabel"):
		$IpLabel.text = "Your IP: " + get_local_ip()

# --- IMPROVED IP FINDER ---
func get_local_ip() -> String:
	var ip_list = IP.get_local_addresses()
	var best_ip = "127.0.0.1"
	
	for ip in ip_list:
		if ip.split(".").size() == 4 and ip != "127.0.0.1" and not ip.begins_with("169.254"):
			# Prioritize Radmin IPs (often start with 26)
			if ip.begins_with("26."):
				return ip
			# Prioritize Home IPs
			if ip.begins_with("192.168."):
				best_ip = ip
			# Pick any valid IP if we haven't found a better one yet
			elif best_ip == "127.0.0.1":
				best_ip = ip
				
	return best_ip

func _on_host_pressed():
	# Save name before hosting
	if name_input.text.strip_edges() != "":
		GameManager.local_player_name = name_input.text
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	
	_start_game()

func _on_join_pressed():
	# CRITICAL: Save name BEFORE creating client
	if name_input.text.strip_edges() != "":
		GameManager.local_player_name = name_input.text
	else:
		# If empty, use a random name so we know it's working
		GameManager.local_player_name = "Player_" + str(randi() % 1000)
		
	var target_ip = "127.0.0.1"
	if ip_input.text.strip_edges() != "":
		target_ip = ip_input.text.strip_edges()
		
	print("Connecting to: " + target_ip)
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(target_ip, PORT) 
	multiplayer.multiplayer_peer = peer
	
	print("Joining as: " + GameManager.local_player_name)

func _on_connected_ok():
	_start_game()

func _on_connected_fail():
	print("Connection Failed.")
	multiplayer.multiplayer_peer = null

func _on_quit_pressed():
	get_tree().quit()

func _start_game():
	hide()
	var world = load("res://Floor.tscn").instantiate()
	get_tree().root.add_child(world)
	queue_free()
