class_name ChessUtils
extends Node


enum CastlingRight {
	WHITE_KINGSIDE,
	WHITE_QUEENSIDE,
	BLACK_KINGSIDE,
	BLACK_QUEENSIDE
}

const CHESS_FILES = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
const CHESS_RANKS = ['1', '2', '3', '4', '5', '6', '7', '8']

const CHESS_POSITIONS = {
	'x': CHESS_FILES,
	'y': CHESS_RANKS
}


static func chess_position_to_board_position(notation_str: String) -> Vector2i:
	if notation_str.length() != 2:
		push_error('Chess notation must be 2 characters long (eg. e5)')
		return Vector2i(-1, -1)
	
	var pos_x := CHESS_POSITIONS.x.find(notation_str[0])
	var pos_y := CHESS_POSITIONS.y.find(notation_str[1])
	
	if pos_x == -1 or pos_y == -1:
		push_error('%s is an invalid chess notation position')
		return Vector2i(-1, -1)
	
	return Vector2i(pos_x, pos_y)


static func uci_to_chess_move(uci_move: String, board_tiles: Array[Array]) -> ChessMove:
	# Parse UCI format: "e2e4" (normal), "e7e8q" (promotion to queen), etc.
	if uci_move.length() < 4:
		push_warning('UCI move must be at least 4 characters (e.g., e2e4), got: %s' % uci_move)
		return null
	
	# Extract from and to positions
	var from_notation := uci_move.substr(0, 2)
	var to_notation := uci_move.substr(2, 2)
	
	var from_pos := chess_position_to_board_position(from_notation)
	var to_pos := chess_position_to_board_position(to_notation)
	
	# Validate positions
	if from_pos == Vector2i(-1, -1) or to_pos == Vector2i(-1, -1):
		push_warning('Invalid UCI move positions: %s' % uci_move)
		return null
	
	# Get tiles
	var from_tile: ChessBoardTile = board_tiles[from_pos.y][from_pos.x]
	var to_tile: ChessBoardTile = board_tiles[to_pos.y][to_pos.x]
	
	if not from_tile.has_piece():
		push_warning('No piece at from position %s in UCI move: %s' % [from_notation, uci_move])
		return null
	
	var piece: ChessPiece = from_tile.piece
	var move_type := ChessMove.Type.NORMAL
	var metadata := {}
	
	# Determine move type based on board state and piece type
	
	# Check for castling (king moves 2 squares horizontally)
	if piece.type == ChessPiece.Type.KING and abs(to_pos.x - from_pos.x) == 2:
		move_type = ChessMove.Type.CASTLE
		# Find the rook based on castling direction
		var rook_x := 0 if to_pos.x < from_pos.x else board_tiles[0].size() - 1
		var rook_tile: ChessBoardTile = board_tiles[from_pos.y][rook_x]
		if rook_tile.has_piece() and rook_tile.piece.type == ChessPiece.Type.ROOK:
			metadata.rook = rook_tile.piece
		else:
			push_warning('Castling move but no rook found: %s' % uci_move)
			return null
	
	# Check for pawn special moves
	elif piece.type == ChessPiece.Type.PAWN:
		var board_height := board_tiles.size()
		var promotion_rank := board_height - 1 if piece.owner_player == ChessController.Player.WHITE else 0
		var is_promotion := to_pos.y == promotion_rank
		
		if is_promotion:
			# Promotion move
			var has_capture := to_tile.has_piece()
			move_type = ChessMove.Type.PROMOTION_CAPTURE if has_capture else ChessMove.Type.PROMOTION
			
			# Extract promotion piece from UCI (e.g., "e7e8q")
			if uci_move.length() > 4:
				var promotion_char := uci_move[4].to_lower()
				metadata.promotion_piece = promotion_char
		
		# Check for en passant (pawn moves diagonally to empty square)
		elif to_pos.x != from_pos.x and not to_tile.has_piece():
			move_type = ChessMove.Type.EN_PASSANT
			# The captured pawn is on the same rank as the moving pawn
			var captured_pawn_tile: ChessBoardTile = board_tiles[from_pos.y][to_pos.x]
			if captured_pawn_tile.has_piece() and captured_pawn_tile.piece.type == ChessPiece.Type.PAWN:
				metadata.captured_piece = captured_pawn_tile.piece
			else:
				push_warning('En passant move but no pawn found to capture: %s' % uci_move)
				return null
		
		# Regular pawn capture
		elif to_tile.has_piece():
			move_type = ChessMove.Type.CAPTURE
	
	# Check for regular capture (non-pawn)
	elif to_tile.has_piece() and to_tile.piece.owner_player != piece.owner_player:
		move_type = ChessMove.Type.CAPTURE
	
	return ChessMove.new(from_pos, to_pos, move_type, metadata)


static func get_opposing_player(to_player: ChessController.Player) -> ChessController.Player:
	return (
		ChessController.Player.WHITE if to_player == ChessController.Player.BLACK
		else ChessController.Player.BLACK
	)


static func is_valid_uci(uci_move: String) -> bool:
	# UCI move must be 4 or 5 characters (e.g., "e2e4" or "e7e8q")
	if uci_move.length() < 4 or uci_move.length() > 5:
		return false
	
	var from_file := uci_move[0]
	var from_rank := uci_move[1]
	if from_file not in CHESS_FILES or from_rank not in CHESS_RANKS:
		return false
	
	var to_file := uci_move[2]
	var to_rank := uci_move[3]
	if to_file not in CHESS_FILES or to_rank not in CHESS_RANKS:
		return false
	
	# If 5 characters, validate promotion piece
	if uci_move.length() == 5:
		var promotion := uci_move[4].to_lower()
		if not promotion in ['q', 'r', 'b', 'n']:
			return false
	
	return true
