extends CharacterBody2D

@export var speed_while_grabbing_multiplier: float = 0.55
@export var speed := 110.0
@export var animation_speed := 70.0
@export var push_force := 55.0

# --- pulling / grabbing ---
@export var pull_strength: float = 3000.0
@export var hold_distance: float = 17.0
@export var max_grab_distance: float = 40.0
@export var grab_damp_boost: float = 8.0
@export var block_pushing_while_grabbing: bool = false
# ------------------------------

# --- stability while grabbing ---
@export var pull_deadzone: float = 2.0
@export var max_pull_speed: float = 120.0
# ------------------------------

# --- NEW: manual rotation controls (Q/E) ---
@export var rotate_speed_degrees_per_sec: float = 140.0   # jak szybko obraca podczas TRZYMANIA Q/E
@export var rotate_damp_boost: float = 6.0                # dodatkowe tłumienie tylko na czas obracania (mniej drżenia)
@export var freeze_tile_while_rotating: bool = false      # zwykle false, bo chcesz dalej pchać/ciągnąć; damp robi robotę
# ------------------------------------------

# --- NEW: punch (P) ---
@export var punch_range: float = 24.0
@export var punch_radius: float = 10.0
@export var punch_strength: float = 520.0   # <-- SŁABSZE niż wcześniej
@export var punch_cooldown: float = 0.18
# ----------------------

# --- entrance smoothness ---
@export var entrance_stop_distance: float = 0.5
# --------------------------

var can_move: bool = true
var animation_time: float = 0.0
var is_entering: bool = false
var entrance_target: Vector2 = Vector2.ZERO

# --- state ---
var grabbed_tile: RigidBody2D = null
var last_move_dir: Vector2 = Vector2.DOWN
var _grabbed_original_linear_damp: float = 0.0
var _grabbed_original_angular_damp: float = 0.0
var grab_dir: Vector2 = Vector2.DOWN

# rotation assistance state
var _rotating_now: bool = false
var _rot_saved_linear_damp: float = 0.0
var _rot_saved_angular_damp: float = 0.0

# punch timing
var _punch_lock_timer: float = 0.0

signal entrance_completed

@onready var sprite: Sprite2D = $Sprite2D
@onready var grab_area: Area2D = $GrabArea

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _physics_process(delta: float) -> void:
	# timers
	if _punch_lock_timer > 0.0:
		_punch_lock_timer = max(0.0, _punch_lock_timer - delta)

	# entrance
	if is_entering:
		var step: float = animation_speed * delta
		global_position = global_position.move_toward(entrance_target, step)

		animation_time += delta * 8.0
		sprite.frame = int(animation_time) % 4

		if global_position.distance_to(entrance_target) <= entrance_stop_distance:
			global_position = entrance_target
			is_entering = false
			can_move = true
			velocity = Vector2.ZERO
			sprite.frame = 0
			animation_time = 0.0
			entrance_completed.emit()
		return

	# --- INPUTS ---
	var want_grab: bool = Input.is_action_pressed("grab")
	var want_punch: bool = Input.is_action_just_pressed("punch")

	# grab press/release
	if want_grab and grabbed_tile == null:
		_try_grab_tile()
	elif (not want_grab) and grabbed_tile != null:
		_release_tile()

	# punch
	if want_punch and _punch_lock_timer <= 0.0:
		_do_punch()

	# --- MOVE ---
	if can_move:
		var input_vector: Vector2 = Vector2.ZERO
		input_vector.x = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
		input_vector.y = Input.get_action_strength("player_down") - Input.get_action_strength("player_up")
		input_vector = input_vector.normalized()

		if input_vector.length() > 0.0:
			last_move_dir = input_vector
			# --- flip sprite left/right ---
		if input_vector.x < -0.01:
			sprite.flip_h = true
		elif input_vector.x > 0.01:
			sprite.flip_h = false

		var current_speed: float = speed
		if grabbed_tile != null:
			current_speed = speed * speed_while_grabbing_multiplier

		velocity = input_vector * current_speed

		if velocity.length() > 0.0:
			animation_time += delta * 8.0
			sprite.frame = int(animation_time) % 4
		else:
			sprite.frame = 0
			animation_time = 0.0

		move_and_slide()

	# --- Pull grabbed tile AFTER moving ---
	if grabbed_tile != null:
		_pull_tile(delta)

	# --- Manual rotation ONLY while grabbing + holding space ---
	# (czyli tylko gdy grabbed_tile != null, bo to wymaga grab)
	if grabbed_tile != null:
		_manual_rotate_tile(delta)
	else:
		# jeśli nie trzymamy tile, upewnij się że nie zostawiliśmy boostów
		if _rotating_now:
			_stop_rotate_boost()

	# --- Push tiles ---
	if can_move:
		if block_pushing_while_grabbing and grabbed_tile != null:
			pass
		else:
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				if collider is RigidBody2D:
					if grabbed_tile != null and collider == grabbed_tile:
						continue
					var push_direction: Vector2 = collision.get_normal() * -1.0
					var impulse: Vector2 = push_direction * (push_force * delta)
					(collider as RigidBody2D).apply_central_impulse(impulse)

