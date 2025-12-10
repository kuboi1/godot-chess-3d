class_name PromotionButton
extends Button


signal promote(to_piece: ChessPiece.Type)

@export var piece_type: ChessPiece.Type = ChessPiece.Type.QUEEN


func _ready() -> void:
	if piece_type == ChessPiece.Type.KING:
		push_warning('King is an invalid promotion piece defaulting to queen')
		piece_type = ChessPiece.Type.QUEEN


func _on_pressed() -> void:
	promote.emit(piece_type)
