class_name ChessController
extends Node3D

enum GameType {
	VS_AI,
	LOCAL_MULTIPLAYER
}

enum Player {
	WHITE,
	BLACK
}

signal check(by_player: Player)
signal checkmate(by_player: Player)
signal stalemate

@export_category('Config')
@export var game_type: GameType = GameType.LOCAL_MULTIPLAYER
@export_subgroup('VS AI')
@export var player_color: Player = Player.WHITE

@export_category('Nodes')
@export var starting_position_generator: ChessStartingPositionGenerator
@export var chess_opponent: ChessOpponentComponent

@onready var opponent_controller: ChessOpponentController = $ChessOpponentController
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
	n_camera.call_deferred(
		'set_player', 
		_current_player if game_type == GameType.LOCAL_MULTIPLAYER else player_color, 
		true
	)
	
	# Generate starting position if a generator is assigned and active
	if starting_position_generator:
		if starting_position_generator.active:
			starting_position_generator.generate_position(_board_tiles)
			_current_player = starting_position_generator.player_to_move
		# Free the generator it will not be needed anymore
		# Remove this in the future if resets or new positions are implemented
		starting_position_generator.queue_free()
	
	if game_type == GameType.VS_AI:
		opponent_controller.player_color = ChessUtils.get_opposing_player(player_color)
		
		opponent_controller.thinking_started.connect(_on_opponent_thinking_started)
		opponent_controller.move_calculated.connect(_on_opponent_move_calculated)
		
		if chess_opponent:
			await register_opponent(chess_opponent)
		else:
			push_warning('Chess controller with game type VS_AI initialized without a chess opponent set.')
		
		if opponent_controller.player_color == Player.WHITE:
			opponent_controller.request_move(_board_tiles, _move_idx)
	
	# Safety check for positions starting with check/checkmate/stalemate
	_check_for_game_over(_current_player)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed('debug_chess_swap_player'):
		_swap_player()


func register_opponent(opponent: ChessOpponentComponent) -> void:
	print('[ChessController] New opponent registered: %s' % chess_opponent)
	chess_opponent = opponent
	
	if not opponent_controller.initialized:
		await opponent_controller.initialize()
	
	opponent_controller.register_opponent(opponent)


func _swap_player() -> void:
	_current_player = Player.BLACK if _current_player == Player.WHITE else Player.WHITE
	
	if game_type == GameType.LOCAL_MULTIPLAYER:
		n_camera.set_player(_current_player)
	elif game_type == GameType.VS_AI:
		_locked = false
		if _current_player != player_color:
			opponent_controller.request_move(_board_tiles, _move_idx)


func _select_piece_on_tile(tile: ChessBoardTile) -> void:
	if tile.piece.owner_player != _current_player:
		return
	
	var piece: ChessPiece = tile.piece
	_legal_moves = tile.piece.get_legal_moves(_board_tiles, _move_idx)
	print('[ChessController] %s legal moves: ' % piece, _legal_moves)
	
	# If piece currently has no legal moves, ignore
	if _legal_moves.is_empty():
		print('[ChessController] %s has no legal moves, not selecting' % piece)
		return
	
	print('[ChessController] Selected: %s' % piece)
	
	if _selected_piece_tile and _selected_piece_tile.has_piece():
		_selected_piece_tile.piece.selected = false
	
	piece.selected = true
	_piece_selected = true
	_selected_piece_tile = tile


func _deselect_piece(piece: ChessPiece) -> void:
	piece.selected = false
	_piece_selected = false
	_legal_moves = []


func _execute_chess_move(move: ChessMove) -> void:
	var from_tile: ChessBoardTile = _board_tiles[move.from.y][move.from.x]
	var to_tile: ChessBoardTile = _board_tiles[move.to.y][move.to.x]
	
	if not from_tile.has_piece():
		push_error('Cannot execute chess move: Tile %s does not have a piece!' % from_tile)
		return
	
	var piece: ChessPiece = from_tile.piece
	
	_locked = true
	to_tile.highlight(false)
	
	# Handle special moves
	if not move.is_normal():
		if move.is_capture():
			# TODO: Capture animation
			print('[ChessController] CAPTURE: %s x %s' % [piece, to_tile.piece])
			to_tile.piece.queue_free()
		
		if move.is_promotion():
			# Free the pawn first and replace it with the promoted piece
			piece.queue_free()
			piece = _handle_pawn_promotion(move, piece.owner_player)
		
		if move.type == ChessMove.Type.CASTLE:
			_execute_castle(move)
		
		if move.type == ChessMove.Type.EN_PASSANT:
			_execute_en_passant(move)
	
	_move_piece(piece, from_tile, to_tile, true)
	_move_idx += 1
	
	# Check if the game is over for the opposing player after the move
	_check_for_game_over(ChessUtils.get_opposing_player(_current_player))
	
	_deselect_piece(piece)


