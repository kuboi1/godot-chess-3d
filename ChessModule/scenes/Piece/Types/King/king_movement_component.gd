class_name KingMovementComponent
extends ChessPieceMovementComponent


func _get_piece_legal_moves(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	_move_idx: int,
	validate_checks: bool
) -> Array[ChessMove]:
	var legal_moves: Array[ChessMove] = []
	
	var king_moves: Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
	]
	
	for move in king_moves:
		var check_pos = current_pos + move
		
		if not _is_in_board_bounds(check_pos, board_dimensions):
			continue
		
		# check_tile: ChessBoardTile|_SimulatedTile
		var check_tile = board[check_pos.y][check_pos.x]
		
		if not check_tile.has_piece():
			legal_moves.append(ChessMove.new(current_pos, check_pos))
		elif check_tile.piece.owner_player != piece_owner:
			legal_moves.append(ChessMove.new(current_pos, check_pos, ChessMove.Type.CAPTURE))
	
	if not has_moved():
		var kingside_castling_move = _check_castling_move(current_pos, board, piece_owner, true, _move_idx, validate_checks)
		if kingside_castling_move != null:
			legal_moves.append(kingside_castling_move)
		
		var queenside_castling_move = _check_castling_move(current_pos, board, piece_owner, false, _move_idx, validate_checks)
		if queenside_castling_move != null:
			legal_moves.append(queenside_castling_move)
	
	return legal_moves


# Helper function to check if castling is possible
# Returns a ChessMove if castling is legal, otherwise null
func _check_castling_move(
	current_pos: Vector2i,
	board: Array[Array],
	piece_owner: ChessController.Player,
	kingside: bool,
	move_idx: int,
	validate_checks: bool
) -> ChessMove:
	var board_width = board[0].size()
	
	var rook_x: int
	var direction: int
	var king_destination_x: int
	
	if kingside:
		rook_x = board_width - 1
		direction = 1
		king_destination_x = current_pos.x + 2
	else:
		rook_x = 0
		direction = -1
		king_destination_x = current_pos.x - 2
	
	# rook_tile: ChessBoardTile|_SimulatedTile
	var rook_tile = board[current_pos.y][rook_x]
	if not rook_tile.has_piece():
		return null
	
	# Piece on tile has to:
	# - be a rook
	# - belong to the same player
	# - not have moved yet
	var rook_piece: ChessPiece = rook_tile.piece
	if (
		rook_piece.type != ChessPiece.Type.ROOK or
		rook_piece.owner_player != piece_owner or
		rook_piece.has_moved()
	):
		return null
	
	var x = current_pos.x + direction
	while x != rook_x:
		# check_tile: ChessBoardTile|_SimulatedTile
		var check_tile = board[current_pos.y][x]
		if check_tile.has_piece():
			return null
		x += direction
	
	# Only validate castling through check if validate_checks is true
	# This prevents infinite recursion when checking attack patterns
	if validate_checks:
		var opposing_player := ChessUtils.get_opposing_player(piece_owner)
		
		# King must not be in check
		if ChessBoardUtils.is_position_attacked(current_pos, opposing_player, board, move_idx):
			return null
		
		# King must not pass through a square that is under attack
		var passing_through_pos = Vector2i(current_pos.x + direction, current_pos.y)
		if ChessBoardUtils.is_position_attacked(passing_through_pos, opposing_player, board, move_idx):
			return null
		
		# King must not end up in check after castling
		var destination_pos = Vector2i(king_destination_x, current_pos.y)
		if ChessBoardUtils.is_position_attacked(destination_pos, opposing_player, board, move_idx):
			return null
	
	return ChessMove.new(current_pos, Vector2i(king_destination_x, current_pos.y), ChessMove.Type.CASTLE, {rook = rook_piece})
