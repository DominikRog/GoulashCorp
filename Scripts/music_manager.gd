extends Node

@export var menu_db: float = 10
@export var level_db: float = 10
@export var fade_time: float = 0.6

@onready var menu_player: AudioStreamPlayer = $MenuPlayer
@onready var level_player: AudioStreamPlayer = $LevelPlayer

var _tween: Tween = null

func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null

func _fade(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", target_db, duration)
	_tween.finished.connect(func(): _tween = null)

# === PUBLIC API ===

# Menu i Dialogue: ta sama ścieżka. Jeśli gra -> zostaw, jeśli nie -> wznów.
func enter_menu_or_dialogue() -> void:
	# wycisz level
	if level_player.playing and not level_player.stream_paused:
		_fade(level_player, -40.0, fade_time)
		await get_tree().create_timer(fade_time).timeout
		level_player.stop()

	# wznow menu/dialog jeśli nie gra
	if menu_player.stream_paused:
		menu_player.stream_paused = false

	if not menu_player.playing:
		menu_player.play()

	# doprowadź głośność do docelowej (łagodnie)
	_fade(menu_player, menu_db, fade_time)

# Start levelu: menu/dialog fade out -> pause (zachowuje pozycję) + level fade in
func enter_level(delay_before_level: float = 0.0) -> void:
	# menu/dialog w dół + pauza (żeby wróciło w tym samym miejscu)
	if menu_player.playing and not menu_player.stream_paused:
		_fade(menu_player, -40.0, fade_time)
		await get_tree().create_timer(fade_time).timeout
		menu_player.stream_paused = true

	if delay_before_level > 0.0:
		await get_tree().create_timer(delay_before_level).timeout

	# start level music
	if not level_player.playing:
		level_player.volume_db = -40.0
		level_player.play()

	_fade(level_player, level_db, fade_time)

# (opcjonalnie) stop wszystkiego
func stop_all(fade: float = 0.4) -> void:
	_kill_tween()
	var t := create_tween()
	t.tween_property(menu_player, "volume_db", -80.0, fade)
	t.parallel().tween_property(level_player, "volume_db", -80.0, fade)
	await get_tree().create_timer(fade).timeout
	menu_player.stop()
	level_player.stop()
	menu_player.stream_paused = false
