class_name ChessSignalBus
extends Node

# Ignore warnings (signals are always used outside the signal bus class)
@warning_ignore_start('unused_signal')

# From controller
signal game_started(metadata: Dictionary)
signal checkmate(by_player: ChessController.Player)
signal resignation(by_player: ChessController.Player)
signal stalemate
signal draw(reason: ChessUtils.DrawReason)

signal player_swapped(current_player: ChessController.Player)
signal move_executed(move: ChessMove, by_player: ChessController.Player)
signal piece_captured(piece: ChessPiece, on_tile: ChessBoardTile)
signal check(by_player: ChessController.Player)
signal promotion_requested(position: Vector2i, player: ChessController.Player)
signal turn_completed

signal move_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile, to_tile: ChessBoardTile)
signal capture_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile)

# To controller
signal new_game(metadata: Dictionary)
signal next_move
signal promote(to_piece: ChessPiece.Type)
signal move_animation_completed
