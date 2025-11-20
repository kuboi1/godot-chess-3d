class_name ChessPieceMovementComponent
extends Node


# Optionally to be used where needed
var move_count: int = 0
var last_move_idx: int = 0


func calculate_legal_moves(
	current_pos: Vector2i, 
	board: Array[Array], 
	move_idx: int,
	validate_checks: bool = true
) -> Array[ChessMove]:
	# Shared logic
	# Can be overwritten directly in derived components if shared logic is not needed
	
	var board_dimension := Vector2i(board.size(), board[0].size())
	
	# Safety check for empty board
	if board_dimension.x == 0 or board_dimension.y == 0:
		return []
	
	# Get the current piece's owner
	# current_tile: ChessBoardTile|_SimulatedTile
	var current_tile = board[current_pos.y][current_pos.x]
	if not current_tile.has_piece():
		return []
	
	var piece_owner: ChessController.Player = current_tile.piece.owner_player
	
	# Get piece specific legal moves
	var legal_moves = _get_piece_legal_moves(
		current_pos, 
		board, 
		board_dimension, 
		piece_owner, 
		move_idx
	)
	
	if validate_checks:
		legal_moves = _filter_out_check_moves(
			legal_moves,
			current_pos,
			board,
			piece_owner,
			move_idx
		)
	
	return legal_moves


func register_move(move_idx: int) -> void:
	move_count += 1
	last_move_idx = move_idx


func has_moved() -> bool:
	return move_count > 0


func _is_in_board_bounds(pos: Vector2i, board_dimensions: Vector2i) -> bool:
	return (
		pos.x >= 0 and 
		pos.x < board_dimensions.x and 
		pos.y >= 0 and 
		pos.y < board_dimensions.y
	)


# Filters out moves that would leave the king in check
func _filter_out_check_moves(
	moves: Array[ChessMove],
	current_pos: Vector2i,
	board: Array[Array],
	piece_owner: ChessController.Player,
	move_idx: int
) -> Array[ChessMove]:
	var legal_moves: Array[ChessMove] = []
	
	for move in moves:
		# Simulate the move
		var simulated_board := ChessBoardUtils.simulate_move(
			current_pos,
			move.pos,
			board,
			move_idx
		)
		
		# Check if the king is in check after this move
		var is_in_check := ChessBoardUtils.is_king_in_check(
			piece_owner,
			simulated_board,
			move_idx
		)
		
		# Only add moves that don't leave the king in check
		if not is_in_check:
			legal_moves.append(move)
	
	return legal_moves


# PIECE SPECIFIC LOGIC HERE
func _get_piece_legal_moves(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	move_idx: int
) -> Array[ChessMove]:
	# Implementation in derived components
	return []
