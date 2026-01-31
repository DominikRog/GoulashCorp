extends Node

@onready var music: AudioStreamPlayer = $Music
var _fade_tween: Tween = null

func play_music() -> void:
	if not music.playing:
		music.play()

func pause_music() -> void:
	music.stream_paused = true

func resume_music() -> void:
	music.stream_paused = false

func fade_to(db: float, duration: float = 0.5) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(music, "volume_db", db, duration)
	_fade_tween.finished.connect(func(): _fade_tween = null)

func resume_if_not_playing() -> void:
	if not music.playing:
		# jeśli była pauza → zdejmij pauzę
		music.stream_paused = false
		music.play()
