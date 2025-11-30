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
		var my_ip = get_smart_local_ip()
		$IpLabel.text = "Your IP: " + my_ip
		# Auto-fill the box for convenience (Optional)
		# if ip_input: ip_input.text = my_ip 

# --- SMART IP FINDER ---
func get_smart_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	var candidates = []

	# 1. Filter out garbage (IPv6, Localhost, APIPA)
	for ip in addresses:
		# Must be IPv4 (contains dot, no colon)
		if "." in ip and not ":" in ip:
			# Ignore Localhost and APIPA (Auto-assigned when no internet)
			if ip != "127.0.0.1" and not ip.begins_with("169.254"):
				candidates.append(ip)

	# 2. Priority Check (Return immediately if found)
	
	# Priority A: Radmin / VPNs (Common for private servers)
	for ip in candidates:
		if ip.begins_with("26."): return ip
		
	# Priority B: Standard Home Networks (192.168.x.x)
	for ip in candidates:
		if ip.begins_with("192.168."): return ip
		
	# Priority C: Enterprise / Class A Networks (10.x.x.x)
	for ip in candidates:
		if ip.begins_with("10."): return ip

	# Priority D: Class B Networks (172.16.x.x - 172.31.x.x)
	# (Often used by Docker/WSL, so we put this last)
	for ip in candidates:
		if ip.begins_with("172."): return ip

	# 3. Fallback: If nothing specific found, return first valid candidate
	if candidates.size() > 0:
		return candidates[0]
		
	return "127.0.0.1"

func _on_host_pressed():
	if name_input.text.strip_edges() != "":
		GameManager.local_player_name = name_input.text
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Failed to host: " + str(error))
		return
		
	multiplayer.multiplayer_peer = peer
	_start_game()

func _on_join_pressed():
	if name_input.text.strip_edges() != "":
		GameManager.local_player_name = name_input.text
	else:
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
	print("Connected to server!")
	_start_game()

func _on_connected_fail():
	print("Connection Failed.")
	multiplayer.multiplayer_peer = null

func _on_quit_pressed():
	get_tree().quit()

func _start_game():
	get_tree().change_scene_to_file("res://scene/Floor.tscn")
