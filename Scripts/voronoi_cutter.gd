extends RefCounted

# Voronoi-based shape cutting engine
# Generates organic puzzle pieces from a 48x48 shape image

class VoronoiPiece:
	var id: int = 0
	var pixels: Array[Vector2i] = []  # Pixel coordinates in this region
	var centroid: Vector2 = Vector2.ZERO  # Center point
	var boundary: PackedVector2Array = PackedVector2Array()  # Polygon outline
	var texture_region: Image = null  # Extracted texture
	var bounding_rect: Rect2i = Rect2i()  # Min rect containing all pixels

	func calculate_centroid():
		"""Calculate the geometric center of all pixels"""
		if pixels.is_empty():
			return

		var sum := Vector2.ZERO
		for pixel in pixels:
			sum += Vector2(pixel)
		centroid = sum / float(pixels.size())

	func calculate_bounding_rect():
		"""Calculate minimum rectangle containing all pixels"""
		if pixels.is_empty():
			return

		var min_x := pixels[0].x
		var max_x := pixels[0].x
		var min_y := pixels[0].y
		var max_y := pixels[0].y

		for pixel in pixels:
			min_x = mini(min_x, pixel.x)
			max_x = maxi(max_x, pixel.x)
			min_y = mini(min_y, pixel.y)
			max_y = maxi(max_y, pixel.y)

		bounding_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

const SHAPE_SIZE := 48
const MIN_PIECE_SIZE := 48  # Minimum pixels per piece (prevents tiny slivers)
const MIN_SEED_DISTANCE := 12.0  # Minimum distance between seed points

var rng := RandomNumberGenerator.new()

func _init():
	rng.randomize()

func cut_shape(shape_image: Image, num_pieces: int = 9) -> Array[VoronoiPiece]:
	"""
	Cut a 48x48 shape into Voronoi regions
	Returns array of VoronoiPiece objects
	"""
	if shape_image == null:
		push_error("VoronoiCutter: shape_image is null")
		return []

	# Generate seed points
	var seeds := generate_seed_points(shape_image, num_pieces)

	if seeds.is_empty():
		push_error("VoronoiCutter: Failed to generate seed points")
		return []

	# Assign each pixel to nearest seed (Voronoi diagram)
	var pieces := create_voronoi_regions(shape_image, seeds)

	# Validate piece sizes and merge small pieces
	pieces = validate_and_merge_pieces(pieces, shape_image)

	# Generate boundaries and extract textures
	for piece in pieces:
		piece.calculate_centroid()
		piece.calculate_bounding_rect()
		piece.boundary = trace_boundary(piece.pixels)
		piece.texture_region = extract_texture(shape_image, piece)

	return pieces

func generate_seed_points(shape_image: Image, num_seeds: int) -> Array[Vector2]:
	"""Generate random seed points within opaque pixels, with minimum distance constraint"""
	var opaque_pixels: Array[Vector2i] = []

	# Find all opaque pixels in the shape
	for y in range(SHAPE_SIZE):
		for x in range(SHAPE_SIZE):
			var alpha := shape_image.get_pixel(x, y).a
			if alpha > 0.1:  # Opaque threshold
				opaque_pixels.append(Vector2i(x, y))

	if opaque_pixels.is_empty():
		push_warning("VoronoiCutter: No opaque pixels found in shape")
		return []

	var seeds: Array[Vector2] = []
	var attempts := 0
	var max_attempts := num_seeds * 50

	# Use Poisson disk sampling for well-distributed seeds
	while seeds.size() < num_seeds and attempts < max_attempts:
		attempts += 1

		# Pick random opaque pixel
		var random_pixel := opaque_pixels[rng.randi_range(0, opaque_pixels.size() - 1)]
		var candidate := Vector2(random_pixel) + Vector2(0.5, 0.5)  # Center of pixel

		# Check minimum distance to existing seeds
		var valid := true
		for existing_seed in seeds:
			if candidate.distance_to(existing_seed) < MIN_SEED_DISTANCE:
				valid = false
				break

		if valid:
			seeds.append(candidate)

	if seeds.size() < num_seeds:
		push_warning("VoronoiCutter: Only generated %d/%d seeds" % [seeds.size(), num_seeds])

	return seeds

