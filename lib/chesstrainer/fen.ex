defmodule Chesstrainer.FEN do
  @spec color_from_fen(String.t()) :: :white | :black | nil
  def color_from_fen(fen) do
    fen
    |> String.split(" ")
    |> Enum.at(1)
    |> color_initial_to_color_atom()
  end

  defp color_initial_to_color_atom("b"), do: :black
  defp color_initial_to_color_atom("w"), do: :white
  defp color_initial_to_color_atom(_), do: nil
end
