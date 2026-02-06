@tool
extends EditorScript

# ============================================================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================================================

# Grid Configuration
var grid_size_tiles: Vector2i = Vector2i(30, 30)  # Number of ground tiles in grid
var tile_size: Vector3 = Vector3(2.0, 0, 2.0)    # Size of each tile in units

# Model Folders (all in PlayersAssets)
var base_folder_path: String = "res://bases/"
var building_models_folder: String = "res://buildings/"
var decor_models_folder: String = "res://decors/"

# Base Model Names (found in Base folder)
var ground_tile_name: String = "base"  # Without .glb extension
var road_straight_name: String = "road_straight"
var road_corner_name: String = "road_corner"

# Lanes Configuration
var lanes_x: int = 3              # Number of vertical lanes (roads running N-S)
var lanes_y: int = 2              # Number of horizontal lanes (roads running E-W)
var lane_width: int = 1           # Width of each lane in tiles

# Building Placement
var building_min_size_tiles: Vector2i = Vector2i(1, 1)  # Minimum building size
var building_max_size_tiles: Vector2i = Vector2i(5, 5)  # Maximum 5 tiles = 10 meters per side
var building_spacing_tiles: int = 1                      # Space between buildings (added to base only)
var building_density_multiplier: float = 1.5            # Increased density multiplier (was 1.0)

# Decor Placement
var decor_density: float = 0.50  
var decor_spacing_tiles: int = 1  # Minimum spacing from buildings/roads
var decor_anchor_points_enabled: Array = [
	"center", "north", "south", "east", "west"
]

# Output Scene Path
var output_scene_path: String = "res://scenes/generated_city.tscn"

# Generation Options
var use_corner_pieces: bool = true
var random_seed: int = 42         # Set to 0 for random seed each time
var generate_buildings: bool = true
var generate_decor: bool = true

# Organization
var create_organization_nodes: bool = true  # Group by type (Ground, Roads, Buildings, Decor)

# Height calculation
var base_tile_height: float = 0.0  # Will be calculated from ground model AABB
var height_offset: float = 0.05     # Additional offset if needed

# ============================================================================
# CLASSES AND STRUCTURES
# ============================================================================

class Section:
	var id: int
	var bounds: Rect2i  # Grid coordinates (x_min, z_min, width, height)
	var available_area: int = 0  # Total available area in tiles
	var available_tiles: Array = []  # Changed from PackedVector2Array to Array
	var occupied_rects: Array = []  # Array of Rect2 representing occupied areas
	var max_buildings: int = 0  # Calculated capacity

class BuildingInfo:
	var model_path: String
	var position: Vector3
	var rotation_y: float
	var scale: Vector3 = Vector3.ONE
	var size_tiles: Vector2i  # Original size
	var rotated_size: Vector2i  # Size after rotation
	var grid_position: Vector2i
	var model_name: String
	var occupied_rect: Rect2  # Area this building occupies (including spacing)

class DecorInfo:
	var model_path: String
	var position: Vector3
	var rotation_y: float
	var scale: Vector3 = Vector3.ONE
	var anchor_point: String
	var model_name: String
	var grid_position: Vector2i
	var occupied_rect: Rect2

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

func _run():
	print("🏙️  Starting CityBuilderCG Scene Generation...")
	print("=" + "=".repeat(59))
	
	# Setup random seed
	if random_seed == 0:
		randomize()
	else:
		seed(random_seed)
	
	# Build full paths
	var ground_tile_path = base_folder_path + ground_tile_name + ".glb"
	var road_straight_path = base_folder_path + road_straight_name + ".glb"
	var road_corner_path = base_folder_path + road_corner_name + ".glb"
	
	# Validate paths
	if not validate_paths(ground_tile_path, road_straight_path, road_corner_path):
		return
	
	# Load all models
	print("\n📦 Loading models...")
	var loaded_models = load_models(ground_tile_path, road_straight_path, road_corner_path)
	if loaded_models.is_empty():
		return
	
	# Calculate base tile height from ground model
	calculate_base_tile_height(loaded_models.ground)
	
	# STEP 1: Generate base grid (30x30 at positions 0-29)
	print("\n" + "=".repeat(60))
	print("STEP 1: GENERATING BASE GRID (positions 0 to %d)" % (grid_size_tiles.x - 1))
	print("=".repeat(60))
	var grid_data = generate_base_grid()
	
	# STEP 2: Add lane roads INSIDE grid (positions 0-29)
	print("\n" + "=".repeat(60))
	print("STEP 2: ADDING LANE ROADS (inside grid only)")
	print("=".repeat(60))
	add_lane_roads(grid_data)
	
	# STEP 3: Add boundary OUTSIDE grid (at positions -1 and grid_size)
	print("\n" + "=".repeat(60))
	print("STEP 3: ADDING BOUNDARY (at positions -1 and %d)" % grid_size_tiles.x)
	print("=".repeat(60))
	add_boundary_outside_grid(grid_data)
	
	# STEP 4: Create sections with area calculation
	print("\n" + "=".repeat(60))
	print("STEP 4: CREATING SECTIONS WITH AREA ANALYSIS")
	print("=".repeat(60))
	var sections = create_sections_from_grid(grid_data)
	
	# STEP 5: Place buildings with increased density
	var building_instances = []
	if generate_buildings and not loaded_models.buildings.is_empty():
		print("\n" + "=".repeat(60))
		print("STEP 5: PLACING BUILDINGS (increased density: %.1fx)" % building_density_multiplier)
		print("=".repeat(60))
		building_instances = place_buildings_in_sections(sections, loaded_models.buildings, grid_data)
		print("✅ Placed %d buildings" % building_instances.size())
	
	# STEP 6: Place decor with increased density
	var decor_instances = []
	if generate_decor and not loaded_models.decor.is_empty():
		print("\n" + "=".repeat(60))
		print("STEP 6: PLACING DECOR WITH INCREASED DENSITY")
		print("=".repeat(60))
		decor_instances = place_decor_on_ground(grid_data, loaded_models.decor, building_instances)
		print("✅ Placed %d decor items (density: %.2f)" % [decor_instances.size(), decor_density])
	
	# Create and save the scene
	print("\n" + "=".repeat(60))
	print("FINAL STEP: CREATING SCENE")
	print("=".repeat(60))
	create_and_save_scene(grid_data, building_instances, decor_instances, loaded_models)
	
	print("\n" + "=".repeat(60))
	print("✅ CITY SCENE GENERATION COMPLETE!")
	print("=".repeat(60))

