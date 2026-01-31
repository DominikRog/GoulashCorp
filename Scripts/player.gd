extends CharacterBody2D

@export var speed := 200.0
@export var push_force := 150.0
var can_move: bool = true
var animation_time: float = 0.0
var is_entering: bool = false
var entrance_target: Vector2 = Vector2.ZERO

signal entrance_completed

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _physics_process(delta):
	# Handle entrance animation
	if is_entering:
		# Move directly without collision during entrance
		var direction = (entrance_target - global_position).normalized()
		global_position += direction * speed * delta

		# Animate walk
		animation_time += delta * 8.0
		sprite.frame = int(animation_time) % 4

		# Check if we reached the target (larger threshold for smoother arrival)
		if global_position.distance_to(entrance_target) < 15.0:
			global_position = entrance_target
			is_entering = false
			can_move = true
			velocity = Vector2.ZERO
			sprite.frame = 0
			entrance_completed.emit()
		return

	# Normal movement
	if can_move:
		var input_vector = Vector2.ZERO

		input_vector.x = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
		input_vector.y = Input.get_action_strength("player_down") - Input.get_action_strength("player_up")

		input_vector = input_vector.normalized()
		velocity = input_vector * speed

		# Animate sprite when moving
		if velocity.length() > 0:
			animation_time += delta * 8.0  # Animation speed
			sprite.frame = int(animation_time) % 4
		else:
			sprite.frame = 0  # Idle frame
			animation_time = 0.0

		# Apply movement
		move_and_slide()

		# Push tiles after movement
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider is RigidBody2D:
				var push_direction = collision.get_normal() * -1
				collider.apply_central_impulse(push_direction * push_force)

func start_entrance(from_pos: Vector2, to_pos: Vector2):
	"""Begin entrance animation from off-screen"""
	global_position = from_pos
	entrance_target = to_pos
	is_entering = true
	can_move = false
	visible = true

func get_entry_position(screen_size: Vector2) -> Vector2:
	"""Get random entry point from screen edge"""
	var side = randi() % 4
	var margin = 50.0
	match side:
		0: return Vector2(-margin, screen_size.y / 2)  # Left
		1: return Vector2(screen_size.x + margin, screen_size.y / 2)  # Right
		2: return Vector2(screen_size.x / 2, -margin)  # Top
		_: return Vector2(screen_size.x / 2, screen_size.y + margin)  # Bottom
