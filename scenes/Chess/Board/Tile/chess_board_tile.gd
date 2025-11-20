class_name ChessBoardTile
extends Area3D

@export_enum('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h') var position_x: String = 'a'
@export_enum('1', '2', '3', '4', '5', '6', '7', '8') var position_y: String = '1'

signal hovered(tile: ChessBoardTile)
signal clicked(tile: ChessBoardTile)

var chess_position: String
var board_position: Vector2i
var position_str: String : 
	get():
		return '%s:(%d,%d)' % [chess_position, board_position.x, board_position.y]

var piece: ChessPiece : 
	get():
		if piece != null and is_instance_valid(piece) and piece.get_parent() == self:
			return piece
		
		return null
	set(value):
		if value.get_parent() != self:
			if value.get_parent() == null:
				self.add_child(value)
			else:
				value.reparent(self)
		
		value.board_postion = board_position
		value.hovered.connect(_on_piece_hovered)
		value.clicked.connect(_on_piece_clicked)
		
		piece = value

var move_valid: bool = false :
	set(value):
		move_valid = value


func _ready() -> void:
	chess_position = '%s%s' % [position_x, position_y]
	board_position = ChessUtils.chess_position_to_board_position(chess_position)
	
	for child in self.get_children():
		if child is ChessPiece:
			if piece == null:
				piece = child
			else:
				push_error('Chess board tile %s:(%d,%d) has more than one ChessPiece child' % [chess_position, board_position.x, board_position.y])


func _to_string() -> String:
	var piece_str := ''
	if has_piece():
		piece_str = '[%s]' % piece
	return 'ChessBoardTile<%s>%s' % [position_str, piece_str]


func has_piece() -> bool:
	return piece != null


func disconnect_piece() -> void:
	piece.hovered.disconnect(_on_piece_hovered)
	piece.clicked.disconnect(_on_piece_clicked)


func _on_piece_hovered() -> void:
	hovered.emit(self)


func _on_piece_clicked() -> void:
	clicked.emit(self)


func _on_mouse_entered() -> void:
	# print('%s hovered' % self)
	
	hovered.emit(self)


func _on_mouse_exited() -> void:
	pass # Replace with function body.


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print('Clicked on: %s' % self)
			
			clicked.emit(self)
