extends Node2D

# Manages puzzle game: spawns shapes, tracks completion, timer

@export var play_area_size: Vector2 = Vector2(1280, 720)
@export var shape_preview_duration: float = 1.0
@export var tile_scene: PackedScene = preload("res://Scenes/Tile.tscn")

# --- VORONOI CUTTING ---
@export var use_voronoi: bool = true  # Toggle between old grid system and new Voronoi
@export var num_pieces: int = 9  # Number of pieces to cut shape into
@export var debug_show_boundaries: bool = false  # Draw piece boundaries for debugging
var VoronoiCutter = preload("res://Scripts/voronoi_cutter.gd")
# -----------------------

# --- window / scaling + tile friction + snapped collision behavior ---
@export var target_window_size: Vector2i = Vector2i(320, 180)
@export var use_integer_scale: bool = true
@export var tile_friction: float = 2.5
@export var tile_bounce: float = 10.0
@export var disable_collision_when_snapped: bool = true
@export var freeze_tile_when_snapped: bool = true
# --------------------------------------------------------------------

# --- NEW: wall "magnetic" repulsion for tiles ---
@export var wall_repulsion_enabled: bool = true
@export var wall_repulsion_range: float = 16.0          # px from wall where repulsion starts
@export var wall_repulsion_strength: float = 24000.0    # overall strength of the field
@export var wall_repulsion_margin: float = 8.0         # where the "wall line" is inside play area
# ------------------------------------------------

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
	player.entrance_completed.connect(_on_player_entrance_completed)
	# ------------------------------------------------------------

	# Get current act data
	var act_data = GameManager.get_current_act_data()
	if act_data.is_empty():
		push_error("No act data found!")
		return

	var shapes_data = act_data.get("shapes", [])
	current_shapes.assign(shapes_data)
	timer = act_data.get("timer", 60.0)

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

func _physics_process(delta: float) -> void:
	# Apply magnetic-like repulsion from play area edges to tiles
	if wall_repulsion_enabled:
		_apply_wall_repulsion(delta)

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

	# Start timer is triggered when player entrance finishes
	# (see _on_player_entrance_completed)

func _on_player_entrance_completed():
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
	"""Create tiles and scatter them randomly - supports Voronoi or grid mode"""
	# Load shape texture (48x48 PNG)
	var shape_texture = load_shape_texture(shape_name)

	if use_voronoi and shape_texture:
		await spawn_voronoi_tiles(shape_name, shape_texture)
	else:
		await spawn_grid_tiles(shape_name, shape_texture)

