class_name KnightMovementComponent
extends ChessPieceMovementComponent


func _get_piece_legal_moves(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	_move_idx: int
) -> Array[ChessMove]:
	var legal_moves: Array[ChessMove] = []
	
	# Knight moves in an "L" shape: 2 squares in one direction, 1 square perpendicular
	# All 8 possible L-shaped moves
	var knight_moves: Array[Vector2i] = [
		Vector2i(2, 1),    # 2 right, 1 up
		Vector2i(2, -1),   # 2 right, 1 down
		Vector2i(-2, 1),   # 2 left, 1 up
		Vector2i(-2, -1),  # 2 left, 1 down
		Vector2i(1, 2),    # 1 right, 2 up
		Vector2i(1, -2),   # 1 right, 2 down
		Vector2i(-1, 2),   # 1 left, 2 up
		Vector2i(-1, -2)   # 1 left, 2 down
	]
	
	# Check each possible knight move
	for move in knight_moves:
		var check_pos = current_pos + move
		
		if not _is_in_board_bounds(check_pos, board_dimensions):
			continue  # Out of bounds, skip this move
		
		# check_tile: ChessBoardTile|_SimulatedTile
		var check_tile = board[check_pos.y][check_pos.x]
		
		if not check_tile.has_piece():
			# Empty tile -> legal move
			legal_moves.append(ChessMove.new(check_pos))
		elif check_tile.piece.owner_player != piece_owner:
			# Enemy piece, can capture it -> legal move
			legal_moves.append(ChessMove.new(check_pos, ChessMove.Type.CAPTURE))
	
	return legal_moves
