class_name BishopMovementComponent
extends ChessPieceMovementComponent


func _get_piece_legal_moves(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	_move_idx: int,
	_validate_checks: bool
) -> Array[ChessMove]:
	var legal_moves: Array[ChessMove] = []
	
	# Four diagonal directions: up-right, up-left, down-right, down-left
	var directions: Array[Vector2i] = [
		Vector2i(1, 1),    # Up-Right
		Vector2i(-1, 1),   # Up-Left
		Vector2i(1, -1),   # Down-Right
		Vector2i(-1, -1)   # Down-Left
	]
	
	# Cast a ray in each direction
	for direction in directions:
		var step = 1
		while true:
			var check_pos = current_pos + (direction * step)
			
			if not _is_in_board_bounds(check_pos, board_dimensions):
				break  # Out of bounds, stop this direction
			
			# check_tile: ChessBoardTile|_SimulatedTile
			var check_tile = board[check_pos.y][check_pos.x]
			
			if not check_tile.has_piece():
				# Empty tile -> legal move
				legal_moves.append(ChessMove.new(current_pos, check_pos))
			else:
				if check_tile.piece.owner_player != piece_owner:
					# Enemy piece, can capture it -> legal move
					legal_moves.append(ChessMove.new(current_pos, check_pos, ChessMove.Type.CAPTURE))
				
				# Stop the ray (can't move past any piece)
				break
			
			step += 1
	
	return legal_moves
