class_name ChessStartingPositionGenerator
extends Node


enum StartingPositionType {
	EXPORT_VAR,
	FEN_NOTATION
}

@export_category('Config')
@export var active: bool = true
@export var use_position: StartingPositionType = StartingPositionType.EXPORT_VAR

@export_category('Positions')
@export var _placements: Array[ChessPiecePlacement] = []
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

const FEN_PIECE_MAP = {
	'p': ChessPiece.Type.PAWN,
	'r': ChessPiece.Type.ROOK,
	'n': ChessPiece.Type.KNIGHT,
	'b': ChessPiece.Type.BISHOP,
	'q': ChessPiece.Type.QUEEN,
	'k': ChessPiece.Type.KING
}


func generate_position(board: Array[Array]) -> Array[Array]:
	# Convert FEN to a piece placement array if needed
	if use_position == StartingPositionType.FEN_NOTATION:
		_placements = _fen_to_placements(_fen_notation_position)
	
	# Validate the placements array
	if not _validate_placements():
		push_error('Could not generate the starting position keeping the original board')
		return board
	
	# Clear the board first
	for row in board:
		for tile: ChessBoardTile in row:
			if tile.has_piece():
				tile.piece.queue_free()
	
	for placement: ChessPiecePlacement in _placements:
		var board_position: Vector2i = ChessUtils.chess_position_to_board_position(
			placement.position
		)
		
		var tile: ChessBoardTile = board[board_position.y][board_position.x]
		var piece_instance: ChessPiece = PIECE_SCENES[placement.piece].instantiate()
		
		piece_instance.owner_player = placement.player
		
		tile.piece = piece_instance
	
	print('Successfully generated a chess position (%d pieces placed)' % _placements.size())
	
	return board


func _fen_to_placements(fen_position: String) -> Array[ChessPiecePlacement]:
	var placements: Array[ChessPiecePlacement] = []
	
	# Basic validation: should have 8 ranks separated by '/'
	var ranks = fen_position.split('/')
	if ranks.size() != 8:
		push_error('Invalid FEN notation: Expected 8 ranks, got %d' % ranks.size())
		return []
	
	# Process each rank (starting from rank 8, which is y=7 in array coordinates)
	for rank_idx in range(8):
		var rank = ranks[rank_idx]
		var file_idx = 0  # Column index (0-7)
		var y = 7 - rank_idx  # Convert FEN rank to array y coordinate (rank 8 = y:7, rank 1 = y:0)
		
		for c in rank:
			# Check if it's a number (empty squares)
			if c.is_valid_int():
				file_idx += int(c)
				continue
			
			# It's a piece
			if file_idx >= 8:
				push_error('Invalid FEN notation: Rank %d exceeds 8 files' % (rank_idx + 1))
				return []
			
			# Determine player based on case
			var player: ChessController.Player
			if c == c.to_upper():
				player = ChessController.Player.WHITE
			else:
				player = ChessController.Player.BLACK
			
			# Determine piece type
			if c.to_lower() not in FEN_PIECE_MAP:
				push_error('Invalid FEN notation: Unknown piece character "%s"' % c)
				return []
			
			var piece_type: ChessPiece.Type = FEN_PIECE_MAP[c.to_lower()]
			
			# Convert array coordinates to chess notation (a-h, 1-8)
			var file_letter = char('a'.unicode_at(0) + file_idx)
			var rank_number = y + 1
			var position = "%s%d" % [file_letter, rank_number]
			
			# Create placement
			var placement := ChessPiecePlacement.new()
			placement.position = position
			placement.piece = piece_type
			placement.player = player
			placements.append(placement)
			
			file_idx += 1
		
		# Validate that this rank has exactly 8 squares
		if file_idx != 8:
			push_error('Invalid FEN notation: Rank %d has %d files, expected 8' % [rank_idx + 1, file_idx])
			return []
	
	return placements


func _validate_placements() -> bool:
	if _placements.is_empty():
		push_error('The placements array is empty')
		return false
	
	var white_king_count = 0
	var black_king_count = 0
	var occupied_positions: Dictionary = {}  # position -> true
	
	for placement in _placements:
		if placement is not ChessPiecePlacement:
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
