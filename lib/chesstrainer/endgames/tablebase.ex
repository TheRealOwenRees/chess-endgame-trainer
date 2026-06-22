defmodule Chesstrainer.Endgames.Tablebase do
  @moduledoc """
  All endgame tablebase related functions.
  """

  alias Chesstrainer.Endgames.Tablebase

  @type result :: :win | :draw | :loss | :unknown

  @type t :: %__MODULE__{
          category: result,
          checkmate: boolean(),
          dtc: integer() | nil,
          dtm: integer() | nil,
          dtw: integer() | nil,
          dtz: integer() | nil,
          insufficient_material: boolean(),
          moves: [Tablebase.Move.t()]
        }

  defstruct category: nil,
            checkmate: false,
            dtc: nil,
            dtm: nil,
            dtw: nil,
            dtz: nil,
            insufficient_material: false,
            moves: nil

  @spec new(String.t()) ::
          {:ok, t()}
          | {:cooldown, non_neg_integer()}
          | {:error, :invalid_endgame}
          | {:error, term()}
  def new(fen) do
    case Tablebase.Cache.get(fen) do
      {_fen, tablebase} ->
        {:cache, tablebase}

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
