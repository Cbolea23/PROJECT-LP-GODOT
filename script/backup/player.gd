extends CharacterBody3D

# --- CONFIG ---
const WALK_SPEED = 5.0
const RUN_SPEED = 7.0
const ROLL_SPEED = 12.0 
const ACCELERATION = 60.0
const DECELERATION = 60.0
const MOUSE_SENSITIVITY = 0.003
const MESH_ROTATION_OFFSET = 0.0 
const LEAN_AMOUNT = 0.15         
const LEAN_SPEED = 8.0           

# --- STAMINA & ANIMATION ---
const MAX_STAMINA = 100.0
const STAMINA_DRAIN_RUN = 20.0 
const STAMINA_COST_ROLL = 25.0 
const STAMINA_REGEN = 10.0 
const ANIM_WALK = "CharacterArmature|Walk"
const ANIM_IDLE = "CharacterArmature|Idle_Neutral"
const ANIM_RUN = "CharacterArmature|Run"
const ANIM_AIM_IDLE = "CharacterArmature|Idle_Gun_Pointing"
const ANIM_AIM_RUN = "CharacterArmature|Run_Shoot"
const ANIM_ROLL = "CharacterArmature|Roll"

# --- NODES ---
@onready var name_label = $Label3D
@onready var anim = $AnimationPlayer
@onready var armature = $CharacterArmature
@onready var flashlight_light = %SpotLight3D
@onready var flashlight_mesh = %FlashlightMesh
@onready var ui_inventory_panel = $UI/Inventory
@onready var ui_stamina_bar = $UI/StaminaBar 
@onready var head = $Head 
@onready var spring_arm = $Head/SpringArm3D 
@onready var camera = $Head/SpringArm3D/Camera3D
@onready var interaction_ray = $Head/SpringArm3D/Camera3D/RayCast3D

@onready var ui_hotbar_slots = [$UI/Hotbar/HBoxContainer/Slot1, $UI/Hotbar/HBoxContainer/Slot2, $UI/Hotbar/HBoxContainer/Slot3]
@onready var ui_bag_slots = [$UI/Inventory/GridContainer/Bag1, $UI/Inventory/GridContainer/Bag2, $UI/Inventory/GridContainer/Bag3, $UI/Inventory/GridContainer/Bag4, $UI/Inventory/GridContainer/Bag5, $UI/Inventory/GridContainer/Bag6]
@onready var skins = [ %Skin_Beach, %Skin_Formal, %Skin_Punk ]

# --- DATA ---
var hotbar_data = [0, 0, 0] 
var inventory_data = [0, 0, 0, 0, 0, 0] 
var active_slot_index = 0
var is_first_person = false
var current_stamina = MAX_STAMINA
var is_rolling = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var original_flashlight_parent 
var original_flashlight_pos = Vector3.ZERO
var original_flashlight_rot = Vector3.ZERO

var player_name_value = ""

@export var current_skin_index = 0:
	set(value):
		current_skin_index = value
		change_skin_visuals(value)

func _enter_tree():
	set_multiplayer_authority(name.to_int())
	add_to_group("player")

func _ready():
	armature.rotation_degrees.y = MESH_ROTATION_OFFSET
	
	if flashlight_light:
		original_flashlight_parent = flashlight_light.get_parent()
		original_flashlight_pos = flashlight_light.position
		original_flashlight_rot = flashlight_light.rotation
	
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true
		flashlight_light.visible = false
		flashlight_mesh.visible = false
		ui_inventory_panel.visible = false
		if ui_stamina_bar: ui_stamina_bar.max_value = MAX_STAMINA
		update_all_ui()
		toggle_camera_mode(true)
		change_skin_visuals(current_skin_index)
	else:
		camera.current = false
		set_physics_process(false)
		set_process_unhandled_input(false)
		name_label.text = "Player " + name
		$UI.visible = false
		change_skin_visuals(current_skin_index)
		
	if name_label:
		name_label.text = player_name_value

