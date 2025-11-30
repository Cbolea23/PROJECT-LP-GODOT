extends CharacterBody3D

# --- CONFIG ---
const WALK_SPEED = 5.0
const RUN_SPEED = 7.0
const ROLL_SPEED = 6.0 # Fast burst of speed
const MOUSE_SENSITIVITY = 0.003

# CAMERA SETTINGS
const BOB_INTENSITY = 0.2
const HEAD_OFFSET = Vector3(0, 1.7, 0)
const FPS_FORWARD_OFFSET = -0.25 # Pushes camera forward to avoid seeing inside face

# --- STAMINA SETTINGS ---
const MAX_STAMINA = 100.0
const STAMINA_DRAIN_RUN = 20.0 
const STAMINA_COST_ROLL = 25.0 
const STAMINA_REGEN = 10.0 

# --- ANIMATIONS ---
const ANIM_WALK = "CharacterArmature|Walk"
const ANIM_IDLE = "CharacterArmature|Idle_Neutral"
const ANIM_RUN = "CharacterArmature|Run"
const ANIM_AIM_IDLE = "CharacterArmature|Idle_Gun_Pointing"
const ANIM_AIM_RUN = "CharacterArmature|Run_Shoot"
const ANIM_ROLL = "CharacterArmature|Roll"

# --- NODES ---
@onready var name_label = $Label3D
@onready var spring_arm = $SpringArm3D
@onready var anim = $AnimationPlayer
@onready var armature = $CharacterArmature
@onready var eyes = $CharacterArmature/Skeleton3D/HeadAttachment/Eyes
@onready var flashlight_light = %SpotLight3D
@onready var flashlight_mesh = %FlashlightMesh
@onready var interaction_ray = $SpringArm3D/Camera3D/RayCast3D 
@onready var ui_inventory_panel = $UI/Inventory
@onready var ui_stamina_bar = $UI/StaminaBar 

@onready var ui_hotbar_slots = [
	$UI/Hotbar/HBoxContainer/Slot1, 
	$UI/Hotbar/HBoxContainer/Slot2, 
	$UI/Hotbar/HBoxContainer/Slot3
]
@onready var ui_bag_slots = [
	$UI/Inventory/GridContainer/Bag1,
	$UI/Inventory/GridContainer/Bag2,
	$UI/Inventory/GridContainer/Bag3,
	$UI/Inventory/GridContainer/Bag4,
	$UI/Inventory/GridContainer/Bag5,
	$UI/Inventory/GridContainer/Bag6
]

@onready var skins = [ %Skin_Beach, %Skin_Formal, %Skin_Punk ]

# --- DATA ---
var hotbar_data = [0, 0, 0] 
var inventory_data = [0, 0, 0, 0, 0, 0] 
var active_slot_index = 0
var is_first_person = false

# --- STATE VARIABLES ---
var current_stamina = MAX_STAMINA
var is_rolling = false
var roll_vector = Vector3.ZERO # Stores direction for the current roll

@export var current_skin_index = 0:
	set(value):
		current_skin_index = value
		change_skin_visuals(value)

func _enter_tree():
	set_multiplayer_authority(name.to_int())
	add_to_group("player")

func _ready():
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$SpringArm3D/Camera3D.current = true
		
		flashlight_light.visible = false
		flashlight_mesh.visible = false
		ui_inventory_panel.visible = false
		
		if ui_stamina_bar: ui_stamina_bar.max_value = MAX_STAMINA
		update_all_ui()
		
		current_skin_index = randi() % 3
		change_skin_visuals(current_skin_index)
	
	else:
		$SpringArm3D/Camera3D.current = false
		set_physics_process(false)
		set_process_unhandled_input(false)
		name_label.text = "Player " + name
		$UI.visible = false
		change_skin_visuals(current_skin_index)

func change_skin_visuals(index):
	if skins == null or skins.is_empty(): return
	for i in range(skins.size()):
		skins[i].visible = (i == index)

