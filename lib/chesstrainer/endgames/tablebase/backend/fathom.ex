defmodule Chesstrainer.Endgames.Tablebase.Backend.Fathom do
  @moduledoc """
  Local Syzygy backend powered by the Fathom NIF.

  Handles positions with up to five pieces. Falls back to the remote backend
  (Lichess by default) when the tablebases are not configured, the probe fails,
  or Fathom cannot answer the position, so play never blocks.

  The backend is overridable for tests via
  `config :chesstrainer, :tablebase_fallback, Module`.
  """

  @behaviour Chesstrainer.Endgames.Tablebase.Backend

  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Backend.Lichess
  alias Chesstrainer.Endgames.Tablebase.Fathom, as: Nif
  alias Chesstrainer.Endgames.Tablebase.Move
  alias Chesstrainer.Endgames.Tablebase.San

  @impl true
  def probe(fen) do
    with {:ok, path} <- tablebase_path(),
         {:ok, _largest} <- Nif.init(path),
         {:ok, {root, moves}} <- Nif.probe(fen) do
      case root do
        :failed -> fallback(fen)
        _ -> {:ok, to_tablebase(fen, root, moves)}
      end
    else
      _ -> fallback(fen)
    end
  end

  defp tablebase_path do
    case Application.get_env(:chesstrainer, :tablebase_path) do
      path when is_binary(path) and path != "" -> {:ok, path}
      _ -> :error
    end
  end

  defp fallback(fen) do
    (Application.get_env(:chesstrainer, :tablebase_fallback) || Lichess).probe(fen)
  end

  defp to_tablebase(_fen, :checkmate, _moves) do
    %Tablebase{category: :loss, checkmate: true, moves: []}
  end

  defp to_tablebase(_fen, :stalemate, _moves) do
    %Tablebase{category: :draw, checkmate: false, moves: []}
  end

  defp to_tablebase(fen, {wdl, _from, _to, _promotes, _ep, _dtz}, moves) do
    %Tablebase{
      category: Tablebase.normalize_wdl(wdl),
      checkmate: false,
      moves: fen |> map_moves(moves) |> sort_moves()
    }
  end

  defp map_moves(fen, moves) do
    Enum.map(moves, fn {wdl, from, to, promotes, _ep, dtz} ->
      uci = uci(from, to, promotes)

      %Move{
        category: move_category(wdl),
        dtz: dtz,
        uci: uci,
        san: San.for_uci(fen, uci)
      }
    end)
  end

  # Best move first: highest mover outcome, then sharpest DTZ (lowest for a
  # mover who is winning, highest for a mover who is losing).
  defp sort_moves(moves) do
    Enum.sort_by(moves, fn %Move{category: category, dtz: dtz} ->
      rank = mover_rank(Tablebase.flip(category))
      {-rank, if(rank == 0, do: -(dtz || 0), else: dtz || 0)}
    end)
  end

  # Fathom reports a move's WDL from the mover's perspective; the trainer stores
  # the resulting position's category (the opponent's perspective).
  defp move_category(wdl), do: Tablebase.flip(Tablebase.normalize_wdl(wdl))

  defp mover_rank(:win), do: 2
  defp mover_rank(:draw), do: 1
  defp mover_rank(:loss), do: 0
  defp mover_rank(_), do: -1

  defp uci(from, to, promotes) do
    square(from) <> square(to) <> promotion_suffix(promotes)
  end

  defp square(square) do
    file = rem(square, 8)
    rank = div(square, 8)
    <<?a + file>> <> Integer.to_string(rank + 1)
  end

  defp promotion_suffix(1), do: "q"
  defp promotion_suffix(2), do: "r"
  defp promotion_suffix(3), do: "b"
  defp promotion_suffix(4), do: "n"
  defp promotion_suffix(_), do: ""
end
