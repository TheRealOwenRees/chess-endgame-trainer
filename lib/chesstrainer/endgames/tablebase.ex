defmodule Chesstrainer.Endgames.Tablebase do
  @moduledoc """
  All endgame tablebase related functions.

  The cached value carries only what the trainer reads: `category`,
  `checkmate`, and `moves`. Cursed-win/blessed-loss are normalised to `:draw` at
  parse time, and distance fields (`dtm`/`dtc`/`dtw`) are not kept because the
  local Syzygy backend cannot produce them.
  """

  alias Chesstrainer.Endgames.Tablebase

  @type result :: :win | :draw | :loss | :unknown

  @type t :: %__MODULE__{
          category: result,
          checkmate: boolean(),
          moves: [Tablebase.Move.t()]
        }

  defstruct category: nil,
            checkmate: false,
            moves: nil

  @doc """
  Normalises a Lichess tablebase category string into a trainer result.

  `cursed-win` and `blessed-loss` are wins/losses only when the 50-move rule is
  ignored, so they are draws in play. Unrecognised values become `:unknown`
  rather than minting arbitrary atoms.
  """
  @spec normalize_category(term()) :: result()
  def normalize_category(category) when category in ["win", "syzygy-win", "maybe-win"], do: :win

  def normalize_category(category) when category in ["draw", "cursed-win", "blessed-loss"],
    do: :draw

  def normalize_category(category) when category in ["loss", "syzygy-loss", "maybe-loss"],
    do: :loss

  def normalize_category(_category), do: :unknown

  @spec new(String.t()) ::
          {:ok, t()}
          | {:cooldown, non_neg_integer()}
          | {:error, :invalid_endgame}
          | {:error, term()}
  def new(fen) do
    case Tablebase.Cache.get(fen) do
      {:ok, tablebase} ->
        {:ok, tablebase}

      _ ->
        case Tablebase.Parser.from_fen(fen) do
          {:error, reason} ->
            {:error, reason}

          {:cooldown, remaining_ms} ->
            {:cooldown, remaining_ms}

          {:ok, tablebase} when tablebase.category == :unknown ->
            {:error, :invalid_endgame}

          {:ok, tablebase} ->
            Tablebase.Cache.put(fen, tablebase)
            {:ok, tablebase}
        end
    end
  end
end
