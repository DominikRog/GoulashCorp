extends RigidBody2D

# Tile piece for puzzle game

@export var tile_size: int = 16
@export var snap_threshold: float = 8.0  # Distance to snap to correct position
@export var snap_force: float = 300.0

var correct_position: Vector2 = Vector2.ZERO
var is_snapped: bool = false
var tile_index: int = 0  # Index in 3x3 grid (0-8)
var shape_id: String = ""  # Which shape this tile belongs to
var can_snap: bool = false  # Prevent snapping until scattered

signal tile_snapped(index: int)

func _ready():
	# Physics setup for pushing
	mass = 2.0
	gravity_scale = 0.0  # Top-down, no gravity
	linear_damp = 3.0  # Slow down naturally
	angular_damp = 5.0  # Prevent spinning
	lock_rotation = true  # Prevent tiles from rotating

	# Add bounce for wall/tile collisions
	var physics_mat = PhysicsMaterial.new()
	physics_mat.bounce = 0.5
	physics_material_override = physics_mat

func _physics_process(_delta):
	if is_snapped or not can_snap:
		return

	# Check if tile is close enough to snap
	var distance = global_position.distance_to(correct_position)
	if distance < snap_threshold:
		snap_to_position()


func snap_to_position():
	"""Lock tile in correct position"""
	if is_snapped:
		return

	is_snapped = true
	global_position = correct_position

	# Disable physics once snapped
	freeze = true

	tile_snapped.emit(tile_index)

func scatter_to(target_pos: Vector2):
	"""Throw tile toward target with physics velocity"""
	var direction = (target_pos - global_position).normalized()
	# Add more angle spread for better distribution
	direction = direction.rotated(randf_range(-0.6, 0.6))
	var speed = randf_range(1000.0, 1300.0)
	linear_velocity = direction * speed
	# Add slight random angular velocity for natural movement (but rotation is locked)
	angular_velocity = 0.0  # Keep at 0 since rotation is locked

	# Enable snapping after a delay (when tile has moved away from correct position)
	await get_tree().create_timer(0.5).timeout
	can_snap = true

func _on_body_entered(body):
	"""Handle collision with player for pushing"""
	if body.name == "Player":
		# Physics will handle the push automatically
		pass

func setup_collision_from_image(tile_image: Image):
	"""Generate collision shape from sprite's alpha channel"""
	if tile_image == null:
		push_warning("No image provided for collision generation")
		return

	# Remove existing CollisionShape2D if present
	var old_collision = get_node_or_null("CollisionShape2D")
	if old_collision:
		old_collision.queue_free()

	# Create BitMap from image alpha channel
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(tile_image, 0.1)  # 0.1 = alpha threshold (10%)

	# Generate polygons from opaque pixels
	var polygons = bitmap.opaque_to_polygons(Rect2(0, 0, tile_size, tile_size), 2.0)  # 2.0 = epsilon for simplification

	# Track if we created any collision shapes
	var collision_created = false

	# Create CollisionPolygon2D for each polygon
	for polygon in polygons:
		if polygon.size() < 3:
			continue  # Skip invalid polygons

		var collision_polygon = CollisionPolygon2D.new()

		# Center the polygon coordinates
		# BitMap coords are 0-16, we want -8 to 8 for centered sprite
		var centered_polygon = PackedVector2Array()
		for point in polygon:
			centered_polygon.append(point - Vector2(tile_size / 2.0, tile_size / 2.0))

		collision_polygon.polygon = centered_polygon
		add_child(collision_polygon)
		collision_created = true

	# If no valid polygons were created, fall back to rectangle
	if not collision_created:
		push_warning("No collision polygons generated, using rectangle fallback")
		var fallback_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(tile_size, tile_size)
		fallback_shape.shape = rect_shape
		add_child(fallback_shape)
