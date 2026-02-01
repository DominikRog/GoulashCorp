extends CanvasLayer

# Persistent blackout overlay that survives scene changes

var overlay: ColorRect
var fade_duration: float = 0.15

func _ready():
	layer = 1000  # Very high layer to be on top of everything

	# Create persistent blackout overlay
	overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0  # Start invisible
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func fade_to_black(duration: float = -1.0) -> void:
	"""Fade screen to black"""
	if duration < 0:
		duration = fade_duration

	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, duration)
	await tween.finished

func fade_from_black(duration: float = -1.0) -> void:
	"""Fade from black to reveal scene"""
	if duration < 0:
		duration = fade_duration

	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, duration)
	await tween.finished

func set_black(is_black: bool) -> void:
	"""Instantly set black or transparent"""
	overlay.modulate.a = 1.0 if is_black else 0.0

func is_black() -> bool:
	"""Check if currently fully black"""
	return overlay.modulate.a >= 1.0
