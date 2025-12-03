using Godot;
using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using chess3d.StockfishEngine.UCI;

[GlobalClass]
public partial class StockfishEngine : Node
{
	// === Signals ===
	[Signal]
	public delegate void EngineReadyEventHandler();

	[Signal]
	public delegate void BestMoveCalculatedEventHandler(string move, string ponder);

	[Signal]
	public delegate void CandidateMovesCalculatedEventHandler(Godot.Collections.Array candidates);

	[Signal]
	public delegate void InfoReceivedEventHandler(string info);

	[Signal]
	public delegate void ErrorOccurredEventHandler(string message);

	[Signal]
	public delegate void InitializationFailedEventHandler(string reason);

	// === Private Fields ===
	private Process _stockfishProcess;
	private StreamWriter _stdin;
	private StreamReader _stdout;
	private StreamReader _stderr;
	private bool _isInitialized = false;
	private bool _isReady = false;

	private bool _stockfishPrintOutput = true;
	private int _defaultThinkTimeMs = 1000; // Default to 1 second
	private int _multiPV = 1; // Number of candidate moves to return (default 1 = only best)

	// Stores candidate moves from MultiPV info lines
	private System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary> _candidateMoves;

	// === Engine Configuration ===
	private string _enginePath;

	// === Lifecycle Methods ===

	public override void _Ready()
	{
		_enginePath = GetStockfishPath();
		GD.Print($"[StockfishEngine] Using stockfish at path: {_enginePath}");
	}

	public override void _ExitTree()
	{
		StopEngine();
	}

	// ============================================================================
	// PLATFORM DETECTION
	// ============================================================================

	/// <summary>
	/// Detects the current platform and returns the appropriate Stockfish executable path.
	/// </summary>
	private string GetStockfishPath()
	{
		string executableName;

		if (OS.GetName() == "Windows")
		{
			executableName = "stockfish-windows.exe";
		}
		else if (OS.GetName() == "Linux")
		{
			executableName = "stockfish-linux";
		}
		else if (OS.GetName() == "macOS")
		{
			executableName = "stockfish-macos";
		}
		else
		{
			GD.PrintErr($"[StockfishEngine] Unsupported platform: {OS.GetName()}");
			return null;
		}

		// Build path relative to project root
		string relativePath = $"engines/chess/{executableName}";
		string absolutePath = ProjectSettings.GlobalizePath($"res://{relativePath}");

		if (!File.Exists(absolutePath))
		{
			GD.PrintErr($"[StockfishEngine] Stockfish executable not found at: {absolutePath}");
			return null;
		}

		// Ensure executable permissions on Unix systems
		if (OS.GetName() != "Windows")
		{
			EnsureExecutablePermissions(absolutePath);
		}

		return absolutePath;
	}

	/// <summary>
	/// Ensures the Stockfish binary has executable permissions on Unix systems.
	/// </summary>
	private void EnsureExecutablePermissions(string path)
	{
		try
		{
			var chmod = new Process
			{
				StartInfo = new ProcessStartInfo
				{
					FileName = "chmod",
					Arguments = $"+x \"{path}\"",
					UseShellExecute = false,
					CreateNoWindow = true
				}
			};
			chmod.Start();
			chmod.WaitForExit();
		}
		catch (Exception e)
		{
			GD.PrintErr($"[StockfishEngine] Failed to set executable permissions: {e.Message}");
		}
	}

	// ============================================================================
	// PROCESS MANAGEMENT
	// ============================================================================

	/// <summary>
	/// Starts the Stockfish engine process.
	/// </summary>
	public bool StartEngine()
	{
		if (_stockfishProcess != null)
		{
			GD.PrintErr("[StockfishEngine] Engine is already running");
			return false;
		}

		if (string.IsNullOrEmpty(_enginePath))
		{
			EmitSignal(SignalName.ErrorOccurred, "Stockfish executable path not set");
			return false;
		}

		try
		{
			_stockfishProcess = new Process
			{
				StartInfo = new ProcessStartInfo
				{
					FileName = _enginePath,
					UseShellExecute = false,
					RedirectStandardInput = true,
					RedirectStandardOutput = true,
					RedirectStandardError = true,
					CreateNoWindow = true
				}
			};

			_stockfishProcess.Start();

			_stdin = _stockfishProcess.StandardInput;
			_stdout = _stockfishProcess.StandardOutput;
			_stderr = _stockfishProcess.StandardError;

			// Start listening to output on background thread
			Task.Run(() => ListenToOutput());
			Task.Run(() => ListenToErrors());

			GD.Print("[StockfishEngine] Engine process started successfully");
			return true;
		}
		catch (Exception e)
		{
			GD.PrintErr($"[StockfishEngine] Failed to start engine: {e.Message}");
			EmitSignal(SignalName.ErrorOccurred, $"Failed to start engine: {e.Message}");
			return false;
		}
	}

