extends Node2D

# Manages puzzle game: spawns shapes, tracks completion, timer

@export var play_area_size: Vector2 = Vector2(1280, 720)
@export var shape_preview_duration: float = 1.0
@export var tile_scene: PackedScene = preload("res://Scenes/Tile.tscn")

# --- NEW: window / scaling + tile friction + snapped collision behavior ---
@export var target_window_size: Vector2i = Vector2i(320, 180)
@export var use_integer_scale: bool = true
@export var tile_friction: float = 2.5
@export var tile_bounce: float = 0.0
@export var disable_collision_when_snapped: bool = true
@export var freeze_tile_when_snapped: bool = true
# ------------------------------------------------------------------------

var current_shapes: Array[String] = []
var current_shape_index: int = 0
var tiles: Array[RigidBody2D] = []
var tile_slots: Array[Node2D] = []
var shape_center: Vector2 = Vector2.ZERO
var timer: float = 0.0
var timer_active: bool = false

@onready var timer_label: Label = $UI/TimerLabel
@onready var shape_display: Node2D = $ShapeDisplay
@onready var player: CharacterBody2D = $Player

signal all_shapes_completed
signal timer_expired
signal shape_completed

func _ready():
	# --- Set window resolution to 320x180 (pixel-art friendly) ---
	_apply_window_settings()
	# ------------------------------------------------------------

	# Get current act data
	var act_data = GameManager.get_current_act_data()
	if act_data.is_empty():
		push_error("No act data found!")
		return

	var shapes_data = act_data.get("shapes", [])
	current_shapes.assign(shapes_data)
	timer = act_data.get("timer", 45.0)

	GameManager.total_shapes_in_act = current_shapes.size()

	# Position player at center and hide initially
	shape_center = play_area_size / 2
	if player:
		player.global_position = shape_center
		player.visible = false
		player.can_move = false

	# Start with first shape
	start_next_shape()

func _process(delta):
	if timer_active:
		timer -= delta
		update_timer_display()

		if timer <= 0:
			timer_active = false
			timer_expired.emit()

func start_next_shape():
	"""Begin the next shape puzzle"""
	if current_shape_index >= current_shapes.size():
		# All shapes completed
		all_shapes_completed.emit()
		return

	var shape_name = current_shapes[current_shape_index]

	# Show preview
	await show_shape_preview(shape_name)

	# Split and scatter
	spawn_and_scatter_tiles(shape_name)

	# Start timer
	timer_active = true

func show_shape_preview(shape_name: String):
	"""Display the complete shape for 1 second"""
	# Create visual of complete shape at center
	var preview = create_shape_preview(shape_name)
	shape_display.add_child(preview)

	await get_tree().create_timer(shape_preview_duration).timeout

	# Remove preview
	preview.queue_free()

func create_shape_preview(shape_name: String) -> Node2D:
	"""Create a visual representation of the complete 3x3 shape"""
	var container = Node2D.new()
	container.position = shape_center

	# Load the complete 48x48 shape texture
	var shape_texture = load_shape_texture(shape_name)

	if shape_texture:
		# Show the complete shape as one sprite
		var sprite = Sprite2D.new()
		sprite.texture = shape_texture
		sprite.position = Vector2.ZERO
		container.add_child(sprite)
	else:
		# Fallback: Create 3x3 grid of colored tiles
		for y in range(3):
			for x in range(3):
				var tile_visual = Sprite2D.new()
				tile_visual.position = Vector2(x * 16 - 16, y * 16 - 16)

				# Placeholder: random color for each tile
				var color_rect = ColorRect.new()
				color_rect.size = Vector2(16, 16)
				color_rect.color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0))
				color_rect.position = Vector2(-8, -8)

				tile_visual.add_child(color_rect)
				container.add_child(tile_visual)

	return container

