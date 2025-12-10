extends Node3D


@onready var chess_signal_bus: ChessSignalBus = $ChessSignalBus
@onready var n_promotion_select: HBoxContainer = $UI/PromotionSelect
@onready var n_start_game_container: CenterContainer = $UI/StartGameContainer
@onready var n_status_label: Label = $UI/StartGameContainer/VBoxContainer/StatusLabel

@onready var camera: Camera3D = $Camera3D
@onready var chess_controller: ChessController = $ChessController

var _animation_queue: Array = []
var _is_animating: bool = false
var _original_cam_trans: Transform3D


func _ready() -> void:
	_original_cam_trans = camera.global_transform
	
	# Connect to signal bus events
	chess_signal_bus.game_started.connect(_on_signal_bus_game_started)
	chess_signal_bus.checkmate.connect(_on_signal_bus_checkmate)
	chess_signal_bus.stalemate.connect(_on_signal_bus_stalemate)
	chess_signal_bus.draw.connect(_on_signal_bus_draw)
	chess_signal_bus.player_swapped.connect(_on_signal_bus_player_swapped)
	chess_signal_bus.move_executed.connect(_on_signal_bus_move_executed)
	chess_signal_bus.piece_captured.connect(_on_signal_bus_piece_captured)
	chess_signal_bus.check.connect(_on_signal_bus_check)
	chess_signal_bus.promotion_requested.connect(_on_signal_bus_promotion_requested)
	chess_signal_bus.turn_completed.connect(_on_signal_bus_turn_completed)
	chess_signal_bus.move_animation_requested.connect(_on_signal_bus_move_animation_requested)
	chess_signal_bus.capture_animation_requested.connect(_on_signal_bus_capture_animation_requested)


func _on_signal_bus_game_started(metadata: Dictionary) -> void:
	print('[Main] game_started event received: %s' % metadata)


func _on_signal_bus_checkmate(by_player: ChessController.Player) -> void:
	print('[Main] checkmate event received by player: %s' % ChessController.Player.keys()[by_player])
	_handle_game_over('CHECKMATE!')


func _on_signal_bus_stalemate() -> void:
	print('[Main] stalemate event received')
	_handle_game_over('STALEMATE!')


func _on_signal_bus_draw(reason: ChessUtils.DrawReason) -> void:
	print('[Main] draw event received %s' % ChessUtils.DrawReason.keys()[reason])
	_handle_game_over('DRAW!')


func _on_signal_bus_player_swapped(current_player: ChessController.Player) -> void:
	print('[Main] player_swapped event received: %s' % ChessController.Player.keys()[current_player])


func _on_signal_bus_move_executed(move: ChessMove, by_player: ChessController.Player) -> void:
	print('[Main] move_executed event received: %s by %s' % [move, ChessController.Player.keys()[by_player]])


func _on_signal_bus_piece_captured(piece: ChessPiece, on_tile: ChessBoardTile) -> void:
	print('[Main] piece_captured event received: %s on %s' % [piece, on_tile])


func _on_signal_bus_check(by_player: ChessController.Player) -> void:
	print('[Main] check event received by player: %s' % ChessController.Player.keys()[by_player])


func _on_signal_bus_promotion_requested(pos: Vector2i, player: ChessController.Player) -> void:
	print('[Main] promotion_requested event received at %s for player: %s' % [pos, ChessController.Player.keys()[player]])
	n_promotion_select.show()


func _on_signal_bus_turn_completed(_move_idx: int) -> void:
	print('[Main] turn_completed event received')
	# For now, immediately emit next_move to continue game flow
	chess_signal_bus.next_move.emit()


func _on_signal_bus_move_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile, to_tile: ChessBoardTile) -> void:
	print('[Main] move_animation_requested event received: %s from %s to %s' % [piece, from_tile, to_tile])
	
	# Add move animation to queue
	_animation_queue.append({
		'type': 'move',
		'piece': piece,
		'from_tile': from_tile,
		'to_tile': to_tile
	})
	
	# Start processing queue if not already animating
	if not _is_animating:
		_process_animation_queue()


func _on_signal_bus_capture_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile) -> void:
	print('[Main] capture_animation_requested event received: %s from %s' % [piece, from_tile])
	
	# Add capture animation to queue
	_animation_queue.append({
		'type': 'capture',
		'piece': piece,
		'from_tile': from_tile,
		'to_tile': null
	})
	
	# Start processing queue if not already animating
	if not _is_animating:
		_process_animation_queue()


func _process_animation_queue() -> void:
	# If queue is empty, signal completion
	if _animation_queue.is_empty():
		_is_animating = false
		print('[Main] All animations completed, emitting move_animation_completed')
		chess_signal_bus.move_animation_completed.emit()
		return
	
	# Get next animation from queue
	_is_animating = true
	var anim_data: Dictionary = _animation_queue.pop_front()
	var anim_type: String = anim_data.type
	var piece: ChessPiece = anim_data.piece
	var from_tile: ChessBoardTile = anim_data.from_tile
	
	if anim_type == 'capture':
		# Animate captured piece off the board
		var off_board_position = from_tile.global_position + Vector3(6, 0, 0)
		var duration = 0.4
		
		var tween = create_tween()
		tween.tween_property(piece, 'global_position', off_board_position, duration)
		tween.finished.connect(func():
			piece.queue_free()
			_on_animation_finished()
		)
	else:  # 'move' type
		var to_tile: ChessBoardTile = anim_data.to_tile
		
		# Calculate duration based on distance
		var distance = from_tile.board_position.distance_to(to_tile.board_position)
		var duration = 0.3 * sqrt(distance)
		
		# Create tween animation
		var tween = create_tween()
		tween.tween_property(piece, 'global_position', to_tile.global_position, duration)
		tween.finished.connect(_on_animation_finished)


func _handle_game_over(status: String) -> void:
	n_status_label.text = status
	n_start_game_container.show()
	
	chess_controller.lock()
	
	camera.current = true
	chess_controller.camera.current = false
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(camera, 'global_transform', _original_cam_trans, 1.0)


func _on_animation_finished() -> void:
	# Process next animation in queue
	_process_animation_queue()


func _on_promotion_button_promote(to_piece: ChessPiece.Type) -> void:
	chess_signal_bus.promote.emit(to_piece)
	n_promotion_select.hide()


func _on_start_game_button_pressed() -> void:
	n_start_game_container.hide()
	
	chess_controller.lock()
	chess_signal_bus.setup_game.emit({})
	
	var chess_cam_trans := chess_controller.camera.get_target_transform()
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(camera, 'global_transform', chess_cam_trans, 1.0)
	tween.finished.connect(
		func():
			chess_controller.unlock()
			camera.current = false
			chess_controller.camera.current = true
			chess_signal_bus.start_game.emit()
	)


func _on_clear_board_button_pressed() -> void:
	chess_signal_bus.clear_board.emit()


func _on_setup_board_button_pressed() -> void:
	chess_signal_bus.setup_game.emit({})