	/// <summary>
	/// Stops the Stockfish engine process gracefully.
	/// </summary>
	public void StopEngine()
	{
		if (_stockfishProcess == null)
		{
			return;
		}

		try
		{
			// Try graceful shutdown first
			SendCommand(UCIProtocol.CMD_QUIT);

			// Wait for process to exit (max 2 seconds)
			if (!_stockfishProcess.WaitForExit(2000))
			{
				// Force kill if it doesn't exit gracefully
				_stockfishProcess.Kill();
				GD.PrintErr("[StockfishEngine] Engine process was forcefully terminated");
			}
			else
			{
				GD.Print("[StockfishEngine] Engine stopped gracefully");
			}
		}
		catch (Exception e)
		{
			GD.PrintErr($"[StockfishEngine] Error stopping engine: {e.Message}");
		}
		finally
		{
			_stdin?.Close();
			_stdout?.Close();
			_stderr?.Close();
			_stockfishProcess?.Dispose();
			_stockfishProcess = null;
			_isInitialized = false;
			_isReady = false;
		}
	}

	// ============================================================================
	// PRIVATE UCI COMMUNICATION METHODS
	// ============================================================================

	/// <summary>
	/// Sends a command to the Stockfish engine via stdin.
	/// This is the core method for all UCI communication.
	/// </summary>
	private void SendCommand(string command)
	{
		if (_stockfishProcess == null || _stdin == null)
		{
			GD.PrintErr("[StockfishEngine] Cannot send command - engine not running");
			EmitSignal(SignalName.ErrorOccurred, "Engine not running");
			return;
		}

		try
		{
			GD.Print($"[StockfishEngine] >>> {command}");
			_stdin.WriteLine(command);
			_stdin.Flush();
		}
		catch (Exception e)
		{
			GD.PrintErr($"[StockfishEngine] Error sending command: {e.Message}");
			EmitSignal(SignalName.ErrorOccurred, $"Error sending command: {e.Message}");
		}
	}

	/// <summary>
	/// Listens to stdout from the Stockfish engine on a background thread.
	/// Parses responses and emits appropriate signals.
	/// </summary>
	private async Task ListenToOutput()
	{
		try
		{
			while (_stockfishProcess != null && !_stockfishProcess.HasExited)
			{
				string line = await _stdout.ReadLineAsync();
				if (line == null) break;
				
				if (_stockfishPrintOutput)
				{
					GD.Print($"[StockfishEngine] <<< {line}");
				}

				// Process the response (will be called on background thread)
				ProcessResponse(line);
			}
		}
		catch (Exception e)
		{
			GD.PrintErr($"[StockfishEngine] Error reading output: {e.Message}");
		}
	}

	/// <summary>
	/// Listens to stderr from the Stockfish engine on a background thread.
	/// </summary>
	private async Task ListenToErrors()
	{
		try
		{
			while (_stockfishProcess != null && !_stockfishProcess.HasExited)
			{
				string line = await _stderr.ReadLineAsync();
				if (line == null) break;

				GD.PrintErr($"[StockfishEngine] STDERR: {line}");
				CallDeferred(MethodName.EmitSignal, SignalName.ErrorOccurred, line);
			}
		}
		catch (Exception e)
		{
			GD.PrintErr($"[StockfishEngine] Error reading stderr: {e.Message}");
		}
	}

