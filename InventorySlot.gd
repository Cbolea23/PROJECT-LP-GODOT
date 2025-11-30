extends TextureRect

# 0=Inventory, 1=Hotbar
@export var slot_type = 0 
@export var slot_index = 0

func _get_drag_data(at_position):
	var player = _get_my_player() # Use new function
	if not player: return null
	
	var item_id = 0
	if slot_type == 0:
		item_id = player.inventory_data[slot_index]
	else:
		item_id = player.hotbar_data[slot_index]
		
	if item_id == 0: return null
	
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return { "origin_index": slot_index, "origin_type": slot_type }

func _can_drop_data(at_position, data):
	return true

func _drop_data(at_position, data):
	var player = _get_my_player() # Use new function
	if player:
		player.swap_inventory_items(data["origin_index"], data["origin_type"], slot_index, slot_type)

# --- NEW HELPER FUNCTION ---
func _get_my_player():
	# Loop through all players and find the one that belongs to THIS computer
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.is_multiplayer_authority():
			return p
	return null