func change_skin_visuals(index):
	if skins == null or skins.is_empty(): return
	for i in range(skins.size()):
		if skins[i]: skins[i].visible = (i == index)

func _unhandled_input(event):
	if $UI/PauseMenu.visible:
		return
		
	if Input.is_action_just_pressed("ui_focus_next"): 
		ui_inventory_panel.visible = not ui_inventory_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_inventory_panel.visible else Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: set_active_slot(0)
		if event.keycode == KEY_2: set_active_slot(1)
		if event.keycode == KEY_3: set_active_slot(2)
		if event.keycode == KEY_V: toggle_camera_mode()

	if Input.is_action_just_pressed("right_click"): toggle_flashlight()
	if Input.is_action_just_pressed("interact"): try_pickup_item()
	if Input.is_key_pressed(KEY_V): toggle_camera_mode()
	if Input.is_action_just_pressed("roll"): attempt_roll()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var is_sprinting = Input.is_action_pressed("sprint")
	
	if is_rolling: pass 
	elif is_sprinting and velocity.length() > 0.1 and is_on_floor():
		current_stamina -= STAMINA_DRAIN_RUN * delta
		if current_stamina < 0: 
			current_stamina = 0
			is_sprinting = false 
	else:
		current_stamina = move_toward(current_stamina, MAX_STAMINA, STAMINA_REGEN * delta)
	if ui_stamina_bar: ui_stamina_bar.value = current_stamina

	if is_rolling:
		velocity.x = move_toward(velocity.x, 0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 2.0 * delta)
	else:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

		var target_speed = 0.0
		if input_dir != Vector2.ZERO:
			target_speed = RUN_SPEED if (is_sprinting and current_stamina > 0) else WALK_SPEED

		if direction:
			velocity.x = move_toward(velocity.x, direction.x * target_speed, ACCELERATION * delta)
			velocity.z = move_toward(velocity.z, direction.z * target_speed, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
			velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)

		var target_lean = (-input_dir.x) * LEAN_AMOUNT 
		armature.rotation.z = lerp(armature.rotation.z, target_lean, LEAN_SPEED * delta)

		handle_animations(target_speed)
	
	# FLASHLIGHT FOLLOW LOGIC
	if is_first_person and flashlight_light and flashlight_light.top_level:
		flashlight_light.global_position = camera.global_position
		flashlight_light.global_rotation = camera.global_rotation

	move_and_slide()

func attempt_roll():
	if not is_rolling and velocity.length() > 1.0 and current_stamina >= STAMINA_COST_ROLL:
		is_rolling = true
		current_stamina -= STAMINA_COST_ROLL
		anim.play(ANIM_ROLL, 0.1, 1.5)
		velocity = velocity.normalized() * ROLL_SPEED
		await anim.animation_finished
		is_rolling = false