func spawn_voronoi_tiles(shape_name: String, shape_texture: Texture2D):
	"""Create tiles using Voronoi cutting algorithm"""
	# Get image data for cutting
	var shape_image = shape_texture.get_image()
	if shape_image == null:
		push_error("Failed to get image from texture")
		await spawn_grid_tiles(shape_name, shape_texture)
		return

	# Cut shape into Voronoi pieces
	var cutter = VoronoiCutter.new()
	var pieces: Array = cutter.cut_shape(shape_image, num_pieces)

	if pieces.is_empty():
		push_error("Voronoi cutting failed, falling back to grid")
		await spawn_grid_tiles(shape_name, shape_texture)
		return

	print("VoronoiCutter: Generated %d pieces" % pieces.size())

	# Create correct positions for each piece (at shape center)
	var correct_positions: Array[Vector2] = []
	for piece in pieces:
		var world_pos = shape_center + piece.centroid - Vector2(24, 24)  # Center the 48x48 shape
		correct_positions.append(world_pos)

	# Create tile slots with Voronoi shapes
	create_voronoi_tile_slots(pieces, correct_positions)

	# Create tiles from Voronoi pieces
	for i in range(pieces.size()):
		var piece = pieces[i]
		var tile = tile_scene.instantiate()

		# Setup tile data BEFORE adding to tree
		tile.shape_id = shape_name
		tile.tile_index = i
		tile.correct_position = correct_positions[i]

		# Add to tree (this triggers _ready)
		add_child(tile)

		# Apply friction
		_apply_tile_friction(tile)

		# Set texture from Voronoi piece
		var sprite = tile.get_node("Sprite2D")
		if piece.texture_region:
			var texture = ImageTexture.create_from_image(piece.texture_region)
			sprite.texture = texture

			# FIXED: Correct sprite offset calculation
			# Sprite is centered by default, so we need to offset it so that
			# the centroid pixel in the texture aligns with the tile position
			var texture_center = Vector2(piece.bounding_rect.size) / 2.0
			var centroid_in_texture = piece.centroid - Vector2(piece.bounding_rect.position)
			sprite.offset = texture_center - centroid_in_texture
		else:
			# Fallback: colored square
			var color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0), 1.0)
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(color)
			var texture_img = ImageTexture.create_from_image(img)
			sprite.texture = texture_img

		# Setup collision from Voronoi boundary
		setup_voronoi_collision(tile, piece)

		# Position tile at correct location
		tile.global_position = correct_positions[i]

		# FREEZE tiles immediately
		tile.freeze = true

		# Connect snapped signal
		tile.tile_snapped.connect(_on_tile_snapped)

		tiles.append(tile)

	# Wait a moment so tiles are visible in formation
	await get_tree().create_timer(0.3).timeout

	# Scatter tiles
	for tile in tiles:
		tile.freeze = false
		tile.collision_layer = 2
		tile.collision_mask = 7

		var scatter_pos = get_random_scatter_position()
		tile.scatter_to(scatter_pos)

	# Show player after delay
	await get_tree().create_timer(2.0).timeout
	if player:
		var entry_pos = Vector2(shape_center.x, play_area_size.y + 50)
		var target_pos = Vector2(shape_center.x, shape_center.y + 60)
		player.start_entrance(entry_pos, target_pos)

func spawn_grid_tiles(shape_name: String, shape_texture: Texture2D):
	"""Create tiles using original 3x3 grid system"""
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
		var tile_image: Image = null

		if tile_texture:
			sprite.texture = tile_texture
			# Extract image data for collision generation
			tile_image = extract_tile_image(shape_texture, tile_x, tile_y)
		else:
			# Placeholder: colored square
			var color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0), 1.0)
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(color)
			var texture = ImageTexture.create_from_image(img)
			sprite.texture = texture
			tile_image = img

		# Setup collision shape from image
		if tile_image:
			tile.setup_collision_from_image(tile_image)

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

func extract_tile_image(shape_texture: Texture2D, tile_x: int, tile_y: int) -> Image:
	"""Extract a 16x16 tile region as Image for collision generation"""
	if shape_texture == null:
		return null

	# Get the full texture as Image
	var full_image = shape_texture.get_image()
	if full_image == null:
		return null

	# Create a new 16x16 image for this tile
	var tile_image = Image.create(16, 16, false, full_image.get_format())

	# Copy the specific 16x16 region from the full image
	tile_image.blit_rect(full_image, Rect2(tile_x * 16, tile_y * 16, 16, 16), Vector2.ZERO)

	return tile_image

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
	"""Create visual slot indicators at tile positions (grid mode)"""
	for i in range(positions.size()):
		var slot = Node2D.new()
		slot.set_script(load("res://Scripts/tile_slot.gd"))
		add_child(slot)
		slot.setup(i, positions[i])
		tile_slots.append(slot)

func create_voronoi_tile_slots(pieces: Array, positions: Array[Vector2]):
	"""Create visual slot indicators showing Voronoi piece shapes"""
	for i in range(pieces.size()):
		var piece = pieces[i]
		var slot = Node2D.new()
		slot.set_script(load("res://Scripts/tile_slot.gd"))
		add_child(slot)

		# Pass piece shape data to slot
		var world_boundary = PackedVector2Array()
		for point in piece.boundary:
			world_boundary.append(shape_center + point - Vector2(24, 24))

		# Calculate sprite offset (same as tile - FIXED)
		var texture_center = Vector2(piece.bounding_rect.size) / 2.0
		var centroid_in_texture = piece.centroid - Vector2(piece.bounding_rect.position)
		var sprite_offset = texture_center - centroid_in_texture

		slot.setup_voronoi(i, positions[i], piece.texture_region, world_boundary, sprite_offset)
		tile_slots.append(slot)

