class_name ChessMove
extends Node


enum Type {
	NORMAL,
	CAPTURE,
	CASTLE,
	EN_PASSANT,
	PROMOTION,
	PROMOTION_CAPTURE
}

var pos: Vector2i
var type: Type
var metadata: Dictionary


func _init(pos: Vector2i, type: Type = Type.NORMAL, metadata: Dictionary = {}) -> void:
	self.pos = pos
	self.type = type
	self.metadata = metadata


func _to_string() -> String:
	return 'ChessMove:<%s:(%d,%d)>' % [Type.keys()[type], pos.x, pos.y]


func is_normal() -> bool:
	return type == Type.NORMAL


func is_capture() -> bool:
	return type in [Type.CAPTURE, Type.PROMOTION_CAPTURE]


func is_promotion() -> bool:
	return type in [Type.PROMOTION, Type.PROMOTION_CAPTURE]
