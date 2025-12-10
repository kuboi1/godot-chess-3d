class_name KnightMovementComponent
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
	
	var knight_moves: Array[Vector2i] = [
		Vector2i(2, 1),
		Vector2i(2, -1),
		Vector2i(-2, 1),
		Vector2i(-2, -1),
		Vector2i(1, 2),
		Vector2i(1, -2),
		Vector2i(-1, 2),
		Vector2i(-1, -2)
	]
	
	for move in knight_moves:
		var check_pos = current_pos + move
		
		if not _is_in_board_bounds(check_pos, board_dimensions):
			continue
		
		# check_tile: ChessBoardTile|_SimulatedTile
		var check_tile = board[check_pos.y][check_pos.x]
		
		if not check_tile.has_piece():
			legal_moves.append(ChessMove.new(current_pos, check_pos))
		elif check_tile.piece.owner_player != piece_owner:
			legal_moves.append(ChessMove.new(current_pos, check_pos, ChessMove.Type.CAPTURE))
	
	return legal_moves
