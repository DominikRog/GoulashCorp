extends CharacterBody2D

@export var speed_while_grabbing_multiplier: float = 0.45
@export var speed := 110.0
@export var animation_speed := 70.0
@export var push_force := 100.0

# --- pulling / grabbing ---
@export var pull_strength: float = 3000.0      # jak mocno "ciągnie" tile
@export var hold_distance: float = 17.0        # gdzie ma być tile względem gracza (w pikselach)
@export var max_grab_distance: float = 40.0    # jak daleko może być tile od gracza zanim puścimy
@export var grab_damp_boost: float = 8.0       # dodatkowy damp podczas trzymania
@export var block_pushing_while_grabbing: bool = true

# --- stability while grabbing ---
@export var pull_deadzone: float = 2.0         # martwa strefa (mniej drżenia)
@export var max_pull_speed: float = 120.0      # limit prędkości tile podczas ciągnięcia
# ------------------------------

var can_move: bool = true
var animation_time: float = 0.0
var is_entering: bool = false
var entrance_target: Vector2 = Vector2.ZERO

# --- state ---
var grabbed_tile: RigidBody2D = null
var last_move_dir: Vector2 = Vector2.DOWN
var _grabbed_original_linear_damp: float = 0.0
var _grabbed_original_angular_damp: float = 0.0

# NEW: direction of the grabbed tile relative to player at grab time (keeps it on the same side)
var grab_dir: Vector2 = Vector2.DOWN
# ----------------

signal entrance_completed

@onready var sprite: Sprite2D = $Sprite2D
@onready var grab_area: Area2D = $GrabArea

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _physics_process(delta):
	# Handle entrance animation
	if is_entering:
		var direction: Vector2 = (entrance_target - global_position).normalized()
		global_position += direction * animation_speed * delta

		animation_time += delta * 8.0
		sprite.frame = int(animation_time) % 4

		if global_position.distance_to(entrance_target) < 15.0:
			global_position = entrance_target
			is_entering = false
			can_move = true
			velocity = Vector2.ZERO
			sprite.frame = 0
			entrance_completed.emit()
		return

	# --- GRAB INPUT ---
	var want_grab: bool = Input.is_action_pressed("grab")

	if want_grab and grabbed_tile == null:
		_try_grab_tile()
	elif (not want_grab) and grabbed_tile != null:
		_release_tile()

	# --- Normal movement ---
	if can_move:
		var input_vector: Vector2 = Vector2.ZERO
		input_vector.x = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
		input_vector.y = Input.get_action_strength("player_down") - Input.get_action_strength("player_up")
		input_vector = input_vector.normalized()

		if input_vector.length() > 0.0:
			last_move_dir = input_vector

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

	# --- Push tiles (only when not grabbing, optionally) ---
	if can_move:
		if (not block_pushing_while_grabbing) or grabbed_tile == null:
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				if collider is RigidBody2D:
					if grabbed_tile != null and collider == grabbed_tile:
						continue
					var push_direction: Vector2 = collision.get_normal() * -1.0
					collider.apply_central_impulse(push_direction * push_force)

func _try_grab_tile():
	if grab_area == null:
		return

	var bodies: Array = grab_area.get_overlapping_bodies()
	var best: RigidBody2D = null
	var best_dist: float = 1e20

	for b in bodies:
		var rb: RigidBody2D = b as RigidBody2D
		if rb == null:
			continue

		# Ignore snapped/disabled tiles
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

	# Keep tile on the same side it was grabbed from (INTUITIVE behavior)
	var v: Vector2 = grabbed_tile.global_position - global_position
	if v.length() < 0.001:
		# fallback: use opposite of movement direction
		grab_dir = Vector2.DOWN
		var lm: float = last_move_dir.length()
		if lm > 0.001:
			grab_dir = -(last_move_dir / lm)
	else:
		grab_dir = v.normalized()

	# Prevent grabbed tile from colliding with player
	grabbed_tile.add_collision_exception_with(self)

	# Boost damping while grabbing
	if grab_damp_boost > 0.0:
		_grabbed_original_linear_damp = grabbed_tile.linear_damp
		_grabbed_original_angular_damp = grabbed_tile.angular_damp
		grabbed_tile.linear_damp = _grabbed_original_linear_damp + grab_damp_boost
		grabbed_tile.angular_damp = _grabbed_original_angular_damp + grab_damp_boost

func _pull_tile(delta: float):
	if grabbed_tile == null:
		return

	if grabbed_tile.freeze or grabbed_tile.collision_layer == 0:
		_release_tile()
		return

	var dist_to_player: float = grabbed_tile.global_position.distance_to(global_position)
	if dist_to_player > max_grab_distance:
		_release_tile()
		return

	# Hold point based on grab_dir captured at grab time (not last_move_dir!)
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

func _release_tile():
	if grabbed_tile == null:
		return

	grabbed_tile.remove_collision_exception_with(self)

	if grab_damp_boost > 0.0:
		grabbed_tile.linear_damp = _grabbed_original_linear_damp
		grabbed_tile.angular_damp = _grabbed_original_angular_damp

	grabbed_tile = null

func start_entrance(from_pos: Vector2, to_pos: Vector2):
	global_position = from_pos
	entrance_target = to_pos
	is_entering = true
	can_move = false
	visible = true

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
