class_name ChessPositionConvertor
extends Node


const CASTLING_RIGHTS_NONE = {
	ChessUtils.CastlingRight.WHITE_KINGSIDE: false,
	ChessUtils.CastlingRight.WHITE_QUEENSIDE: false,
	ChessUtils.CastlingRight.BLACK_KINGSIDE: false,
	ChessUtils.CastlingRight.BLACK_QUEENSIDE: false
}
const CASTLING_RIGHTS_ALL = {
	ChessUtils.CastlingRight.WHITE_KINGSIDE: true,
	ChessUtils.CastlingRight.WHITE_QUEENSIDE: true,
	ChessUtils.CastlingRight.BLACK_KINGSIDE: true,
	ChessUtils.CastlingRight.BLACK_QUEENSIDE: true
}


static func fen_to_chess_positions(fen_position: String) -> Array[ChessPosition]:
	var positions: Array[ChessPosition] = []
	
	# FEN piece mapping (lowercase = black, uppercase = white)
	const FEN_PIECE_MAP = {
		'p': ChessPiece.Type.PAWN,
		'r': ChessPiece.Type.ROOK,
		'n': ChessPiece.Type.KNIGHT,
		'b': ChessPiece.Type.BISHOP,
		'q': ChessPiece.Type.QUEEN,
		'k': ChessPiece.Type.KING
	}
	
	# Split FEN string and get just the board position part (ignore other parts)
	var fen_parts = fen_position.split(' ')
	var board_fen = fen_parts[0]
	
	# Split into ranks (rows)
	var ranks = board_fen.split('/')
	if ranks.size() != 8:
		push_error('Invalid FEN notation: Expected 8 ranks, got %d' % ranks.size())
		return []
	
	# Process each rank (FEN starts from rank 8 down to rank 1)
	for rank_idx in range(8):
		var rank = ranks[rank_idx]
		var file_idx = 0  # Column index (0-7, a-h)
		var chess_rank = 8 - rank_idx  # Convert to chess rank (8, 7, 6, ..., 1)
		
		for c in rank:
			# Check if it's a number (empty squares)
			if c.is_valid_int():
				file_idx += int(c)
				continue
			
			# Validate file index
			if file_idx >= 8:
				push_error('Invalid FEN notation: Rank %d exceeds 8 files' % chess_rank)
				return []
			
			# Determine player based on case
			var player: ChessController.Player
			if c == c.to_upper():
				player = ChessController.Player.WHITE
			else:
				player = ChessController.Player.BLACK
			
			# Determine piece type
			var piece_char = c.to_lower()
			if piece_char not in FEN_PIECE_MAP:
				push_error('Invalid FEN notation: Unknown piece character "%s"' % c)
				return []
			
			var piece_type: ChessPiece.Type = FEN_PIECE_MAP[piece_char]
			
			# Convert to chess notation (e.g., 'e4')
			var file_letter = char('a'.unicode_at(0) + file_idx)
			var position = '%s%d' % [file_letter, chess_rank]
			
			# Create ChessPosition
			var chess_pos := ChessPosition.new()
			chess_pos.position = position
			chess_pos.piece = piece_type
			chess_pos.player = player
			positions.append(chess_pos)
			
			file_idx += 1
		
		# Validate that this rank has exactly 8 squares
		if file_idx != 8:
			push_error('Invalid FEN notation: Rank %d has %d files, expected 8' % [chess_rank, file_idx])
			return []
	
	return positions


