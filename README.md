# 3D Chess Module for Godot 4.4

A fully-featured, plug-and-play 3D chess module with customizable AI opponents built with Godot Engine 4.4. Designed as a modular component that can be easily integrated into any Godot project.

## What is ChessModule?

ChessModule is a complete chess engine implementation with:
- **Complete Chess Rules**: Check, checkmate, stalemate, castling, en passant, pawn promotion, and all draw conditions
- **AI Integration**: Stockfish engine with configurable difficulty (skill levels 0-20) and opening book support
- **Two Game Modes**: VS AI or Local Multiplayer
- **Signal-Based Architecture**: Fully decoupled via ChessSignalBus for easy integration
- **3D Assets**: Low-poly chess piece models and board included

This repository includes:
- **ChessModule/** - The core chess engine (this is what you integrate)
- **UI/** - Example UI components for the showcase
- **scenes/main.tscn** - A showcase implementation demonstrating usage

## Integration Guide

### Step 1: Copy ChessModule to Your Project

Copy the entire `ChessModule/` directory into your Godot project:

```
YourProject/
├── ChessModule/           # ← Copy this entire folder
│   ├── scenes/           # Chess scenes and components
│   ├── scripts/          # C# Stockfish wrapper (optional, for AI mode)
│   └── engines/          # Stockfish binaries (optional, for AI mode)
└── [your other files]
```

**Note**: If you only need Local Multiplayer mode, you can skip copying `scripts/` and `engines/` directories.

### Step 2: Add ChessController to Your Scene

The ChessController is the main entry point. Add it to your scene:

```gdscript
# Method 1: Instantiate in code
var chess_controller = preload("res://ChessModule/scenes/Controller/chess_controller.tscn").instantiate()
add_child(chess_controller)

# Method 2: Add via editor
# Drag ChessModule/scenes/Controller/chess_controller.tscn into your scene tree
```

### Step 3: Configure Game Settings

Configure the controller via exports or code:

```gdscript
# Game mode
chess_controller.game_type = ChessController.GameType.LOCAL_MULTIPLAYER  # or VS_AI

# For VS_AI mode
chess_controller.player_color = ChessController.Player.WHITE  # Your color

# Get reference to signal bus
var chess_signal_bus: ChessSignalBus = chess_controller.chess_signal_bus
```

### Step 4: Input Requirements

ChessModule uses **mouse input** for piece interaction. No custom input mappings required - it uses Godot's built-in mouse events on Area3D nodes.

**What the module handles:**
- Mouse hover over pieces and tiles (via Area3D mouse detection)
- Mouse clicks to select and move pieces (via Area3D input events)
- Piece highlighting and selection

**What you need to provide:**
- A camera that can see the chess board (Or set the camera inside the controller as current)
- Optional: Camera controls (chess_camera_up, chess_camera_down, debug_chess_swap_player)

### Step 5: Initialize and Start a Game

Connect to signals and start:

```gdscript
extends Node3D

@onready var chess_controller: ChessController = $ChessController
@onready var chess_signal_bus: ChessSignalBus = chess_controller.chess_signal_bus

func _ready() -> void:
    # Connect to game events
    chess_signal_bus.game_started.connect(_on_game_started)
    chess_signal_bus.checkmate.connect(_on_checkmate)
    chess_signal_bus.stalemate.connect(_on_stalemate)
    chess_signal_bus.move_executed.connect(_on_move_executed)
    chess_signal_bus.turn_completed.connect(_on_turn_completed)

    # Start game
    chess_signal_bus.setup_game.emit({})
    chess_signal_bus.start_game.emit()

func _on_game_started(metadata: Dictionary) -> void:
    print("Chess game started!")

func _on_checkmate(by_player: ChessController.Player) -> void:
    print("Checkmate! Winner: ", ChessController.Player.keys()[by_player])

func _on_stalemate() -> void:
    print("Stalemate - Draw!")

func _on_move_executed(move: ChessMove, by_player: ChessController.Player) -> void:
    print("Move by ", ChessController.Player.keys()[by_player])

func _on_turn_completed(move_idx: int) -> void:
    # Advance to next player
    chess_signal_bus.next_move.emit()
```

### Step 6: Handle Animations (Required)

ChessModule requests animations via signals but doesn't implement them. You must handle animations and notify completion:

```gdscript
func _ready() -> void:
    # ... other connections ...

    chess_signal_bus.move_animation_requested.connect(_on_move_animation)
    chess_signal_bus.capture_animation_requested.connect(_on_capture_animation)

func _on_move_animation(piece: ChessPiece, from_tile: ChessBoardTile, to_tile: ChessBoardTile) -> void:
    var tween = create_tween()
    tween.tween_property(piece, "global_position", to_tile.global_position, 0.3)
    await tween.finished

    # CRITICAL: Must emit when animation completes
    chess_signal_bus.move_animation_completed.emit()

func _on_capture_animation(piece: ChessPiece, from_tile: ChessBoardTile) -> void:
    var tween = create_tween()
    tween.tween_property(piece, "global_position", piece.global_position + Vector3(5, 0, 0), 0.3)
    await tween.finished
    piece.queue_free()
```

### Step 7: Handle Pawn Promotion (Required)

When a pawn reaches the end, provide UI for piece selection:

```gdscript
func _ready() -> void:
    chess_signal_bus.promotion_requested.connect(_on_promotion_requested)

func _on_promotion_requested(position: Vector2i, player: ChessController.Player) -> void:
    # Show UI with 4 buttons: Queen, Rook, Bishop, Knight
    show_promotion_ui()

func _on_player_selects_queen() -> void:
    chess_signal_bus.promote.emit(ChessPiece.Type.QUEEN)
    hide_promotion_ui()
```

## AI Opponent Setup

To enable AI vs Player mode:

```gdscript
# Set game type
chess_controller.game_type = ChessController.GameType.VS_AI
chess_controller.player_color = ChessController.Player.WHITE

# Create and configure opponent
var opponent = ChessOpponentComponent.new()
opponent.skill_level = 10       # 0 (easiest) to 20 (hardest)
opponent.think_time_ms = 2000   # Time AI takes per move (ms)

# Register opponent
chess_signal_bus.register_opponent.emit(opponent)
```

**Requirements for AI mode:**
- `ChessModule/scripts/StockfishEngine/` - C# wrapper for Stockfish
- `ChessModule/engines/chess/` - Stockfish binaries (platform-specific)
- Godot with C# support enabled

## Complete Signal Reference

### Signals FROM Controller (Events to listen to)

```gdscript
# Game State Events
signal game_started(metadata: Dictionary)
# Emitted when game starts. metadata contains: game_type, player_color, starting_player

signal checkmate(by_player: ChessController.Player)
# Emitted when a player wins by checkmate

signal stalemate
# Emitted when game ends in stalemate

signal draw(reason: ChessUtils.DrawReason)
# Emitted on draw. Reasons: FIFTY_MOVE, THREEFOLD_REPETITION, INSUFFICIENT_MATERIAL

# Turn Events
signal player_swapped(current_player: ChessController.Player)
# Emitted when active player changes

signal move_executed(move: ChessMove, by_player: ChessController.Player)
# Emitted after a move is executed (before animation)

signal piece_captured(piece: ChessPiece, on_tile: ChessBoardTile)
# Emitted when a piece is captured

signal check(by_player: ChessController.Player)
# Emitted when a player puts opponent in check

signal turn_completed(move_idx: int)
# Emitted after move animation completes. Emit next_move to continue.

# Special Move Events
signal promotion_requested(position: Vector2i, player: ChessController.Player)
# Emitted when pawn reaches end. Show UI and emit promote signal.

# Animation Events (YOU must implement animations)
signal move_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile, to_tile: ChessBoardTile)
# Animate piece movement, then emit move_animation_completed

signal capture_animation_requested(piece: ChessPiece, from_tile: ChessBoardTile)
# Animate piece being captured
```

### Signals TO Controller (Commands to emit)

```gdscript
# Game Control
signal setup_game(metadata: Dictionary)
# Initialize board. metadata can include: player_color, flip_sides

signal start_game
# Start the game (call after setup_game)

signal clear_board
# Remove all pieces from board

# Turn Control
signal next_move
# Advance to next player (emit after turn_completed)

signal move_animation_completed
# Notify that move animation finished (REQUIRED after move_animation_requested)

# Game Actions
signal promote(to_piece: ChessPiece.Type)
# Complete pawn promotion with selected piece type

signal register_opponent(opponent: ChessOpponentComponent)
# Register AI opponent (for VS_AI mode)
```

## Key Classes

### ChessController

**Enums:**
```gdscript
enum GameType { VS_AI, LOCAL_MULTIPLAYER }
enum Player { WHITE, BLACK }
```

**Key Exports:**
```gdscript
@export var game_type: GameType
@export var player_color: Player              # Your color in VS_AI mode
@export var start_cleared: bool = false       # Start with empty board
@export var chess_signal_bus: ChessSignalBus  # Signal bus reference
```

**Public Methods:**
```gdscript
func lock() -> void        # Prevent player input
func unlock() -> void      # Allow player input
func shutdown_ai() -> void # Shutdown Stockfish engine
```

### ChessPiece

**Enum:**
```gdscript
enum Type { KING, QUEEN, ROOK, KNIGHT, BISHOP, PAWN }
```

**Properties:**
```gdscript
var owner_player: ChessController.Player
var board_position: Vector2i
var type: Type
```

### ChessMove

**Enum:**
```gdscript
enum Type { NORMAL, CAPTURE, CASTLE, EN_PASSANT, PROMOTION, PROMOTION_CAPTURE }
```

**Properties:**
```gdscript
var from: Vector2i       # Starting position
var to: Vector2i         # Destination
var type: Type           # Move type
var metadata: Dictionary # Additional data (captured_piece, rook, promotion_piece, etc.)
```

## Configuration Options

### Custom Starting Positions (FEN)

```gdscript
var starting_pos_gen = ChessStartingPositionGenerator.new()
starting_pos_gen.position_type = ChessStartingPositionGenerator.StartingPositionType.FEN
starting_pos_gen._fen_notation_position = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
chess_controller.starting_position_generator = starting_pos_gen
```

### AI Opponent with Opening Book

```gdscript
var opponent = ChessOpponentComponent.new()
opponent.skill_level = 15
opponent.think_time_ms = 1500
opponent._use_openings_prob = 0.8  # 80% chance to use opening book
# Opening resources are in ChessModule/scenes/Opponent/Component/Opening/Openings/
```

## Utility Classes (Brief Reference)

### ChessUtils (Static)

Common helper functions:
```gdscript
static func chess_position_to_board_position(notation: String) -> Vector2i
static func board_position_to_chess_position(pos: Vector2i) -> String
static func get_opposing_player(player: Player) -> Player
static func uci_to_chess_move(uci: String, board: Array[Array]) -> ChessMove
```

### ChessBoardUtils (Static)

Board analysis utilities:
```gdscript
static func is_position_attacked(pos: Vector2i, by_player: Player, board: Array[Array], move_idx: int) -> bool
static func is_king_in_check(player: Player, board: Array[Array], move_idx: int) -> bool
static func player_has_legal_moves(player: Player, board: Array[Array], move_idx: int) -> bool
static func simulate_move(move: ChessMove, board: Array[Array]) -> Array[Array]
```

### ChessPositionConvertor (Static)

FEN notation conversion:
```gdscript
static func board_tiles_to_fen(tiles: Array[Array], current_player: Player, move_idx: int, halfmove_clock: int) -> String
static func fen_to_chess_positions(fen: String) -> Dictionary
```

## ChessModule File Structure

```
ChessModule/
├── scenes/                  # All chess scenes
│   ├── Controller/         # ChessController - main entry point
│   ├── Board/              # ChessBoard and ChessBoardTile (8x8 grid)
│   ├── Piece/              # ChessPiece base class + 3D models
│   │   ├── Types/         # 6 piece implementations (King, Queen, Rook, Bishop, Knight, Pawn)
│   │   └── assets/        # 3D models and materials
│   ├── Camera/             # ChessCamera (4-position system)
│   ├── SignalBus/          # ChessSignalBus - central event hub
│   ├── Opponent/           # AI opponent system
│   │   ├── Component/     # ChessOpponentComponent configuration
│   │   └── Controller/    # ChessOpponentController - Stockfish integration
│   └── Services/           # Utility classes and helpers
├── scripts/                # C# wrapper (optional, VS_AI only)
│   └── StockfishEngine/   # UCI protocol implementation
└── engines/                # Stockfish binaries (optional, VS_AI only)
    └── chess/             # Platform-specific executables
```

## Advanced Topics

### Architecture Overview

- **Signal Bus Pattern**: All components communicate through ChessSignalBus for maximum decoupling
- **Component-Based Movement**: Each piece type uses Strategy pattern - movement logic is delegated to specialized components
- **Hierarchical Signals**: Input propagates: Mouse → Piece → Tile → Board → Controller
- **Animation Queue**: Your implementation can queue animations for sequential processing
- **Board Simulation**: Moves can be tested without modifying actual board state using `ChessBoardUtils.simulate_move()`

### Accessing Board State

```gdscript
# Get board tiles (8x8 array)
var board_tiles: Array[Array] = chess_controller._board_tiles

# Check a specific tile
var tile: ChessBoardTile = board_tiles[row][col]
if tile.has_piece():
    var piece: ChessPiece = tile.piece
    print("Piece: ", piece.type, " Owner: ", piece.owner_player)
```

### Custom Camera Integration

ChessModule includes a ChessCamera with 4 preset positions, but you can use your own:

```gdscript
# Use your own camera instead
chess_controller.camera.current = false
my_camera.current = true
```

## Showcase Implementation

This repository includes a complete working example in `scenes/main.tscn` that demonstrates:
- Game initialization and setup
- Animation queue system (sequential move/capture animations)
- Pawn promotion UI
- Camera transitions
- Game over handling

The `UI/` folder contains example UI components. These are showcase-specific and not required for ChessModule integration.

## Requirements

- Godot Engine 4.4+
- **For AI mode only**:
  - Godot with C# support (.NET 6.0+)
  - Stockfish binaries (included for Windows, Linux, macOS)

## License

DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE (WTFPL)
Version 2, December 2004

Copyright (C) 2024

Everyone is permitted to copy and distribute verbatim or modified
copies of this license document, and changing it is allowed as long
as the name is changed.

DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

0. You just DO WHAT THE FUCK YOU WANT TO.
