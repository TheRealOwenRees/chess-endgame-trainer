defmodule Chesstrainer.Endgames.Tablebase.San do
  @moduledoc """
  Generates Standard Algebraic Notation for a UCI move in a position.

  The local Fathom backend returns moves as board squares, so this turns them
  into the SAN the trainer displays. Returns `nil` when the move cannot be
  parsed or is not legal in the position.
  """

  alias Chex.Game
  alias Chex.Piece

  @files ~w(a b c d e f g h)a
  @piece_letters %{king: "K", queen: "Q", rook: "R", bishop: "B", knight: "N"}

  @spec for_uci(String.t(), String.t()) :: String.t() | nil
  def for_uci(fen, uci) do
    with {:ok, game} <- game(fen),
         {:ok, from, to, promote} <- parse_uci(uci),
         {name, color, _start} <- Map.get(game.board, from),
         {:ok, next} <- Game.move(game, {from, to}, promote || :queen) do
      build(game, name, color, from, to, promote) <> suffix(next)
    else
      _ -> nil
    end
  end

  defp game(fen) do
    Game.new(fen)
  rescue
    _ -> {:error, :invalid_fen}
  end

  defp build(game, name, color, from, to, promote) do
    if name == :king and abs(file_index(from) - file_index(to)) == 2 do
      if file_index(to) > file_index(from), do: "O-O", else: "O-O-O"
    else
      normal(game, name, color, from, to, promote)
    end
  end

  defp normal(game, name, color, from, to, promote) do
    capture = capture?(game, color, from, to)
    capture_marker = if capture, do: "x", else: ""

    prefix =
      if name == :pawn do
        if capture, do: file(from), else: ""
      else
        Map.get(@piece_letters, name, "") <> disambiguation(game, name, color, from, to)
      end

    prefix <> capture_marker <> square_string(to) <> promotion_suffix(promote)
  end

  defp capture?(game, color, from, to) do
    case Map.get(game.board, to) do
      {_name, ^color, _start} -> false
      {_name, _other, _start} -> true
      nil -> piece_name(game, from) == :pawn and file_index(from) != file_index(to)
    end
  end

  # Adds a file/rank/both only when another same-type piece could also reach `to`.
  defp disambiguation(game, name, color, from, to) do
    others =
      game.board
      |> Enum.filter(fn {square, {pname, pcolor, _start}} ->
        square != from and pname == name and pcolor == color and
          to in Piece.possible_moves(game, square)
      end)
      |> Enum.map(fn {square, _piece} -> square end)

    cond do
      others == [] ->
        ""

      Enum.all?(others, &(file_index(&1) != file_index(from))) ->
        file(from)

      Enum.all?(others, &(rank(&1) != rank(from))) ->
        Integer.to_string(rank(from))

      true ->
        file(from) <> Integer.to_string(rank(from))
    end
  end

  defp suffix(next) do
    cond do
      Game.checkmate?(next) -> "#"
      Game.in_check?(next, next.active_color) -> "+"
      true -> ""
    end
  end

  defp promotion_suffix(nil), do: ""
  defp promotion_suffix(:queen), do: "=Q"
  defp promotion_suffix(:rook), do: "=R"
  defp promotion_suffix(:bishop), do: "=B"
  defp promotion_suffix(:knight), do: "=N"

  defp piece_name(game, square) do
    case Map.get(game.board, square) do
      {name, _color, _start} -> name
      nil -> nil
    end
  end

  defp parse_uci(uci) when is_binary(uci) do
    with <<ff, fr, tf, tr, promotion::binary>> <- uci,
         {:ok, from} <- parse_square(ff, fr),
         {:ok, to} <- parse_square(tf, tr),
         {:ok, promote} <- parse_promotion(promotion) do
      {:ok, from, to, promote}
    else
      _ -> :error
    end
  end

  defp parse_uci(_uci), do: :error

  defp parse_square(file, rank) when file in ?a..?h and rank in ?1..?8 do
    {:ok, {String.to_existing_atom(<<file>>), rank - ?0}}
  end

  defp parse_square(_file, _rank), do: :error

  defp parse_promotion(""), do: {:ok, nil}
  defp parse_promotion("q"), do: {:ok, :queen}
  defp parse_promotion("r"), do: {:ok, :rook}
  defp parse_promotion("b"), do: {:ok, :bishop}
  defp parse_promotion("n"), do: {:ok, :knight}
  defp parse_promotion(_promotion), do: :error

  defp file_index({file, _rank}), do: Enum.find_index(@files, &(&1 == file))
  defp file({file, _rank}), do: Atom.to_string(file)
  defp rank({_file, rank}), do: rank
  defp square_string({file, rank}), do: Atom.to_string(file) <> Integer.to_string(rank)
end
