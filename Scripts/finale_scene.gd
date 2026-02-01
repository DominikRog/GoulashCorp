extends Node2D

# Final cinematic scene after Act 6 completion

@export var zoom_duration: float = 2.0
@export var text_duration: float = 2.5
@export var explosion_delay: float = 1.0
@export var end_screen_duration: float = 3.0
@export var tile_scene: PackedScene = preload("res://Scenes/Tile.tscn")
@export var scatter_force_min: float = 300.0
@export var scatter_force_max: float = 600.0
@export var typewriter_speed: float = 0.05  # Seconds per character

@onready var camera: Camera2D = $Camera2D
@onready var king_sprite: Sprite2D = $King
@onready var dialogue_label: Label = $UI/DialogueLabel
@onready var end_screen: ColorRect = $UI/EndScreen

var play_area_size: Vector2 = Vector2(320, 176)
var is_typing: bool = false
var current_text: String = ""
var current_char_index: float = 0.0

func _ready():
	# Hide UI elements initially
	dialogue_label.visible = false
	dialogue_label.modulate.a = 0.0
	end_screen.visible = false
	end_screen.modulate.a = 0.0

	# Position king at center
	var center = play_area_size / 2.0
	king_sprite.global_position = center

	# Load king sprite
	_load_king_sprite()

	# Scale up king sprite so it's big enough to split into pieces
	king_sprite.scale = Vector2(3.0, 3.0)  # Make king 3x larger (48x48 pixels)

	# Camera starts at center with normal zoom
	camera.global_position = center
	camera.zoom = Vector2(1.0, 1.0)

	# Wait a frame for scene setup
	await get_tree().process_frame

	# Fade from black (if coming from blackout transition)
	if BlackoutManager.is_black():
		await get_tree().create_timer(0.2).timeout
		await BlackoutManager.fade_from_black(0.5)

	# Start the sequence
	await get_tree().create_timer(0.5).timeout
	start_finale_sequence()

func _process(delta: float):
	# Typewriter effect
	if is_typing:
		current_char_index += delta / typewriter_speed
		var chars_to_show = int(current_char_index)
		if chars_to_show >= current_text.length():
			# Finished typing
			dialogue_label.text = current_text
			is_typing = false
		else:
			dialogue_label.text = current_text.substr(0, chars_to_show)

func _load_king_sprite():
	"""Load the king character sprite"""
	var sprite_path = "res://Assets/king_full.png"
	if ResourceLoader.exists(sprite_path):
		var full_texture = load(sprite_path)

		# King sprite is a 4-frame animation strip, use just first frame
		if full_texture:
			var img = full_texture.get_image()
			if img:
				var frame_width = img.get_width() / 4  # 4 frames
				var frame_height = img.get_height()

				# Extract first frame using AtlasTexture
				var atlas = AtlasTexture.new()
				atlas.atlas = full_texture
				atlas.region = Rect2(0, 0, frame_width, frame_height)
				king_sprite.texture = atlas
			else:
				king_sprite.texture = full_texture
		else:
			_load_fallback_sprite()
	else:
		_load_fallback_sprite()

func _load_fallback_sprite():
	"""Load fallback sprite if king not found"""
	# Create placeholder colored rect
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.6, 0.2, 1.0))  # Golden color for king
	king_sprite.texture = ImageTexture.create_from_image(img)