# ============================================================================
# HEIGHT CALCULATION
# ============================================================================

func calculate_base_tile_height(ground_scene: PackedScene):
	"""Calculate the height of the base tile by instantiating it and getting its AABB"""
	if not ground_scene:
		print("⚠️  Warning: Ground scene not loaded, using height 0")
		base_tile_height = 0.0
		return
	
	# Temporarily instantiate the ground tile
	var temp_instance = ground_scene.instantiate()
	
	# Get all MeshInstance3D nodes
	var meshes = []
	get_all_mesh_instances(temp_instance, meshes)
	
	if meshes.is_empty():
		print("⚠️  Warning: No meshes found in ground tile, using height 0")
		base_tile_height = 0.0
		temp_instance.queue_free()
		return
	
	# Calculate combined AABB
	var combined_aabb = meshes[0].get_aabb()
	for i in range(1, meshes.size()):
		combined_aabb = combined_aabb.merge(meshes[i].get_aabb())
	
	# The height is the max Y value of the AABB
	base_tile_height = combined_aabb.position.y + combined_aabb.size.y
	
	print("📏 Base tile height calculated: %.3f units" % base_tile_height)
	print("📏 Height offset: %.3f units" % height_offset)
	
	# Clean up
	temp_instance.queue_free()

func get_all_mesh_instances(node: Node, meshes: Array):
	"""Recursively collect all MeshInstance3D nodes"""
	if node is MeshInstance3D:
		meshes.append(node)
	
	for child in node.get_children():
		get_all_mesh_instances(child, meshes)

# ============================================================================
# STEP 1: GENERATE BASE GRID
# ============================================================================

func generate_base_grid() -> Dictionary:
	print("Generating %dx%d grid at positions [0 to %d, 0 to %d]..." % [
		grid_size_tiles.x, grid_size_tiles.y,
		grid_size_tiles.x - 1, grid_size_tiles.y - 1
	])
	
	var grid_data = {
		"tiles": {},  # Key: Vector2i grid position, Value: tile type
		"ground_positions": [],
		"road_positions": [],
		"corner_positions": [],
		"all_positions": []
	}
	
	# Initialize all tiles as ground (ONLY positions 0 to grid_size-1)
	for x in range(grid_size_tiles.x):
		for z in range(grid_size_tiles.y):
			var pos = Vector2i(x, z)
			grid_data.tiles[pos] = "ground"
			grid_data.ground_positions.append(pos)
			grid_data.all_positions.append(pos)
	
	print("✅ Created %d ground tiles" % grid_data.ground_positions.size())
	return grid_data

# ============================================================================
# STEP 2: ADD LANE ROADS (INSIDE GRID ONLY)
# ============================================================================

