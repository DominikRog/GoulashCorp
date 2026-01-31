extends RigidBody2D

# Tile piece for puzzle game

@export var tile_size: int = 16
@export var snap_threshold: float = 8.0  # Distance to snap to correct position
@export var snap_force: float = 300.0

# --- NEW: smooth snap settings ---
@export var snap_duration: float = 0.14       # how long the "slide" takes
@export var snap_deadzone: float = 1.0        # small zone to avoid micro jitter
# -------------------------------

var correct_position: Vector2 = Vector2.ZERO
var is_snapped: bool = false
var tile_index: int = 0  # Index in 3x3 grid (0-8)
var shape_id: String = ""  # Which shape this tile belongs to
var can_snap: bool = false  # Prevent snapping until scattered

# --- NEW: internal state ---
var _is_snapping: bool = false
var _snap_tween: Tween = null
# ---------------------------

signal tile_snapped(index: int)

func _ready():
	# Physics setup for pushing
	mass = 2.0
	gravity_scale = 0.0  # Top-down, no gravity
	linear_damp = 3.0  # Slow down naturally
	angular_damp = 8.0  # Higher damping to prevent crazy spinning
	lock_rotation = false  # Allow natural rotation

	# Add some bounce for walls, but not too much
	var physics_mat = PhysicsMaterial.new()
	physics_mat.bounce = 0.3  # Moderate bounce off walls
	physics_material_override = physics_mat

func _physics_process(_delta):
	if is_snapped or not can_snap or _is_snapping:
		return

	# Check if tile is close enough to snap
	var distance: float = global_position.distance_to(correct_position)
	if distance < snap_threshold:
		_start_smooth_snap()

func _start_smooth_snap():
	"""Smoothly slide tile into correct position, then lock it."""
	if is_snapped or _is_snapping:
		return

	_is_snapping = true

	# Stop physics motion immediately so it doesn't fight the tween
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true

	# If there is an old tween (safety), kill it
	if _snap_tween != null:
		_snap_tween.kill()
		_snap_tween = null

	# Create tween to slide into place
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_SINE)
	_snap_tween.set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(self, "global_position", correct_position, snap_duration)
	_snap_tween.parallel().tween_property(self, "rotation", 0.0, snap_duration)  # Also reset rotation

	_snap_tween.finished.connect(func() -> void:
		# Ensure exact final alignment
		global_position = correct_position
		rotation = 0.0  # Reset rotation to align properly

		is_snapped = true
		_is_snapping = false
		_snap_tween = null

		# Emit AFTER arriving so PuzzleManager can safely disable collisions, etc.
		tile_snapped.emit(tile_index)
	)

# Kept for compatibility if something calls it directly
func snap_to_position():
	"""Lock tile in correct position (now smooth)."""
	_start_smooth_snap()

func scatter_to(target_pos: Vector2):
	"""Throw tile toward target with physics velocity"""
	# Cancel any snapping in progress (e.g., if reused or restarted)
	_is_snapping = false
	if _snap_tween != null:
		_snap_tween.kill()
		_snap_tween = null

	is_snapped = false
	freeze = false
	can_snap = false

	var direction: Vector2 = (target_pos - global_position).normalized()
	# Add more angle spread for better distribution
	direction = direction.rotated(randf_range(-0.6, 0.6))
	var speed: float = randf_range(1000.0, 1300.0)
	linear_velocity = direction * speed

	# Add gentle random angular velocity for natural tumbling (not crazy spinning)
	angular_velocity = randf_range(-2.0, 2.0)

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
	var polygons = bitmap.opaque_to_polygons(Rect2(0, 0, tile_size, tile_size), 2.0)  # 2.0 = epsilon

	# Track if we created any collision shapes
	var collision_created: bool = false

	# Create CollisionPolygon2D for each polygon
	for polygon in polygons:
		if polygon.size() < 3:
			continue  # Skip invalid polygons

		var collision_polygon = CollisionPolygon2D.new()

		# Center the polygon coordinates
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
