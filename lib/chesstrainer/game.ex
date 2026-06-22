defmodule Chesstrainer.Game do
  @moduledoc """
  Game related functions
  """
  alias Chesstrainer.Endgames

  @type game_type :: :endgame
  @type square :: {atom(), pos_integer()}
  @type move :: {square, square}
  @type colors :: :white | :black
  @type game_state :: :continue | :loss | :draw
  @type result :: :win | :draw | :loss

  @type t :: %__MODULE__{
          player_color: colors,
          board: map(),
          active_color: colors,
          castling: list(),
          en_passant: term() | nil,
          moves: list(),
          halfmove_clock: non_neg_integer(),
          fullmove_clock: non_neg_integer(),
          captures: list(),
          check: term() | nil,
          result: result,
          pgn: String.t() | nil,
          orientation: colors,
          move_from_square: square,
          move_to_square: square,
          game_type: game_type,
          fen: String.t(),
          tablebase: term(),
          game_state: game_state
        }

  defstruct board: %{},
            player_color: :white,
            active_color: :white,
            castling: [],
            en_passant: nil,
            moves: [],
            halfmove_clock: 0,
            fullmove_clock: 0,
            captures: [],
            check: nil,
            result: nil,
            pgn: nil,
            orientation: :white,
            move_from_square: nil,
            move_to_square: nil,
            game_type: nil,
            fen: nil,
            tablebase: nil,
            game_state: :continue

  @doc """
  Builds a `%ChessTrainer.Game{}` from a FEN string.

  On success, returns `{:ok, game}` with the parsed board state.

  If the FEN string is invalid, `Chex.Parser.FEN.parse/1` raises a
  `MatchError`. This function rescues that exception and returns
  `{:error, :invalid_fen, game}`, where `game` is a fallback position
  containing only kings.

  This is a bad implementation in the Chex libary and should be fixed at our fork:
  https://github.com/therealowenrees/chex

  We should return something like{:ok, game} | {:error | :invalid_fen}

  ## Examples

      iex> ChessTrainer.Game.game_from_fen("valid fen", :endgame)
      {:ok, %ChessTrainer.Game{}}

      iex> ChessTrainer.Game.game_from_fen("invalid fen", :endgame)
      {:error, :invalid_fen, %ChessTrainer.Game{}}

  """
  @dialyzer {:nowarn_function, game_from_fen: 2}
  @spec game_from_fen(String.t(), game_type()) :: {:ok, t()} | {:error, :invalid_fen, t()}
  def game_from_fen(fen, game_type) do
    try do
      {:ok, %Chex.Game{} = chex_game} = Chex.Parser.FEN.parse(fen)

      game = %__MODULE__{
        board: chex_game.board,
        player_color: chex_game.active_color,
        active_color: chex_game.active_color,
        castling: chex_game.castling,
        en_passant: chex_game.en_passant,
        moves: chex_game.moves,
        halfmove_clock: chex_game.halfmove_clock,
        fullmove_clock: chex_game.fullmove_clock,
        captures: chex_game.captures,
        check: chex_game.check,
        result: chex_game.result,
        pgn: chex_game.pgn,
        orientation: chex_game.active_color,
        move_from_square: nil,
        move_to_square: nil,
        game_type: game_type,
        fen: fen,
        game_state: :continue,
        tablebase:
          if game_type === :endgame do
            Endgames.Tablebase.new(fen)
          else
            nil
          end
      }

      {:ok, game}
    rescue
      # if a MatchError error is raised, then return a game with only kings on the board
      MatchError ->
        game = %__MODULE__{
          board: %{
            {:e, 1} => {:king, :white, {:e, 1}},
            {:e, 8} => {:king, :black, {:e, 8}}
          },
          player_color: :white,
          active_color: :white,
          castling: [],
          en_passant: nil,
          moves: [],
          halfmove_clock: 0,
          fullmove_clock: 0,
          captures: nil,
          check: nil,
          result: :draw,
          pgn: nil,
          orientation: :white,
          move_from_square: nil,
          move_to_square: nil,
          game_type: :endgame,
          fen: "4k3/8/8/8/8/8/8/4K3 w - - 0 1",
          game_state: :draw,
          tablebase: nil
        }

        {:error, :invalid_fen, game}
    end
  end
end