func spawn_and_scatter_tiles(shape_name: String):
	"""Create 9 tiles and scatter them randomly"""
	# Load shape texture (48x48 PNG)
	var shape_texture = load_shape_texture(shape_name)

	# Calculate correct positions (3x3 grid centered)
	var correct_positions: Array[Vector2] = []
	for y in range(3):
		for x in range(3):
			var pos = shape_center + Vector2(x * 16 - 16, y * 16 - 16)
			correct_positions.append(pos)

	# Create tile slots (render behind tiles)
	create_tile_slots(correct_positions)

	# Create tiles at their correct grid positions first
	for i in range(9):
		var tile = tile_scene.instantiate()

		# Calculate which part of the 48x48 texture this tile uses
		var tile_x = i % 3
		var tile_y = i / 3
		var tile_texture = extract_tile_texture(shape_texture, tile_x, tile_y)

		# Setup tile data BEFORE adding to tree
		tile.shape_id = shape_name
		tile.tile_index = i
		tile.correct_position = correct_positions[i]

		# Add to tree (this triggers _ready)
		add_child(tile)

		# Apply friction / material so tiles don't slide like on ice
		_apply_tile_friction(tile)

		# Set texture/sprite after node is in tree
		var sprite = tile.get_node("Sprite2D")
		if tile_texture:
			sprite.texture = tile_texture
		else:
			# Placeholder: colored square
			var color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0), 1.0)
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(color)
			var texture = ImageTexture.create_from_image(img)
			sprite.texture = texture

		# Position tile at its CORRECT position in the 3x3 grid
		tile.global_position = correct_positions[i]

		# FREEZE tiles immediately to prevent any physics movement before scatter
		tile.freeze = true

		# Connect snapped signal
		tile.tile_snapped.connect(_on_tile_snapped)

		tiles.append(tile)

	# Wait a moment so tiles are visible in grid formation
	await get_tree().create_timer(0.3).timeout

	# Now scatter them from their grid positions with velocity
	for tile in tiles:
		# Unfreeze and enable collision for tiles
		tile.freeze = false
		tile.collision_layer = 2
		tile.collision_mask = 7

		var scatter_pos = get_random_scatter_position()
		tile.scatter_to(scatter_pos)

	# Show player after 2.0 second delay (let tiles scatter and settle)
	await get_tree().create_timer(2.0).timeout
	if player:
		# Player enters from bottom
		var entry_pos = Vector2(shape_center.x, play_area_size.y + 50)
		# Target is below the shape with offset
		var target_pos = Vector2(shape_center.x, shape_center.y + 60)
		player.start_entrance(entry_pos, target_pos)

func load_shape_texture(shape_name: String) -> Texture2D:
	"""Load 48x48 shape texture from Assets/Shapes/"""
	var path = "res://Assets/Shapes/" + shape_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	else:
		# Return null if not found, tile will use placeholder
		return null

func extract_tile_texture(shape_texture: Texture2D, tile_x: int, tile_y: int) -> Texture2D:
	"""Extract a 16x16 tile from the 48x48 shape texture"""
	if shape_texture == null:
		return null

	# Create AtlasTexture to represent one tile from the shape
	var atlas = AtlasTexture.new()
	atlas.atlas = shape_texture
	atlas.region = Rect2(tile_x * 16, tile_y * 16, 16, 16)
	return atlas

func get_random_scatter_position() -> Vector2:
	"""Get a random position within play area, away from center"""
	var margin = 100
	var attempts = 0
	var max_attempts = 20

	while attempts < max_attempts:
		var x = randf_range(margin, play_area_size.x - margin)
		var y = randf_range(margin, play_area_size.y - margin)
		var pos = Vector2(x, y)

		# Ensure it's far enough from center (increased distance)
		if pos.distance_to(shape_center) > 150:
			return pos

		attempts += 1

	# Fallback - ensure good spread in all directions
	var angle = randf() * TAU  # Random angle in radians (0 to 2*PI)
	var distance = randf_range(150, 250)  # Distance from center
	return shape_center + Vector2(cos(angle), sin(angle)) * distance

func create_tile_slots(positions: Array[Vector2]):
	"""Create visual slot indicators at tile positions"""
	for i in range(positions.size()):
		var slot = Node2D.new()
		slot.set_script(load("res://Scripts/tile_slot.gd"))
		add_child(slot)
		slot.setup(i, positions[i])
		tile_slots.append(slot)

func _on_tile_snapped(index: int):
	"""Called when a tile snaps into place"""
	# Update slot visual
	if index < tile_slots.size():
		tile_slots[index].set_filled(true)

	# NEW: make the snapped tile stop blocking the player / other tiles
	# We identify snapped tiles by their tile_index == slot index.
	if disable_collision_when_snapped:
		for tile in tiles:
			# tile.tile_index exists in your flow; no renaming.
			if tile.tile_index == index:
				_disable_tile_collision(tile)
				if freeze_tile_when_snapped:
					tile.freeze = true
				break

	# Check if all tiles are snapped
	var all_snapped = true
	for tile in tiles:
		if not tile.is_snapped:
			all_snapped = false
			break

	if all_snapped:
		complete_current_shape()

