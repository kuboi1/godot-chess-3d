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

@export_category('Config')
@export var game_type: GameType = GameType.LOCAL_MULTIPLAYER
@export var start_cleared: bool = false
@export_subgroup('VS AI')
@export var player_color: Player = Player.WHITE

@export_category('Nodes')
@export var starting_position_generator: ChessStartingPositionGenerator
@export var chess_opponent: ChessOpponentComponent
@export var chess_signal_bus: ChessSignalBus

@onready var opponent_controller: ChessOpponentController = $ChessOpponentController
@onready var camera: ChessCamera = $ChessCamera
@onready var _board: ChessBoard = $ChessBoard

var _current_player: Player = Player.WHITE
var _move_idx: int = 0
var _halfmove_clock: int = 0
var _position_history: Dictionary = {}  # Key: position string, Value: occurrence count

var can_exit_game: bool = true

var _board_tiles: Array[Array] :
	get():
		return _board.tiles

var _locked := false
var _game_over := false

var _piece_selected := false
var _selected_piece_tile: ChessBoardTile

var _legal_moves: Array[ChessMove] = []

var _pending_promotion_move: ChessMove
var _pending_promotion_player: Player


func _ready() -> void:
	if not chess_signal_bus:
		push_error('ChessController requires chess_signal_bus to be set!')
		return
	
	camera.set_player(
		_current_player if game_type == GameType.LOCAL_MULTIPLAYER else player_color
	)
	
	chess_signal_bus.promote.connect(_on_signal_bus_promote)
	chess_signal_bus.next_move.connect(_on_signal_bus_next_move)
	chess_signal_bus.move_animation_completed.connect(_on_signal_bus_move_animation_completed)
	chess_signal_bus.setup_game.connect(_on_signal_bus_setup_game)
	chess_signal_bus.start_game.connect(_on_signal_bus_start_game)
	chess_signal_bus.clear_board.connect(_on_signal_bus_clear_board)
	chess_signal_bus.register_opponent.connect(_on_signal_bus_register_opponent)
	chess_signal_bus.shutdown_ai.connect(_on_signal_bus_shutdown_ai)
	
	opponent_controller.thinking_started.connect(_on_opponent_thinking_started)
	opponent_controller.move_calculated.connect(_on_opponent_move_calculated)
	
	if start_cleared:
		_board.clear_board()
	
	# Prevent interaction until setup_game/start_game signals are received
	_game_over = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed('debug_chess_swap_player'):
		_swap_player()


func lock() -> void:
	_locked = true


func unlock() -> void:
	_locked = false


func shutdown_ai() -> void:
	if opponent_controller.initialized:
		opponent_controller.shutdown()
		print('[ChessController] AI opponent shut down')


func _register_opponent(opponent: ChessOpponentComponent) -> void:
	print('[ChessController] New opponent registered: %s' % opponent)
	chess_opponent = opponent
	
	if not opponent_controller.initialized:
		await opponent_controller.initialize()
	
	opponent_controller.register_opponent(opponent)


func _reset_game_state() -> void:
	_current_player = Player.WHITE
	_move_idx = 0
	_halfmove_clock = 0
	_position_history.clear()
	_locked = false
	_game_over = false
	_piece_selected = false
	_selected_piece_tile = null
	_legal_moves.clear()
	_pending_promotion_move = null
	_pending_promotion_player = Player.WHITE


func _swap_player() -> void:
	_current_player = Player.BLACK if _current_player == Player.WHITE else Player.WHITE
	
	chess_signal_bus.player_swapped.emit(_current_player)
	
	if game_type == GameType.LOCAL_MULTIPLAYER:
		camera.set_player(_current_player)
	elif game_type == GameType.VS_AI:
		_locked = false
		if _current_player != player_color:
			opponent_controller.request_move(_board_tiles, _move_idx, _halfmove_clock)


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
	
	if not move.is_normal():
		if move.is_capture():
			var captured_piece = to_tile.piece
			chess_signal_bus.piece_captured.emit(captured_piece, to_tile)
			chess_signal_bus.capture_animation_requested.emit(captured_piece, to_tile)
			print('[ChessController] CAPTURE: %s x %s' % [piece, captured_piece])
		
		if move.is_promotion():
			# Check if this is AI promotion or has promotion piece in metadata
			if move.metadata.has('promotion_piece'):
				# AI move - use the piece from metadata
				var piece_type: ChessPiece.Type = _promotion_char_to_piece_type(move.metadata.promotion_piece)
				var promoted_piece: ChessPiece = _create_promoted_piece(piece_type, piece.owner_player)
				to_tile.piece = promoted_piece
				piece.queue_free()
			else:
				# Player move - request UI selection
				_pending_promotion_move = move
				_pending_promotion_player = piece.owner_player
				chess_signal_bus.promotion_requested.emit(move.to, piece.owner_player)
				return  # Wait for promotion signal from bus
		
		if move.type == ChessMove.Type.EN_PASSANT:
			_execute_en_passant(move)
	
	_finalize_move(move, piece)


