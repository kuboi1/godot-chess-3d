class_name ChessOpponentController
extends Node


const CANDIDATE_SCORE_CP = 'cp'
const CANDIDATE_SCORE_MATE = 'mate'

signal thinking_started
signal move_calculated(uci_move: String)

@export var base_mate_score: int = 2500
@export var mate_distance_penalty: int = 10

var initialized: bool = false

var opponent: ChessOpponentComponent
var player_color: ChessController.Player = ChessController.Player.BLACK

var skill_level: int = 10 : 
	get():
		if opponent:
			return opponent.skill_level
		return skill_level
var think_time_ms: int = 1000 : 
	get():
		if opponent:
			return opponent.think_time_ms
		return think_time_ms
var search_depth: int = 20 : 
	get():
		if opponent:
			return opponent.search_depth
		return search_depth
var candidate_moves: int = 5 : 
	get():
		if opponent:
			return opponent.candidate_moves
		return candidate_moves
var move_randomness: float = 0.5 : 
	get():
		if opponent:
			return opponent.move_randomness
		return move_randomness
var mate_vision: int = 5 : 
	get():
		if opponent:
			return opponent.mate_vision
		return mate_vision

var _opening: ChessOpening
var _opening_move_idx: int = 0
var _is_in_opening: bool = false

var _chess_engine: StockfishEngine


func initialize(engine_debug_mode: bool = false) -> void:
	await _init_chess_engine(engine_debug_mode)


func register_opponent(opponent_component: ChessOpponentComponent) -> void:
	opponent = opponent_component
	
	_opening = opponent.pick_random_opening(player_color)
	if _opening:
		_opening_move_idx = 0
		_is_in_opening = true
		print('[ChessOpponentController] Opening %s will be played' % _opening)
	
	if not _chess_engine:
		push_warning('Registered opponent before initializing opponent. Skill level was not registered')
	
	_chess_engine.SetSkillLevel(skill_level)
	
	print('[ChessOpponentController] Opponent registered: SkillLevel=%d, ThinkTimeMS=%d, SearchDepth=%d, MultiPV=%d, Randomness=%.2f, MateVision=%d' % [
		skill_level, think_time_ms, search_depth, candidate_moves, move_randomness, mate_vision
	])


func _init_chess_engine(debug_mode: bool) -> void:
	_chess_engine = StockfishEngine.new()
	self.add_child(_chess_engine)
	
	# Connect signals
	_chess_engine.EngineReady.connect(_on_engine_ready)
	_chess_engine.CandidateMovesCalculated.connect(_on_candidate_moves_calculated)
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
	if _is_in_opening:
		var opening_move: String = _opening.get_move(_opening_move_idx)
		if ChessBoardUtils.is_uci_move_legal(opening_move, player_color, board_tiles, move_idx):
			move_calculated.emit(opening_move)
			_opening_move_idx += 1
			_is_in_opening = _opening_move_idx < _opening.get_move_count()
			if not _is_in_opening:
				print('[ChessOpponentController] %s opening finished' % _opening)
			return
		
		# If move is illegal get out of opening and calculate the move as usual
		print('[ChessOpponentController] The next opening move %s is not legal -> skipping the rest of the %s opening' % [opening_move, _opening])
		_is_in_opening = false
	
	update_position(board_tiles, move_idx)
	_chess_engine.GetBestMove(think_time_ms, search_depth)
	thinking_started.emit()


