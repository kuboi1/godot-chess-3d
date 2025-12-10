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
	
	var directions: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1)
	]
	
	for direction in directions:
		var step = 1
		while true:
			var check_pos = current_pos + (direction * step)
			
			if not _is_in_board_bounds(check_pos, board_dimensions):
				break
			
			# check_tile: ChessBoardTile|_SimulatedTile
			var check_tile = board[check_pos.y][check_pos.x]
			
			if not check_tile.has_piece():
				legal_moves.append(ChessMove.new(current_pos, check_pos))
			else:
				if check_tile.piece.owner_player != piece_owner:
					legal_moves.append(ChessMove.new(current_pos, check_pos, ChessMove.Type.CAPTURE))
				
				break
			
			step += 1
	
	return legal_moves
