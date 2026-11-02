defmodule Chesstrainer.Endgames.Endgame do
  @moduledoc """
  A singular endgame entry
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Chesstrainer.Key

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "endgames" do
    field :fen, :string
    field :color, Ecto.Enum, values: [:white, :black]
    field :key, :string
    field :message, :string
    field :notes, :string
    field :result, Ecto.Enum, values: [:win, :loss, :draw]
    field :rating, :integer
    field :rating_deviation, :integer
    field :times_attempted, :integer
    field :times_solved, :integer

    many_to_many :themes, Chesstrainer.Themes.Theme,
      join_through: "endgames_themes",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(endgame, attrs) do
    endgame
    |> cast(normalize_attrs(attrs), [:fen, :message, :notes, :result, :rating, :color])
    |> validate_required([:fen, :color], message: "Invalid FEN")
    |> validate_required([:result, :rating])
    |> validate_change(:fen, fn :fen, fen ->
      case fen_issues(fen) do
        [] -> []
        issues -> [fen: "is not a valid FEN: #{Enum.join(issues, "; ")}"]
      end
    end)
    |> unique_constraint(:fen, message: "FEN already exists")
    |> put_key()
  end

  defp put_key(changeset) do
    case Key.from_fen(get_field(changeset, :fen)) do
      {:ok, key} -> put_change(changeset, :key, key)
      {:error, :invalid_fen} -> changeset
    end
  end

  defp normalize_attrs(%{"fen" => fen} = attrs) when is_binary(fen),
    do: Map.put(attrs, "fen", Chesstrainer.FEN.normalize(fen))

  defp normalize_attrs(%{fen: fen} = attrs) when is_binary(fen),
    do: Map.put(attrs, :fen, Chesstrainer.FEN.normalize(fen))

  defp normalize_attrs(attrs), do: attrs

  # Strict structural validation. Mirrors chess.js rules so the FEN survives
  # both the server-side parser (Chex, permissive) and the client-side parser
  # (chess.js, strict).
  defp fen_issues(fen) do
    case String.split(fen, " ") do
      [board, active, _castling, _en_passant, halfmove, fullmove] ->
        issues = []

        issues =
          if valid_board?(board),
            do: issues,
            else: ["board must be 8 ranks of 8 squares each"]

        issues =
          if active in ["w", "b"],
            do: issues,
            else: ["active color must be 'w' or 'b'"]

        issues =
          if non_negative_integer?(halfmove),
            do: issues,
            else: ["halfmove clock must be a non-negative integer"]

        issues =
          if positive_integer?(fullmove),
            do: issues,
            else: ["fullmove number must be a positive integer"]

        issues

      _ ->
        ["must have 6 space-separated fields"]
    end
  end

  defp valid_board?(board) do
    ranks = String.split(board, "/")

    length(ranks) == 8 and Enum.all?(ranks, &valid_rank?/1)
  end

  defp valid_rank?(rank) do
    squares =
      rank
      |> String.graphemes()
      |> Enum.reduce(0, fn
        g, acc when byte_size(g) == 1 ->
          c = :binary.first(g)

          if c >= ?1 and c <= ?8 do
            acc + (c - ?0)
          else
            acc + 1
          end
      end)

    squares == 8
  end

  defp non_negative_integer?(str), do: integer_string?(str) and String.to_integer(str) >= 0
  defp positive_integer?(str), do: integer_string?(str) and String.to_integer(str) >= 1

  defp integer_string?(str) do
    Regex.match?(~r/^[0-9]+$/, str)
  end
end