func _try_grab_tile() -> void:
	if grab_area == null:
		return

	var bodies: Array = grab_area.get_overlapping_bodies()
	var best: RigidBody2D = null
	var best_dist: float = 1e20

	for b in bodies:
		var rb: RigidBody2D = b as RigidBody2D
		if rb == null:
			continue
		if rb.freeze:
			continue
		if rb.collision_layer == 0:
			continue

		var d: float = rb.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = rb

	if best == null:
		return

	grabbed_tile = best

	# Keep tile on the same side it was grabbed from
	var v: Vector2 = grabbed_tile.global_position - global_position
	if v.length() < 0.001:
		grab_dir = Vector2.DOWN
		var lm: float = last_move_dir.length()
		if lm > 0.001:
			grab_dir = -(last_move_dir / lm)
	else:
		grab_dir = v.normalized()

	# prevent pushing player around
	grabbed_tile.add_collision_exception_with(self)

	# boost damping while grabbing (stability)
	if grab_damp_boost > 0.0:
		_grabbed_original_linear_damp = grabbed_tile.linear_damp
		_grabbed_original_angular_damp = grabbed_tile.angular_damp
		grabbed_tile.linear_damp = _grabbed_original_linear_damp + grab_damp_boost
		grabbed_tile.angular_damp = _grabbed_original_angular_damp + grab_damp_boost

	# IMPORTANT: no auto rotation alignment here anymore (per your request)

func _manual_rotate_tile(delta: float) -> void:
	if grabbed_tile == null:
		return
	if grabbed_tile.freeze:
		return
	if grabbed_tile.collision_layer == 0:
		return

	var left: bool = Input.is_action_pressed("rotate_left")
	var right: bool = Input.is_action_pressed("rotate_right")

	var dir_sign: float = 0.0
	if left and not right:
		dir_sign = -1.0
	elif right and not left:
		dir_sign = 1.0

	if dir_sign == 0.0:
		# stop extra boost when not rotating
		if _rotating_now:
			_stop_rotate_boost()
		return

	# apply rotation damp boost while rotating (reduces jitter)
	if not _rotating_now:
		_start_rotate_boost()

	# stop angular velocity fighting our manual rotate
	grabbed_tile.angular_velocity = 0.0

	# optional freeze during rotate
	var was_frozen: bool = grabbed_tile.freeze
	if freeze_tile_while_rotating:
		grabbed_tile.freeze = true

	var step_rad: float = deg_to_rad(rotate_speed_degrees_per_sec) * delta * dir_sign
	grabbed_tile.rotation += step_rad

	if freeze_tile_while_rotating:
		grabbed_tile.freeze = was_frozen

