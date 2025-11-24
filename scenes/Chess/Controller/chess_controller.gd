class_name ChessController
extends Node3D


enum Player {
	WHITE,
	BLACK
}

signal check(by_player: Player)
signal checkmate(by_player: Player)
signal stalemate

@export var starting_position_generator: ChessStartingPositionGenerator

@onready var n_board: ChessBoard = $ChessBoard
@onready var n_camera: ChessCamera = $ChessCamera

var _current_player: Player = Player.WHITE
var _move_idx: int = 0

var _board_tiles: Array[Array] :
	get():
		return n_board.tiles

var _locked := false
var _game_over := false

var _piece_selected := false
var _selected_piece_tile: ChessBoardTile

var _legal_moves: Array[ChessMove] = []


func _ready() -> void:
	# Generate starting position if a generator is assigned and active
	if starting_position_generator:
		if starting_position_generator.active:
			starting_position_generator.generate_position(_board_tiles)
			_current_player = starting_position_generator.player_to_move
		# Free the generator it will not be needed anymore
		# Remove this in the future if resets or new positions are implemented
		starting_position_generator.queue_free()
	
	n_camera.call_deferred('set_player', _current_player, true)
	
	# Safety check for positions starting with check/checkmate/stalemate
	_check_for_game_over(_current_player)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed('debug_chess_swap_player'):
		_swap_player()


func _swap_player() -> void:
	_current_player = Player.BLACK if _current_player == Player.WHITE else Player.WHITE
	
	n_camera.set_player(_current_player)


func _select_piece_on_tile(tile: ChessBoardTile) -> void:
	if tile.piece.owner_player != _current_player:
		return
	
	_legal_moves = tile.piece.get_legal_moves(_board_tiles, _move_idx)
	print('%s legal moves: ' % tile.piece, _legal_moves)
	
	# If piece currently has no legal moves, ignore
	if _legal_moves.is_empty():
		print('%s has no legal moves, not selecting' % tile.piece)
		return
	
	print('Selected: %s' % tile.piece)
	_piece_selected = true
	_selected_piece_tile = tile


func _deselect_piece() -> void:
	_piece_selected = false
	_legal_moves = []


func _execute_chess_move(move: ChessMove) -> void:
	var piece: ChessPiece = _selected_piece_tile.piece
	var tile: ChessBoardTile = _board_tiles[move.pos.y][move.pos.x]
	
	_locked = true
	
	# Handle special moves
	if not move.is_normal():
		if move.is_capture():
			# TODO: Capture animation
			print('CAPTURE: %s x %s' % [piece, tile.piece])
			tile.piece.queue_free()
		
		if move.is_promotion():
			# Free the pawn first and replace it with the promoted piece
			piece.queue_free()
			piece = _handle_pawn_promotion(move)
		
		if move.type == ChessMove.Type.CASTLE:
			_execute_castle(move)
		
		if move.type == ChessMove.Type.EN_PASSANT:
			_execute_en_passant(move)
	
	_move_piece(piece, _selected_piece_tile, tile, true)
	_move_idx += 1
	
	# Check if the game is over for the opposing player after the move
	_check_for_game_over(ChessUtils.get_opposing_player(_current_player))
	
	_deselect_piece()


func _execute_castle(move: ChessMove) -> void:
	if &'rook' not in move.metadata or move.metadata.rook.type != ChessPiece.Type.ROOK:
		push_error('Tried to make a CASTLE move but there is no rook ChessPiece in ChessMove.metadata')
		return
	
	print('%s CASTLES' % Player.keys()[_current_player])
	
	var rook_piece: ChessPiece = move.metadata.rook
	var rook_current_pos: Vector2i = rook_piece.board_postion
	var rook_tile: ChessBoardTile = _board_tiles[rook_current_pos.y][rook_current_pos.x]
	
	# Calculate rook's destination based on king's destination
	var king_destination_x: int = move.pos.x
	var rook_destination_x: int
	
	if rook_current_pos.x > king_destination_x:
		rook_destination_x = king_destination_x - 1
	else:
		rook_destination_x = king_destination_x + 1
	
	var rook_destination: Vector2i = Vector2i(rook_destination_x, move.pos.y)
	var rook_destination_tile: ChessBoardTile = _board_tiles[rook_destination.y][rook_destination.x]
	
	_move_piece(rook_piece, rook_tile, rook_destination_tile, false)