static func chess_positions_to_fen(
	positions: Array[ChessPosition],
	active_player: ChessController.Player = ChessController.Player.WHITE,
	castling_rights: Dictionary = CASTLING_RIGHTS_NONE,
	en_passant_position: String = '',
	halfmoves: int = 0,
	fullmove: int = 1
) -> String:
	# Piece to FEN character mapping
	const PIECE_TO_FEN = {
		ChessPiece.Type.PAWN: 'p',
		ChessPiece.Type.ROOK: 'r',
		ChessPiece.Type.KNIGHT: 'n',
		ChessPiece.Type.BISHOP: 'b',
		ChessPiece.Type.QUEEN: 'q',
		ChessPiece.Type.KING: 'k'
	}
	
	# Create an 8x8 board representation (null = empty square)
	var board: Array[Array] = []
	for _rank in range(8):
		var rank_array: Array = []
		rank_array.resize(8)
		rank_array.fill(null)
		board.append(rank_array)
	
	# Fill the board with pieces
	for pos in positions:
		var board_pos = ChessUtils.chess_position_to_board_position(pos.position)
		if board_pos == Vector2i(-1, -1):
			push_error('Invalid chess position: "%s"' % pos.position)
			continue
		
		# Store piece info at board position
		board[board_pos.y][board_pos.x] = {
			'piece': pos.piece,
			'player': pos.player
		}
	
	# Build FEN rank strings (rank 8 to rank 1)
	var rank_strings: Array[String] = []
	for rank_idx in range(7, -1, -1):  # Start from rank 8 (y=7) down to rank 1 (y=0)
		var rank_fen = ''
		var empty_count = 0
		
		for file_idx in range(8):  # a-h (x=0-7)
			var square = board[rank_idx][file_idx]
			
			if square == null:
				# Empty square
				empty_count += 1
			else:
				# Add accumulated empty squares
				if empty_count > 0:
					rank_fen += str(empty_count)
					empty_count = 0
				
				# Add piece character
				var piece_char = PIECE_TO_FEN[square.piece]
				if square.player == ChessController.Player.WHITE:
					piece_char = piece_char.to_upper()
				rank_fen += piece_char
		
		# Add any remaining empty squares at end of rank
		if empty_count > 0:
			rank_fen += str(empty_count)
		
		rank_strings.append(rank_fen)
	
	# Join ranks with '/'
	var board_fen = '/'.join(rank_strings)
	
	# Active player
	var active_color = 'w' if active_player == ChessController.Player.WHITE else 'b'
	
	# Castling rights
	var castling_fen = ''
	if castling_rights.get(ChessUtils.CastlingRight.WHITE_KINGSIDE, false):
		castling_fen += 'K'
	if castling_rights.get(ChessUtils.CastlingRight.WHITE_QUEENSIDE, false):
		castling_fen += 'Q'
	if castling_rights.get(ChessUtils.CastlingRight.BLACK_KINGSIDE, false):
		castling_fen += 'k'
	if castling_rights.get(ChessUtils.CastlingRight.BLACK_QUEENSIDE, false):
		castling_fen += 'q'
	if castling_fen == '':
		castling_fen = '-'
	
	# En passant target square
	var en_passant_fen = '-'
	if en_passant_position != '':
		# Validate the en passant position
		var ep_board_pos = ChessUtils.chess_position_to_board_position(en_passant_position)
		if ep_board_pos != Vector2i(-1, -1):
			# Valid position
			en_passant_fen = en_passant_position
		else:
			push_error('Invalid en passant position: "%s"' % en_passant_position)
	
	# Build complete FEN string
	var fen = '%s %s %s %s %d %d' % [
		board_fen,
		active_color,
		castling_fen,
		en_passant_fen,
		halfmoves,
		fullmove
	]
	
	return fen


static func board_tiles_to_positions(board_tiles: Array[Array]) -> Array[ChessPosition]:
	var positions: Array[ChessPosition] = []
	
	for row in board_tiles:
		for tile: ChessBoardTile in row:
			if tile.has_piece():
				var pos = ChessPosition.new()
				pos.position = tile.chess_position
				pos.piece = tile.piece.type
				pos.player = tile.piece.owner_player
				positions.append(pos)
	
	return positions


static func board_tiles_to_fen(
	board_tiles: Array[Array],
	active_player: ChessController.Player,
	move_idx: int,
	halfmove_clock: int = -1,
	fullmove: int = 1
) -> String:
	var positions = board_tiles_to_positions(board_tiles)
	var castling_rights = _infer_castling_rights(board_tiles)
	var en_passant_position = _infer_en_passant(board_tiles, active_player, move_idx)
	# Use 0 for halfmove clock if -1 (not tracking)
	var halfmoves = 0 if halfmove_clock == -1 else halfmove_clock
	
	return chess_positions_to_fen(
		positions,
		active_player,
		castling_rights,
		en_passant_position,
		halfmoves,
		fullmove
	)


