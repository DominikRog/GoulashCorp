extends CharacterBody2D

@export var speed: float = 220.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# startowa animacja
	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("Idle"):
			sprite.play("Idle")

func _physics_process(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	if input_vector.length() > 0.0:
		velocity = input_vector.normalized() * speed

		# animacja ruchu
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("Move"):
			if sprite.animation != "Move":
				sprite.play("Move")

		# flip lewo/prawo (jeśli sprite patrzy w prawo domyślnie)
		if input_vector.x != 0:
			sprite.flip_h = input_vector.x < 0
	else:
		velocity = Vector2.ZERO

		# animacja idle
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("Idle"):
			if sprite.animation != "Idle":
				return

	move_and_slide()