func _execute_en_passant(move: ChessMove) -> void:
	if &'captured_piece' not in move.metadata or move.metadata.captured_piece is not ChessPiece:
		push_error('Tried to make an EN_PASSANT move but there is no captured_piece ChessPiece instance in ChessMove.metadata')
		return
	
	print('EN PASSANT')
	
	var captured_piece: ChessPiece = move.metadata.captured_piece
	# TODO: Capture animation
	captured_piece.queue_free()


func _handle_pawn_promotion(move: ChessMove) -> ChessPiece:
	# TODO: Let the player promote to pieces other than the queen
	# Replace the pawn on the selected tile with a promoted piece
	var promoted_piece: ChessPiece = load('res://scenes/Chess/Piece/Types/Queen/queen.tscn').instantiate()
	_selected_piece_tile.piece = promoted_piece
	return promoted_piece


func _move_piece(
	piece: ChessPiece,
	from_tile: ChessBoardTile, 
	to_tile: ChessBoardTile,
	signal_anim_end: bool,
	anim_duration: float = 0.3
) -> void:
	print('Executing move #%d: %s from %s to %s' % [_move_idx, piece, from_tile, to_tile])
	
	from_tile.disconnect_piece()
	to_tile.piece = piece
	piece.register_move(_move_idx)
	
	# Animation
	# TODO: A pickup animation would be better here but this will do for now
	var distance = from_tile.board_position.distance_to(to_tile.board_position)
	var scaled_duration = anim_duration * sqrt(distance)
	var tween = create_tween()
	
	if signal_anim_end:
		tween.finished.connect(_on_piece_move_finished)
	
	tween.tween_property(piece, 'global_position', to_tile.global_position, scaled_duration)


func _check_for_game_over(for_player: Player) -> void:
	# Check if the player is in check and if they have a legal move left
	var is_player_in_check := ChessBoardUtils.is_king_in_check(
		for_player, 
		_board_tiles, 
		_move_idx
	)
	var player_has_legal_moves := ChessBoardUtils.player_has_legal_moves(
		for_player,
		_board_tiles,
		_move_idx
	)
	if not player_has_legal_moves:
		_game_over = true
		if is_player_in_check:
			var opposing_player := ChessUtils.get_opposing_player(for_player)
			checkmate.emit(opposing_player)
			print('CHECKMATE BY %s' % Player.keys()[opposing_player])
		else:
			print('STALEMATE')
			stalemate.emit()
	elif is_player_in_check:
		var opposing_player := ChessUtils.get_opposing_player(for_player)
		print('CHECK BY %s' % Player.keys()[opposing_player])
		check.emit(opposing_player)


func _on_chess_camera_animation_started() -> void:
	_locked = true


func _on_chess_camera_animation_finished() -> void:
	_locked = false


func _on_chess_board_tile_hovered(tile: ChessBoardTile) -> void:
	pass # Replace with function body.


func _on_chess_board_tile_clicked(tile: ChessBoardTile) -> void:
	if _locked:
		return
	
	if _piece_selected:
		if tile == _selected_piece_tile:
			_deselect_piece()
			print('Deselected: %s' % tile.piece)
			return
		
		if tile.has_piece() and tile.piece.owner_player == _current_player:
			_select_piece_on_tile(tile)
			return
		
		var move_idx = _legal_moves.find_custom(func(move: ChessMove): return move.pos == tile.board_position)
		
		if move_idx > -1:
			var move: ChessMove = _legal_moves[move_idx]
			_execute_chess_move(move)
		else:
			print('%s is not a legal move' % tile.position_str)
	elif tile.has_piece():
		_select_piece_on_tile(tile)



func _on_piece_move_finished() -> void:
	if not _game_over:
		_swap_player()
