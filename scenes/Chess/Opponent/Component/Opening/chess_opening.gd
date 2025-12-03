class_name ChessOpening
extends Resource


@export var side: ChessController.Player
## Intended to only push the engine towards the position so 1-4 moves should be enough
@export var moves: Array[String] = []
@export var name: String = ''


func _to_string() -> String:
	return name if name != '' else 'Unnamed opening'


func get_move_count() -> int:
	return moves.size()


func get_move(index: int) -> String:
	if index >= 0 and index < moves.size():
		return moves[index]
	return ''
