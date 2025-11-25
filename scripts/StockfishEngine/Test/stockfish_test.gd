extends Node

var engine: StockfishEngine
var _initialization_failed: bool = false
var _test_6_completed: bool = false

func _ready() -> void:
	print("=== Stockfish Engine Test Starting ===")
	
	engine = StockfishEngine.new()
	add_child(engine)
	
	# Connect to all engine signals (signals must use PascalCase - no auto-conversion)
	engine.EngineReady.connect(_on_engine_ready)
	engine.BestMoveCalculated.connect(_on_best_move_calculated)
	engine.InfoReceived.connect(_on_info_received)
	engine.ErrorOccurred.connect(_on_error_occurred)
	engine.InitializationFailed.connect(_on_initialization_failed)
	
	engine.SetStockfishPrintOutput(false)
	
	# Start the test sequence
	await _run_test_sequence()


func _run_test_sequence() -> void:
	print("\n--- Test 1: Engine Initialization ---")
	
	# Call initialize (signal-based, no return value) - snake_case!
	engine.Initialize()
	
	# Wait for EngineReady signal - PascalCase for signals!
	await engine.EngineReady
	
	if _initialization_failed:
		print("ERROR: Engine initialization failed!")
		return
	
	print("✓ Engine initialized successfully")
	
	# Wait a moment for engine to be ready
	await get_tree().create_timer(0.5).timeout
	
	print("\n--- Test 2: Set Skill Level ---")
	engine.SetSkillLevel(5)
	print("✓ Skill level set to 5 (beginner-intermediate)")
	
	await get_tree().create_timer(0.2).timeout
	
	print("\n--- Test 3: Start New Game ---")
	engine.NewGame()
	print("✓ New game initialized")
	
	await get_tree().create_timer(0.2).timeout
	
	print("\n--- Test 4: Set Position (Scholar's Mate Setup) ---")
	# Starting position FEN
	var fen = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"
	engine.SetPosition(fen, [])
	print("✓ Position set to FEN: ", fen)
	
	await get_tree().create_timer(0.2).timeout
	
	print("\n--- Test 5: Get Best Move (1000ms think time) ---")
	engine.GetBestMove(1000)
	print("⏳ Waiting for best move calculation...")
	# Result will be printed via signal callback


# Signal Callbacks

func _on_engine_ready() -> void:
	print("📡 SIGNAL: EngineReady")


func _on_best_move_calculated(move: String, ponder: String) -> void:
	print("📡 SIGNAL: BestMoveCalculated")
	print("   Best move: ", move)
	if ponder != "":
		print("   Ponder move: ", ponder)
	
	# Parse and explain the move
	_explain_move(move)
	
	# Run test 6 only once (after first best move)
	if not _test_6_completed:
		_test_6_completed = true
		await get_tree().create_timer(1.0).timeout
		_test_skill_level(20)


func _on_info_received(info: String) -> void:
	if "depth" in info and "score cp" in info:
		print("📊 INFO: ", info)
	pass


func _on_error_occurred(message: String) -> void:
	print("❌ ERROR: ", message)


func _on_initialization_failed(reason: String) -> void:
	print("❌ INITIALIZATION FAILED: ", reason)
	_initialization_failed = true


# Helper Functions

func _explain_move(move: String) -> void:
	if move.length() < 4:
		return
	
	var from_square = move.substr(0, 2)
	var to_square = move.substr(2, 2)
	var promotion = ""
	
	if move.length() == 5:
		promotion = " (promotes to " + move.substr(4, 1).to_upper() + ")"
	
	print("   → Move: ", from_square, " to ", to_square, promotion)


func _test_skill_level(level: int) -> void:
	print("\n--- Test 6: Different Skill Level ---")
	
	# Test with maximum strength
	engine.SetSkillLevel(level)
	print("✓ Testing with Skill Level %d" % level)
	
	# Set a tactical position (white to move, can win material)
	var fen = "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4"
	engine.SetPosition(fen, [])
	
	await get_tree().create_timer(0.2).timeout
	
	engine.GetBestMove(2000)
	print("⏳ Calculating best move with 2 second think time...")
	
	await get_tree().create_timer(3.0).timeout
	
	print("\n=== All Tests Complete ===")
	print("Check the output above to verify:")
	print("  1. Engine initialized without errors")
	print("  2. Signals fired correctly")
	print("  3. Best moves were calculated")
	print("  4. No error messages appeared")
