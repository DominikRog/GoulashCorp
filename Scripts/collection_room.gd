extends Node2D

# Collection room where player collects mask and transforms

@export var play_area_size: Vector2 = Vector2(240, 128)
@export var collection_distance: float = 20.0  # Distance to trigger mask collection

var mask_position: Vector2
var player_entrance_position: Vector2
var has_answered: bool = false
var mask_collected: bool = false

@onready var player: CharacterBody2D = $Player
@onready var mask_sprite: Sprite2D = $Mask
@onready var popup: Control = $Popup
@onready var question_label: Label = $Popup/QuestionText
@onready var choices_container: VBoxContainer = $Popup/ChoicesContainer

func _ready():
	# Calculate positions: player at 1/3, mask at 2/3
	player_entrance_position = Vector2(play_area_size.x / 3.0, play_area_size.y / 2.0)
	mask_position = Vector2(play_area_size.x * 2.0 / 3.0, play_area_size.y / 2.0)

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

	# Show popup immediately
	show_mind_puzzle()

func _process(_delta):
	if not has_answered or mask_collected:
		return

	# Check if player is close enough to collect mask
	if player and mask_sprite:
		var distance = player.global_position.distance_to(mask_position)
		if distance <= collection_distance:
			collect_mask()

func show_mind_puzzle():
	"""Display mind puzzle popup (80-90% of screen)"""
	# Get current act data
	var act_data = GameManager.get_current_act_data()
	if act_data.is_empty():
		push_error("No act data for mind puzzle!")
		return

	# Show completed shapes as hint
	question_label.text = act_data.get("question", "")

	# Clear existing choices
	clear_choices()

	# Add answer choices
	var answers = act_data.get("answers", [])
	for answer in answers:
		add_choice_button(answer["text"], answer["correct"])

	# Show popup
	popup.visible = true

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
	choices_container.add_child(button)

func _on_choice_selected(is_correct: bool):
	"""Handle answer selection"""
	if is_correct:
		# Hide popup and start player entrance
		popup.visible = false
		has_answered = true
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