func add_lane_roads(grid_data: Dictionary):
	if lanes_x <= 0 and lanes_y <= 0:
		print("⚠️  No lanes configured, skipping lane roads")
		return
	
	var lane_count = 0
	
	# Calculate lane positions
	var lane_positions_x = calculate_lane_positions(lanes_x, grid_size_tiles.x)
	var lane_positions_z = calculate_lane_positions(lanes_y, grid_size_tiles.y)
	
	print("Lane positions X: %s" % str(lane_positions_x))
	print("Lane positions Z: %s" % str(lane_positions_z))
	
	# Add horizontal lanes (roads running E-W)
	for z_pos in lane_positions_z:
		for w in range(lane_width):
			var lane_z = z_pos - int(floor(lane_width / 2.0)) + w
			
			# Only place lanes within grid bounds (0 to grid_size-1)
			if lane_z < 0 or lane_z >= grid_size_tiles.y:
				continue
			
			for x in range(grid_size_tiles.x):
				var pos = Vector2i(x, lane_z)
				
				# Convert ground to road
				if grid_data.tiles.get(pos) == "ground":
					grid_data.tiles[pos] = "road"
					grid_data.road_positions.append(pos)
					
					# Remove from ground positions
					grid_data.ground_positions.erase(pos)
					lane_count += 1
	
	# Add vertical lanes (roads running N-S)
	for x_pos in lane_positions_x:
		for w in range(lane_width):
			var lane_x = x_pos - int(floor(lane_width / 2.0)) + w
			
			# Only place lanes within grid bounds (0 to grid_size-1)
			if lane_x < 0 or lane_x >= grid_size_tiles.x:
				continue
			
			for z in range(grid_size_tiles.y):
				var pos = Vector2i(lane_x, z)
				
				# Convert ground to road (if not already road)
				if grid_data.tiles.get(pos) == "ground":
					grid_data.tiles[pos] = "road"
					grid_data.road_positions.append(pos)
					
					# Remove from ground positions
					grid_data.ground_positions.erase(pos)
					lane_count += 1
	
	print("✅ Added %d lane road tiles" % lane_count)

# ============================================================================
# STEP 3: ADD BOUNDARY (OUTSIDE GRID, AFTER LANES)
# ============================================================================

func add_boundary_outside_grid(grid_data: Dictionary):
	print("Adding boundary at positions -1 and %d..." % grid_size_tiles.x)
	
	var boundary_min = -1
	var boundary_max = grid_size_tiles.x
	var boundary_count = 0
	
	# Top and bottom boundaries (full width including corners)
	for x in range(boundary_min, boundary_max + 1):
		# Bottom boundary
		var pos_bottom = Vector2i(x, boundary_min)
		grid_data.tiles[pos_bottom] = "road"
		grid_data.road_positions.append(pos_bottom)
		grid_data.all_positions.append(pos_bottom)
		boundary_count += 1
		
		# Top boundary
		var pos_top = Vector2i(x, boundary_max)
		grid_data.tiles[pos_top] = "road"
		grid_data.road_positions.append(pos_top)
		grid_data.all_positions.append(pos_top)
		boundary_count += 1
	
	# Left and right boundaries (without corners, already added)
	for z in range(0, grid_size_tiles.y):
		# Left boundary
		var pos_left = Vector2i(boundary_min, z)
		grid_data.tiles[pos_left] = "road"
		grid_data.road_positions.append(pos_left)
		grid_data.all_positions.append(pos_left)
		boundary_count += 1
		
		# Right boundary
		var pos_right = Vector2i(boundary_max, z)
		grid_data.tiles[pos_right] = "road"
		grid_data.road_positions.append(pos_right)
		grid_data.all_positions.append(pos_right)
		boundary_count += 1
	
	# Add corner pieces
	if use_corner_pieces:
		var corners = [
			Vector2i(boundary_min, boundary_min),  # Bottom-left
			Vector2i(boundary_max, boundary_min),  # Bottom-right
			Vector2i(boundary_max, boundary_max),  # Top-right
			Vector2i(boundary_min, boundary_max)   # Top-left
		]
		
		for corner_pos in corners:
			grid_data.tiles[corner_pos] = "corner"
			grid_data.corner_positions.append(corner_pos)
			
			# Remove from road positions if exists
			grid_data.road_positions.erase(corner_pos)
		
		print("✅ Added boundary with %d road tiles and %d corners" % [boundary_count - 4, 4])
	else:
		print("✅ Added boundary with %d road tiles" % boundary_count)

# ============================================================================
# STEP 4: CREATE SECTIONS
# ============================================================================

func create_sections_from_grid(grid_data: Dictionary) -> Array:
	var sections = []
	var section_id = 0
	
	# Find all rectangular sections by analyzing road patterns
	var processed = {}
	
	for pos in grid_data.ground_positions:
		if processed.has(pos):
			continue
		
		# Try to find a rectangular section starting from this position
		var section = find_section_at(pos, grid_data, processed)
		if section and section.bounds.get_area() > 0:
			section.id = section_id
			sections.append(section)
			section_id += 1
			
			# Calculate section properties
			calculate_section_properties(section, grid_data)
	
	print("Found %d sections" % sections.size())
	return sections

func find_section_at(start_pos: Vector2i, grid_data: Dictionary, processed: Dictionary) -> Section:
	# Find the bounding rectangle for this section
	var min_x = start_pos.x
	var max_x = start_pos.x
	var min_z = start_pos.y
	var max_z = start_pos.y
	
	# Expand in all directions until we hit roads or boundaries
	# Expand right
	while max_x + 1 < grid_size_tiles.x and grid_data.tiles.get(Vector2i(max_x + 1, start_pos.y)) == "ground":
		max_x += 1
	
	# Expand down
	while max_z + 1 < grid_size_tiles.y and grid_data.tiles.get(Vector2i(start_pos.x, max_z + 1)) == "ground":
		max_z += 1
	
	# Expand left
	while min_x > 0 and grid_data.tiles.get(Vector2i(min_x - 1, start_pos.y)) == "ground":
		min_x -= 1
	
	# Expand up
	while min_z > 0 and grid_data.tiles.get(Vector2i(start_pos.x, min_z - 1)) == "ground":
		min_z -= 1
	
	# Verify it's a valid rectangle
	var section = Section.new()
	section.bounds = Rect2i(min_x, min_z, max_x - min_x + 1, max_z - min_z + 1)
	
	# Mark all tiles in this section as processed
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var pos = Vector2i(x, z)
			if grid_data.tiles.get(pos) == "ground":
				processed[pos] = true
	
	return section

