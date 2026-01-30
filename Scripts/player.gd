extends CharacterBody2D

@export var speed := 200.0
@export var push_force := 150.0
var can_move: bool = true
var animation_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta):
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