func _on_tile_snapped(index: int):
	"""Called when a tile snaps into place"""
	# Update slot visual
	if index < tile_slots.size():
		tile_slots[index].set_filled(true)

	# Make the snapped tile stop blocking the player / other tiles
	if disable_collision_when_snapped:
		for tile in tiles:
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
	timer += 45.0

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
	timer = act_data.get("timer", 60.0)

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
	get_tree().change_scene_to_file("res://Scenes/Dialogue.tscn")

func _on_timer_expired():
	"""Timer ran out, restart puzzle"""
	restart_puzzle()

# ============================================================
# Helper functions
# ============================================================

func _apply_window_settings():
	if target_window_size.x > 0 and target_window_size.y > 0:
		DisplayServer.window_set_size(target_window_size)

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
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = tile_friction
	mat.bounce = 0.0  # No bounce for puzzle feel

	tile.physics_material_override = mat

	# Keep the damping values set in tile.gd _ready() for natural physics feel
	# (linear_damp = 3.0, angular_damp = 2.0 for natural rotation)

func _disable_tile_collision(tile: RigidBody2D):
	tile.collision_layer = 0
	tile.collision_mask = 0

	for child in tile.get_children():
		if child is CollisionShape2D:
			child.disabled = true
		elif child is CollisionPolygon2D:
			child.disabled = true

func _apply_wall_repulsion(delta: float) -> void:
	# Repel tiles from the play area edges like a magnetic field.
	# Stronger near the wall, fades to zero at wall_repulsion_range.

	var rng: float = wall_repulsion_range
	if rng < 1.0:
		rng = 1.0

	var strength: float = wall_repulsion_strength

	# Define inner "wall lines"
	var left_x: float = wall_repulsion_margin
	var right_x: float = play_area_size.x - wall_repulsion_margin
	var top_y: float = wall_repulsion_margin
	var bottom_y: float = play_area_size.y - wall_repulsion_margin

	for t in tiles:
		var tile: RigidBody2D = t
		if tile == null:
			continue
		if tile.freeze:
			continue
		if tile.collision_layer == 0:
			continue

		var p: Vector2 = tile.global_position
		var force: Vector2 = Vector2.ZERO

		# Left wall
		var dl: float = p.x - left_x
		if dl < rng:
			var k: float = 1.0 - (dl / rng)
			if k > 0.0:
				force.x += strength * k * k

		# Right wall
		var dr: float = right_x - p.x
		if dr < rng:
			var k2: float = 1.0 - (dr / rng)
			if k2 > 0.0:
				force.x -= strength * k2 * k2

		# Top wall
		var dt: float = p.y - top_y
		if dt < rng:
			var k3: float = 1.0 - (dt / rng)
			if k3 > 0.0:
				force.y += strength * k3 * k3

		# Bottom wall
		var db: float = bottom_y - p.y
		if db < rng:
			var k4: float = 1.0 - (db / rng)
			if k4 > 0.0:
				force.y -= strength * k4 * k4

		if force != Vector2.ZERO:
			# Scale by delta so it feels stable across FPS
			tile.apply_central_force(force * delta)

func setup_voronoi_collision(tile: RigidBody2D, piece):
	"""Setup collision polygon from Voronoi piece boundary"""
	# Remove existing collision shapes
	for child in tile.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.queue_free()

	if piece.boundary.is_empty():
		push_warning("Voronoi piece has empty boundary, using fallback collision")
		# Fallback: rectangle
		var fallback_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(16, 16)
		fallback_shape.shape = rect_shape
		tile.add_child(fallback_shape)
		return

	# Create collision polygon from boundary
	var collision_polygon = CollisionPolygon2D.new()

	# Convert boundary to local coordinates (relative to centroid)
	var local_boundary = PackedVector2Array()
	for point in piece.boundary:
		var local_point = point - piece.centroid
		local_boundary.append(local_point)

	collision_polygon.polygon = local_boundary
	tile.add_child(collision_polygon)

	print("Created collision polygon with %d vertices for piece %d" % [local_boundary.size(), piece.id])
