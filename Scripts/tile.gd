extends RigidBody2D

# Tile piece for puzzle game

@export var tile_size: int = 16
@export var snap_threshold: float = 8.0  # Distance to snap to correct position
@export var snap_force: float = 300.0

var correct_position: Vector2 = Vector2.ZERO
var is_snapped: bool = false
var tile_index: int = 0  # Index in 3x3 grid (0-8)
var shape_id: String = ""  # Which shape this tile belongs to

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal tile_snapped

func _ready():
	# Physics setup for pushing
	mass = 2.0
	gravity_scale = 0.0  # Top-down, no gravity
	linear_damp = 3.0  # Slow down naturally
	angular_damp = 5.0  # Prevent spinning

func _physics_process(_delta):
	if is_snapped:
		return

	# Check if tile is close enough to snap
	var distance = global_position.distance_to(correct_position)
	if distance < snap_threshold:
		snap_to_position()

func setup(shape_name: String, index: int, correct_pos: Vector2, texture: Texture2D = null):
	"""Initialize tile with its correct position and appearance"""
	shape_id = shape_name
	tile_index = index
	correct_position = correct_pos

	if texture:
		sprite.texture = texture
	else:
		# Placeholder: colored square
		create_placeholder_sprite()

func create_placeholder_sprite():
	"""Create a simple colored square for testing"""
	# Generate a random bright color for visibility
	var color = Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0), 1.0)

	# Create a simple texture
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)

	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture

func snap_to_position():
	"""Lock tile in correct position"""
	if is_snapped:
		return

	is_snapped = true
	global_position = correct_position

	# Disable physics once snapped
	freeze = true

	# Visual feedback
	modulate = Color(1, 1, 1, 1)  # Full brightness when snapped

	tile_snapped.emit()

func scatter_to(target_pos: Vector2):
	"""Move tile to a random position at start"""
	global_position = target_pos
	# Start slightly dimmed
	modulate = Color(0.8, 0.8, 0.8, 1)

func _on_body_entered(body):
	"""Handle collision with player for pushing"""
	if body.name == "Player":
		# Physics will handle the push automatically
		pass
