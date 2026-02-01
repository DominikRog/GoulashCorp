extends Node
class_name AnomalyManager

enum AnomalyType {
	NONE,
	FAST_PLAYER,
	WEAK_PLAYER,
	STRONG_WALL_REPULSION
}

@export var init_delay: float = 5.0

# Wagi losowania
@export var weight_fast_player: int = 1
@export var weight_weak_player: int = 1
@export var weight_strong_walls: int = 1
@export var weight_none: int = 1

# --- Parametry anomalii ---
@export var fast_player_speed_multiplier: float = 1.7
@export var weak_player_push_multiplier: float = 0.10
@export var wall_repulsion_range_multiplier: float = 10.0
@export var wall_repulsion_strength_multiplier: float = 2.0
# --------------------------

# --- UI ICON ---
@export var ui_icon_path: NodePath = NodePath("../UI/AnomalyIcon")
@export var ui_show_seconds: float = 1.0

@export var icon_speed: Texture2D
@export var icon_weak: Texture2D
@export var icon_repulsion: Texture2D
@export var icon_none: Texture2D
# --------------

var _icon: TextureRect = null
var _icon_hide_tween: Tween = null

var current: AnomalyType = AnomalyType.NONE
var pending: bool = false
var active: bool = false

var _rng := RandomNumberGenerator.new()
var _timer: SceneTreeTimer = null
var _run_id: int = 0  # token zabezpieczający przed starymi timerami

var _player: Node = null
var _puzzle: Node = null

# --- backup wartości bazowych ---
var _base_player_speed: float = 0.0
var _base_player_push_force: float = 0.0
var _base_wall_enabled: bool = false
var _base_wall_range: float = 0.0
var _base_wall_strength: float = 0.0
var _base_saved: bool = false
# -------------------------------

func bind(player: Node, puzzle_manager: Node) -> void:
	_player = player
	_puzzle = puzzle_manager

	_rng.randomize()
	_save_base_if_needed()

	# znajdź ikonę UI
	_icon = null
	if ui_icon_path != NodePath("") and has_node(ui_icon_path):
		_icon = get_node(ui_icon_path) as TextureRect
	if _icon != null:
		_icon.visible = false
		_icon.modulate.a = 1.0

func start_for_level() -> void:
	# wyczyść poprzednie
	reset()

	_save_base_if_needed()

	current = _roll_anomaly()
	pending = true

	# token na ten "run"
	_run_id += 1
	var my_id := _run_id

	var d: float = max(0.0, init_delay)
	_timer = get_tree().create_timer(d)
	_timer.timeout.connect(func() -> void:
		_on_init_delay_timeout(my_id)
	)

func _on_init_delay_timeout(my_id: int) -> void:
	# jeśli w międzyczasie był reset/nowy start -> ignoruj
	if my_id != _run_id:
		return

	_timer = null
	if not pending:
		return

	pending = false
	apply_current()

func apply_current() -> void:
	if active:
		return
	if _player == null or _puzzle == null:
		current = AnomalyType.NONE
		return

	_save_base_if_needed()

	_show_anomaly_icon(current)

	match current:
		AnomalyType.NONE:
			active = true
			return
		AnomalyType.FAST_PLAYER:
			if _player.has_method("set"):
				_player.set("speed", _base_player_speed * fast_player_speed_multiplier)
			active = true
		AnomalyType.WEAK_PLAYER:
			if _player.has_method("set"):
				_player.set("push_force", _base_player_push_force * weak_player_push_multiplier)
			active = true
		AnomalyType.STRONG_WALL_REPULSION:
			if _puzzle.has_method("set"):
				_puzzle.set("wall_repulsion_enabled", true)
				_puzzle.set("wall_repulsion_range", _base_wall_range * wall_repulsion_range_multiplier)
				_puzzle.set("wall_repulsion_strength", _base_wall_strength * wall_repulsion_strength_multiplier)
			active = true

func reset() -> void:
	# anuluje opóźnienie + cofa efekty + chowa ikonkę
	pending = false

	# unieważnij stare timeouty
	_run_id += 1

	_timer = null

	if active:
		_restore_base()
	active = false
	current = AnomalyType.NONE

	_hide_icon_now()

# ===========================
# Helpers
# ===========================

func _save_base_if_needed() -> void:
	if _base_saved:
		return
	if _player == null or _puzzle == null:
		return

	# Player: speed, push_force
	if _player.has_method("get"):
		var s = _player.get("speed")
		_base_player_speed = float(s)

		var pf = _player.get("push_force")
		_base_player_push_force = float(pf)

	# PuzzleManager: wall repulsion
	if _puzzle.has_method("get"):
		_base_wall_enabled = bool(_puzzle.get("wall_repulsion_enabled"))
		_base_wall_range = float(_puzzle.get("wall_repulsion_range"))
		_base_wall_strength = float(_puzzle.get("wall_repulsion_strength"))

	_base_saved = true

func _restore_base() -> void:
	if _player != null and _player.has_method("set"):
		_player.set("speed", _base_player_speed)
		_player.set("push_force", _base_player_push_force)

	if _puzzle != null and _puzzle.has_method("set"):
		_puzzle.set("wall_repulsion_enabled", _base_wall_enabled)
		_puzzle.set("wall_repulsion_range", _base_wall_range)
		_puzzle.set("wall_repulsion_strength", _base_wall_strength)

func _roll_anomaly() -> AnomalyType:
	var items: Array[AnomalyType] = []
	var weights: Array[int] = []

	items.append(AnomalyType.FAST_PLAYER)
	weights.append(max(0, weight_fast_player))

	items.append(AnomalyType.WEAK_PLAYER)
	weights.append(max(0, weight_weak_player))

	items.append(AnomalyType.STRONG_WALL_REPULSION)
	weights.append(max(0, weight_strong_walls))

	items.append(AnomalyType.NONE)
	weights.append(max(0, weight_none))

	var total: int = 0
	for w in weights:
		total += w

	if total <= 0:
		return AnomalyType.NONE

	var r: int = _rng.randi_range(1, total)
	var acc: int = 0

	for i in range(items.size()):
		acc += weights[i]
		if r <= acc:
			return items[i]

	return AnomalyType.NONE

# ===========================
# UI icon
# ===========================

func _hide_icon_now() -> void:
	if _icon_hide_tween != null:
		_icon_hide_tween.kill()
		_icon_hide_tween = null
	if _icon != null:
		_icon.visible = false
		_icon.modulate.a = 1.0

func _show_anomaly_icon(kind: AnomalyType) -> void:
	if _icon == null:
		return

	if _icon_hide_tween != null:
		_icon_hide_tween.kill()
		_icon_hide_tween = null

	var tex: Texture2D = null
	match kind:
		AnomalyType.FAST_PLAYER:
			tex = icon_speed
		AnomalyType.WEAK_PLAYER:
			tex = icon_weak
		AnomalyType.STRONG_WALL_REPULSION:
			tex = icon_repulsion
		AnomalyType.NONE:
			tex = icon_none
		_:
			tex = icon_none

	if tex == null:
		return

	_icon.texture = tex
	_icon.visible = true
	_icon.modulate.a = 1.0

	var show_time: float = max(0.05, float(ui_show_seconds))

	_icon_hide_tween = create_tween()
	_icon_hide_tween.tween_interval(max(0.0, show_time - 0.15))
	_icon_hide_tween.tween_property(_icon, "modulate:a", 0.0, 0.15)
	_icon_hide_tween.finished.connect(func() -> void:
		if _icon != null:
			_icon.visible = false
			_icon.modulate.a = 1.0
		_icon_hide_tween = null
	)
