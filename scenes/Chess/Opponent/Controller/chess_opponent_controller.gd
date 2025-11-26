class_name ChessOpponentController
extends Node


signal thinking_started
signal move_calculated(uci_move: String)

var initialized: bool = false

var player_color: ChessController.Player = ChessController.Player.BLACK
var think_time_ms: int = 1000
var search_depth: int = 20
var skill_level: int = 10 :
	set(value):
		skill_level = value
		
		if _chess_engine:
			_chess_engine.SetSkillLevel(skill_level)

var _chess_engine: StockfishEngine


func initialize(engine_debug_mode: bool = false) -> void:
	await _init_chess_engine(engine_debug_mode)


func _init_chess_engine(debug_mode: bool) -> void:
	_chess_engine = StockfishEngine.new()
	self.add_child(_chess_engine)
	
	# Connect signals
	_chess_engine.EngineReady.connect(_on_engine_ready)
	_chess_engine.BestMoveCalculated.connect(_on_best_move_calculated)
	_chess_engine.InfoReceived.connect(_on_info_received)
	_chess_engine.ErrorOccurred.connect(_on_error_occurred)
	_chess_engine.InitializationFailed.connect(_on_initialization_failed)
	
	_chess_engine.SetStockfishPrintOutput(debug_mode)
	
	_chess_engine.Initialize()
	
	await _chess_engine.EngineReady


# This can be later updated to use a starting position and moves, but this will do for now
func update_position(board_tiles: Array[Array], move_idx: int) -> void:
	var fen_pos: String = ChessPositionConvertor.board_tiles_to_fen(
		board_tiles,
		player_color,
		move_idx
	)
	_chess_engine.SetPosition(fen_pos, [])


func request_move(board_tiles: Array[Array], move_idx: int) -> void:
	update_position(board_tiles, move_idx)
	_chess_engine.GetBestMove(think_time_ms, search_depth)
	thinking_started.emit()


func _on_engine_ready() -> void:
	print('[ChessOpponentController] Stockfish engine ready')
	initialized = true
	
	_chess_engine.SetSkillLevel(skill_level)


func _on_best_move_calculated(move: String, _ponder: String) -> void:
	move_calculated.emit(move)


func _on_info_received(info: String) -> void:
	print('[ChessOpponentController] ENGINE: %s' % info)


func _on_error_occurred(message: String) -> void:
	push_error('Engine error: %s' % message)


func _on_initialization_failed(reason: String) -> void:
	push_error('Stockfish engine failed to initialize: %s' % reason)
