class_name ChessCamera
extends Node3D


enum Position {
	PLAYER_WHITE,
	PLAYER_BLACK,
	OVERHEAD_WHITE,
	OVERHEAD_BLACK
}

const STARTING_POSITIONS = {
	Position.PLAYER_WHITE: {
		'arm_length': 7.0,
		'rotation': Vector3(deg_to_rad(-32.0), deg_to_rad(0.0), deg_to_rad(0.0))
	},
	Position.PLAYER_BLACK: {
		'arm_length': 7.0,
		'rotation': Vector3(deg_to_rad(-32.0), deg_to_rad(180.0), deg_to_rad(0.0))
	}
}

const POSITIONS = {
	Position.PLAYER_WHITE: {
		'arm_length': 8.0,
		'rotation': Vector3(deg_to_rad(-45.0), deg_to_rad(0.0), deg_to_rad(0.0))
	},
	Position.PLAYER_BLACK: {
		'arm_length': 8.0,
		'rotation': Vector3(deg_to_rad(-45.0), deg_to_rad(180.0), deg_to_rad(0.0))
	},
	Position.OVERHEAD_WHITE: {
		'arm_length': 7.0,
		'rotation': Vector3(deg_to_rad(-90.0), deg_to_rad(0.0), deg_to_rad(0.0))
	},
	Position.OVERHEAD_BLACK: {
		'arm_length': 7.0,
		'rotation': Vector3(deg_to_rad(-90.0), deg_to_rad(180.0), deg_to_rad(0.0))
	}
}

@export var player_pos_timing: float = 1.0
@export var overhead_timing: float = 0.5

signal animation_started
signal animation_finished

@onready var n_spring_arm = $SpringArm3D

var _current_position: Position = Position.PLAYER_WHITE
var _current_player: ChessController.Player = ChessController.Player.WHITE

var _position_locked: bool = false


func _input(event: InputEvent) -> void:
	if _position_locked:
		return
	
	if event.is_action_pressed('chess_camera_up'):
		if _is_overhead():
			return
		
		if _current_player == ChessController.Player.WHITE:
			_change_position(Position.OVERHEAD_WHITE, overhead_timing)
		elif _current_player == ChessController.Player.BLACK:
			_change_position(Position.OVERHEAD_BLACK, overhead_timing)
	
	if event.is_action_pressed('chess_camera_down'):
		if not _is_overhead():
			return
		
		_change_position_to_player(overhead_timing)


func set_player(player: ChessController.Player, init: bool = false) -> void:
	_current_player = player
	_change_position_to_player(player_pos_timing, init)


func _change_position(to: Position, timing: float) -> void:
	_current_position = to
	_position_locked = true
	
	var length_tween = create_tween()
	var rotation_tween = create_tween()
	
	length_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.set_ease(Tween.EASE_OUT)
	
	rotation_tween.finished.connect(_on_position_change_finished)
	
	length_tween.tween_property(n_spring_arm, 'spring_length', POSITIONS[to]['arm_length'], timing)
	rotation_tween.tween_property(n_spring_arm, 'rotation', POSITIONS[to]['rotation'], timing)
	
	animation_started.emit()


func _change_position_to_player(timing: float, init: bool = false) -> void:
	var pos: Position
	match _current_player:
		ChessController.Player.WHITE:
			pos = Position.PLAYER_WHITE
		ChessController.Player.BLACK:
			pos = Position.PLAYER_BLACK
		_:
			return
	
	if init:
		n_spring_arm.spring_length = STARTING_POSITIONS[pos]['arm_length']
		n_spring_arm.rotation = STARTING_POSITIONS[pos]['rotation']
	
	_change_position(pos, timing)


func _is_overhead() -> bool:
	return _current_position in [Position.OVERHEAD_WHITE, Position.OVERHEAD_BLACK]


func _on_position_change_finished() -> void:
	_position_locked = false
	animation_finished.emit()
