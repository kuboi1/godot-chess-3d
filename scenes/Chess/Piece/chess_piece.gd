class_name ChessPiece
extends Node3D


enum Type {
	KING,
	QUEEN,
	ROOK,
	KNIGHT,
	BISHOP,
	PAWN
}

enum SpecialMove {
	CASTLE,
	EN_PASSANT
}

signal hovered
signal clicked

@export var owner_player: ChessController.Player = ChessController.Player.WHITE
@export var type: Type

@onready var pre_white_mat: StandardMaterial3D = preload('res://scenes/Chess/Piece/assets/cp_white_material.tres')
@onready var pre_black_mat: StandardMaterial3D = preload('res://scenes/Chess/Piece/assets/cp_black_material.tres')

@onready var n_mesh = $Mesh

var _movement_component: ChessPieceMovementComponent

var board_postion: Vector2i

var move_count: int :
	get():
		return _movement_component.move_count
var last_move_idx: int :
	get():
		return _movement_component.last_move_idx


func _ready() -> void:
	var initialized = _init_piece()
	if not initialized:
		push_error('Chess piece %s could not be initialized' % self)
	
	if owner_player == ChessController.Player.WHITE:
		n_mesh.material_override = pre_white_mat
	else:
		n_mesh.material_override = pre_black_mat


func _init_piece() -> bool:
	for child in self.get_children():
		if child is ChessPieceMovementComponent:
			_movement_component = child
	
	if _movement_component == null:
		push_error('The MovementComponent child of chess piece %s is missing a ChessPieceMovementComponent derived script' % self)
	
	return _movement_component != null


func _to_string() -> String:
	return 'ChessPiece:<%s:%s>' % [Type.keys()[type], ChessController.Player.keys()[owner_player]]


func get_legal_moves(
	board: Array[Array], 
	move_idx: int, 
	validate_checks: bool = true
) -> Array[ChessMove]:
	return _movement_component.calculate_legal_moves(
		board_postion, 
		board, 
		move_idx, 
		validate_checks
	)


func register_move(move_idx: int) -> void:
	_movement_component.register_move(move_idx)


func has_moved() -> bool:
	return _movement_component.has_moved()


func _on_mouse_entered() -> void:
	# print('%s hovered' % self)
	
	hovered.emit()


func _on_mouse_exited() -> void:
	pass # Replace with function body.


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print('Clicked on: %s' % self)
			
			clicked.emit()