func create_voronoi_regions(shape_image: Image, seeds: Array[Vector2]) -> Array[VoronoiPiece]:
	"""Assign each pixel to its nearest seed to create Voronoi regions"""
	var pieces: Array[VoronoiPiece] = []

	# Initialize pieces
	for i in range(seeds.size()):
		var piece := VoronoiPiece.new()
		piece.id = i
		pieces.append(piece)

	# Assign each opaque pixel to nearest seed
	for y in range(SHAPE_SIZE):
		for x in range(SHAPE_SIZE):
			var alpha := shape_image.get_pixel(x, y).a
			if alpha <= 0.1:  # Skip transparent pixels
				continue

			var pixel := Vector2(x, y) + Vector2(0.5, 0.5)  # Center of pixel

			# Find nearest seed
			var nearest_seed_idx := 0
			var nearest_distance := pixel.distance_to(seeds[0])

			for i in range(1, seeds.size()):
				var distance := pixel.distance_to(seeds[i])
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_seed_idx = i

			# Add pixel to piece
			pieces[nearest_seed_idx].pixels.append(Vector2i(x, y))

	return pieces

func validate_and_merge_pieces(pieces: Array[VoronoiPiece], _shape_image: Image) -> Array[VoronoiPiece]:
	"""Remove tiny pieces and merge them with neighbors"""
	var valid_pieces: Array[VoronoiPiece] = []
	var small_pieces: Array[VoronoiPiece] = []

	# Separate valid and small pieces
	for piece in pieces:
		if piece.pixels.size() >= MIN_PIECE_SIZE:
			valid_pieces.append(piece)
		else:
			small_pieces.append(piece)

	# Merge small pieces into nearest valid piece
	for small_piece in small_pieces:
		if valid_pieces.is_empty():
			continue  # Edge case: all pieces are small

		# Find centroid of small piece
		small_piece.calculate_centroid()

		# Find nearest valid piece
		var nearest_idx := 0
		var nearest_dist := INF

		for i in range(valid_pieces.size()):
			valid_pieces[i].calculate_centroid()
			var dist := small_piece.centroid.distance_to(valid_pieces[i].centroid)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_idx = i

		# Merge pixels into nearest piece
		valid_pieces[nearest_idx].pixels.append_array(small_piece.pixels)

	# Reassign IDs
	for i in range(valid_pieces.size()):
		valid_pieces[i].id = i

	return valid_pieces

func trace_boundary(pixels: Array[Vector2i]) -> PackedVector2Array:
	"""
	Extract boundary polygon from pixel list using marching squares
	Returns polygon in local coordinates (relative to piece center)
	"""
	if pixels.is_empty():
		return PackedVector2Array()

	# Create a bitmap of the pixels
	var min_x := pixels[0].x
	var max_x := pixels[0].x
	var min_y := pixels[0].y
	var max_y := pixels[0].y

	for pixel in pixels:
		min_x = mini(min_x, pixel.x)
		max_x = maxi(max_x, pixel.x)
		min_y = mini(min_y, pixel.y)
		max_y = maxi(max_y, pixel.y)

	var width := max_x - min_x + 1
	var height := max_y - min_y + 1

	# Create a 2D grid marking which cells are filled
	var grid: Array[Array] = []
	for _y in range(height + 2):  # +2 for border
		var row: Array[bool] = []
		row.resize(width + 2)
		row.fill(false)
		grid.append(row)

	# Fill grid with pixel positions (offset by 1 for border)
	for pixel in pixels:
		var gx := pixel.x - min_x + 1
		var gy := pixel.y - min_y + 1
		grid[gy][gx] = true

	# Use BitMap for contour tracing (more robust)
	var bitmap := BitMap.new()
	bitmap.create(Vector2i(width + 2, height + 2))

	for y in range(height + 2):
		for x in range(width + 2):
			bitmap.set_bit(x, y, grid[y][x])

	# Extract polygon
	var polygons := bitmap.opaque_to_polygons(Rect2(0, 0, width + 2, height + 2), 2.0)

	if polygons.is_empty():
		push_warning("VoronoiCutter: No boundary found for piece")
		return PackedVector2Array()

	# Use the largest polygon (handles holes)
	var largest_polygon := polygons[0]
	for polygon in polygons:
		if polygon.size() > largest_polygon.size():
			largest_polygon = polygon

	# Convert to world coordinates (offset back)
	var boundary := PackedVector2Array()
	for point in largest_polygon:
		var world_point := Vector2(point.x - 1 + min_x, point.y - 1 + min_y)
		boundary.append(world_point)

	return boundary

func extract_texture(shape_image: Image, piece: VoronoiPiece) -> Image:
	"""Extract texture region for this piece (with transparency)"""
	if piece.pixels.is_empty():
		return null

	var rect := piece.bounding_rect
	var texture := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	texture.fill(Color(0, 0, 0, 0))  # Transparent

	# Copy pixels from original image
	for pixel in piece.pixels:
		var local_x := pixel.x - rect.position.x
		var local_y := pixel.y - rect.position.y
		var color := shape_image.get_pixel(pixel.x, pixel.y)
		texture.set_pixel(local_x, local_y, color)

	return texture
