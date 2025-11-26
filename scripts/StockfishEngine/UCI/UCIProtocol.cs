using Godot;
using System;

namespace chess3d.StockfishEngine.UCI
{
	/// <summary>
	/// UCI (Universal Chess Interface) protocol constants and utilities.
	/// https://www.chessprogramming.org/UCI
	/// </summary>
	public static class UCIProtocol
	{
		// === Commands to Engine ===
		public const string CMD_UCI = "uci";
		public const string CMD_IS_READY = "isready";
		public const string CMD_UCI_NEW_GAME = "ucinewgame";
		public const string CMD_POSITION = "position";
		public const string CMD_POSITION_STARTPOS = "position startpos";
		public const string CMD_POSITION_FEN = "position fen";
		public const string CMD_GO = "go";
		public const string CMD_STOP = "stop";
		public const string CMD_QUIT = "quit";
		public const string CMD_SET_OPTION = "setoption";

		// === Responses from Engine ===
		public const string RESP_UCI_OK = "uciok";
		public const string RESP_READY_OK = "readyok";
		public const string RESP_BEST_MOVE = "bestmove";
		public const string RESP_INFO = "info";
		public const string RESP_OPTION = "option";

		// === Common UCI Options ===
		public const string OPT_SKILL_LEVEL = "Skill Level";
		public const string OPT_THREADS = "Threads";
		public const string OPT_HASH = "Hash";
		public const string OPT_PONDER = "Ponder";
		public const string OPT_MULTI_PV = "MultiPV";

		// === Go Command Parameters ===
		public const string GO_INFINITE = "infinite";
		public const string GO_MOVE_TIME = "movetime";
		public const string GO_DEPTH = "depth";
		public const string GO_NODES = "nodes";
		public const string GO_WTIME = "wtime";
		public const string GO_BTIME = "btime";
		public const string GO_WINC = "winc";
		public const string GO_BINC = "binc";

		/// <summary>
		/// Builds a "position" command with FEN notation.
		/// </summary>
		public static string BuildPositionFEN(string fen, string[] moves = null)
		{
			var command = $"{CMD_POSITION_FEN} {fen}";
			if (moves != null && moves.Length > 0)
			{
				command += " moves " + string.Join(" ", moves);
			}
			return command;
		}

		/// <summary>
		/// Builds a "position startpos" command with optional move list.
		/// </summary>
		public static string BuildPositionStartPos(string[] moves = null)
		{
			var command = CMD_POSITION_STARTPOS;
			if (moves != null && moves.Length > 0)
			{
				command += " moves " + string.Join(" ", moves);
			}
			return command;
		}

		/// <summary>
		/// Builds a "go" command with optional movetime (milliseconds) and depth limits.
		/// Pass -1 to omit a parameter. Stockfish will stop when any specified limit is reached.
		/// </summary>
		public static string BuildGo(int moveTimeMs = -1, int depth = -1)
		{
			var command = CMD_GO;

			if (moveTimeMs > 0)
			{
				command += $" {GO_MOVE_TIME} {moveTimeMs}";
			}

			if (depth > 0)
			{
				command += $" {GO_DEPTH} {depth}";
			}

			// If no parameters specified, default to infinite search
			if (moveTimeMs <= 0 && depth <= 0)
			{
				command += $" {GO_INFINITE}";
			}

			return command;
		}

		/// <summary>
		/// Builds a "setoption" command.
		/// </summary>
		public static string BuildSetOption(string optionName, string value)
		{
			return $"{CMD_SET_OPTION} name {optionName} value {value}";
		}

		/// <summary>
		/// Parses a "bestmove" response to extract the move.
		/// Example: "bestmove e2e4 ponder e7e5" -> returns "e2e4"
		/// </summary>
		public static string ParseBestMove(string response)
		{
			if (string.IsNullOrEmpty(response) || !response.StartsWith(RESP_BEST_MOVE))
			{
				return null;
			}

			var parts = response.Split(' ', StringSplitOptions.RemoveEmptyEntries);
			return parts.Length > 1 ? parts[1] : null;
		}

		/// <summary>
		/// Parses a "bestmove" response to extract the ponder move (if present).
		/// Example: "bestmove e2e4 ponder e7e5" -> returns "e7e5"
		/// </summary>
		public static string ParsePonderMove(string response)
		{
			if (string.IsNullOrEmpty(response) || !response.StartsWith(RESP_BEST_MOVE))
			{
				return null;
			}

			var parts = response.Split(' ', StringSplitOptions.RemoveEmptyEntries);
			if (parts.Length > 3 && parts[2] == "ponder")
			{
				return parts[3];
			}
			return null;
		}
	}
}
