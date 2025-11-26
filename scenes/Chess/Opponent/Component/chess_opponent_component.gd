class_name ChessOpponentComponent
extends Node


@export_category('Characteristics')
@export var player_name: String

@export_category('Stockfish Config')
@export_range(0, 20) var skill_level: int
@export_range(100, 10000, 10) var think_time_ms: int
@export_range(1, 1000) var search_depth: int


func _to_string() -> String:
	return 'ChessOpponent<%s|(s:%d,t:%d,d:%d)>' % [player_name, skill_level, think_time_ms, search_depth]