func calculate_section_properties(section: Section, grid_data: Dictionary):
	# Count available tiles
	var available_count = 0
	for x in range(section.bounds.position.x, section.bounds.position.x + section.bounds.size.x):
		for z in range(section.bounds.position.y, section.bounds.position.y + section.bounds.size.y):
			var pos = Vector2i(x, z)
			if grid_data.tiles.get(pos) == "ground":
				available_count += 1
				section.available_tiles.append(Vector2(x, z))
	
	section.available_area = available_count
	
	# Estimate max buildings with increased density
	var avg_building_area = (building_min_size_tiles.x + building_max_size_tiles.x) * \
							(building_min_size_tiles.y + building_max_size_tiles.y) / 4.0
	var avg_with_spacing = avg_building_area + (building_spacing_tiles * 4)
	section.max_buildings = max(1, int(section.available_area / avg_with_spacing * building_density_multiplier))
	
	print("   Section %d: %dx%d tiles, %d available, max %d buildings (density: %.1fx)" % [
		section.id, section.bounds.size.x, section.bounds.size.y,
		section.available_area, section.max_buildings, building_density_multiplier
	])

# ============================================================================
# STEP 5: PLACE BUILDINGS (AT BASE TILE HEIGHT)
# ============================================================================

func place_buildings_in_sections(sections: Array, building_models: Array, grid_data: Dictionary) -> Array:
	var all_buildings = []
	
	for section in sections:
		print("\n   Processing Section %d (area: %d tiles, capacity: %d buildings)" % [
			section.id, section.available_area, section.max_buildings
		])
		
		var placed_count = 0
		
		# Convert available_tiles to Array for shuffle
		var available_tiles_array = []
		for tile in section.available_tiles:
			available_tiles_array.append(Vector2i(int(tile.x), int(tile.y)))
		
		# Shuffle the array
		shuffle_array(available_tiles_array)
		
		for building_num in range(section.max_buildings):
			if available_tiles_array.size() == 0:
				print("      No more available tiles for buildings")
				break
			
			var max_attempts = 20  # Increased attempts for higher density
			var placed = false
			
			for attempt in range(max_attempts):
				# Randomly select a building model
				var model_info = building_models[randi() % building_models.size()]
				
				# Random size within constraints
				var width = randi_range(building_min_size_tiles.x, building_max_size_tiles.x)
				var depth = randi_range(building_min_size_tiles.y, building_max_size_tiles.y)
				
				# Random rotation (0, 90, 180, 270)
				var rotation_degrees = float((randi() % 4) * 90)
				var rotated_size = get_rotated_size(Vector2i(width, depth), rotation_degrees)
				
				# Try random positions from available tiles
				if available_tiles_array.size() == 0:
					break
					
				var try_tile_idx = randi() % available_tiles_array.size()
				var try_pos = available_tiles_array[try_tile_idx]
				
				# Check if this position is valid
				if can_place_building_at(try_pos, rotated_size, section, grid_data):
					# Place the building!
					var building = create_building_instance(
						try_pos, 
						Vector2i(width, depth),
						rotated_size,
						rotation_degrees,
						model_info
					)
					
					all_buildings.append(building)
					section.occupied_rects.append(building.occupied_rect)
					
					# Remove occupied tiles from available tiles
					var tiles_to_remove = []
					for i in range(available_tiles_array.size()):
						var tile_pos = available_tiles_array[i]
						if tile_pos.x >= try_pos.x and tile_pos.x < try_pos.x + rotated_size.x and \
						   tile_pos.y >= try_pos.y and tile_pos.y < try_pos.y + rotated_size.y:
							tiles_to_remove.append(i)
					
					# Remove in reverse order to maintain indices
					tiles_to_remove.reverse()
					for idx in tiles_to_remove:
						available_tiles_array.remove_at(idx)
					
					placed_count += 1
					placed = true
					
					print("      Building %d: %dx%d (rot %.0f°) at (%d,%d)" % [
						placed_count, width, depth, rotation_degrees,
						try_pos.x, try_pos.y
					])
					break  # Successfully placed, move to next building
			
			if not placed and available_tiles_array.size() > 0:
				# Remove first tile and continue (helps with very dense packing)
				available_tiles_array.remove_at(0)
		
		print("   Section %d: Placed %d/%d buildings" % [section.id, placed_count, section.max_buildings])
	
	return all_buildings

