# This script manages the entire 15-puzzle game logic.
extends Node2D

# --- Constants and Variables ---

# Preload the Tile scene so we can create instances of it.
const TileScene = preload("res://tile.tscn")

# Define the size of the grid (e.g., 4 for a 4x4 puzzle).
const GRID_SIZE = 4

# A reference to the GridContainer node in the scene tree.
# The '@onready' keyword ensures the variable is assigned after the node is ready.
@onready var grid_container = $UI/GridContainer

# A 2D array to represent the logical state of the puzzle board.
# It will store numbers, with 0 representing the empty space.
var board = []
# A dictionary to store the actual tile node instances, keyed by their number.
var tiles = {}
# A Vector2i to keep track of the coordinates of the empty slot on the board.
var empty_pos


# --- Godot Engine Functions ---

# This function is called automatically when the node enters the scene tree.
# It's the starting point for our game setup.
func _ready():
	# 1. Create the solved state of the board.
	setup_board()
	# 2. Shuffle the board to create a random, solvable puzzle.
	shuffle_board()
	# 3. Create and display the tile nodes based on the board's state.
	draw_board()


# --- Game Setup and Initialization ---

# Creates the initial, solved state of the board in the 'board' array.
func setup_board():
	board.clear() # Ensure the board is empty before setup.
	var tile_number = 1
	for y in range(GRID_SIZE):
		var row = [] # Create a new row for our 2D array.
		for x in range(GRID_SIZE):
			# Fill the board with numbers from 1 to 15.
			if tile_number <= GRID_SIZE * GRID_SIZE - 1:
				row.append(tile_number)
				tile_number += 1
			else:
				# The last spot is the empty one, which we represent with 0.
				row.append(0) 
		board.append(row)
	
	# The initial empty position is the bottom-right corner.
	empty_pos = Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)


# Shuffles the board to create a solvable puzzle.
# It works by making a large number of random, valid moves from the solved state.
func shuffle_board():
	# Perform 1000 random swaps.
	for i in range(1000):
		# Get a list of tiles that can legally move into the empty space.
		var neighbors = get_valid_neighbors(empty_pos)
		# Pick one of those neighbors at random.
		var random_neighbor = neighbors[randi() % neighbors.size()]
		# Swap the empty spot with the chosen neighbor.
		swap_tiles(random_neighbor, empty_pos)


# Creates and displays the tile nodes based on the current state of the 'board' array.
# This function is also used to refresh the visual grid after every move.
func draw_board():
	# First, remove all existing tile nodes from the grid container.
	for child in grid_container.get_children():
		child.queue_free()
	tiles.clear() # Also clear our dictionary of tile references.

	# Iterate through our logical board array.
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var tile_number = board[y][x]
			var new_size = 500 # This variable is defined correctly here.

			# If the spot is not the empty one (0), create a tile for it.
			if tile_number != 0:
				var tile_instance = TileScene.instantiate()
				tile_instance.text = str(tile_number)
				# THIS IS THE MISSING LINE YOU NEED TO ADD
				tile_instance.custom_minimum_size = Vector2(new_size, new_size)
				
				# Connect the tile's 'pressed' signal to our handler function.
				# We use .bind() to pass the tile's number with the signal.
				tile_instance.pressed.connect(on_tile_pressed.bind(tile_number))
				grid_container.add_child(tile_instance)
				tiles[tile_number] = tile_instance
			else:
				# If it's the empty spot, add a simple placeholder Control node.
				# This ensures the grid layout doesn't collapse.
				var empty_space = Control.new()
				# The empty space is now correctly set to the 'new_size'
				empty_space.custom_minimum_size = Vector2(new_size, new_size)
				grid_container.add_child(empty_space)


# --- Signal Handlers / Game Logic ---

# This function is called whenever any tile's 'pressed' signal is emitted.
func on_tile_pressed(tile_number):
	# Find the grid coordinates of the tile that was just pressed.
	var tile_pos = find_tile_pos(tile_number)
	
	# Check if the pressed tile is next to the empty spot.
	if is_adjacent(tile_pos, empty_pos):
		# If it is, swap them.
		swap_tiles(tile_pos, empty_pos)
		# Redraw the entire board to reflect the move.
		draw_board() 
		# After the move, check if the puzzle has been solved.
		if check_win_condition():
			print("You Win!")
			# Wait for 1 second, then reload the scene to start a new game.
			get_tree().create_timer(1.0).timeout.connect(func(): get_tree().reload_current_scene())


# --- Core Game Mechanics ---

# Swaps the values of two positions in the 'board' array.
func swap_tiles(pos1, pos2):
	# Use a temporary variable to hold one value during the swap.
	var temp = board[pos1.y][pos1.x]
	board[pos1.y][pos1.x] = board[pos2.y][pos2.x]
	board[pos2.y][pos2.x] = temp
	
	# After the swap, we must update our 'empty_pos' variable to reflect the new
	# location of the empty spot (0).
	if board[pos1.y][pos1.x] == 0:
		empty_pos = pos1
	else:
		empty_pos = pos2


# Checks if the board is in the solved state.
func check_win_condition():
	var expected_number = 1
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			# We check every spot except for the very last one.
			if y < GRID_SIZE - 1 or x < GRID_SIZE - 1:
				# If any tile is not what we expect, the puzzle isn't solved.
				if board[y][x] != expected_number:
					return false # Return immediately.
				expected_number += 1
	# If we get through the whole loop without finding a mistake, it's solved.
	return true


# --- Helper Functions ---

# Finds the (x, y) coordinates of a given tile number in our 'board' array.
func find_tile_pos(tile_number):
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if board[y][x] == tile_number:
				return Vector2i(x, y)
	return Vector2i(-1, -1) # Should not happen in this game.


# Checks if two positions are adjacent (but not diagonally).
# It uses the "Manhattan distance" formula.
func is_adjacent(pos1, pos2):
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1


# Returns a list of valid grid coordinates that are neighbors to a given position.
# This is used by the shuffle function to find valid moves.
func get_valid_neighbors(pos):
	var neighbors = []
	# Define the four cardinal directions.
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var new_pos = pos + dir
		# Check if the new position is within the grid boundaries.
		if new_pos.x >= 0 and new_pos.x < GRID_SIZE and new_pos.y >= 0 and new_pos.y < GRID_SIZE:
			neighbors.append(new_pos)
	return neighbors