func _start_rotate_boost() -> void:
	if grabbed_tile == null:
		return
	_rotating_now = true
	_rot_saved_linear_damp = grabbed_tile.linear_damp
	_rot_saved_angular_damp = grabbed_tile.angular_damp
	if rotate_damp_boost > 0.0:
		grabbed_tile.linear_damp = _rot_saved_linear_damp + rotate_damp_boost
		grabbed_tile.angular_damp = _rot_saved_angular_damp + rotate_damp_boost

func _stop_rotate_boost() -> void:
	if grabbed_tile == null:
		_rotating_now = false
		return
	if rotate_damp_boost > 0.0:
		grabbed_tile.linear_damp = _rot_saved_linear_damp
		grabbed_tile.angular_damp = _rot_saved_angular_damp
	_rotating_now = false

func _pull_tile(delta: float) -> void:
	if grabbed_tile == null:
		return

	if grabbed_tile.freeze or grabbed_tile.collision_layer == 0:
		_release_tile()
		return

	var dist_to_player: float = grabbed_tile.global_position.distance_to(global_position)
	if dist_to_player > max_grab_distance:
		_release_tile()
		return

	var hold_point: Vector2 = global_position + grab_dir * hold_distance
	var to_target: Vector2 = hold_point - grabbed_tile.global_position
	var dist: float = to_target.length()
	if dist < 0.001:
		return

	if dist <= pull_deadzone:
		grabbed_tile.linear_velocity *= 0.5
		return

	var dir: Vector2 = to_target / dist
	grabbed_tile.linear_velocity += dir * (pull_strength * delta)

	var vel: Vector2 = grabbed_tile.linear_velocity
	var vlen: float = vel.length()
	if vlen > max_pull_speed:
		grabbed_tile.linear_velocity = vel * (max_pull_speed / vlen)

func _release_tile() -> void:
	if grabbed_tile == null:
		return

	# stop rotate boost if active
	if _rotating_now:
		_stop_rotate_boost()

	grabbed_tile.remove_collision_exception_with(self)

	# restore damp if changed
	if grab_damp_boost > 0.0:
		grabbed_tile.linear_damp = _grabbed_original_linear_damp
		grabbed_tile.angular_damp = _grabbed_original_angular_damp

	grabbed_tile = null

func _do_punch() -> void:
	_punch_lock_timer = punch_cooldown

	var dir: Vector2 = last_move_dir
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	dir = dir.normalized()

	var center: Vector2 = global_position + dir * punch_range

	var shape := CircleShape2D.new()
	shape.radius = punch_radius

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(params, 16)

	var best_rb: RigidBody2D = null
	var best_dist: float = 1e20

	for hit in results:
		var obj = hit.get("collider")
		var rb: RigidBody2D = obj as RigidBody2D
		if rb == null:
			continue
		if rb.freeze:
			continue
		if rb.collision_layer == 0:
			continue
		if grabbed_tile != null and rb == grabbed_tile:
			continue

		var d: float = rb.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best_rb = rb

	if best_rb == null:
		return

	best_rb.apply_central_impulse(dir * punch_strength)

func start_entrance(from_pos: Vector2, to_pos: Vector2) -> void:
	global_position = from_pos
	entrance_target = to_pos
	is_entering = true
	can_move = false
	visible = true

	animation_time = 0.0
	sprite.frame = 0

	if grabbed_tile != null:
		_release_tile()

func get_entry_position(screen_size: Vector2) -> Vector2:
	var side = randi() % 4
	var margin = 50.0
	match side:
		0: return Vector2(-margin, screen_size.y / 2)
		1: return Vector2(screen_size.x + margin, screen_size.y / 2)
		2: return Vector2(screen_size.x / 2, -margin)
		_: return Vector2(screen_size.x / 2, screen_size.y + margin)