func _unhandled_input(event):
	# INVENTORY
	if Input.is_action_just_pressed("ui_focus_next"): 
		ui_inventory_panel.visible = not ui_inventory_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_inventory_panel.visible else Input.MOUSE_MODE_CAPTURED

	# HOTBAR
	if Input.is_key_pressed(KEY_1): set_active_slot(0)
	if Input.is_key_pressed(KEY_2): set_active_slot(1)
	if Input.is_key_pressed(KEY_3): set_active_slot(2)

	# ACTIONS
	if Input.is_action_just_pressed("right_click"): toggle_flashlight()
	if Input.is_action_just_pressed("interact"): try_pickup_item()
	if Input.is_key_pressed(KEY_V): toggle_camera_mode()
	
	# ROLL ACTION
	if Input.is_action_just_pressed("roll"):
		attempt_roll()

	# MOUSE LOOK
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_first_person:
			spring_arm.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/4, PI/4)
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			armature.rotation.y = 0 
		else:
			spring_arm.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			spring_arm.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/4, PI/4)

# --- ACTION LOGIC ---
func attempt_roll():
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if not is_rolling and input_dir != Vector2.ZERO and current_stamina >= STAMINA_COST_ROLL:
		is_rolling = true
		current_stamina -= STAMINA_COST_ROLL
		
		# 1. Get Camera's Global Y Rotation
		var cam_y_rot = spring_arm.global_rotation.y
		
		# 2. Calculate World Direction based on Camera
		# We rotate the input vector by the camera's facing direction
		var world_direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, cam_y_rot).normalized()
		
		# 3. Store the World Vector for the physics process to use
		roll_vector = world_direction
		
		# 4. Snap Mesh Rotation (CRITICAL FIX)
		# We calculate the angle the move is facing in World Space
		var target_world_angle = atan2(world_direction.x, world_direction.z)
		# We convert it to Local Space by subtracting the Body's rotation
		armature.rotation.y = angle_difference(global_rotation.y, target_world_angle)
		
		anim.play(ANIM_ROLL, 0.1,1.5)
		await anim.animation_finished
		is_rolling = false

# --- CAMERA LOGIC ---
func toggle_camera_mode():
	is_first_person = not is_first_person
	
	# ALWAYS parent to self now (fixes bobbing)
	if spring_arm.get_parent() != self:
		spring_arm.reparent(self)

	if is_first_person:
		spring_arm.rotation = Vector3(0, PI, 0) 
		spring_arm.spring_length = 0
	else:
		spring_arm.position = Vector3(0, 1.5, 0)
		spring_arm.rotation = Vector3.ZERO
		spring_arm.spring_length = 1.0 # Change this value to 5.0 or 6.0 for a larger camera distance

# --- ITEM LOGIC ---
func set_active_slot(index):
	active_slot_index = index
	var item = hotbar_data[active_slot_index]
	
	if item == 1: 
		flashlight_mesh.visible = true
		flashlight_light.visible = false 
	else:
		flashlight_mesh.visible = false
		flashlight_light.visible = false
	update_all_ui()

func toggle_flashlight():
	if hotbar_data[active_slot_index] == 1:
		flashlight_light.visible = not flashlight_light.visible

func try_pickup_item():
	if interaction_ray.is_colliding():
		var object = interaction_ray.get_collider()
		if object.is_in_group("pickable"):
			var item_id = object.item_id if "item_id" in object else 1
			for i in range(hotbar_data.size()):
				if hotbar_data[i] == 0:
					hotbar_data[i] = item_id
					object.queue_free()
					update_all_ui()
					call_deferred("set_active_slot", active_slot_index)
					return
			for i in range(inventory_data.size()):
				if inventory_data[i] == 0:
					inventory_data[i] = item_id
					object.queue_free()
					update_all_ui()
					return

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

func update_all_ui():
	for i in range(3):
		ui_hotbar_slots[i].texture = get_item_icon(hotbar_data[i])
		ui_hotbar_slots[i].modulate = Color(1, 1, 0) if i == active_slot_index else Color(1, 1, 1)
	for i in range(6):
		ui_bag_slots[i].texture = get_item_icon(inventory_data[i])

