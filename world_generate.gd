extends Node2D

@export var MAP_WIDTH: int = 6*16
@export var MAP_HEIGHT: int = 6*16
@export var noise: FastNoiseLite
@export var tile_width = 16
@export var tile_height = 16

var grass_tiles = [
	Vector2i(0 ,0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2)
]

var water_tiles = [
	Vector2i(8, 14)
]

var tree_tiles = [
	Vector2i(17, 7)
]

var sand_tiles = [
	Vector2i(20, 1)
]

# references to tilemaplayers
@onready var grass: TileMapLayer = $grass
@onready var water: TileMapLayer = $water
@onready var trees: TileMapLayer = $trees

var generated_tiles: Dictionary = {}
var generated_chunks: Dictionary = {}

var chunk_dimension: int = 16 # 16x16 chunks

func str_to_vector2i(s: String) -> Vector2i:
	s = s.lstrip("(")
	s = s.rstrip(")")
	var parts = s.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func save_world_info(path: String = "res://world_info.json") -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data = {
			"seed": noise.seed,
			"noise_type": noise.noise_type,
			"frequency": noise.frequency,
			"fractal_type": noise.fractal_type,
			"octaves": noise.fractal_octaves,
			"lacunarity": noise.fractal_lacunarity,
			"gain": noise.fractal_gain,
			"weighted_strength": noise.fractal_weighted_strength,
			"ping_pong_strength": noise.fractal_ping_pong_strength,
			"domain_warp_enabled": noise.domain_warp_enabled,
			"domain_warp_amplitude": noise.domain_warp_amplitude
		}
		
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		print("Unable to save world info..")
		
func load_world_info(path: String = "res://world_info.json") -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var world_info = JSON.parse_string(file.get_as_text())
		
		noise = FastNoiseLite.new()
		noise.seed = world_info["seed"]
		noise.noise_type = world_info["noise_type"]
		noise.frequency = world_info["frequency"]
		noise.fractal_type = world_info["fractal_type"]
		noise.fractal_octaves = world_info["octaves"]
		noise.fractal_lacunarity = float(world_info["lacunarity"])
		noise.fractal_gain = world_info["gain"]
		noise.fractal_weighted_strength = world_info["weighted_strength"]
		noise.fractal_ping_pong_strength = world_info["ping_pong_strength"]
		noise.domain_warp_enabled = world_info["domain_warp_enabled"]
		noise.domain_warp_amplitude = world_info["domain_warp_amplitude"]
		
		print("world info loaded sucessfully.")
	else:
		print("cannot load world info.")

func save_world(path: String = "res://world.json") -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data = {}
		for tile in generated_tiles:
			data[str(tile)] = generated_tiles[tile]

		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		print("[SAVE WORLD] unable to save world!")

func load_world(path: String = "res://world.json"):
	if not FileAccess.file_exists(path):
		print("[LOAD WORLD] File doesn't exists.")
	var file = FileAccess.open(path, FileAccess.READ)
	var tiles = JSON.parse_string(file.get_as_text())
	
	grass.clear()
	trees.clear()
	water.clear()
	
	for key in tiles:
		#print(key)
		var tile_pos = str_to_vector2i(str(key))
		var tile_info = tiles[key]
		var atlas_coords = str_to_vector2i(tile_info.tile)
		
		match tile_info.cell_type:
			"grass":
				grass.set_cell(tile_pos, 0,  atlas_coords)
			"tree":
				grass.set_cell(tile_pos, 0, Vector2i(0 ,0))
				trees.set_cell(tile_pos, 0, atlas_coords)
			"water":
				water.set_cell(tile_pos, 0, atlas_coords)

func get_camera_chunk() -> Vector2i:
	var camera = get_viewport().get_camera_2d().global_position
	var chunk_x = int(floor(camera.x / (chunk_dimension * tile_width)))
	var chunk_y = int(floor(camera.y / (chunk_dimension * tile_height)))
	return Vector2i(chunk_x, chunk_y)	

func generate_tile(position: Vector2i) -> void:
	var noise_val = noise.get_noise_2d(position.x, position.y)
	var cell_type = ""
	var tile: Vector2i
	if(noise_val < 0.08 and noise_val > 0):
		tile = water_tiles.pick_random()
		cell_type = "water"
		
		water.set_cell(Vector2i(position.x, position.y), 0, tile)
	else:
		tile = grass_tiles.pick_random()
		cell_type = "grass"
		
		grass.set_cell(Vector2i(position.x, position.y), 0, tile)

		var rnd = randi() % 100
		if(rnd > 90):
			tile = tree_tiles.pick_random()
			cell_type = "tree"
			trees.set_cell(Vector2i(position.x, position.y), 0, tile)
	
	generated_tiles[position] = {
		"cell_type": cell_type,
		"tile": tile
	}

func generate_chunk(chunk_position:Vector2i, chunk_dimension: int = 16):
	if generated_chunks.has(chunk_position):
		return
	
	var start_x = chunk_position.x
	var start_y = chunk_position.y
	
	generated_chunks[chunk_position] = true
	for x in range(start_x, start_x + chunk_dimension):
		for y in range(start_y, start_y + chunk_dimension):
			#print(Vector2i(x,y))
			generate_tile(Vector2i(x, y))
	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(noise == null):
		print("[world generation] Noise is null.. creating default noise")
		noise = FastNoiseLite.new()
	#noise.seed = randi()
	
	var file_path = "res://world.json"
	if not FileAccess.file_exists(file_path):
		print("generating world")
		noise.seed = randi()
		for x in range(MAP_WIDTH / chunk_dimension):
			for y in range(MAP_HEIGHT / chunk_dimension):
				generate_chunk(Vector2i(x * chunk_dimension, y * chunk_dimension))
		save_world()
		save_world_info()
	else:
		print("[world generation] world found.. loading it right now")
		load_world_info()
		load_world(file_path)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var camera_chunk = get_camera_chunk()
	var radius = 3
	
	for x in range(camera_chunk.x - radius - 1 , camera_chunk.x + radius + 1):
		for y in range(camera_chunk.y - radius, camera_chunk.y + radius + 1):
			var pos = Vector2i(x, y)
			if not generated_chunks.has(pos):
				generate_chunk(Vector2i(x * chunk_dimension, y * chunk_dimension))
