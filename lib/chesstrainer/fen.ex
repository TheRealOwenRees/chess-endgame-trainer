defmodule Chesstrainer.FEN do
  @board_pieces ~w(p n b r q k P N B R Q K)

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

  @doc """
  Returns the position key for a FEN: the board, side to move, castling and
  en-passant fields, with the halfmove and fullmove clocks dropped.

  A tablebase answer depends only on the position, so two FENs that differ only
  in their clocks resolve to the same position key and share a cache entry.

  ## Examples

      iex> Chesstrainer.FEN.position_key("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      "8/8/3k4/8/8/3K1R2/8/8 w - -"

      iex> Chesstrainer.FEN.position_key("8/8/3k4/8/8/3K1R2/8/8 w - - 37 99")
      "8/8/3k4/8/8/3K1R2/8/8 w - -"
  """
  @spec position_key(String.t()) :: String.t()
  def position_key(fen) when is_binary(fen) do
    case String.split(fen) do
      [board, active, castling, en_passant | _] ->
        Enum.join([board, active, castling, en_passant], " ")

      _ ->
        String.trim(fen)
    end
  end

  @doc """
  Counts the pieces on the board, or returns `nil` if the board field is not a
  well-formed FEN board.

  Kings count as pieces; empty-square digits are ignored. This is the number
  tablebases are sized by, so a position with more than seven pieces is beyond
  every tablebase.

  ## Examples

      iex> Chesstrainer.FEN.piece_count("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      3

      iex> Chesstrainer.FEN.piece_count("not a fen")
      nil
  """
  @spec piece_count(String.t() | nil) :: non_neg_integer() | nil
  def piece_count(fen) when is_binary(fen) do
    case String.split(fen, " ") do
      [board | _] -> board_piece_count(board)
      _ -> nil
    end
  end

  def piece_count(_fen), do: nil

  @doc """
  Returns the board field of a FEN as eight ranks, each a list of eight squares,
  where each square is a piece letter or `nil`.

  Returns `nil` when the board field is not a well-formed FEN board. Only the
  board field is read; the active colour and clocks are ignored.

  ## Examples

      iex> Chesstrainer.FEN.board("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1") |> Enum.at(2)
      [nil, nil, nil, "k", nil, nil, nil, nil]

      iex> Chesstrainer.FEN.board("not a fen")
      nil
  """
  @spec board(String.t() | nil) :: [[String.t() | nil]] | nil
  def board(fen) when is_binary(fen) do
    case String.split(fen, " ") do
      [board | _] -> parse_board(board)
      _ -> nil
    end
  end

  def board(_fen), do: nil

  defp parse_board(board) do
    case String.split(board, "/") do
      ranks when length(ranks) == 8 ->
        squares = Enum.map(ranks, &parse_rank/1)
        if Enum.all?(squares, &is_list/1), do: squares, else: nil

      _ ->
        nil
    end
  end

  defp parse_rank(rank) do
    rank
    |> String.graphemes()
    |> Enum.reduce_while([], fn
      <<c>>, acc when c in ?1..?8 -> {:cont, List.duplicate(nil, c - ?0) ++ acc}
      piece, acc when piece in @board_pieces -> {:cont, [piece | acc]}
      _other, _acc -> {:halt, nil}
    end)
    |> case do
      squares when is_list(squares) and length(squares) == 8 -> Enum.reverse(squares)
      _ -> nil
    end
  end

  defp board_piece_count(board) do
    board
    |> String.graphemes()
    |> Enum.reduce_while(0, fn
      "/", acc ->
        {:cont, acc}

      <<c>>, acc when c in ?1..?8 ->
        {:cont, acc}

      piece, acc when piece in ~w(p n b r q k P N B R Q K) ->
        {:cont, acc + 1}

      _other, _acc ->
        {:halt, nil}
    end)
  end

  defp color_initial_to_color_atom("b"), do: :black
  defp color_initial_to_color_atom("w"), do: :white
  defp color_initial_to_color_atom(_), do: nil
end
