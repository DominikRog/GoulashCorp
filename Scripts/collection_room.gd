extends Node2D

# Collection room where player collects mask and transforms

@export var play_area_size: Vector2 = Vector2(240, 128)
@export var collection_distance: float = 20.0  # Distance to trigger mask collection
@export var levitation_amplitude: float = 3.0  # How much mask moves up/down
@export var levitation_speed: float = 2.0  # How fast mask levitates
@export var snap_duration: float = 0.2  # Duration of snap-to-face animation

var mask_position: Vector2
var mask_base_position: Vector2  # Original position for levitation
var player_entrance_position: Vector2
var has_answered: bool = false
var mask_collected: bool = false
var levitation_time: float = 0.0
var is_snapping: bool = false

# Typewriter effect variables
var full_text: String = ""
var current_char_index: float = 0.0
var typewriter_speed: float = 0.07  # Seconds per character (higher = slower)
var is_typing: bool = false
var text_fully_displayed: bool = false
var waiting_for_input: bool = false

@onready var player: CharacterBody2D = $Player
@onready var mask_sprite: Sprite2D = $Mask
@onready var control: Control = $Control
@onready var popup: Control = $Popup
@onready var question_label: Label = $Popup/QuestionText
@onready var choices_container: VBoxContainer = $Popup/ChoicesContainer
@onready var snap_sound: AudioStreamPlayer2D = $SnapSound


func _ready():
	MusicManager.enter_menu_or_dialogue()
	# Calculate positions: player at 1/3, mask at 2/3
	player_entrance_position = Vector2(play_area_size.x / 3.0, play_area_size.y / 2.0)
	mask_base_position = Vector2(play_area_size.x * 2.0 / 3.0, play_area_size.y / 2.0)
	mask_position = mask_base_position

	# Get next character mask sprite
	var act_data = GameManager.get_current_act_data()
	var next_character = act_data.get("next_character", "")

	# Setup mask
	if mask_sprite:
		mask_sprite.global_position = mask_position
		load_mask_sprite(next_character)
		mask_sprite.visible = true

	# Setup player (hidden initially)
	if player:
		player.visible = false
		player.can_move = false

		# Set player sprite to current character (before possession)
		update_player_sprite()

	# Show popup immediately
	show_mind_puzzle()

func _process(delta):
	# Typewriter effect
	if is_typing:
		current_char_index += delta / typewriter_speed
		var chars_to_show = int(current_char_index)
		if chars_to_show >= full_text.length():
			# Finished typing
			question_label.text = full_text
			is_typing = false
			text_fully_displayed = true
			waiting_for_input = true
		else:
			question_label.text = full_text.substr(0, chars_to_show)

	# Levitate mask (up and down)
	if has_answered and not mask_collected and not is_snapping:
		levitation_time += delta * levitation_speed
		var offset_y = sin(levitation_time) * levitation_amplitude
		if mask_sprite:
			mask_sprite.global_position = mask_base_position + Vector2(0, offset_y)

	if not has_answered or mask_collected or is_snapping:
		return

	# Check if player is close enough to snap mask to face
	if player and mask_sprite:
		var distance = player.global_position.distance_to(mask_sprite.global_position)
		if distance <= collection_distance:
			snap_mask_to_face()

func _input(event: InputEvent) -> void:
	if waiting_for_input and text_fully_displayed:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			# Show choices (keep text visible)
			waiting_for_input = false
			text_fully_displayed = false
			choices_container.visible = true
			# Focus first button
			if choices_container.get_child_count() > 0:
				var first_button = choices_container.get_child(0)
				first_button.grab_focus()
			# Mark input as handled to prevent immediate button press
			get_viewport().set_input_as_handled()
			return

	# Number key shortcuts for choices
	if choices_container.visible and not is_typing and not waiting_for_input:
		if event is InputEventKey and event.pressed and not event.echo:
			var keycode = event.keycode
			if keycode >= KEY_1 and keycode <= KEY_9:
				var index = keycode - KEY_1
				if index < choices_container.get_child_count():
					var button = choices_container.get_child(index)
					if button is Button:
						button.emit_signal("pressed")
					get_viewport().set_input_as_handled()

