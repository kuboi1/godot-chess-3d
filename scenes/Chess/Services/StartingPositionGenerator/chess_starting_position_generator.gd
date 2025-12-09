class_name ChessStartingPositionGenerator
extends Node


enum StartingPositionType {
	CUSTOM,
	FEN_NOTATION
}

@export_category('Config')
@export var active: bool = true
@export var use_position: StartingPositionType = StartingPositionType.CUSTOM
@export var player_to_move: ChessController.Player

@export_category('Positions')
@export_subgroup('Custom')
@export var _positions: Array[ChessPosition] = []
@export_subgroup('Fen')
## Only supports the first part of the string. Who's move it is is determined by the player_to_move export var
@export var _fen_notation_position: String

# Pieces preloads
const PIECE_SCENES = {
	ChessPiece.Type.PAWN: preload('res://scenes/Chess/Piece/Types/Pawn/pawn.tscn'),
	ChessPiece.Type.ROOK: preload('res://scenes/Chess/Piece/Types/Rook/rook.tscn'),
	ChessPiece.Type.KNIGHT: preload('res://scenes/Chess/Piece/Types/Knight/knight.tscn'),
	ChessPiece.Type.BISHOP: preload('res://scenes/Chess/Piece/Types/Bishop/bishop.tscn'),
	ChessPiece.Type.QUEEN: preload('res://scenes/Chess/Piece/Types/Queen/queen.tscn'),
	ChessPiece.Type.KING: preload('res://scenes/Chess/Piece/Types/King/king.tscn'),
}


func generate_position(board: Array[Array]) -> Array[Array]:
	# Convert FEN to a piece placement array if needed
	if use_position == StartingPositionType.FEN_NOTATION:
		_positions = ChessPositionConvertor.fen_to_chess_positions(_fen_notation_position)
	
	# Validate the placements array
	if not _validate_positions():
		push_error('Could not generate the starting position keeping the original board')
		return board
	
	# Clear the board first
	for row in board:
		for tile: ChessBoardTile in row:
			if tile.has_piece():
				tile.piece.queue_free()
	
	for placement: ChessPosition in _positions:
		var board_position: Vector2i = ChessUtils.chess_position_to_board_position(
			placement.position
		)
		
		var tile: ChessBoardTile = board[board_position.y][board_position.x]
		var piece_instance: ChessPiece = PIECE_SCENES[placement.piece].instantiate()
		
		piece_instance.owner_player = placement.player
		
		# Rotate black pieces to face inside the board
		if placement.player == ChessController.Player.BLACK:
			piece_instance.rotation_degrees.y = 180
		
		tile.piece = piece_instance
	
	print('[ChessStartingPositionGenerator] Successfully generated a chess position (%d pieces placed)' % _positions.size())
	
	return board


func _validate_positions() -> bool:
	if _positions.is_empty():
		push_error('The placements array is empty')
		return false
	
	var white_king_count = 0
	var black_king_count = 0
	var occupied_positions: Dictionary = {}  # position -> true
	
	for placement in _positions:
		if placement is not ChessPosition:
			push_error('One or more placements in the placements array was not assigned properly')
			return false
		
		# Check if position is valid
		var board_pos = ChessUtils.chess_position_to_board_position(placement.position)
		if board_pos == Vector2i(-1, -1):
			push_error('Invalid placement: Position "%s" is not a valid chess position' % placement.position)
			return false
		
		# Check for duplicate positions
		if placement.position in occupied_positions:
			push_error('Invalid placement: Position "%s" has multiple pieces' % placement.position)
			return false
		occupied_positions[placement.position] = true
		
		# Count kings
		if placement.piece == ChessPiece.Type.KING:
			if placement.player == ChessController.Player.WHITE:
				white_king_count += 1
			else:
				black_king_count += 1
	
	# Validate king counts
	if white_king_count != 1:
		push_error('Invalid placement: Expected exactly 1 white king, found %d' % white_king_count)
		return false
	
	if black_king_count != 1:
		push_error('Invalid placement: Expected exactly 1 black king, found %d' % black_king_count)
		return false
	
	return true
