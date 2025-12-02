class_name ChessOpponentComponent
extends Node


@export_category('Characteristics')
@export var player_name: String

@export_category('Stockfish Config')
@export_range(0, 20) var skill_level: int = 5
@export_range(100, 10000, 10) var think_time_ms: int = 1000
@export_range(1, 1000) var search_depth: int = 100

@export_category('Human-like Behavior')
@export_range(1, 20) var candidate_moves: int = 5
@export_range(0.0, 2.0, 0.1) var move_randomness: float = 0.5
@export_range(0, 10) var mate_vision: int = 5

@export_category('Openings')
## Intended to only push the engine towards the position so 1-4 moves should be enough
@export var _openings: Array[ChessOpening] = []
@export_range(0.0, 1.0, 0.05) var _use_openings_prob: float = 1.0


func _ready() -> void:
	# Validate openings
	if _has_openings():
		for opening: ChessOpening in _openings:
			for move: String in opening.hardcoded_moves:
				if not ChessUtils.is_valid_uci(move):
					push_error('Move %s in opening is not a valid UCI move! Disabling openings for this opponent' % move)
					_openings = []
					return


func _to_string() -> String:
	return 'ChessOpponent<%s>' % player_name


func uses_openings(on_side: ChessController.Player) -> bool:
	if not _has_openings():
		return false
	
	for opening: ChessOpening in _openings:
		if opening.side == on_side:
			return true
	
	return false


func pick_random_opening(for_side: ChessController.Player) -> ChessOpening:
	if not uses_openings(for_side):
		return null
	
	# Flip if an opening should be used
	if _use_openings_prob < randf():
		return null
	
	return (
		_openings
			.filter(func (opening: ChessOpening): return opening.side == for_side)
			.pick_random()
	)


func _has_openings() -> bool:
	return not _openings.is_empty() and _use_openings_prob > 0.0
