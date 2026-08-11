defmodule Chesstrainer.FEN do
  @spec color_from_fen(String.t()) :: :white | :black | nil
  def color_from_fen(fen) do
    fen
    |> String.split(" ")
    |> Enum.at(1)
    |> color_initial_to_color_atom()
  end

  @doc """
  Normalizes a FEN string for storage.

  Trims surrounding whitespace and rewrites a fullmove number of `"0"` to
  `"1"`. The fullmove rewrite is a chess.js-compatibility fix — chess.js
  rejects fullmove `0` as invalid even though many board editors default
  to it. Other FEN fields are left untouched; structural errors are
  surfaced by the Endgame changeset, not silently masked here.

  ## Examples

      iex> Chesstrainer.FEN.normalize("  8/8/3k4/8/8/3K1R2/8/8 w - - 0 0\\n  ")
      "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"

      iex> Chesstrainer.FEN.normalize("8/8/3k4/8/8/3K1R2/8/8 w - - 0 5")
      "8/8/3k4/8/8/3K1R2/8/8 w - - 0 5"

      iex> Chesstrainer.FEN.normalize("not a fen")
      "not a fen"
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(fen) when is_binary(fen) do
    trimmed = String.trim(fen)

    case String.split(trimmed, " ") do
      [board, active, castling, en_passant, halfmove, "0"] ->
        Enum.join([board, active, castling, en_passant, halfmove, "1"], " ")

      _ ->
        trimmed
    end
  end

  defp color_initial_to_color_atom("b"), do: :black
  defp color_initial_to_color_atom("w"), do: :white
  defp color_initial_to_color_atom(_), do: nil
end
