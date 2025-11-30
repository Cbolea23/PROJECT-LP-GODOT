extends Node

var players = {}
var local_player_name = "Player"
var player_names = {} 

# --- NEW: SPAWN MANAGEMENT ---
# Store assigned spawn indices to ensure uniqueness
var player_spawn_indices = {}

func get_spawn_index(id):
	if not player_spawn_indices.has(id):
		# Assign the next available index based on current count
		player_spawn_indices[id] = player_spawn_indices.size() % 5
	return player_spawn_indices[id]
