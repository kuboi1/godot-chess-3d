class_name ChessBoard
extends Node3D


@onready var n_tile_container: Node3D = $Tiles

signal tile_start_hover(tile: ChessBoardTile)
signal tile_end_hover(tile: ChessBoardTile)
signal tile_clicked(tile: ChessBoardTile)

# Array[Array[ChessBoardTile]]
var tiles: Array[Array] = []


func _ready() -> void:
	_load_tiles()


func _load_tiles() -> void:
	for tile: ChessBoardTile in n_tile_container.get_children():
		tile.start_hover.connect(_on_tile_start_hover)
		tile.end_hover.connect(_on_tile_end_hover)
		tile.clicked.connect(_on_tile_clicked)
		
		if (tile.board_position.y + 1) > tiles.size():
			tiles.append([tile])
		else:
			tiles[tile.board_position.y].append(tile)


func _on_tile_start_hover(tile: ChessBoardTile) -> void:
	tile_start_hover.emit(tile)


func _on_tile_end_hover(tile: ChessBoardTile) -> void:
	tile_end_hover.emit(tile)


func _on_tile_clicked(tile: ChessBoardTile) -> void:
	tile_clicked.emit(tile)


func clear_board() -> void:
	for row in tiles:
		for tile: ChessBoardTile in row:
			if tile.has_piece():
				tile.piece.queue_free()
