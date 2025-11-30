extends TextureRect

# 0=Inventory, 1=Hotbar
@export var slot_type = 0 
@export var slot_index = 0

var is_hovered = false

func _ready():
	mouse_entered.connect(func(): is_hovered = true)
	mouse_exited.connect(func(): is_hovered = false)
	
	# FORCE the mouse filter to be correct
	mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event):
	if not is_hovered: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: _quick_swap(0); get_viewport().set_input_as_handled()
		if event.keycode == KEY_2: _quick_swap(1); get_viewport().set_input_as_handled()
		if event.keycode == KEY_3: _quick_swap(2); get_viewport().set_input_as_handled()

func _quick_swap(hotbar_idx):
	var player = _get_my_player()
	if player:
		player.swap_inventory_items(slot_index, slot_type, hotbar_idx, 1)

# --- DEBUGGED DRAG DATA ---
func _get_drag_data(at_position):
	print("Attempting to drag from Slot ", slot_index, " (Type: ", slot_type, ")")
	
	var player = _get_my_player() 
	if not player: 
		print("ERROR: Player not found! Are you the multiplayer authority?")
		return null
	
	var item_id = 0
	if slot_type == 0:
		item_id = player.inventory_data[slot_index]
	else:
		item_id = player.hotbar_data[slot_index]
		
	if item_id == 0: 
		print("Slot is empty (ID: 0), nothing to drag.")
		return null
	
	print("Dragging Item ID: ", item_id)
	
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return { "origin_index": slot_index, "origin_type": slot_type }

func _can_drop_data(at_position, data):
	return true

func _drop_data(at_position, data):
	print("Dropping into Slot ", slot_index)
	var player = _get_my_player() 
	if player:
		player.swap_inventory_items(data["origin_index"], data["origin_type"], slot_index, slot_type)

# --- ROBUST PLAYER FINDER ---
func _get_my_player():
	var players = get_tree().get_nodes_in_group("player")
	
	# 1. Try finding the Multiplayer Authority (Standard way)
	for p in players:
		if p.is_multiplayer_authority():
			return p
			
	# 2. FALLBACK: If running single scene test, just take the first player
	if players.size() > 0:
		return players[0]
		
	return null