func _normalize_candidate_score(candidate: Dictionary) -> Dictionary:
	var normalized := candidate.duplicate()
	var score_type: String = candidate.get('score_type', CANDIDATE_SCORE_CP)
	var raw_score: int = candidate.get('score', 0)
	var normalized_score: int
	
	if score_type == CANDIDATE_SCORE_MATE:
		# Apply mate vision logic
		var mate_distance: int = abs(raw_score)
		var multiplier: float = _get_mate_score_multiplier(mate_distance)
		
		# Base mate score with distance penalty (faster mates are better)
		var mate_score: int = base_mate_score - (mate_distance * mate_distance_penalty)
		
		# Apply multiplier based on mate vision
		if multiplier < 0.01:
			# Can't see the mate at all
			normalized_score = 300  # ~3 pawns
		else:
			normalized_score = int(mate_score * multiplier)
		
		# Negative if opponent's mate
		if raw_score < 0:
			normalized_score = -normalized_score
	else:
		normalized_score = raw_score
	
	normalized['score'] = normalized_score
	return normalized


func _get_mate_score_multiplier(mate_distance: int) -> float:
	# Perfect vision - always sees all mates
	if mate_vision >= 10:
		return 1.0
	
	# Blind to mates - treat as normal position
	if mate_vision == 0:
		return 0.0
	
	# Within vision range - always spot it
	if mate_distance <= mate_vision:
		return 1.0
	
	# Beyond vision - exponentially harder to see
	var overage: float = mate_distance - mate_vision
	return max(0.05, 1.0 / (overage + 1.0))


func _select_weighted_move(candidates: Array) -> String:
	if candidates.size() == 0:
		push_error('Cannot select from empty candidate list')
		return ''
	
	if candidates.size() == 1:
		return candidates[0].get('move', '')
	
	# Find best score to calculate weights
	var best_score: int = candidates[0].get('score', 0)
	for candidate in candidates:
		var score: int = candidate.get('score', 0)
		if score > best_score:
			best_score = score
	
	# Calculate weights for each candidate
	var weights: Array[float] = []
	var total_weight: float = 0.0
	
	for candidate in candidates:
		var score: int = candidate.get('score', 0)
		var score_diff: float = abs(best_score - score)
		
		# Temperature-scaled weight
		var weight: float
		if move_randomness < 0.01:
			# Pick best
			weight = 1.0 if score == best_score else 0.0
		else:
			# Exponential decay
			weight = exp(-score_diff / (100.0 * move_randomness))
		
		weights.append(weight)
		total_weight += weight
	
	# Normalize weights
	if total_weight > 0:
		for i in range(weights.size()):
			weights[i] /= total_weight
	
	# Weighted random selection
	var rand_value: float = randf()
	var cumulative: float = 0.0
	
	for i in range(candidates.size()):
		cumulative += weights[i]
		if rand_value <= cumulative:
			var selected_move: String = candidates[i].get('move', '')
			print('[ChessOpponentController] Selected move %s (multipv=%d, score=%d, weight=%.2f)' % [
				selected_move,
				candidates[i].get('multipv', 0),
				candidates[i].get('score', 0),
				weights[i]
			])
			return selected_move
	
	# Fallback (shouldn't reach here)
	push_warning('Could not calculate weighted best move from candidate moves. Weird...')
	return candidates[0].get('move', '')


func _on_engine_ready() -> void:
	print('[ChessOpponentController] Stockfish engine ready')
	initialized = true
	
	# Configure MultiPV for candidate move analysis
	_chess_engine.SetMultiPV(candidate_moves)


func _on_candidate_moves_calculated(candidates: Array) -> void:
	if candidates.size() == 0:
		push_error('No candidate moves received from engine')
		return
	
	# Normalize scores with mate_vision
	var normalized_candidates: Array = []
	for candidate in candidates:
		var normalized = _normalize_candidate_score(candidate)
		normalized_candidates.append(normalized)
	
	# Select move using weighted randomness
	var selected_move: String = _select_weighted_move(normalized_candidates)
	move_calculated.emit(selected_move)


func _on_info_received(info: String) -> void:
	print('[ChessOpponentController] ENGINE: %s' % info)


func _on_error_occurred(message: String) -> void:
	push_error('Engine error: %s' % message)


func _on_initialization_failed(reason: String) -> void:
	push_error('Stockfish engine failed to initialize: %s' % reason)
