extends CharacterBody2D
class_name Goblin

@export var speed: float = 65.0

# kiedy ma się pojawić pierwszy raz / po śmierci
@export var spawn_delay_first: float = 5.0
@export var respawn_delay: float = 8.0

# tor wewnątrz pola
@export var track_margin: float = 18.0
@export var angular_jitter_guard: float = 0.0001

# --- PENTAGRAM PATH (rounded) ---
@export var star_outer_radius: float = 220.0
@export var star_inner_radius: float = 25.0
@export var star_roundness: float = 0.6
@export var path_speed_scale: float = 1.0
# -------------------------------

# grab
@export var grab_radius: float = 16.0
@export var hold_distance: float = 10.0
@export var max_grab_distance: float = 46.0

# ciągnięcie tile (stabilne, bez telepania)
@export var carry_spring: float = 140.0
@export var carry_damping: float = 40.0
@export var max_tile_speed: float = 160.0

# anim
@export var anim_fps: float = 8.0
@export var idle_frame: int = 0

var puzzle_manager: Node = null
var active: bool = false
var grabbed_tile: RigidBody2D = null

# --- pentagram path state ---
var _star_points: PackedVector2Array = PackedVector2Array()
var _u: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
# ---------------------------

# saved collision state (so we can disable during "dead")
var _saved_layer: int = 0
var _saved_mask: int = 0

var _anim_time: float = 0.0
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("goblin")

	# zapamiętaj kolizje goblina (co masz ustawione w edytorze)
	_saved_layer = collision_layer
	_saved_mask = collision_mask

	visible = false
	active = false
	_set_collision_enabled(false)

	if puzzle_manager == null:
		puzzle_manager = get_parent()

	_spawn_after_delay(spawn_delay_first)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if puzzle_manager == null:
		return

	_follow_pentagram(delta)

	# grab "po drodze"
	if grabbed_tile == null:
		_try_grab_nearby_tile()
	else:
		_carry_tile_pd(delta)

	_update_animation(delta)

# ============================================================
# Spawn / punch / reset
# ============================================================

func _spawn_after_delay(delay: float) -> void:
	# "martwy" stan: nie przeszkadza niczym
	active = false
	visible = false
	_set_collision_enabled(false)
	_release_tile()

	await get_tree().create_timer(max(0.0, delay)).timeout

	_build_pentagram()

	_u = 0.0
	global_position = _sample_star(_u)
	_prev_pos = global_position

	visible = true
	active = true
	_set_collision_enabled(true)

func on_punched() -> void:
	# natychmiast zniknij + wyłącz kolizję, żeby nie zostawał "niewidzialny klocek"
	if not active:
		return
	_spawn_after_delay(respawn_delay)

func reset_goblin(first_delay: float = 5.0) -> void:
	active = false
	visible = false
	_set_collision_enabled(false)
	_release_tile()
	_spawn_after_delay(first_delay)

# ============================================================
# Collision enable/disable (FIX: no invisible collider after death)
# ============================================================

func _set_collision_enabled(enabled: bool) -> void:
	if enabled:
		collision_layer = _saved_layer
		collision_mask = _saved_mask
	else:
		collision_layer = 0
		collision_mask = 0

	# 100% pewności: wyłącz też wszystkie shape'y (nawet jeśli są zagnieżdżone)
	for ch in find_children("", "CollisionShape2D", true, false):
		(ch as CollisionShape2D).disabled = not enabled
	for ch in find_children("", "CollisionPolygon2D", true, false):
		(ch as CollisionPolygon2D).disabled = not enabled

# ============================================================
# PENTAGRAM movement
# ============================================================

func _build_pentagram() -> void:
	var size: Vector2 = _play_area_size()

	# wewnętrzny prostokąt toru
	var left: float = track_margin
	var right: float = size.x - track_margin
	var top: float = track_margin
	var bottom: float = size.y - track_margin

	var center: Vector2 = Vector2((left + right) * 0.5, (top + bottom) * 0.5)

	# dopasuj promienie, żeby nie wybiegać poza pole
	var max_rx: float = max(40.0, (right - left) * 0.5)
	var max_ry: float = max(40.0, (bottom - top) * 0.5)
	var max_r: float = min(max_rx, max_ry)

	# NIE NADPISUJ exportów – użyj lokalnych wartości
	var outer_r: float = clamp(star_outer_radius, 40.0, max_r)
	var inner_r: float = clamp(star_inner_radius, 10.0, outer_r - 5.0)
	var round: float = clamp(star_roundness, 0.0, 1.0)

	_star_points = _make_pentagram_points(center, outer_r, inner_r, round)

