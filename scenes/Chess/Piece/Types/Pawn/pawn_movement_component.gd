class_name PawnMovementComponent
extends ChessPieceMovementComponent


func _get_piece_legal_moves(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	move_idx: int,
	_validate_checks: bool
) -> Array[ChessMove]:
	var legal_moves: Array[ChessMove] = []
	
	# Determine forward direction based on player
	var forward_direction: int = 1 if piece_owner == ChessController.Player.WHITE else -1
	
	# Determine ranks
	var starting_rank = 1 if piece_owner == ChessController.Player.WHITE else board_dimensions.y - 2
	var promotion_rank: int = board_dimensions.y - 1 if piece_owner == ChessController.Player.WHITE else 0
	
	# Forward movement
	var one_forward = current_pos + Vector2i(0, forward_direction)
	if _is_in_board_bounds(one_forward, board_dimensions):
		# one_forward_tile: ChessBoardTile|_SimulatedTile
		var one_forward_tile = board[one_forward.y][one_forward.x]
		if not one_forward_tile.has_piece():
			# Check for promotion
			if _is_promotion_pos(one_forward, promotion_rank):
				legal_moves.append(ChessMove.new(current_pos, one_forward, ChessMove.Type.PROMOTION))
			else:
				legal_moves.append(ChessMove.new(current_pos, one_forward))
			
			# Two square forward movement (only from starting rank)
			if current_pos.y == starting_rank:
				var two_forward = current_pos + Vector2i(0, forward_direction * 2)
				if _is_in_board_bounds(two_forward, board_dimensions):
					# two_forward_tile: ChessBoardTile|_SimulatedTile
					var two_forward_tile = board[two_forward.y][two_forward.x]
					if not two_forward_tile.has_piece():
						legal_moves.append(ChessMove.new(current_pos, two_forward))
	
	# Diagonal captures
	var diagonal_offsets: Array[Vector2i] = [
		Vector2i(1, forward_direction),   # Right diagonal
		Vector2i(-1, forward_direction)   # Left diagonal
	]
	
	for offset in diagonal_offsets:
		var diagonal_pos = current_pos + offset
		if _is_in_board_bounds(diagonal_pos, board_dimensions):
			# diagonal_tile: ChessBoardTile|_SimulatedTile
			var diagonal_tile = board[diagonal_pos.y][diagonal_pos.x]
			if diagonal_tile.has_piece() and diagonal_tile.piece.owner_player != piece_owner:
				# Check for promotion
				if _is_promotion_pos(diagonal_pos, promotion_rank):
					legal_moves.append(ChessMove.new(current_pos, diagonal_pos, ChessMove.Type.PROMOTION_CAPTURE))
				else:
					legal_moves.append(ChessMove.new(current_pos, diagonal_pos, ChessMove.Type.CAPTURE))
	
	# En passant
	var en_passant_moves = _check_en_passant(current_pos, board, board_dimensions, piece_owner, forward_direction, move_idx)
	legal_moves.append_array(en_passant_moves)
	
	return legal_moves


func _check_en_passant(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	forward_direction: int,
	move_idx: int
) -> Array[ChessMove]:
	var en_passant_moves: Array[ChessMove] = []
	
	# White pawns can en passant on rank 5, Black pawns on rank 4
	var en_passant_rank = board_dimensions.y - 4 if piece_owner == ChessController.Player.WHITE else board_dimensions.y - 5
	if current_pos.y != en_passant_rank:
		return en_passant_moves
	
	# Check adjacent tiles for enemy pawns that just moved 2 squares
	var adjacent_offsets: Array[int] = [1, -1]
	for x_offset in adjacent_offsets:
		var adjacent_pos = current_pos + Vector2i(x_offset, 0)
		if not _is_in_board_bounds(adjacent_pos, board_dimensions):
			continue
		
		# adjacent_tile: ChessBoardTile|_SimulatedTile
		var adjacent_tile = board[adjacent_pos.y][adjacent_pos.x]
		if not adjacent_tile.has_piece():
			continue
		
		var adjacent_piece = adjacent_tile.piece
		# Check en passant conditions
		if (
			adjacent_piece.owner_player != piece_owner and
			adjacent_piece.type == ChessPiece.Type.PAWN and
			adjacent_piece.move_count == 1 and
			adjacent_piece.last_move_idx == move_idx - 1
		):
			var capture_pos = current_pos + Vector2i(x_offset, forward_direction)
			en_passant_moves.append(
				ChessMove.new(current_pos, capture_pos, ChessMove.Type.EN_PASSANT, {captured_piece = adjacent_piece})
			)
	
	return en_passant_moves


func _is_promotion_pos(pos: Vector2i, promotion_rank: int) -> bool:
	return pos.y == promotion_rank
