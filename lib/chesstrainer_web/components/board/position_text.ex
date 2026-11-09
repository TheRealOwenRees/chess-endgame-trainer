defmodule ChesstrainerWeb.Board.PositionText do
  @moduledoc """
  Plain-language descriptions of a chess position for assistive technology.

  A chessground board is a picture to a screen reader, so the play surface and
  the static boards use this text as their accessible name or description.
  """

  alias Chesstrainer.FEN

  @files ~w(a b c d e f g h)

  @names %{
    "k" => "king",
    "q" => "queen",
    "r" => "rook",
    "b" => "bishop",
    "n" => "knight",
    "p" => "pawn"
  }

  @doc """
  Describes whose turn it is and where every piece stands.

  Returns a generic description when the FEN cannot be read.

  ## Examples

      iex> ChesstrainerWeb.Board.PositionText.summary("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      "White to move. White: king on d3, rook on f3. Black: king on d6."
  """
  @spec summary(String.t() | nil) :: String.t()
  def summary(fen) when is_binary(fen) do
    case FEN.board(fen) do
      nil ->
        "Chess position."

      rows ->
        ["#{turn(fen)}." | piece_groups(rows)]
        |> Enum.join(" ")
    end
  end

  def summary(_fen), do: "Chess position."

  defp turn(fen) do
    case FEN.color_from_fen(fen) do
      :white -> "White to move"
      :black -> "Black to move"
      _ -> "Side to move unknown"
    end
  end

  defp piece_groups(rows) do
    ["White", "Black"]
    |> Enum.map(fn label -> group(label, rows) end)
    |> Enum.reject(&is_nil/1)
  end

  defp group(label, rows) do
    colour = if label == "White", do: :white, else: :black

    case pieces(rows, colour) do
      [] -> nil
      pieces -> "#{label}: #{Enum.join(pieces, ", ")}."
    end
  end

  defp pieces(rows, colour) do
    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, rank_index} ->
      row
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {nil, _file_index} ->
          []

        {piece, file_index} ->
          if piece_colour(piece) == colour do
            square = "#{Enum.at(@files, file_index)}#{8 - rank_index}"
            ["#{Map.fetch!(@names, String.downcase(piece))} on #{square}"]
          else
            []
          end
      end)
    end)
  end

  defp piece_colour(piece) do
    if piece == String.upcase(piece), do: :white, else: :black
  end
end