func complete_current_shape():
	"""Current shape is complete, move to next"""
	var shape_name = current_shapes[current_shape_index]

	# Hide player during transition
	if player:
		player.visible = false
		player.can_move = false

	# Clear tiles
	for tile in tiles:
		tile.queue_free()
	tiles.clear()

	# Clear slots
	for slot in tile_slots:
		slot.queue_free()
	tile_slots.clear()

	# Update game state
	GameManager.complete_shape(shape_name)
	shape_completed.emit()

	current_shape_index += 1

	# Check if all shapes done
	if current_shape_index >= current_shapes.size():
		timer_active = false
		all_shapes_completed.emit()
	else:
		# Next shape
		start_next_shape()

func restart_puzzle():
	"""Restart current puzzle after timer expires"""
	# Hide player during restart
	if player:
		player.visible = false
		player.can_move = false

	# Clear tiles
	for tile in tiles:
		tile.queue_free()
	tiles.clear()

	# Clear slots
	for slot in tile_slots:
		slot.queue_free()
	tile_slots.clear()

	# Reset timer
	var act_data = GameManager.get_current_act_data()
	timer = act_data.get("timer", 45.0)

	# Restart same shape
	current_shape_index = max(0, current_shape_index)
	start_next_shape()

func update_timer_display():
	"""Update the timer UI"""
	if timer_label:
		var minutes = int(timer) / 60
		var seconds = int(timer) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

		# Warning color when low
		if timer < 10:
			timer_label.modulate = Color(1, 0.3, 0.3)
		else:
			timer_label.modulate = Color(1, 1, 1)

func _on_all_shapes_completed():
	"""All shapes in act are done, move to mind puzzle"""
	# Transition to dialogue for mind puzzle
	get_tree().change_scene_to_file("res://Scenes/Dialogue.tscn")

func _on_timer_expired():
	"""Timer ran out, restart puzzle"""
	restart_puzzle()

# ============================================================
# Helper functions (NEW) - no renaming of your existing vars
# ============================================================

func _apply_window_settings():
	# Sets actual window size. For pixel-art you usually also set viewport stretch in Project Settings,
	# but this at least enforces the base window size from code.
	if target_window_size.x > 0 and target_window_size.y > 0:
		DisplayServer.window_set_size(target_window_size)

	# If you want pixel-perfect integer scaling, it is best done in:
	# Project Settings -> Display -> Window -> Stretch:
	#   Mode = canvas_items, Aspect = keep, Scale = integer
	# BUT we can approximate by snapping the window scale to an integer factor here.
	if use_integer_scale:
		var screen_size: Vector2i = Vector2i(DisplayServer.screen_get_size())

		var tw: int = int(target_window_size.x)
		var th: int = int(target_window_size.y)
		if tw <= 0: tw = 1
		if th <= 0: th = 1

		var scale_x: int = int(screen_size.x / tw)
		var scale_y: int = int(screen_size.y / th)
		var scale: int = int(min(scale_x, scale_y))
		if scale < 1:
			scale = 1

		var final_size: Vector2i = Vector2i(int(target_window_size.x) * scale, int(target_window_size.y) * scale)
		DisplayServer.window_set_size(final_size)

func _apply_tile_friction(tile: RigidBody2D):
	# PhysicsMaterial in Godot 4 (2D) is applied via physics_material_override on CollisionObject2D (RigidBody2D here)
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = tile_friction
	mat.bounce = tile_bounce

	tile.physics_material_override = mat

	# Optional but very helpful: reduces "ice sliding" by damping movement/rotation
	# You can tune these or export them if you want later.
	tile.linear_damp = 10.0
	tile.angular_damp = 10.0

func _disable_tile_collision(tile: RigidBody2D):
	# Easiest reliable way: remove it from all layers/masks so it stops blocking.
	# (Works without needing to know what else is in the world.)
	tile.collision_layer = 0
	tile.collision_mask = 0

	# Optional extra: if the tile has a CollisionShape2D, disable it too.
	var cs := tile.get_node_or_null("CollisionShape2D")
	if cs and cs is CollisionShape2D:
		cs.disabled = true
