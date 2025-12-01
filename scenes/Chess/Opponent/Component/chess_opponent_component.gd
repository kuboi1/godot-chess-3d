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


func _to_string() -> String:
	return 'ChessOpponent<%s|(t:%d,d:%d)>' % [player_name, think_time_ms, search_depth]
