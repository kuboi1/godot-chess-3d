class_name ChessBoardUtils
extends Node


static func is_position_attacked(
	board_position: Vector2i,
	by_player: ChessController.Player,
	board: Array[Array],
	move_idx: int
) -> bool:
	for board_row in board:
		for tile in board_row:
			if not tile.has_piece():
				continue
			
			var piece: ChessPiece = tile.piece
			
			# Only check pieces owned by the attacking player
			if piece.owner_player != by_player:
				continue
			
			# Legal moves without validating checks
			var piece_legal_moves := piece.get_legal_moves(board, move_idx, false)
			
			for move: ChessMove in piece_legal_moves:
				if move.to == board_position:
					return true
	
	# No attacking piece found
	return false


static func is_king_in_check(
	player: ChessController.Player,
	board: Array[Array],
	move_idx: int
) -> bool:
	var king_pos := find_king_pos(board, player)
	
	# King not found - should never happen
	if king_pos == Vector2i(-1, -1):
		push_warning('%s king was not found on the board. Weird...' % ChessController.Player.keys()[player])
		return false
	
	return is_position_attacked(
		king_pos,
		ChessUtils.get_opposing_player(player),
		board,
		move_idx
	)


static func is_insufficient_material(board: Array[Array]) -> bool:
	var piece_count := 0
	var king_count := 0
	
	for row in board:
		for tile: ChessBoardTile in row:
			if tile.has_piece():
				piece_count += 1
				if tile.piece.type == ChessPiece.Type.KING:
					king_count += 1
	
	# Only kings remaining
	return piece_count == 2 and king_count == 2


static func player_has_legal_moves(
	player: ChessController.Player, 
	board: Array[Array], 
	move_idx: int
) -> bool:
	for row in board:
		# tile: ChessBoardTile|_SimulatedTile
		for tile in row:
			if tile.has_piece() and tile.piece.owner_player == player:
				var piece: ChessPiece = tile.piece
				var legal_moves = piece.get_legal_moves(board, move_idx)
				if legal_moves.size() > 0:
					return true
	
	return false


static func find_king_pos(board: Array[Array], player: ChessController.Player) -> Vector2i:
	for y in range(board.size()):
		for x in range(board[y].size()):
			# tile: ChessBoardTile|_SimulatedTile
			var tile = board[y][x]
			if tile.has_piece():
				var piece: ChessPiece = tile.piece
				if piece.owner_player == player and piece.type == ChessPiece.Type.KING:
					return Vector2i(x, y)
	
	# Fallback (should never happen)
	return Vector2i(-1, -1)


static func simulate_move(
	from_pos: Vector2i,
	to_pos: Vector2i,
	board: Array[Array],
	move_idx: int
) -> Array[Array]:
	var simulated_board: Array[Array] = []
	
	for y in range(board.size()):
		var row: Array = []
		for x in range(board[y].size()):
			# tile: ChessBoardTile|_SimulatedTile
			var tile = board[y][x]
			var current_pos = Vector2i(x, y)
			
			var piece_at_pos: ChessPiece
			if current_pos == to_pos:
				# Moving piece arrives here
				piece_at_pos = board[from_pos.y][from_pos.x].piece
			elif current_pos == from_pos:
				# Source tile becomes empty
				piece_at_pos = null
			else:
				# All other positions keep their current piece
				piece_at_pos = tile.piece
			
			row.append(_SimulatedTile.new(piece_at_pos, current_pos))
		simulated_board.append(row)
	
	return simulated_board


static func is_move_legal(
	move: ChessMove,
	by_player: ChessController.Player,
	board: Array[Array],
	move_idx: int
) -> bool:
	if move == null:
		return false
	
	# Check if from position is valid
	if move.from.x < 0 or move.from.x >= board[0].size() or move.from.y < 0 or move.from.y >= board.size():
		return false
	
	var from_tile = board[move.from.y][move.from.x]
	
	# Check if there's a piece at from position
	if not from_tile.has_piece():
		return false
	
	var piece: ChessPiece = from_tile.piece
	
	# Check if piece belongs to the player
	if piece.owner_player != by_player:
		return false
	
	var legal_moves := piece.get_legal_moves(board, move_idx)
	
	# Check if the requested move is in the piece's legal moves
	for legal_move: ChessMove in legal_moves:
		if legal_move.to == move.to:
			return true
	
	return false


static func is_uci_move_legal(
	uci_move: String,
	by_player: ChessController.Player,
	board: Array[Array],
	move_idx: int
) -> bool:
	# Convert UCI notation to ChessMove
	var chess_move := ChessUtils.uci_to_chess_move(uci_move, board)
	
	# Check if conversion was successful
	if chess_move == null:
		return false
	
	return is_move_legal(chess_move, by_player, board, move_idx)


# Lightweight object that mimics ChessBoardTile interface for simulation purposes
class _SimulatedTile:
	var piece: ChessPiece
	var board_position: Vector2i
	
	func _init(p: ChessPiece, pos: Vector2i) -> void:
		piece = p
		board_position = pos
	
	func has_piece() -> bool:
		return piece != null