func toggle_camera_mode(force_update = false):
	if not force_update: is_first_person = not is_first_person
	
	if is_first_person:
		# FPS MODE
		spring_arm.spring_length = 0
		spring_arm.position = Vector3.ZERO
		_set_mesh_shadow_mode(armature, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		
		# Teleport Light (No Reparenting!)
		if flashlight_light:
			flashlight_light.top_level = true 
			
	else:
		# TPS MODE
		spring_arm.spring_length = 1
		spring_arm.position = Vector3(0.5, 0, 0)
		_set_mesh_shadow_mode(armature, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		
		# Restore Light
		if flashlight_light:
			flashlight_light.top_level = false
			flashlight_light.position = original_flashlight_pos
			flashlight_light.rotation = original_flashlight_rot

func _set_mesh_shadow_mode(node, mode):
	if node is MeshInstance3D:
		node.cast_shadow = mode
	for child in node.get_children():
		_set_mesh_shadow_mode(child, mode)

func handle_animations(target_speed):
	if is_rolling: return
	var is_holding_flashlight = (hotbar_data[active_slot_index] == 1)
	var current_anim = anim.current_animation
	
	if velocity.length() > 0.5:
		if target_speed == RUN_SPEED:
			var run_anim = ANIM_AIM_RUN if is_holding_flashlight else ANIM_RUN
			if current_anim != run_anim: anim.play(run_anim, 0.2)
		else:
			if current_anim != ANIM_WALK: anim.play(ANIM_WALK, 0.2)
	else:
		var idle_anim = ANIM_AIM_IDLE if is_holding_flashlight else ANIM_IDLE
		if current_anim != idle_anim: anim.play(idle_anim, 0.2)

# --- INVENTORY & ITEM LOGIC ---
func set_active_slot(index):
	active_slot_index = index
	var item = hotbar_data[active_slot_index]
	flashlight_mesh.visible = (item == 1)
	flashlight_light.visible = false 
	update_all_ui()

func toggle_flashlight():
	if hotbar_data[active_slot_index] == 1:
		flashlight_light.visible = not flashlight_light.visible

func try_pickup_item():
	if interaction_ray.is_colliding():
		var object = interaction_ray.get_collider()
		if object.is_in_group("pickable"):
			request_pickup.rpc_id(1, object.get_path())

@rpc("any_peer", "call_local", "reliable")
func request_pickup(object_path):
	if not multiplayer.is_server(): return
	var object = get_node_or_null(object_path)
	if object and object.is_in_group("pickable"):
		var item_id = object.item_id if "item_id" in object else 1
		var sender_id = multiplayer.get_remote_sender_id()
		receive_item.rpc_id(sender_id, item_id)
		remove_object_globally.rpc(object_path)

@rpc("any_peer", "call_local", "reliable")
func receive_item(item_id):
	if multiplayer.get_remote_sender_id() != 1: return
	if add_item_to_data(hotbar_data, item_id): return
	if add_item_to_data(inventory_data, item_id): return
	print("Inventory Full!")

@rpc("any_peer", "call_local", "reliable")
func remove_object_globally(object_path):
	if multiplayer.get_remote_sender_id() != 1: return
	var object = get_node_or_null(object_path)
	if object:
		object.queue_free()

func add_item_to_data(arr, item_id):
	for i in range(arr.size()):
		if arr[i] == 0:
			arr[i] = item_id
			update_all_ui()
			if arr == hotbar_data and i == active_slot_index:
				call_deferred("set_active_slot", active_slot_index)
			return true
	return false

func update_all_ui():
	for i in range(3):
		ui_hotbar_slots[i].texture = get_item_icon(hotbar_data[i])
		ui_hotbar_slots[i].modulate = Color(1, 1, 0) if i == active_slot_index else Color(1, 1, 1)
	for i in range(6): ui_bag_slots[i].texture = get_item_icon(inventory_data[i])

func get_item_icon(id):
	match id:
		1: return preload("res://icon.svg") 
		2: return preload("res://icon.svg") 
		_: return null

@rpc("call_local", "reliable")
func set_player_name(p_name):
	# Store it in the variable (so it remembers it even if Label isn't ready)
	player_name_value = p_name
	
	# Try to set the label immediately (if the player is already spawned)
	if name_label: 
		name_label.text = p_name
	
func swap_inventory_items(from_idx, from_type, to_idx, to_type):
	var item_moving = inventory_data[from_idx] if from_type == 0 else hotbar_data[from_idx]
	var item_target = inventory_data[to_idx] if to_type == 0 else hotbar_data[to_idx]

	if from_type == 0: inventory_data[from_idx] = item_target
	else: hotbar_data[from_idx] = item_target

	if to_type == 0: inventory_data[to_idx] = item_moving
	else: hotbar_data[to_idx] = item_moving

	update_all_ui()
	if (from_type == 1 and from_idx == active_slot_index) or (to_type == 1 and to_idx == active_slot_index):
		set_active_slot(active_slot_index)
