defmodule Chesstrainer.EndgamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chesstrainer.Endgames` context.
  """

  @doc """
  Generate a unique endgame FEN.

  Endgames have a unique constraint on :fen, so tests need distinct FENs when
  inserting more than one. The white king moves across 56 board squares and the
  fullmove number is always unique, so repeated calls cannot collide.
  """
  def unique_endgame_fen do
    n = System.unique_integer([:positive, :monotonic])
    rank = rem(div(n, 8), 7) + 1
    file = rem(n, 8)
    # Avoid placing the white king directly next to the black king on e8.
    file = if rank == 7 and file == 4, do: 0, else: file

    white_king_row = row_with_king(file)

    board =
      8..1//-1
      |> Enum.map(fn
        8 -> "4k3"
        ^rank -> white_king_row
        _ -> "8"
      end)
      |> Enum.join("/")

    "#{board} w - - 0 #{n}"
  end

  defp row_with_king(file) do
    before_count = file
    after_count = 7 - file

    before_part = if before_count > 0, do: Integer.to_string(before_count), else: ""
    after_part = if after_count > 0, do: Integer.to_string(after_count), else: ""

    before_part <> "K" <> after_part
  end

  @doc """
  Generate an endgame.

  A simple K v K position with a unique FEN, color, rating, and result.
  """
  def endgame_fixture(attrs \\ %{}) do
    {:ok, endgame} =
      attrs
      |> Enum.into(%{
        fen: unique_endgame_fen(),
        color: :white,
        result: :win,
        rating: 1500
      })
      |> Chesstrainer.Endgames.create_endgame()

    endgame
  end
end