func get_item_icon(id):
	if id == 1: return preload("res://icon.svg") 
	if id == 2: return preload("res://icon.svg") 
	return null

# --- PHYSICS ---
func _physics_process(delta):
	# Add Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- STAMINA MANAGEMENT ---
	var is_sprinting = Input.is_action_pressed("sprint")
	
	if is_rolling:
		pass 
	elif is_sprinting and velocity.length() > 0:
		current_stamina -= STAMINA_DRAIN_RUN * delta
		if current_stamina < 0: 
			current_stamina = 0
			is_sprinting = false 
	else:
		current_stamina = move_toward(current_stamina, MAX_STAMINA, STAMINA_REGEN * delta)
	
	if ui_stamina_bar: ui_stamina_bar.value = current_stamina

	# --- MOVEMENT CALCULATION ---
	
	# --- MOVEMENT CALCULATION ---
	
	if is_rolling:
		velocity.x = roll_vector.x * ROLL_SPEED
		velocity.z = roll_vector.z * ROLL_SPEED
		
	else:
		# STANDARD MOVEMENT
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
		if input_dir:
			# 1. Get Camera Rotation
			var cam_y_rot = spring_arm.global_rotation.y
			
			# 2. Calculate Direction relative to Camera (Universal Fix)
			var direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, cam_y_rot).normalized()
			
			# Speed Logic
			var current_speed = WALK_SPEED
			if is_sprinting and current_stamina > 0: 
				current_speed = RUN_SPEED
				
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			
			# Rotation Logic
			if not is_first_person:
				# TPS: Rotate mesh to face movement
				var target_world_angle = atan2(direction.x, direction.z)
				# Convert to local space for the armature
				var local_target = angle_difference(global_rotation.y, target_world_angle)
				armature.rotation.y = lerp_angle(armature.rotation.y, local_target, 0.15)
			else:
				# FPS: Mesh always aligns with body (reset to 0)
				armature.rotation.y = lerp_angle(armature.rotation.y, 0, 0.15)
			
			# Animations
			var is_holding_flashlight = (hotbar_data[active_slot_index] == 1)
			if current_speed == RUN_SPEED:
				if is_holding_flashlight:
					if anim.current_animation != ANIM_AIM_RUN: anim.play(ANIM_AIM_RUN)
				else:
					if anim.current_animation != ANIM_RUN: anim.play(ANIM_RUN)
			else:
				if anim.current_animation != ANIM_WALK: anim.play(ANIM_WALK)

		else:
			# Decelerate
			velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
			velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
			
			# Reset Armature Rotation slightly when idle
			if not is_rolling:
				armature.rotation.y = lerp_angle(armature.rotation.y, 0, 0.1)
			
			var is_holding_flashlight = (hotbar_data[active_slot_index] == 1)
			if is_holding_flashlight:
				if anim.current_animation != ANIM_AIM_IDLE: anim.play(ANIM_AIM_IDLE, 0.2)
			else:
				if anim.current_animation != ANIM_IDLE: anim.play(ANIM_IDLE, 0.2)

	move_and_slide()
	
	# FPS Head Bob & Clipping Logic
	if is_first_person:
		# Calculate Steady position (attached to body)
		var steady_position = global_position + Vector3(0, HEAD_OFFSET.y, 0)
		# Calculate Real eye position (bouncing)
		var real_eye_position = eyes.global_position
		
		# Blend them
		var final_pos = steady_position.lerp(real_eye_position, BOB_INTENSITY)
		
		# Push forward to avoid clipping
		final_pos += -global_basis.z * FPS_FORWARD_OFFSET
		
		spring_arm.global_position = final_pos
		
# --- MULTIPLAYER NAME SYNC ---
@rpc("call_local", "reliable")
func set_player_name(p_name):
	# Update the 3D Label above head
	if name_label:
		name_label.text = p_name
