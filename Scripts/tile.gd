extends RigidBody2D

# Tile piece for puzzle game

@export var tile_size: int = 16
@export var snap_threshold: float = 8.0  # Distance to snap to correct position
@export var snap_force: float = 300.0

# --- NEW: require correct rotation to snap ---
@export var require_correct_rotation_for_snap: bool = true
@export var snap_rotation_threshold_degrees: float = 10.0   # tolerancja kąta do snap (np. 10 stopni)
# --- NEW: smooth snap ---
@export var snap_duration: float = 0.16
@export var snap_rotation_duration: float = 0.24
@export var snap_delay_after_scatter: float = 0.5
# --------------------------------------------

var correct_position: Vector2 = Vector2.ZERO
var is_snapped: bool = false
var tile_index: int = 0  # Index in 3x3 grid (0-8)
var shape_id: String = ""  # Which shape this tile belongs to
var can_snap: bool = false  # Prevent snapping until scattered

# NEW: store correct/original rotation (set by PuzzleManager)
var correct_rotation: float = 0.0
func get_correct_rotation() -> float:
	return correct_rotation

# --- internal ---
var _is_snapping: bool = false
var _snap_tween: Tween = null
@onready var snap_sound: AudioStreamPlayer2D = $CorrectTile
# ---------------------------

signal tile_snapped(index: int)

func _ready():
	mass = 2.0
	gravity_scale = 0.0  # Top-down, no gravity

	# Damping (feel)
	linear_damp = 3.0
	angular_damp = 5.0

	# rotation unlocked (bo chcesz swobodne rotacje)
	# lock_rotation = false

	var physics_mat: PhysicsMaterial = PhysicsMaterial.new()
	physics_mat.bounce = 0.5
	physics_material_override = physics_mat

func _physics_process(_delta):
	if is_snapped or not can_snap or _is_snapping:
		return

	# 1) dystans
	var distance: float = global_position.distance_to(correct_position)
	if distance > snap_threshold:
		return

	# 2) kąt (opcjonalnie)
	if require_correct_rotation_for_snap:
		var ang_err: float = abs(_angle_delta(rotation, correct_rotation))
		var thr: float = deg_to_rad(snap_rotation_threshold_degrees)
		if ang_err > thr:
			return

	# jeśli oba warunki spełnione -> płynnie dosnapuj
	_start_smooth_snap()

func _start_smooth_snap():
	if is_snapped or _is_snapping:
		return

	_is_snapping = true

	# zatrzymaj fizykę zanim zaczniemy tween
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true

	if _snap_tween != null:
		_snap_tween.kill()
		_snap_tween = null
		
	if snap_sound:
		snap_sound.pitch_scale = randf_range(0.95, 1.05)
		snap_sound.play()

	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_SINE)
	_snap_tween.set_ease(Tween.EASE_IN_OUT)

	# pozycja
	_snap_tween.tween_property(self, "global_position", correct_position, snap_duration)

	# rotacja (też płynnie, ale zwykle wolniej)
	# ustawiamy target tak, by obrót poszedł najkrótszą drogą
	var target_rot: float = _wrap_angle_near(correct_rotation, rotation)
	_snap_tween.parallel().tween_property(self, "rotation", target_rot, snap_rotation_duration)

	_snap_tween.finished.connect(func() -> void:
		global_position = correct_position
		rotation = correct_rotation
		is_snapped = true
		_is_snapping = false
		_snap_tween = null

		# zostaje zamrożone (PuzzleManager dodatkowo wyłączy kolizję, jak masz)
		freeze = true

		tile_snapped.emit(tile_index)
	)

func snap_to_position():
	# zachowujemy kompatybilność z istniejącym wywołaniem
	_start_smooth_snap()

func scatter_to(target_pos: Vector2):
	# reset stanu
	_is_snapping = false
	if _snap_tween != null:
		_snap_tween.kill()
		_snap_tween = null

	is_snapped = false
	freeze = false
	can_snap = false

	var direction: Vector2 = (target_pos - global_position).normalized()
	direction = direction.rotated(randf_range(-0.6, 0.6))
	var speed: float = randf_range(1000.0, 1300.0)
	linear_velocity = direction * speed

	# zostawiamy angular_velocity jaki masz w projekcie (jak chcesz “wir”, tu możesz podnieść)
	# angular_velocity = randf_range(-6.0, 6.0)

	await get_tree().create_timer(snap_delay_after_scatter).timeout
	can_snap = true

func _angle_delta(a: float, b: float) -> float:
	# signed delta w zakresie [-PI, PI]
	var d: float = fposmod(a - b + PI, TAU) - PI
	return d

func _wrap_angle_near(target: float, current: float) -> float:
	# zwraca target przesunięty o +/- TAU tak, by był możliwie blisko current
	var a: float = fposmod(target, TAU)
	var c: float = fposmod(current, TAU)
	var delta: float = a - c
	if delta > PI:
		a -= TAU
	elif delta < -PI:
		a += TAU
	return current + (a - c)

func _on_body_entered(body):
	if body.name == "Player":
		pass

func setup_collision_from_image(tile_image: Image):
	if tile_image == null:
		push_warning("No image provided for collision generation")
		return

	var old_collision = get_node_or_null("CollisionShape2D")
	if old_collision:
		old_collision.queue_free()

	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(tile_image, 0.1)

	var polygons = bitmap.opaque_to_polygons(Rect2(0, 0, tile_size, tile_size), 2.0)

	var collision_created: bool = false

	for polygon in polygons:
		if polygon.size() < 3:
			continue

		var collision_polygon = CollisionPolygon2D.new()

		var centered_polygon = PackedVector2Array()
		for point in polygon:
			centered_polygon.append(point - Vector2(tile_size / 2.0, tile_size / 2.0))

		collision_polygon.polygon = centered_polygon
		add_child(collision_polygon)
		collision_created = true

	if not collision_created:
		push_warning("No collision polygons generated, using rectangle fallback")
		var fallback_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(tile_size, tile_size)
		fallback_shape.shape = rect_shape
		add_child(fallback_shape)
