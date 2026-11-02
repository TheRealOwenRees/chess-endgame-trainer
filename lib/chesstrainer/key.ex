defmodule Chesstrainer.Key do
  @moduledoc """
  Derives an endgame's canonical material Key from its FEN.

  The Key is a color-agnostic material signature: each side's pieces, stronger
  side first, for example `"KQ v KR"`. It ignores piece placement and bishop
  square colour. Within a side the pieces are written `K`, then `Q`, `R`, `B`,
  `N`, `P`; the two sides are ordered by material value
  (`Q=9, R=5, B=3, N=3, P=1`, kings ignored).
  """

  @piece_order [{"q", "Q"}, {"r", "R"}, {"b", "B"}, {"n", "N"}, {"p", "P"}]
  @values %{"q" => 9, "r" => 5, "b" => 3, "n" => 3, "p" => 1}
  @pieces ~w(p n b r q k P N B R Q K)
  @digits ~w(1 2 3 4 5 6 7 8)

  @doc """
  Returns the canonical material Key for a FEN.

  ## Examples

      iex> Chesstrainer.Key.from_fen("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      {:ok, "KR v K"}

      iex> Chesstrainer.Key.from_fen("6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1")
      {:ok, "KPPP v KPP"}

      iex> Chesstrainer.Key.from_fen("not a fen")
      {:error, :invalid_fen}
  """
  @spec from_fen(String.t() | nil) :: {:ok, String.t()} | {:error, :invalid_fen}
  def from_fen(fen) when is_binary(fen) do
    with [board | _] <- String.split(fen),
         {:ok, white, black} <- parse_board(board) do
      {:ok, join_sides(white, black)}
    else
      _ -> {:error, :invalid_fen}
    end
  end

  def from_fen(_fen), do: {:error, :invalid_fen}

  defp parse_board(board) do
    ranks = String.split(board, "/")

    result =
      if length(ranks) == 8 do
        Enum.reduce_while(
          ranks,
          {:ok, %{"w" => new_counts(), "b" => new_counts()}},
          fn rank, {:ok, acc} ->
            case add_rank(rank, acc) do
              {:ok, acc} -> {:cont, {:ok, acc}}
              :error -> {:halt, :error}
            end
          end
        )
      else
        :error
      end

    case result do
      {:ok, %{"w" => white, "b" => black}} -> {:ok, white, black}
      :error -> :error
    end
  end

  defp new_counts, do: Map.new(~w(k q r b n p), &{&1, 0})

  defp add_rank(rank, acc) do
    rank
    |> String.graphemes()
    |> Enum.reduce_while({0, acc}, fn char, {squares, acc} ->
      cond do
        char in @digits ->
          {:cont, {squares + String.to_integer(char), acc}}

        char in @pieces ->
          side = if char == String.downcase(char), do: "b", else: "w"
          piece = String.downcase(char)

          counts =
            acc
            |> Map.fetch!(side)
            |> Map.update!(piece, &(&1 + 1))

          {:cont, {squares + 1, Map.put(acc, side, counts)}}

        true ->
          {:halt, :error}
      end
    end)
    |> case do
      {8, acc} -> {:ok, acc}
      _ -> :error
    end
  end

  defp join_sides(white, black) do
    {first, second} = order_sides(white, black)
    "#{side_string(first)} v #{side_string(second)}"
  end

  defp side_string(counts) do
    "K" <>
      Enum.map_join(@piece_order, fn {lower, upper} ->
        String.duplicate(upper, counts[lower])
      end)
  end

  defp order_sides(white, black) do
    if rank(white) >= rank(black), do: {white, black}, else: {black, white}
  end

  defp rank(counts) do
    {value(counts), counts["q"], counts["r"], counts["b"], counts["n"], counts["p"]}
  end

  defp value(counts) do
    Enum.reduce(@values, 0, fn {piece, weight}, total ->
      total + counts[piece] * weight
    end)
  end
end