	/// <summary>
	/// Processes a response line from Stockfish.
	/// Use CallDeferred when emitting signals since this runs on a background thread.
	/// </summary>
	private void ProcessResponse(string line)
	{
		if (string.IsNullOrWhiteSpace(line))
		{
			return;
		}

		// UCI initialization complete
		if (line == UCIProtocol.RESP_UCI_OK)
		{
			_isInitialized = true;
			GD.Print("[StockfishEngine] Engine initialized (uciok received)");
			CallDeferred(MethodName.EmitSignal, SignalName.EngineReady);
		}
		// Engine ready for commands
		else if (line == UCIProtocol.RESP_READY_OK)
		{
			_isReady = true;
			GD.Print("[StockfishEngine] Engine ready (readyok received)");
		}
		// Best move calculated
		else if (line.StartsWith(UCIProtocol.RESP_BEST_MOVE))
		{
			string move = UCIProtocol.ParseBestMove(line);
			string ponder = UCIProtocol.ParsePonderMove(line);

			if (!string.IsNullOrEmpty(move))
			{
				// Emit traditional best move signal
				CallDeferred(MethodName.EmitSignal, SignalName.BestMoveCalculated, move, ponder ?? "");

				// If MultiPV is enabled, also emit candidate moves signal
				if (_multiPV >= 1 && _candidateMoves != null && _candidateMoves.Count > 0)
				{
					// Convert to Godot array sorted by multipv index
					var candidateArray = new Godot.Collections.Array();
					for (int i = 1; i <= _multiPV; i++)
					{
						if (_candidateMoves.ContainsKey(i))
						{
							candidateArray.Add(_candidateMoves[i]);
						}
					}
					CallDeferred(MethodName.EmitSignal, SignalName.CandidateMovesCalculated, candidateArray);
				}

				// Clear candidate moves for next calculation
				_candidateMoves = null;
			}
		}
		// Info output (search progress, evaluation, etc.)
		else if (line.StartsWith(UCIProtocol.RESP_INFO))
		{
			// Parse MultiPV info lines
			if (_multiPV > 1)
			{
				ParseMultiPVInfo(line);
			}

			if (_stockfishPrintOutput)
			{
				CallDeferred(MethodName.EmitSignal, SignalName.InfoReceived, line);
			}
		}
	}

	/// <summary>
	/// Parses an info line to extract MultiPV candidate move data.
	/// Example: "info depth 20 multipv 1 score cp 42 pv e2e4 e7e5"
	/// Example: "info depth 15 multipv 2 score mate 3 pv f3g5 h6g5"
	/// </summary>
	private void ParseMultiPVInfo(string line)
	{
		var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);

		int multiPvIndex = -1;
		int depth = -1;
		int scoreCP = 0;
		int scoreMate = 0;
		bool hasScore = false;
		string scoreType = "";
		string pvMove = null;

		// Parse the info line
		for (int i = 0; i < parts.Length; i++)
		{
			if (parts[i] == "multipv" && i + 1 < parts.Length)
			{
				int.TryParse(parts[i + 1], out multiPvIndex);
			}
			else if (parts[i] == "depth" && i + 1 < parts.Length)
			{
				int.TryParse(parts[i + 1], out depth);
			}
			else if (parts[i] == "score" && i + 2 < parts.Length)
			{
				if (parts[i + 1] == "cp")
				{
					int.TryParse(parts[i + 2], out scoreCP);
					scoreType = "cp";
					hasScore = true;
				}
				else if (parts[i + 1] == "mate")
				{
					int.TryParse(parts[i + 2], out scoreMate);
					scoreType = "mate";
					hasScore = true;
				}
			}
			else if (parts[i] == "pv" && i + 1 < parts.Length)
			{
				pvMove = parts[i + 1]; // First move of principal variation
				break; // Stop after finding pv
			}
		}