func show_mind_puzzle():
	"""Display mind puzzle popup (80-90% of screen)"""
	# Get current act data
	var act_data = GameManager.get_current_act_data()
	if act_data.is_empty():
		push_error("No act data for mind puzzle!")
		return

	# Start typewriter effect
	start_typewriter(act_data.get("question", ""))

	# Clear existing choices
	clear_choices()

	# Add answer choices (hidden initially)
	var answers = act_data.get("answers", [])
	for answer in answers:
		add_choice_button(answer["text"], answer["correct"])

	# Hide choices initially
	choices_container.visible = false

	# Show popup
	popup.visible = true

func start_typewriter(text: String):
	"""Start typewriter effect for given text"""
	full_text = text
	current_char_index = 0
	is_typing = true
	text_fully_displayed = false
	waiting_for_input = false
	question_label.text = ""
	choices_container.visible = false

func clear_choices():
	"""Remove all choice buttons"""
	for child in choices_container.get_children():
		child.queue_free()

func add_choice_button(text: String, is_correct: bool):
	"""Add a choice button"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 28)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_on_choice_selected.bind(is_correct))
	button.focus_mode = Control.FOCUS_ALL
	choices_container.add_child(button)

func _on_choice_selected(is_correct: bool):
	"""Handle answer selection"""
	if is_correct:
		# Hide popup and start player entrance
		popup.visible = false
		has_answered = true
		control.visible = false
		start_player_entrance()
	else:
		# Wrong answer - restart act
		GameManager.restart_current_act()
		get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

func start_player_entrance():
	"""Start player walking in from left"""
	if not player:
		return

	# Entry position (from left edge)
	var entry_pos = Vector2(-50, play_area_size.y / 2.0)

	# Walk to 1/3 position
	player.start_entrance(entry_pos, player_entrance_position)

func snap_mask_to_face():
	"""Snap mask to player's face with animation"""
	if is_snapping or mask_collected:
		return

	is_snapping = true

	# Create tween for smooth snap animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Snap to player's face position
	if player and mask_sprite:
		tween.tween_property(mask_sprite, "global_position", player.global_position, snap_duration)

	# When snap completes, collect mask
	await tween.finished
	collect_mask()

func collect_mask():
	"""Collect mask and swap character sprite"""
	if mask_collected:
		return

	mask_collected = true

	# Hide mask
	if mask_sprite:
		mask_sprite.visible = false

	# Get current act data for character swap
	var act_data = GameManager.get_current_act_data()
	var next_character = act_data.get("next_character", "")

	# Swap player sprite instantly (animation later)
	swap_character_sprite(next_character)

	# Update game manager
	GameManager.advance_to_next_act(next_character)

	# Brief pause then blackout to next act
	await get_tree().create_timer(0.5).timeout

	# Check if game is won
	if GameManager.current_act > 6:
		# Victory - could show victory screen here
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	else:
		# Next act
		get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

func load_mask_sprite(character_name: String):
	"""Load mask sprite for the next character"""
	if not mask_sprite:
		return

	# Try to load character mask sprite
	var mask_path = "res://Assets/" + character_name + "_mask.png"
	if ResourceLoader.exists(mask_path):
		mask_sprite.texture = load(mask_path)
	else:
		# Fallback: use placeholder (Main_Dude.png or colored square)
		var fallback_path = "res://Assets/Main_Dude.png"
		if ResourceLoader.exists(fallback_path):
			mask_sprite.texture = load(fallback_path)
		else:
			# Create colored placeholder
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color(1.0, 0.8, 0.2, 1.0))  # Golden color for mask
			mask_sprite.texture = ImageTexture.create_from_image(img)
		print("Mask sprite not found: " + mask_path + " (using fallback)")

func update_player_sprite():
	"""Update player sprite to current character from GameManager"""
	if not player:
		return

	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Get current character from GameManager
	var character_name = GameManager.current_character
	if character_name.is_empty():
		character_name = "demon"  # Default fallback

	# Try to load character sprite
	var sprite_path = "res://Assets/" + character_name + "_full.png"
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
	else:
		# Fallback: keep current sprite
		print("Character sprite not found: " + sprite_path)

func swap_character_sprite(character_name: String):
	"""Swap player sprite to new character (instant for now)"""
	if not player:
		return

	var sprite = player.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Try to load character sprite
	var sprite_path = "res://Assets/" + character_name + "_full.png"
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
	else:
		# Fallback: keep current sprite
		print("Character sprite not found: " + sprite_path)
