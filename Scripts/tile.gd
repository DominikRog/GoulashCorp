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
	var speed = randf_range(500.0, 700.0)
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