func _execute_castle(move: ChessMove) -> void:
	if &'rook' not in move.metadata or move.metadata.rook.type != ChessPiece.Type.ROOK:
		push_error('Tried to make a CASTLE move but there is no rook ChessPiece in ChessMove.metadata')
		return
	
	print('[ChessController] %s CASTLES' % Player.keys()[_current_player])
	
	var rook_piece: ChessPiece = move.metadata.rook
	var rook_current_pos: Vector2i = rook_piece.board_postion
	var rook_tile: ChessBoardTile = _board_tiles[rook_current_pos.y][rook_current_pos.x]
	
	# Calculate rook's destination based on king's destination
	var king_destination_x: int = move.to.x
	var rook_destination_x: int
	
	if rook_current_pos.x > king_destination_x:
		rook_destination_x = king_destination_x - 1
	else:
		rook_destination_x = king_destination_x + 1
	
	var rook_destination: Vector2i = Vector2i(rook_destination_x, move.to.y)
	var rook_destination_tile: ChessBoardTile = _board_tiles[rook_destination.y][rook_destination.x]
	
	_move_piece(rook_piece, rook_tile, rook_destination_tile, false)


func _execute_en_passant(move: ChessMove) -> void:
	if &'captured_piece' not in move.metadata or move.metadata.captured_piece is not ChessPiece:
		push_error('Tried to make an EN_PASSANT move but there is no captured_piece ChessPiece instance in ChessMove.metadata')
		return
	
	print('[ChessController] EN PASSANT')
	
	var captured_piece: ChessPiece = move.metadata.captured_piece
	# TODO: Capture animation
	captured_piece.queue_free()


func _handle_pawn_promotion(move: ChessMove, owner_player: Player) -> ChessPiece:
	# TODO: Let the player promote to pieces other than the queen
	# Replace the pawn on the selected tile with a promoted piece
	var promoted_piece: ChessPiece = load('res://scenes/Chess/Piece/Types/Queen/queen.tscn').instantiate()
	promoted_piece.owner_player = owner_player
	_selected_piece_tile.piece = promoted_piece
	return promoted_piece


func _move_piece(
	piece: ChessPiece,
	from_tile: ChessBoardTile, 
	to_tile: ChessBoardTile,
	signal_anim_end: bool,
	anim_duration: float = 0.3
) -> void:
	print('[ChessController] Executing move #%d: %s from %s to %s' % [_move_idx, piece, from_tile, to_tile])
	
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
			print('[ChessController] CHECKMATE BY %s' % Player.keys()[opposing_player])
		else:
			print('[ChessController] STALEMATE')
			stalemate.emit()
	elif is_player_in_check:
		var opposing_player := ChessUtils.get_opposing_player(for_player)
		print('[ChessController] CHECK BY %s' % Player.keys()[opposing_player])
		check.emit(opposing_player)


func _is_players_turn() -> bool:
	if game_type == GameType.LOCAL_MULTIPLAYER:
		return true
	
	return _current_player == player_color


func _on_chess_camera_animation_started() -> void:
	_locked = true


func _on_chess_camera_animation_finished() -> void:
	_locked = false


func _on_chess_board_tile_start_hover(tile: ChessBoardTile) -> void:
	if _locked or _game_over:
		return
	
	var legal_move_idx = _legal_moves.find_custom(func(move: ChessMove): return move.to == tile.board_position)
	if legal_move_idx > -1:
		var move: ChessMove = _legal_moves[legal_move_idx]
		tile.highlight(true, move.is_capture())
	
	if tile.has_piece():
		var piece = tile.piece
		if game_type == GameType.VS_AI and piece.owner_player == player_color:
			piece.set_hover_effect(true)
		elif piece.owner_player == _current_player:
			piece.set_hover_effect(true)


func _on_chess_board_tile_end_hover(tile: ChessBoardTile) -> void:
	if _locked or _game_over:
		return
	
	tile.highlight(false)
	
	if tile.has_piece():
		var piece = tile.piece
		if game_type == GameType.VS_AI and piece.owner_player == player_color:
			piece.set_hover_effect(false)
		elif piece.owner_player == _current_player:
			piece.set_hover_effect(false)


func _on_chess_board_tile_clicked(tile: ChessBoardTile) -> void:
	if _locked or not _is_players_turn():
		return
	
	if _piece_selected:
		if tile == _selected_piece_tile:
			var piece: ChessPiece = tile.piece
			_deselect_piece(piece)
			print('[ChessController] Deselected: %s' % piece)
			return
		
		if tile.has_piece() and tile.piece.owner_player == _current_player:
			_select_piece_on_tile(tile)
			return
		
		var move_idx = _legal_moves.find_custom(func(move: ChessMove): return move.to == tile.board_position)
		
		if move_idx > -1:
			var move: ChessMove = _legal_moves[move_idx]
			_execute_chess_move(move)
		else:
			print('[ChessController] %s is not a legal move' % tile.position_str)
	elif tile.has_piece() and tile.piece.owner_player == _current_player:
		_select_piece_on_tile(tile)


func _on_piece_move_finished() -> void:
	if not _game_over:
		_swap_player()


func _on_opponent_thinking_started() -> void:
	print('[ChessController] AI opponent: Thinking started')


func _on_opponent_move_calculated(uci_move: String) -> void:
	var move: ChessMove = ChessUtils.uci_to_chess_move(uci_move, _board_tiles)
	print('[ChessController] AI opponent: Move calculated - %s' % move)
	_execute_chess_move(move)
