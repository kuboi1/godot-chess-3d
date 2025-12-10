class_name ChessCamera
extends Node3D


enum Position {
	WHITE_DEFAULT,
	BLACK_DEFAULT,
	WHITE_OVERHEAD,
	BLACK_OVERHEAD
}

const STARTING_POSITIONS = {
	Position.WHITE_DEFAULT: {
		'arm_length': 8.0,
		'rotation': Vector3(deg_to_rad(-32.0), deg_to_rad(0.0), deg_to_rad(0.0))
	},
	Position.BLACK_DEFAULT: {
		'arm_length': 8.0,
		'rotation': Vector3(deg_to_rad(-32.0), deg_to_rad(180.0), deg_to_rad(0.0))
	}
}

const POSITIONS = {
	Position.WHITE_DEFAULT: {
		'arm_length': 7.5,
		'rotation': Vector3(deg_to_rad(-40.0), deg_to_rad(0.0), deg_to_rad(0.0))
	},
	Position.BLACK_DEFAULT: {
		'arm_length': 7.5,
		'rotation': Vector3(deg_to_rad(-40.0), deg_to_rad(180.0), deg_to_rad(0.0))
	},
	Position.WHITE_OVERHEAD: {
		'arm_length': 7.0,
		'rotation': Vector3(deg_to_rad(-70.0), deg_to_rad(0.0), deg_to_rad(0.0))
	},
	Position.BLACK_OVERHEAD: {
		'arm_length': 7.0,
		'rotation': Vector3(deg_to_rad(-90.0), deg_to_rad(180.0), deg_to_rad(0.0))
	}
}

@export var player_pos_timing: float = 1.0
@export var overhead_timing: float = 0.5

signal animation_started
signal animation_finished

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var _current_position: Position = Position.WHITE_DEFAULT
var _current_player: ChessController.Player = ChessController.Player.WHITE

var _position_locked: bool = false

var current: bool:
	get:
		return _camera.current
	set(value):
		_camera.current = value
		set_process_input(value)


func _ready() -> void:
	current = false


func _input(event: InputEvent) -> void:
	if _position_locked:
		return
	
	if event.is_action_pressed('chess_camera_up'):
		if _is_overhead():
			return
		
		if _current_player == ChessController.Player.WHITE:
			_change_position(Position.WHITE_OVERHEAD, overhead_timing)
		elif _current_player == ChessController.Player.BLACK:
			_change_position(Position.BLACK_OVERHEAD, overhead_timing)
	
	if event.is_action_pressed('chess_camera_down'):
		if not _is_overhead():
			return
		
		_change_position_to_player(overhead_timing)


func set_player(player: ChessController.Player) -> void:
	_current_player = player
	_change_position_to_player(player_pos_timing)


func get_target_transform() -> Transform3D:
	return _camera.global_transform


func _change_position(to: Position, timing: float) -> void:
	_current_position = to
	_position_locked = true
	
	var length_tween = create_tween()
	var rotation_tween = create_tween()
	
	length_tween.set_ease(Tween.EASE_OUT)
	rotation_tween.set_ease(Tween.EASE_OUT)
	
	rotation_tween.finished.connect(_on_position_change_finished)
	
	length_tween.tween_property(_spring_arm, 'spring_length', POSITIONS[to]['arm_length'], timing)
	rotation_tween.tween_property(_spring_arm, 'rotation', POSITIONS[to]['rotation'], timing)
	
	animation_started.emit()


func _change_position_to_player(timing: float) -> void:
	var pos: Position
	match _current_player:
		ChessController.Player.WHITE:
			pos = Position.WHITE_DEFAULT
		ChessController.Player.BLACK:
			pos = Position.BLACK_DEFAULT
		_:
			return
	
	_change_position(pos, timing)


func _is_overhead() -> bool:
	return _current_position in [Position.WHITE_OVERHEAD, Position.BLACK_OVERHEAD]


func _on_position_change_finished() -> void:
	_position_locked = false
	animation_finished.emit()