func _follow_pentagram(delta: float) -> void:
	_build_pentagram()

	# parametryzacja "u" (0..1) – stała prędkość w przybliżeniu
	var du: float = (speed * path_speed_scale / 800.0) * delta
	_u += max(du, angular_jitter_guard)

	var new_pos: Vector2 = _sample_star(_u)

	velocity = (new_pos - _prev_pos) / max(0.0001, delta)
	_prev_pos = new_pos

	# goblin jako "duch toru"
	global_position = new_pos

func _make_pentagram_points(center: Vector2, outer_r: float, inner_r: float, round: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var start_angle: float = -PI * 0.5

	# 10 punktów: outer/inner na zmianę
	for i in range(10):
		var outer: bool = (i % 2) == 0
		var r: float = outer_r if outer else inner_r
		var a: float = start_angle + TAU * float(i) / 10.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)

	return pts

func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		2.0 * p1 +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _sample_star(u: float) -> Vector2:
	var n: int = _star_points.size()
	if n < 4:
		return global_position

	u = fposmod(u, 1.0)

	var seg: float = u * float(n)
	var i1: int = int(floor(seg)) % n
	var t: float = seg - floor(seg)

	var i0: int = (i1 - 1 + n) % n
	var i2: int = (i1 + 1) % n
	var i3: int = (i1 + 2) % n

	# Catmull-Rom + opcjonalne "roundness"
	var p: Vector2 = _catmull_rom(_star_points[i0], _star_points[i1], _star_points[i2], _star_points[i3], t)

	var round: float = clamp(star_roundness, 0.0, 1.0)
	if round > 0.0:
		var smooth: float = t * t * (3.0 - 2.0 * t)
		var tt: float = lerp(t, smooth, round)
		p = _catmull_rom(_star_points[i0], _star_points[i1], _star_points[i2], _star_points[i3], tt)

	return p

# ============================================================
# Grab / carry
# ============================================================

func _try_grab_nearby_tile() -> void:
	var candidate: RigidBody2D = _nearest_unplaced_tile_in_radius(grab_radius)
	if candidate == null:
		return
	_grab_tile(candidate)

func _nearest_unplaced_tile_in_radius(r: float) -> RigidBody2D:
	var best: RigidBody2D = null
	var best_d: float = 1e20

	var arr = null
	if puzzle_manager != null:
		arr = puzzle_manager.get("tiles")

	if arr is Array:
		for it in arr:
			var rb: RigidBody2D = it as RigidBody2D
			if rb == null:
				continue
			if rb.freeze:
				continue
			if rb.collision_layer == 0:
				continue

			# tile.gd ma is_snapped (best-effort)
			var snapped: bool = false
			var v = rb.get("is_snapped")
			if v is bool and v:
				snapped = true
			if snapped:
				continue

			var d: float = rb.global_position.distance_to(global_position)
			if d <= r and d < best_d:
				best_d = d
				best = rb

	return best

func _grab_tile(tile_body: RigidBody2D) -> void:
	if tile_body == null:
		return
	grabbed_tile = tile_body
	grabbed_tile.add_collision_exception_with(self)
	grabbed_tile.angular_velocity = 0.0

func _carry_tile_pd(delta: float) -> void:
	if grabbed_tile == null or not is_instance_valid(grabbed_tile):
		_release_tile()
		return

	if grabbed_tile.freeze or grabbed_tile.collision_layer == 0:
		_release_tile()
		return

	var d: float = grabbed_tile.global_position.distance_to(global_position)
	if d > max_grab_distance:
		_release_tile()
		return

	# trzymamy tile ZA goblinem
	var dir: Vector2 = velocity
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	var hold_point: Vector2 = global_position - dir * hold_distance

	var pos_err: Vector2 = hold_point - grabbed_tile.global_position
	var vel_err: Vector2 = -grabbed_tile.linear_velocity

	var accel_vec: Vector2 = pos_err * carry_spring + vel_err * carry_damping
	grabbed_tile.linear_velocity += accel_vec * delta

	var v: Vector2 = grabbed_tile.linear_velocity
	var vl: float = v.length()
	if vl > max_tile_speed:
		grabbed_tile.linear_velocity = v * (max_tile_speed / vl)

func _release_tile() -> void:
	if grabbed_tile == null:
		return
	if is_instance_valid(grabbed_tile):
		grabbed_tile.remove_collision_exception_with(self)
	grabbed_tile = null

# ============================================================
# Helpers
# ============================================================

func _play_area_size() -> Vector2:
	var size: Vector2 = Vector2(1280, 720)
	if puzzle_manager != null:
		var pas = puzzle_manager.get("play_area_size")
		if pas is Vector2:
			size = pas
	return size

func _update_animation(delta: float) -> void:
	if sprite == null:
		return

	if velocity.length() < 1.0:
		sprite.frame = idle_frame
		_anim_time = 0.0
		return

	_anim_time += delta
	var frames: int = max(1, sprite.hframes * sprite.vframes)
	sprite.frame = int(_anim_time * anim_fps) % frames
