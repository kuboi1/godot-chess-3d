class_name QueenMovementComponent
extends ChessPieceMovementComponent


@onready var rook_component: RookMovementComponent = self.get_node('RookComponent')
@onready var bishop_component: BishopMovementComponent = self.get_node('BishopComponent')

# The queen movement combines the rook and bishop movements
func _get_piece_legal_moves(
	current_pos: Vector2i,
	board: Array[Array],
	board_dimensions: Vector2i,
	piece_owner: ChessController.Player,
	move_idx: int,
	validate_checks: bool
) -> Array[ChessMove]:
	if not rook_component or not bishop_component:
		push_error('QueenMovementComponent requires RookMovementComponent and BishopMovementComponent child nodes')
		return []
	
	var straight_moves = rook_component._get_piece_legal_moves(current_pos, board, board_dimensions, piece_owner, move_idx, validate_checks)
	var diagonal_moves = bishop_component._get_piece_legal_moves(current_pos, board, board_dimensions, piece_owner, move_idx, validate_checks)
	
	return straight_moves + diagonal_moves