		// Only store if we have valid multiPV data
		if (multiPvIndex > 0 && pvMove != null && hasScore)
		{
			// Initialize candidate moves dictionary if needed
			if (_candidateMoves == null)
			{
				_candidateMoves = new System.Collections.Generic.Dictionary<int, Godot.Collections.Dictionary>();
			}

			// Create candidate move data with raw scores
			// The GDScript layer will apply mate_vision normalization
			var candidate = new Godot.Collections.Dictionary
			{
				{ "move", pvMove },
				{ "multipv", multiPvIndex },
				{ "depth", depth },
				{ "score_type", scoreType }
			};

			// Store raw score value
			if (scoreType == "mate")
			{
				candidate["score"] = scoreMate; // Raw mate distance (positive or negative)
			}
			else if (scoreType == "cp")
			{
				candidate["score"] = scoreCP; // Raw centipawn score
			}

			// Store or update candidate (later depths overwrite earlier ones)
			_candidateMoves[multiPvIndex] = candidate;
		}
	}

	/// <summary>
	/// Waits for the engine to be ready by sending "isready" and waiting for "readyok".
	/// This is a synchronization mechanism in UCI protocol.
	/// </summary>
	private async Task<bool> WaitForReady(int timeoutMs = 5000)
	{
		_isReady = false;
		SendCommand(UCIProtocol.CMD_IS_READY);

		int elapsed = 0;
		while (!_isReady && elapsed < timeoutMs)
		{
			await Task.Delay(50);
			elapsed += 50;
		}

		return _isReady;
	}

	// ============================================================================
	// PUBLIC API METHODS
	// ============================================================================

	/// <summary>
	/// Initializes the UCI engine (async version for C# callers).
	/// Starts the engine process and sends the "uci" command.
	/// Returns true if initialization succeeds within the timeout.
	/// </summary>
	public async Task<bool> InitializeAsync()
	{
		// Start engine if not already running
		if (_stockfishProcess == null)
		{
			if (!StartEngine())
			{
				return false;
			}
		}

		// Send UCI initialization command
		SendCommand(UCIProtocol.CMD_UCI);

		// Wait for uciok response (max 5 seconds)
		int timeout = 5000;
		int elapsed = 0;

		while (!_isInitialized && elapsed < timeout)
		{
			await Task.Delay(50);
			elapsed += 50;
		}

		if (_isInitialized)
		{
			GD.Print("[StockfishEngine] Engine initialized successfully");
			return true;
		}
		else
		{
			GD.PrintErr("[StockfishEngine] Engine initialization timed out");
			EmitSignal(SignalName.InitializationFailed, "Engine initialization timed out");
			return false;
		}
	}

	/// <summary>
	/// Initializes the UCI engine (GDScript-friendly version).
	/// Emits EngineReady signal on success, InitializationFailed on failure.
	/// </summary>
	public async void Initialize()
	{
		bool success = await InitializeAsync();
		if (!success)
		{
			EmitSignal(SignalName.InitializationFailed, "Initialization failed");
		}
		// EngineReady signal is already emitted by ProcessResponse when uciok is received
	}
	
	/// <summary>
	/// Controls if the stdout of the Stockfish process should be printed.
	/// Default true.
	/// </summary>
	public void SetStockfishPrintOutput(bool printOutput)
	{
		_stockfishPrintOutput = printOutput;
	}
	
	/// <summary>
	/// Sets default think time for calculating best moves.
	/// Has to be bigger than 1 or the setter is ignored.
	/// </summary>
	public void SetDefaultThinkTimeMs(int thinkTimeMs)
	{
		if (thinkTimeMs < 1)
		{
			return;
		}
		_defaultThinkTimeMs = thinkTimeMs;
	}

	/// <summary>
	/// Sets the chess position using FEN notation and optional move list.
	/// </summary>
	public void SetPosition(string fen, string[] moves)
	{
		SendCommand(UCIProtocol.BuildPositionFEN(fen, moves));
	}

	/// <summary>
	/// Requests the best move with optional time limit (milliseconds) and depth limit.
	/// Pass -1 to use defaults or omit a parameter.
	/// Result will be emitted via BestMoveCalculated signal.
	/// </summary>
	public void GetBestMove(int thinkTimeMs = -1, int depth = -1)
	{
		int finalThinkTime = thinkTimeMs >= 1 ? thinkTimeMs : _defaultThinkTimeMs;
		SendCommand(UCIProtocol.BuildGo(finalThinkTime, depth));
	}

	/// <summary>
	/// Requests evaluation of specific moves only using the searchmoves parameter.
	/// This forces Stockfish to ONLY analyze the provided moves, returning their scores.
	/// Useful for validating specific opening book moves.
	/// Result will be emitted via BestMoveCalculated and CandidateMovesCalculated signals.
	/// </summary>
	public void GetBestMoveWithSearchMoves(int thinkTimeMs = -1, int depth = -1, string[] searchMoves = null)
	{
		int finalThinkTime = thinkTimeMs >= 1 ? thinkTimeMs : _defaultThinkTimeMs;
		SendCommand(UCIProtocol.BuildGoWithSearchMoves(finalThinkTime, depth, searchMoves));
	}

	/// <summary>
	/// Sets the Stockfish skill level (0-20, where 20 is maximum strength).
	/// </summary>
	public void SetSkillLevel(int level)
	{
		// Clamp level to valid range
		level = Math.Clamp(level, 0, 20);
		SendCommand(UCIProtocol.BuildSetOption(UCIProtocol.OPT_SKILL_LEVEL, level.ToString()));
	}

	/// <summary>
	/// Sets MultiPV (number of candidate moves to analyze).
	/// When MultiPV > 1, Stockfish will return multiple candidate moves with evaluations.
	/// Results will be emitted via CandidateMovesCalculated signal.
	/// </summary>
	public void SetMultiPV(int count)
	{
		// Clamp to valid range (1-500, though typically 1-20 is reasonable)
		count = Math.Clamp(count, 1, 500);
		_multiPV = count;
		SendCommand(UCIProtocol.BuildSetOption(UCIProtocol.OPT_MULTI_PV, count.ToString()));
	}

	/// <summary>
	/// Starts a new game (resets engine state).
	/// </summary>
	public void NewGame()
	{
		SendCommand(UCIProtocol.CMD_UCI_NEW_GAME);
	}
}