func shuffle_array(array: Array):
	# Custom shuffle function for arrays
	var n = array.size()
	for i in range(n - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp

func get_rotated_size(original_size: Vector2i, rotation_degrees: float) -> Vector2i:
	var rot_normalized = int(rotation_degrees) % 360
	
	# Swap dimensions for 90° and 270° rotations
	if rot_normalized == 90 or rot_normalized == 270:
		return Vector2i(original_size.y, original_size.x)
	else:
		return original_size

func can_place_building_at(pos: Vector2i, size: Vector2i, section: Section, grid_data: Dictionary) -> bool:
	# Check if building fits within section bounds
	if pos.x + size.x > section.bounds.position.x + section.bounds.size.x or \
	   pos.y + size.y > section.bounds.position.y + section.bounds.size.y:
		return false
	
	# Check all tiles are ground
	for dx in range(size.x):
		for dz in range(size.y):
			var check_pos = pos + Vector2i(dx, dz)
			if grid_data.tiles.get(check_pos) != "ground":
				return false
	
	# Check spacing from roads (no road within spacing distance)
	for dx in range(-building_spacing_tiles, size.x + building_spacing_tiles):
		for dz in range(-building_spacing_tiles, size.y + building_spacing_tiles):
			var check_pos = pos + Vector2i(dx, dz)
			var tile_type = grid_data.tiles.get(check_pos)
			if tile_type == "road" or tile_type == "corner":
				return false
	
	# Check collision with existing buildings in this section
	var occupied_rect = Rect2(
		pos.x - building_spacing_tiles,
		pos.y - building_spacing_tiles,
		size.x + (building_spacing_tiles * 2),
		size.y + (building_spacing_tiles * 2)
	)
	
	for existing_rect in section.occupied_rects:
		if occupied_rect.intersects(existing_rect):
			return false
	
	return true

func create_building_instance(grid_pos: Vector2i, original_size: Vector2i, rotated_size: Vector2i, rotation: float, model_info: Dictionary) -> BuildingInfo:
	var building = BuildingInfo.new()
	building.model_path = model_info.path
	building.model_name = model_info.name
	building.size_tiles = original_size
	building.rotated_size = rotated_size
	building.grid_position = grid_pos
	building.rotation_y = rotation
	
	# Calculate world position (center of building)
	var world_x = (grid_pos.x + rotated_size.x / 2.0) * tile_size.x
	var world_z = (grid_pos.y + rotated_size.y / 2.0) * tile_size.z
	
	# PLACED AT BASE TILE HEIGHT WITH OFFSET
	building.position = Vector3(world_x, base_tile_height + height_offset, world_z)
	
	# Occupied rect (with spacing)
	building.occupied_rect = Rect2(
		grid_pos.x - building_spacing_tiles,
		grid_pos.y - building_spacing_tiles,
		rotated_size.x + (building_spacing_tiles * 2),
		rotated_size.y + (building_spacing_tiles * 2)
	)
	
	# Slight scale variation
	var scale_var = randf_range(0.95, 1.05)
	building.scale = Vector3(scale_var, scale_var, scale_var)
	
	return building

# ============================================================================
# STEP 6: PLACE DECOR (AT BASE TILE HEIGHT)
# ============================================================================

# STEP 6: Place decor with increased density
func place_decor_on_ground(grid_data: Dictionary, decor_models: Array, buildings: Array) -> Array:
	var all_decor = []
	
	if decor_models.is_empty():
		return all_decor
	
	var placed_count = 0
	
	# Calculate target number of decor items
	var target_decor = int(grid_data.ground_positions.size() * decor_density)
	
	# For very high density (>= 0.5), try to place on as many tiles as possible
	if decor_density >= 0.5:
		target_decor = int(grid_data.ground_positions.size() * 0.8)  # Try for 80% coverage max
	
	print("Placing decor on %d ground tiles (target: %d, density: %.2f)" % [
		grid_data.ground_positions.size(), target_decor, decor_density
	])
	
	# Shuffle ground positions
	var shuffled_ground = grid_data.ground_positions.duplicate()
	shuffle_array(shuffled_ground)
	
	for ground_pos in shuffled_ground:
		if placed_count >= target_decor:
			break
		
		# For high density, skip the random check entirely
		if decor_density < 1.0:
			# Only do random skip for densities less than 100%
			if randf() > decor_density:
				continue
		
		# Check if valid for decor
		if not is_valid_decor_position(ground_pos, grid_data, buildings, all_decor):
			continue
		
		# Pick random decor model
		var model_info = decor_models[randi() % decor_models.size()]
		
		# Pick random anchor point
		var anchor = decor_anchor_points_enabled[randi() % decor_anchor_points_enabled.size()]
		
		# Calculate position AT BASE TILE HEIGHT
		var world_x = ground_pos.x * tile_size.x
		var world_z = ground_pos.y * tile_size.z
		var base_pos = Vector3(world_x, base_tile_height + height_offset, world_z)
		var offset = get_anchor_offset(anchor, tile_size)
		var decor_pos = base_pos + offset
	
		# Create decor
		var decor = DecorInfo.new()
		decor.model_path = model_info.path
		decor.model_name = model_info.name
		decor.position = decor_pos
		decor.anchor_point = anchor
		decor.grid_position = ground_pos
		
		# Occupied rect (1 tile with spacing)
		decor.occupied_rect = Rect2(
			ground_pos.x - decor_spacing_tiles,
			ground_pos.y - decor_spacing_tiles,
			1 + (decor_spacing_tiles * 2),
			1 + (decor_spacing_tiles * 2)
		)
		
		# Random rotation
		decor.rotation_y = float((randi() % 4) * 90)
		
		# Random scale variation
		var scale_var = randf_range(0.8, 1.2)
		decor.scale = Vector3(scale_var, scale_var, scale_var)
		
		all_decor.append(decor)
		placed_count += 1
	
	return all_decor

func is_valid_decor_position(pos: Vector2i, grid_data: Dictionary, buildings: Array, existing_decor: Array) -> bool:
	# Must be ground tile
	if grid_data.tiles.get(pos) != "ground":
		return false
	
	# Check if the tile itself is a road
	var tile_type = grid_data.tiles.get(pos)
	if tile_type == "road" or tile_type == "corner":
		return false
	
	# For decor spacing, only check immediate neighbors (not the full spacing area)
	# This allows decor to be placed closer to roads
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue  # Skip the tile itself (already checked)
			
			var check_pos = pos + Vector2i(dx, dz)
			var neighbor_type = grid_data.tiles.get(check_pos)
			if neighbor_type == "road" or neighbor_type == "corner":
				# Allow decor next to roads, just not on them
				pass  # This is OK for high density
	
	# Create occupied rect for this decor (minimal spacing)
	var decor_rect = Rect2(
		pos.x,
		pos.y,
		1,
		1
	)
	
	# Check collision with buildings (using minimal overlap)
	for building in buildings:
		# Create a smaller check area for buildings
		var building_check_rect = Rect2(
			building.grid_position.x,
			building.grid_position.y,
			building.rotated_size.x,
			building.rotated_size.y
		)
		if decor_rect.intersects(building_check_rect):
			return false
	
	# Check collision with existing decor (allow some overlap for high density)
	for decor in existing_decor:
		var existing_decor_rect = Rect2(
			decor.grid_position.x,
			decor.grid_position.y,
			1,
			1
		)
		# Only prevent exact same tile placement
		if decor_rect.intersects(existing_decor_rect):
			return false
	
	return true

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func validate_paths(ground_path: String, road_straight_path: String, road_corner_path: String) -> bool:
	var errors = []
	
	if not FileAccess.file_exists(ground_path):
		errors.append("Ground tile not found: " + ground_path)
	
	if not FileAccess.file_exists(road_straight_path):
		errors.append("Road straight not found: " + road_straight_path)
	
	if use_corner_pieces and not FileAccess.file_exists(road_corner_path):
		errors.append("Road corner not found: " + road_corner_path)
		use_corner_pieces = false
	
	# Check if folders exist
	var base_dir = DirAccess.open(base_folder_path)
	if not base_dir:
		errors.append("Base folder not found: " + base_folder_path)
	
	if generate_buildings:
		var building_dir = DirAccess.open(building_models_folder)
		if not building_dir:
			errors.append("Building folder not found: " + building_models_folder)
	
	if generate_decor:
		var decor_dir = DirAccess.open(decor_models_folder)
		if not decor_dir:
			errors.append("Decor folder not found: " + decor_models_folder)
	
	if errors.size() > 0:
		print("❌ VALIDATION ERRORS:")
		for error in errors:
			print("   - " + error)
		return false
	
	return true

func load_models(ground_path: String, road_straight_path: String, road_corner_path: String) -> Dictionary:
	var models = {
		"ground": null,
		"road_straight": null,
		"road_corner": null,
		"buildings": [],
		"decor": []
	}
	
	# Load base models
	models.ground = load(ground_path)
	models.road_straight = load(road_straight_path)
	if use_corner_pieces:
		models.road_corner = load(road_corner_path)
	
	if not models.ground or not models.road_straight:
		print("❌ ERROR: Could not load base models")
		return {}
	
	print("   Base models loaded from: " + base_folder_path)
	
	# Load building models
	if generate_buildings:
		var building_dir = DirAccess.open(building_models_folder)
		if building_dir:
			building_dir.list_dir_begin()
			var file_name = building_dir.get_next()
			var building_count = 0
			
			while file_name != "":
				if file_name.ends_with(".glb") and not building_dir.current_is_dir():
					var full_path = building_models_folder.path_join(file_name)
					var model = load(full_path)
					if model:
						models.buildings.append({
							"path": full_path,
							"scene": model,
							"name": extract_model_name(file_name)
						})
						building_count += 1
				file_name = building_dir.get_next()
			
			print("   Building models: %d loaded" % building_count)
	
	# Load decor models
	if generate_decor:
		var decor_dir = DirAccess.open(decor_models_folder)
		if decor_dir:
			decor_dir.list_dir_begin()
			var file_name = decor_dir.get_next()
			var decor_count = 0
			
			while file_name != "":
				if file_name.ends_with(".glb") and not decor_dir.current_is_dir():
					var full_path = decor_models_folder.path_join(file_name)
					var model = load(full_path)
					if model:
						models.decor.append({
							"path": full_path,
							"scene": model,
							"name": extract_model_name(file_name)
						})
						decor_count += 1
				file_name = decor_dir.get_next()
			
			print("   Decor models: %d loaded" % decor_count)
	
	return models

func calculate_lane_positions(num_lanes: int, grid_size: int) -> PackedInt32Array:
	var positions = PackedInt32Array()
	
	if num_lanes <= 0:
		return positions
	
	# Distribute lanes evenly across the grid
	var spacing = float(grid_size) / (num_lanes + 1)
	
	for i in range(1, num_lanes + 1):
		var pos = int(round(spacing * i))
		positions.append(pos)
	
	return positions

func get_anchor_offset(anchor: String, tile_size: Vector3) -> Vector3:
	var offset = Vector3.ZERO
	
	match anchor:
		"north":
			offset = Vector3(0, 0, -tile_size.z / 3)
		"south":
			offset = Vector3(0, 0, tile_size.z / 3)
		"east":
			offset = Vector3(tile_size.x / 3, 0, 0)
		"west":
			offset = Vector3(-tile_size.x / 3, 0, 0)
		"northeast":
			offset = Vector3(tile_size.x / 3, 0, -tile_size.z / 3)
		"northwest":
			offset = Vector3(-tile_size.x / 3, 0, -tile_size.z / 3)
		"southeast":
			offset = Vector3(tile_size.x / 3, 0, tile_size.z / 3)
		"southwest":
			offset = Vector3(-tile_size.x / 3, 0, tile_size.z / 3)
		# "center" stays at Vector3.ZERO
	
	return offset

# ============================================================================
# FINAL SCENE CREATION
# ============================================================================

func create_and_save_scene(grid_data: Dictionary, buildings: Array, decor: Array, models: Dictionary):
	var instance_counts = {
		"ground": 0,
		"roads": 0,
		"corners": 0,
		"buildings": 0,
		"decor": 0
	}
	
	# Create root node
	var root = Node3D.new()
	root.name = "GeneratedCity"
	
	# Create organization nodes
	var ground_node = root
	var roads_node = root
	var buildings_node = root
	var decor_node = root
	
	if create_organization_nodes:
		ground_node = Node3D.new()
		ground_node.name = "Ground"
		root.add_child(ground_node)
		ground_node.owner = root
		
		roads_node = Node3D.new()
		roads_node.name = "Roads"
		root.add_child(roads_node)
		roads_node.owner = root
		
		buildings_node = Node3D.new()
		buildings_node.name = "Buildings"
		root.add_child(buildings_node)
		buildings_node.owner = root
		
		decor_node = Node3D.new()
		decor_node.name = "Decor"
		root.add_child(decor_node)
		decor_node.owner = root
	
	# Create ground tiles
	print("   Creating ground tiles...")
	instance_counts.ground = create_tiles_from_grid(grid_data, "ground", models.ground, ground_node, root)
	
	# Create road tiles
	print("   Creating road tiles...")
	instance_counts.roads = create_tiles_from_grid(grid_data, "road", models.road_straight, roads_node, root)
	
	# Create corner tiles
	if use_corner_pieces and models.road_corner:
		print("   Creating corner tiles...")
		instance_counts.corners = create_tiles_from_grid(grid_data, "corner", models.road_corner, roads_node, root)
	
	# Create buildings
	if generate_buildings and buildings.size() > 0:
		print("   Creating buildings...")
		instance_counts.buildings = create_building_instances(buildings, models.buildings, buildings_node, root)
	
	# Create decor
	if generate_decor and decor.size() > 0:
		print("   Creating decor...")
		instance_counts.decor = create_decor_instances(decor, models.decor, decor_node, root)
	
	# Save the scene
	save_scene_to_file(root, instance_counts)

func create_tiles_from_grid(grid_data: Dictionary, tile_type: String, scene: PackedScene, parent_node: Node3D, root_node: Node) -> int:
	var count = 0
	var counter = {}
	
	# Get the right position array based on tile type
	var positions = []
	match tile_type:
		"ground":
			positions = grid_data.ground_positions
		"road":
			positions = grid_data.road_positions
		"corner":
			positions = grid_data.corner_positions
	
	for i in range(positions.size()):
		var grid_pos = positions[i]
		
		# Calculate world position
		var world_x = grid_pos.x * tile_size.x
		var world_z = grid_pos.y * tile_size.z
		var world_pos = Vector3(world_x, 0, world_z)
		
		# Create instance
		var instance = scene.instantiate()
		instance.position = world_pos
		
		# Set rotation for roads
		if tile_type == "road":
			instance.rotation_degrees.y = determine_road_rotation(grid_pos, tile_type, grid_data) + 90
		if tile_type == "corner":
			instance.rotation_degrees.y = determine_road_rotation(grid_pos, tile_type, grid_data) + 180
		
		# Set name
		var model_name = extract_model_name(scene.resource_path.get_file())
		var instance_name = "%s_Instance_%d" % [model_name, counter.get(model_name, 0)]
		instance.name = instance_name
		
		# Update counter
		counter[model_name] = counter.get(model_name, 0) + 1
		
		parent_node.add_child(instance)
		instance.owner = root_node
		count += 1
	
	return count

func determine_road_rotation(grid_pos: Vector2i, tile_type: String, grid_data: Dictionary) -> float:
	if tile_type == "corner":
		# Determine corner rotation based on position
		var boundary_min = -1
		var boundary_max = grid_size_tiles.x
		
		if grid_pos == Vector2i(boundary_min, boundary_min):  # Bottom-left
			return 180
		elif grid_pos == Vector2i(boundary_max, boundary_min):  # Bottom-right
			return 90
		elif grid_pos == Vector2i(boundary_max, boundary_max):  # Top-right
			return 0
		elif grid_pos == Vector2i(boundary_min, boundary_max):  # Top-left
			return 270
	
	# For straight roads, check neighbors to determine orientation
	var left_road = grid_data.tiles.get(Vector2i(grid_pos.x - 1, grid_pos.y)) in ["road", "corner"]
	var right_road = grid_data.tiles.get(Vector2i(grid_pos.x + 1, grid_pos.y)) in ["road", "corner"]
	var top_road = grid_data.tiles.get(Vector2i(grid_pos.x, grid_pos.y - 1)) in ["road", "corner"]
	var bottom_road = grid_data.tiles.get(Vector2i(grid_pos.x, grid_pos.y + 1)) in ["road", "corner"]
	
	# If more horizontal connections, rotate for horizontal road
	if (left_road or right_road) and not (top_road or bottom_road):
		return 0  # Horizontal
	else:
		return 90  # Vertical

func create_building_instances(buildings: Array, building_models: Array, parent_node: Node3D, root_node: Node) -> int:
	var count = 0
	
	# Group buildings by model for better naming
	var buildings_by_model = {}
	for building in buildings:
		var model_name = building.model_name
		if not buildings_by_model.has(model_name):
			buildings_by_model[model_name] = []
		buildings_by_model[model_name].append(building)
	
	# Create instances for each building model type
	for model_name in buildings_by_model:
		var model_list = buildings_by_model[model_name]
		
		# Find the scene for this model
		var scene = null
		for model_info in building_models:
			if model_info.name == model_name:
				scene = model_info.scene
				break
		
		if scene:
			for i in range(model_list.size()):
				var building = model_list[i]
				var instance = scene.instantiate()
				
				instance.position = building.position
				instance.rotation_degrees.y = building.rotation_y
				instance.scale = building.scale
				instance.name = "%s_Instance_%d" % [model_name, i]
				
				parent_node.add_child(instance)
				instance.owner = root_node
				count += 1
	
	return count

func create_decor_instances(decor_items: Array, decor_models: Array, parent_node: Node3D, root_node: Node) -> int:
	var count = 0
	
	# Group decor by model for better naming
	var decor_by_model = {}
	for decor_item in decor_items:
		var model_name = decor_item.model_name
		if not decor_by_model.has(model_name):
			decor_by_model[model_name] = []
		decor_by_model[model_name].append(decor_item)
	
	# Create instances for each decor model type
	for model_name in decor_by_model:
		var model_list = decor_by_model[model_name]
		
		# Find the scene for this model
		var scene = null
		for model_info in decor_models:
			if model_info.name == model_name:
				scene = model_info.scene
				break
		
		if scene:
			for i in range(model_list.size()):
				var decor_item = model_list[i]
				var instance = scene.instantiate()
				
				instance.position = decor_item.position
				instance.rotation_degrees.y = decor_item.rotation_y
				instance.scale = decor_item.scale
				instance.name = "%s_Instance_%d" % [model_name, i]
				
				parent_node.add_child(instance)
				instance.owner = root_node
				count += 1
	
	return count

func save_scene_to_file(root_node: Node, instance_counts: Dictionary):
	print("\n💾 Saving scene to: " + output_scene_path)
	
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root_node)
	
	if result == OK:
		var save_result = ResourceSaver.save(packed_scene, output_scene_path)
		if save_result == OK:
			print("✅ Scene saved successfully!")
			print("\n📊 Generation Statistics:")
			print("   Ground Tiles:   %d" % instance_counts.ground)
			print("   Road Tiles:     %d" % instance_counts.roads)
			print("   Corner Tiles:   %d" % instance_counts.corners)
			print("   Buildings:      %d (placed at height %.3f)" % [instance_counts.buildings, base_tile_height + height_offset])
			print("   Decor Items:    %d (placed at height %.3f)" % [instance_counts.decor, base_tile_height + height_offset])
			print("   TOTAL:          %d nodes" % (instance_counts.ground + instance_counts.roads + 
													  instance_counts.corners + instance_counts.buildings + 
													  instance_counts.decor))
			
			# Open the scene in the editor
			var editor_interface = get_editor_interface()
			editor_interface.open_scene_from_path(output_scene_path)
			print("\n🚀 Scene opened in editor!")
		else:
			print("❌ ERROR: Could not save scene to: " + output_scene_path)
	else:
		print("❌ ERROR: Could not pack scene")
	
	# Clean up
	root_node.queue_free()

func extract_model_name(file_name: String) -> String:
	# Remove .glb extension and replace dots with underscores
	return file_name.replace(".glb", "").replace(".", "_")
