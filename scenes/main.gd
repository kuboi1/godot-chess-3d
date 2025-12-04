extends Node3D


@onready var chess_controller: ChessController = $ChessController
@onready var n_promotion_select: HBoxContainer = $UI/PromotionSelect


func _on_chess_controller_promotion_requested(_position: Vector2i, _player: ChessController.Player) -> void:
	n_promotion_select.show()


func _on_promotion_button_promote(to_piece: ChessPiece.Type) -> void:
	chess_controller.complete_promotion(to_piece)
	n_promotion_select.hide()