func start_finale_sequence():
	"""Run the full finale sequence"""
	# 1. Zoom to king
	await zoom_to_king()

	# 2. Show first dialogue
	await show_dialogue("Kingdom is yours")

	# 3. Show second dialogue
	await show_dialogue("Or is it?")

	# 4. Wait a moment
	await get_tree().create_timer(explosion_delay).timeout

	# 5. Explode king into tiles
	await explode_king()

	# 6. Show end screen
	await show_end_screen()

	# 7. Return to main menu
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func zoom_to_king():
	"""Zoom camera to king smoothly"""
	var tween = create_tween()
	tween.set_parallel(true)
	# Zoom to 2x for small resolution (320x176)
	tween.tween_property(camera, "zoom", Vector2(2.0, 2.0), zoom_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func show_dialogue(text: String):
	"""Show dialogue text with typewriter effect"""
	current_text = text
	current_char_index = 0.0
	dialogue_label.text = ""
	dialogue_label.visible = true
	dialogue_label.modulate.a = 1.0

	# Start typewriter effect
	is_typing = true

	# Wait for typing to complete
	while is_typing:
		await get_tree().create_timer(0.1).timeout

	# Hold the complete text
	await get_tree().create_timer(text_duration).timeout

	# Fade out
	var tween_out = create_tween()
	tween_out.tween_property(dialogue_label, "modulate:a", 0.0, 0.5)
	await tween_out.finished

	dialogue_label.visible = false
	dialogue_label.modulate.a = 1.0  # Reset for next use

func explode_king():
	"""Break king sprite into tiles and scatter them"""
	var king_texture = king_sprite.texture
	var king_scale = king_sprite.scale

	# Hide original sprite
	king_sprite.visible = false

	# Get king position
	var king_pos = king_sprite.global_position

	# Determine texture size (handles AtlasTexture)
	var texture_size = Vector2(16, 16)  # Default for character sprites
	if king_texture:
		if king_texture is AtlasTexture:
			var atlas = king_texture as AtlasTexture
			texture_size = atlas.region.size
		else:
			var img = king_texture.get_image()
			if img:
				texture_size = Vector2(img.get_width(), img.get_height())

	# Create tiles - use smaller tile size for more pieces
	# King is 16x16, split into 8x8 tiles = 2x2 grid (4 pieces)
	var tile_size = 8
	var grid_cols = max(2, int(texture_size.x / tile_size))
	var grid_rows = max(2, int(texture_size.y / tile_size))

	print("King texture size: ", texture_size, " scaled to ", texture_size * king_scale, " - Creating ", grid_cols, "x", grid_rows, " grid with ", tile_size, "px tiles")

	var tiles: Array[RigidBody2D] = []

	# Calculate scaled tile size for positioning
	var scaled_tile_size = tile_size * king_scale.x

	for y in range(grid_rows):
		for x in range(grid_cols):
			var tile = tile_scene.instantiate()
			add_child(tile)

			# Position at king's location (in grid formation) accounting for scale
			var total_width  = grid_cols * scaled_tile_size
			var total_height = grid_rows * scaled_tile_size

			var offset = Vector2(
				x * scaled_tile_size + scaled_tile_size / 2.0 - total_width / 2.0,
				y * scaled_tile_size + scaled_tile_size / 2.0 - total_height / 2.0
			)

			tile.global_position = king_pos + offset

			# Extract tile texture
			var sprite = tile.get_node("Sprite2D")
			# Apply same scale as king sprite
			sprite.scale = king_scale

			if king_texture:
				# Get the base texture for extraction
				var base_texture = king_texture
				var offset_x = 0
				var offset_y = 0

				# If it's an atlas, get the atlas texture and offset
				if king_texture is AtlasTexture:
					var atlas = king_texture as AtlasTexture
					base_texture = atlas.atlas
					offset_x = int(atlas.region.position.x)
					offset_y = int(atlas.region.position.y)

				# Extract tile from texture
				var tile_texture = extract_tile_texture_with_offset(base_texture, x, y, tile_size, offset_x, offset_y)
				if tile_texture:
					sprite.texture = tile_texture
				else:
					# Random colored tile as fallback
					var color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0))
					var img = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
					img.fill(color)
					sprite.texture = ImageTexture.create_from_image(img)
			else:
				# Fallback color
				var color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0))
				var img = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
				img.fill(color)
				sprite.texture = ImageTexture.create_from_image(img)

			# Add collision shape (tile scene doesn't have one by default)
			var collision_shape = CollisionShape2D.new()
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(tile_size, tile_size)
			collision_shape.shape = rect_shape
			tile.add_child(collision_shape)

			# Make tile physics-enabled
			tile.freeze = false
			tile.collision_layer = 2
			tile.collision_mask = 4  # Only collide with walls
			tile.gravity_scale = 0.0

			tiles.append(tile)

	# Small delay before explosion
	await get_tree().create_timer(0.2).timeout

	# Apply random forces to scatter tiles
	for tile in tiles:
		var angle = randf() * TAU
		var force = randf_range(scatter_force_min, scatter_force_max)
		var direction = Vector2(cos(angle), sin(angle))
		tile.apply_central_impulse(direction * force)

		# Add slight rotation
		tile.angular_velocity = randf_range(-10.0, 10.0)

	# Wait for tiles to scatter
	await get_tree().create_timer(2.0).timeout

func extract_tile_texture_with_offset(texture: Texture2D, tile_x: int, tile_y: int, tile_size: int, offset_x: int, offset_y: int) -> Texture2D:
	"""Extract a tile region from the texture with offset support"""
	if texture == null:
		return null

	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(offset_x + tile_x * tile_size, offset_y + tile_y * tile_size, tile_size, tile_size)
	return atlas

func show_end_screen():
	"""Show 'The End' screen with fade in"""
	end_screen.visible = true

	# Fade in
	var tween = create_tween()
	tween.tween_property(end_screen, "modulate:a", 1.0, 1.5)
	await tween.finished

	# Hold
	await get_tree().create_timer(end_screen_duration).timeout