static func _infer_castling_rights(board_tiles: Array[Array]) -> Dictionary:
	var rights = CASTLING_RIGHTS_NONE.duplicate()
	
	# Starting positions
	const WHITE_KING_START_POS = Vector2i(4, 0)
	const BLACK_KING_START_POS = Vector2i(4, 7)
	const WHITE_KINGSIDE_ROOK_POS = Vector2i(7, 0)
	const WHITE_QUEENSIDE_ROOK_POS = Vector2i(0, 0)
	const BLACK_KINGSIDE_ROOK_POS = Vector2i(7, 7)
	const BLACK_QUEENSIDE_ROOK_POS = Vector2i(0, 7)
	
	# Check white castling
	if _can_king_castle(board_tiles, ChessController.Player.WHITE, WHITE_KING_START_POS):
		if _check_rook_for_castling(board_tiles, WHITE_KINGSIDE_ROOK_POS, ChessController.Player.WHITE):
			rights[ChessUtils.CastlingRight.WHITE_KINGSIDE] = true
		if _check_rook_for_castling(board_tiles, WHITE_QUEENSIDE_ROOK_POS, ChessController.Player.WHITE):
			rights[ChessUtils.CastlingRight.WHITE_QUEENSIDE] = true
	
	# Check black castling
	if _can_king_castle(board_tiles, ChessController.Player.BLACK, BLACK_KING_START_POS):
		if _check_rook_for_castling(board_tiles, BLACK_KINGSIDE_ROOK_POS, ChessController.Player.BLACK):
			rights[ChessUtils.CastlingRight.BLACK_KINGSIDE] = true
		if _check_rook_for_castling(board_tiles, BLACK_QUEENSIDE_ROOK_POS, ChessController.Player.BLACK):
			rights[ChessUtils.CastlingRight.BLACK_QUEENSIDE] = true
	
	return rights


static func _can_king_castle(
	board_tiles: Array[Array],
	player: ChessController.Player,
	king_start_pos: Vector2i
) -> bool:
	var king_pos = ChessBoardUtils.find_king_pos(board_tiles, player)
	if king_pos != king_start_pos:
		return false
	
	var king_tile: ChessBoardTile = board_tiles[king_pos.y][king_pos.x]
	return not king_tile.piece.has_moved()


static func _check_rook_for_castling(
	board_tiles: Array[Array],
	rook_pos: Vector2i,
	player: ChessController.Player
) -> bool:
	var rook_tile: ChessBoardTile = board_tiles[rook_pos.y][rook_pos.x]
	if not rook_tile.has_piece():
		return false
	
	return rook_tile.piece.type == ChessPiece.Type.ROOK and \
		rook_tile.piece.owner_player == player and \
		not rook_tile.piece.has_moved()


static func _infer_en_passant(
	board_tiles: Array[Array],
	active_player: ChessController.Player,
	move_idx: int
) -> String:
	# White pawns can en passant on rank 5 (y=4), Black on rank 4 (y=3)
	var check_rank = 4 if active_player == ChessController.Player.WHITE else 3
	
	# Iterate through the rank looking for pawns of the active player
	for x in range(8):
		var tile: ChessBoardTile = board_tiles[check_rank][x]
		if not tile.has_piece():
			continue
		
		var piece = tile.piece
		if piece.type != ChessPiece.Type.PAWN or piece.owner_player != active_player:
			continue
		
		var legal_moves = piece.get_legal_moves(board_tiles, move_idx)
		
		# Check if any move is en passant
		for move in legal_moves:
			if move.type == ChessMove.Type.EN_PASSANT:
				# Convert the target position to chess notation
				var ep_pos = move.to
				var file_letter = ChessUtils.CHESS_POSITIONS.x[ep_pos.x]
				var rank_number = ChessUtils.CHESS_POSITIONS.y[ep_pos.y]
				return '%s%s' % [file_letter, rank_number]
	
	return ''
