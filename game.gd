# This script manages the entire 15-puzzle game logic.
extends Node2D

# --- Constants and Variables ---

const TileScene = preload("res://tile.tscn")
const GRID_SIZE = 4
const ANIMATION_SPEED = 0.1 # Duration of the tile slide animation in seconds.

@onready var grid_container = $UI/GridContainer

var board = []
var tiles = {}
var empty_pos: Vector2i

# A flag to prevent input while a tile is animating.
var is_moving = false

# --- Godot Engine Functions ---

func _ready():
	# Configure the grid container to allow for manual positioning of tiles.
	# This is necessary for the animation to work correctly.
	grid_container.layout_mode = 1 # Set anchors to 0,0,1,1 (full rect)
	grid_container.columns = GRID_SIZE
	
	setup_board()
	# We must draw the board before shuffling so the tile nodes exist.
	create_tiles()
	# Wait for one frame so the container can calculate its size before we shuffle.
	await get_tree().process_frame
	shuffle_board()
	# After shuffling the logical board, update the visual positions of the tiles.
	update_board_visuals(false) # 'false' means no animation for the initial setup.


# --- Game Setup and Initialization ---

func setup_board():
	board.clear()
	var tile_number = 1
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			if tile_number <= GRID_SIZE * GRID_SIZE - 1:
				row.append(tile_number)
				tile_number += 1
			else:
				row.append(0)
		board.append(row)
	
	empty_pos = Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)

# This function now only creates the tile instances once at the beginning.
func create_tiles():
	for child in grid_container.get_children():
		child.queue_free()
	tiles.clear()

	var tile_number = 1
	for _y in range(GRID_SIZE):
		for _x in range(GRID_SIZE):
			if tile_number <= GRID_SIZE * GRID_SIZE - 1:
				var tile_instance = TileScene.instantiate()
				tile_instance.text = str(tile_number)
				tile_instance.pressed.connect(on_tile_pressed.bind(tile_number))
				grid_container.add_child(tile_instance)
				tiles[tile_number] = tile_instance
				tile_number += 1

# Shuffles the board by performing many random swaps.
func shuffle_board():
	for _i in range(1000):
		var neighbors = get_valid_neighbors(empty_pos)
		var random_neighbor = neighbors[randi() % neighbors.size()]
		swap_tiles(random_neighbor, empty_pos) # Only swap the logical board

# This new function updates the positions of the existing tiles.
# It can animate the movement or place them instantly.
func update_board_visuals(animated: bool = true):
	var tile_size = grid_container.size / GRID_SIZE
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var tile_number = board[y][x]
			if tile_number != 0:
				var tile_node = tiles[tile_number]
				var target_pos = Vector2(x, y) * tile_size
				
				# If not animating, just set the position instantly.
				if not animated:
					tile_node.position = target_pos
				# Otherwise, create and run a tween for a smooth slide.
				else:
					is_moving = true
					var tween = create_tween()
					tween.tween_property(tile_node, "position", target_pos, ANIMATION_SPEED).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					# Once the tween finishes, re-enable input.
					await tween.finished
					is_moving = false


# --- Signal Handlers / Game Logic ---

func on_tile_pressed(tile_number):
	# Do nothing if a tile is already in motion.
	if is_moving:
		return

	var tile_pos = find_tile_pos(tile_number)
	
	if is_adjacent(tile_pos, empty_pos):
		swap_tiles(tile_pos, empty_pos)
		# Instead of redrawing, we now update the visuals with animation.
		update_board_visuals()
		
		if check_win_condition():
			print("You Win!")
			# Use await instead of connect for cleaner syntax.
			await get_tree().create_timer(1.0).timeout
			get_tree().reload_current_scene()


# --- Core Game Mechanics ---

func swap_tiles(pos1, pos2):
	var temp = board[pos1.y][pos1.x]
	board[pos1.y][pos1.x] = board[pos2.y][pos2.x]
	board[pos2.y][pos2.x] = temp
	
	if board[pos1.y][pos1.x] == 0:
		empty_pos = pos1
	else:
		empty_pos = pos2


func check_win_condition():
	var expected_number = 1
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if y < GRID_SIZE - 1 or x < GRID_SIZE - 1:
				if board[y][x] != expected_number:
					return false
				expected_number += 1
	return true


# --- Helper Functions ---

func find_tile_pos(tile_number):
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if board[y][x] == tile_number:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func is_adjacent(pos1, pos2):
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1


func get_valid_neighbors(pos):
	var neighbors = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var new_pos = pos + dir
		if new_pos.x >= 0 and new_pos.x < GRID_SIZE and new_pos.y >= 0 and new_pos.y < GRID_SIZE:
			neighbors.append(new_pos)
	return neighbors
