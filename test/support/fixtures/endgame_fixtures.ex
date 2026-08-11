defmodule Chesstrainer.EndgamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chesstrainer.Endgames` context.
  """

  @doc """
  Generate a unique endgame FEN.

  Endgames have a unique constraint on :fen, so tests need
  distinct FENs when inserting more than one. Each call
  shifts the white king's file to avoid FEN collisions.
  """
  def unique_endgame_fen do
    # White king on rank 1 in columns b..g, leaving 1-6 empty squares
    # before and 6-1 after. Both before_king and after_king are valid
    # single digits (1-8), and the rank sums to 8.
    offset = System.unique_integer([:positive]) |> rem(6)
    before_king = offset + 1
    after_king = 7 - before_king
    "4k3/8/8/8/8/8/8/#{before_king}K#{after_king} w - - 0 1"
  end

  @doc """
  Generate an endgame.

  A simple K v K position with a unique FEN, color,
  key, rating, and result.
  """
  def endgame_fixture(attrs \\ %{}) do
    {:ok, endgame} =
      attrs
      |> Enum.into(%{
        fen: unique_endgame_fen(),
        key: "KQ v K",
        color: :white,
        result: :win,
        rating: 1500
      })
      |> Chesstrainer.Endgames.create_endgame()

    endgame
  end
end