func _finalize_move(move: ChessMove, piece: ChessPiece) -> void:
	var from_tile: ChessBoardTile = _board_tiles[move.from.y][move.from.x]
	var to_tile: ChessBoardTile = _board_tiles[move.to.y][move.to.x]
	
	# Move the main piece (king for castling) and request animation
	_move_piece(piece, from_tile, to_tile)
	
	if move.type == ChessMove.Type.CASTLE:
		_execute_castle(move)
	
	# Update halfmove clock (50-move rule tracking)
	if piece.type == ChessPiece.Type.PAWN or move.is_capture():
		_halfmove_clock = 0
		# Clear position history on irreversible moves (pawn moves and captures)
		# Positions before these moves can never be repeated
		_position_history.clear()
	else:
		_halfmove_clock += 1
	
	
	# Record the current position for threefold repetition
	_record_position()
	
	chess_signal_bus.move_executed.emit(move, piece.owner_player)
	
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
	
	_move_piece(rook_piece, rook_tile, rook_destination_tile)


func _execute_en_passant(move: ChessMove) -> void:
	if &'captured_piece' not in move.metadata or move.metadata.captured_piece is not ChessPiece:
		push_error('Tried to make an EN_PASSANT move but there is no captured_piece ChessPiece instance in ChessMove.metadata')
		return
	
	print('[ChessController] EN PASSANT')
	
	var captured_piece: ChessPiece = move.metadata.captured_piece
	var captured_piece_pos: Vector2i = captured_piece.board_position
	var captured_piece_tile: ChessBoardTile = _board_tiles[captured_piece_pos.y][captured_piece_pos.x]
	
	chess_signal_bus.capture_animation_requested.emit(captured_piece, captured_piece_tile)


func _promotion_char_to_piece_type(promotion_char: String) -> ChessPiece.Type:
	match promotion_char.to_lower():
		'q':
			return ChessPiece.Type.QUEEN
		'r':
			return ChessPiece.Type.ROOK
		'b':
			return ChessPiece.Type.BISHOP
		'n':
			return ChessPiece.Type.KNIGHT
		_:
			push_warning('Unknown promotion character "%s", defaulting to Queen' % promotion_char)
			return ChessPiece.Type.QUEEN


func _create_promoted_piece(piece_type: ChessPiece.Type, owner_player: Player) -> ChessPiece:
	var scene_path: String
	match piece_type:
		ChessPiece.Type.QUEEN:
			scene_path = 'res://scenes/Chess/Piece/Types/Queen/queen.tscn'
		ChessPiece.Type.ROOK:
			scene_path = 'res://scenes/Chess/Piece/Types/Rook/rook.tscn'
		ChessPiece.Type.BISHOP:
			scene_path = 'res://scenes/Chess/Piece/Types/Bishop/bishop.tscn'
		ChessPiece.Type.KNIGHT:
			scene_path = 'res://scenes/Chess/Piece/Types/Knight/knight.tscn'
		_:
			push_error('Cannot promote to piece type: %s' % ChessPiece.Type.keys()[piece_type])
			scene_path = 'res://scenes/Chess/Piece/Types/Queen/queen.tscn'
	
	var promoted_piece: ChessPiece = load(scene_path).instantiate()
	promoted_piece.owner_player = owner_player
	return promoted_piece


func _move_piece(
	piece: ChessPiece,
	from_tile: ChessBoardTile,
	to_tile: ChessBoardTile
) -> void:
	print('[ChessController] Executing move #%d: %s from %s to %s' % [_move_idx, piece, from_tile, to_tile])
	
	from_tile.disconnect_piece()
	to_tile.piece = piece
	piece.register_move(_move_idx)
	
	can_exit_game = false
	chess_signal_bus.move_animation_requested.emit(piece, from_tile, to_tile)


func _check_for_game_over(for_player: Player) -> void:
	var is_draw := _check_for_draw()
	if is_draw:
		return
	
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
			chess_signal_bus.checkmate.emit(opposing_player)
			print('[ChessController] CHECKMATE BY %s' % Player.keys()[opposing_player])
		else:
			print('[ChessController] STALEMATE')
			chess_signal_bus.stalemate.emit()
	elif is_player_in_check:
		var opposing_player := ChessUtils.get_opposing_player(for_player)
		print('[ChessController] CHECK BY %s' % Player.keys()[opposing_player])
		chess_signal_bus.check.emit(opposing_player)


