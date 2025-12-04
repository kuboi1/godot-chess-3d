class_name ChessSignalBus
extends Node


# From controller
signal game_started(metadata: Dictionary)
signal checkmate(by_player: ChessController.Player)
signal resignation(by_player: ChessController.Player)
signal stalemate
signal draw # TODO: Add reason

signal player_swapped(current_player: ChessController.Player)
signal move_executed(move: ChessMove, by_player: ChessController.Player)
signal piece_captured(piece: ChessPiece, on_tile: ChessBoardTile)
signal check(by_player: ChessController.Player)
signal promotion_requested(position: Vector2i, player: ChessController.Player)
signal turn_completed

signal move_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile, to_tile: ChessBoardTile)
signal capture_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile)

# To controller
signal next_move
signal promote(to_piece: ChessPiece.Type)
signal move_animation_completed
