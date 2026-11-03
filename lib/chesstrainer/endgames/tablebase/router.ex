defmodule Chesstrainer.Endgames.Tablebase.Router do
  @moduledoc """
  Chooses a tablebase backend by piece count.

  Positions with five or fewer pieces go to the local slot; six or seven go to
  the remote slot. The local slot currently points at Lichess until the local
  Syzygy backend lands, so this ships without changing today's behaviour.

  Positions with eight or more pieces are beyond every tablebase and are
  rejected without a network call.
  """

  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Backend.Lichess
  alias Chesstrainer.FEN

  @max_local_pieces 5
  @max_pieces 7

  # The local Syzygy backend will replace Lichess here once it exists.
  @local_backend Lichess
  @remote_backend Lichess

  @spec backend(String.t()) :: {:ok, module()} | {:error, :not_covered | :invalid_endgame}
  def backend(fen) do
    case FEN.piece_count(fen) do
      count when is_integer(count) and count <= @max_local_pieces -> {:ok, @local_backend}
      count when is_integer(count) and count <= @max_pieces -> {:ok, @remote_backend}
      count when is_integer(count) -> {:error, :not_covered}
      _ -> {:error, :invalid_endgame}
    end
  end

  @spec probe(String.t()) ::
          {:ok, Tablebase.t()} | {:cooldown, non_neg_integer()} | {:error, term()}
  def probe(fen) do
    case backend(fen) do
      {:ok, backend} -> backend.probe(fen)
      {:error, reason} -> {:error, reason}
    end
  end
end