func _check_for_draw() -> bool:
	# Check for fifty-move rule (100 halfmoves = 50 full moves)
	if _halfmove_clock >= 100:
		_game_over = true
		print('[ChessController] DRAW - Fifty-move rule')
		chess_signal_bus.draw.emit(ChessUtils.DrawReason.FIFTY_MOVE)
		return true
	
	# Check for threefold repetition
	var position_key := _get_position_key()
	if position_key in _position_history and _position_history[position_key] >= 3:
		_game_over = true
		print('[ChessController] DRAW - Threefold repetition')
		chess_signal_bus.draw.emit(ChessUtils.DrawReason.THREEFOLD_REPETITION)
		return true
	
	# Check for insufficient material
	if ChessBoardUtils.is_insufficient_material(_board_tiles):
		_game_over = true
		print('[ChessController] DRAW - Insufficient material')
		chess_signal_bus.draw.emit(ChessUtils.DrawReason.INSUFFICIENT_MATERIAL)
		return true
	
	return false


func _record_position() -> void:
	var position_key := _get_position_key()
	if position_key in _position_history:
		_position_history[position_key] += 1
	else:
		_position_history[position_key] = 1


func _get_position_key() -> String:
	# Generate position key from first 4 FEN fields
	var fen := ChessPositionConvertor.board_tiles_to_fen(
		_board_tiles,
		_current_player,
		_move_idx,
		_halfmove_clock
	)
	var fen_parts := fen.split(' ')
	return ' '.join(fen_parts.slice(0, 4))


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


func _on_signal_bus_move_animation_completed() -> void:
	can_exit_game = true
	
	if not _game_over:
		chess_signal_bus.turn_completed.emit(_move_idx)
		_move_idx += 1
		_check_for_game_over(_current_player)

# OPPONENT SIGNALS

func _on_opponent_thinking_started() -> void:
	print('[ChessController] AI opponent: Thinking started')


func _on_opponent_move_calculated(uci_move: String) -> void:
	var move: ChessMove = ChessUtils.uci_to_chess_move(uci_move, _board_tiles)
	print('[ChessController] AI opponent: Move calculated - %s' % move)
	_execute_chess_move(move)

# SIGNAL BUS SIGNALS

func _on_signal_bus_setup_game(metadata: Dictionary) -> void:
	print('[ChessController] Setting up game...')
	
	# Handle metadata for player color
	if metadata.has("flip_sides") and metadata.flip_sides:
		player_color = ChessUtils.get_opposing_player(player_color)
		print('[ChessController] Flipped sides - now playing as %s' % Player.keys()[player_color])
	elif metadata.has("player_color"):
		player_color = metadata.player_color
		print('[ChessController] Set player color to %s' % Player.keys()[player_color])
	
	_reset_game_state()
	_game_over = true  # Keep locked until start_game is called
	
	if starting_position_generator:
		starting_position_generator.generate_position(_board_tiles)
		_current_player = starting_position_generator.player_to_move
	else:
		push_warning('No starting position generator assigned, board will remain as is')
	
	camera.set_player(
		_current_player if game_type == GameType.LOCAL_MULTIPLAYER else player_color
	)
	
	if game_type == GameType.VS_AI:
		opponent_controller.player_color = ChessUtils.get_opposing_player(player_color)
		
		if chess_opponent:
			await _register_opponent(chess_opponent)
		else:
			push_warning('Chess controller with game type VS_AI initialized without a chess opponent set.')
	
	print('[ChessController] Game setup complete')


func _on_signal_bus_start_game() -> void:
	print('[ChessController] Starting game...')
	
	_game_over = false  # Unlock the game
	
	if game_type == GameType.VS_AI:
		# Request move if AI plays first
		if opponent_controller.player_color == Player.WHITE:
			opponent_controller.request_move(_board_tiles, _move_idx, _halfmove_clock)
	
	# Record starting position for threefold repetition
	_record_position()
	
	var game_metadata := {
		"game_type": game_type,
		"player_color": player_color if game_type == GameType.VS_AI else -1,
		"starting_player": _current_player
	}
	chess_signal_bus.game_started.emit(game_metadata)
	
	print('[ChessController] Game started successfully')


func _on_signal_bus_promote(to_piece: ChessPiece.Type) -> void:
	if not _pending_promotion_move:
		push_error('Promotion signal received but no pending promotion!')
		return
	
	print('[ChessController] Completing promotion to %s' % ChessPiece.Type.keys()[to_piece])
	
	if _selected_piece_tile.has_piece():
		_selected_piece_tile.piece.queue_free()
	
	var promoted_piece := _create_promoted_piece(to_piece, _pending_promotion_player)
	
	# Place the piece on the selected tile it will get moved in _finalize_move
	_selected_piece_tile.piece = promoted_piece
	
	_finalize_move(_pending_promotion_move, promoted_piece)
	
	_pending_promotion_move = null


func _on_signal_bus_next_move() -> void:
	if not _game_over:
		_swap_player()


func _on_signal_bus_register_opponent(opponent: ChessOpponentComponent) -> void:
	await _register_opponent(opponent)


func _on_signal_bus_clear_board() -> void:
	_board.clear_board()
	print('[ChessController] Cleared board')


func _on_signal_bus_shutdown_ai() -> void:
	shutdown_ai()
