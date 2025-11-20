class_name ChessUtils
extends Node


const CHESS_POSITIONS = {
	'x': ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
	'y': ['1', '2', '3', '4', '5', '6', '7', '8']
}


static func chess_position_to_board_position(notation_str: String) -> Vector2i:
	if notation_str.length() != 2:
		push_error('Chess notation must be 2 characters long (eg. e5)')
		return Vector2i(-1, -1)
	
	var pos_x := CHESS_POSITIONS.x.find(notation_str[0])
	var pos_y := CHESS_POSITIONS.y.find(notation_str[1])
	
	if pos_x == -1 or pos_y == -1:
		push_error('%s is an invalid chess notation position')
		return Vector2i(-1, -1)
	
	return Vector2i(pos_x, pos_y)


static func get_opposing_player(to_player: ChessController.Player) -> ChessController.Player:
	return (
		ChessController.Player.WHITE if to_player == ChessController.Player.BLACK 
		else ChessController.Player.BLACK
	)
