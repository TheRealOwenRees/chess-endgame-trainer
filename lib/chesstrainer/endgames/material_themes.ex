defmodule Chesstrainer.Endgames.MaterialThemes do
  @moduledoc """
  Derives each endgame's material family from its canonical Key.

  Every endgame belongs to exactly one family, so the themes behave as a
  partition: selecting several in a filter produces their union, never an
  ambiguous intersection. A lone king against heavy or pawn material is split
  out because those positions teach a specific technique — basic mate or
  promotion — rather than a general material class.

  Families are derived, never judged. They are stored with source `derived`, so
  a refresh replaces them without touching curated or community themes.
  Positions with no legal content (`K v K`) and rows without a Key are skipped.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  @families [
    basic_mate: %{
      name: "basic mate",
      description:
        "A lone king against the queen or a rook, with no pawns: the puzzle is about delivering mate."
    },
    king_and_pawn: %{
      name: "king and pawn",
      description:
        "A lone king against king and pawns: the puzzle is about promotion, or holding the draw."
    },
    bare_king_other: %{
      name: "bare king other",
      description:
        "A lone king against minor pieces, or against pawns and pieces: usually a technique exercise with little counterplay."
    },
    queen_and_pawn: %{
      name: "queen and pawn",
      description: "Queens and pawns on the board."
    },
    queen_endgame: %{
      name: "queen endgame",
      description: "Queens on the board, with no pawns."
    },
    rook_and_pawn: %{
      name: "rook and pawn",
      description: "Rooks and pawns, with no queens."
    },
    rook_endgame: %{
      name: "rook endgame",
      description: "Rooks, with no queens and no pawns."
    },
    minor_piece_and_pawn: %{
      name: "minor piece and pawn",
      description: "Bishops and knights with pawns, with no queens or rooks."
    },
    minor_piece_endgame: %{
      name: "minor piece endgame",
      description: "Bishops and knights, with no queens, rooks or pawns."
    },
    pawn_endgame: %{
      name: "pawn endgame",
      description: "Kings and pawns only."
    }
  ]

  @type family ::
          :basic_mate
          | :king_and_pawn
          | :bare_king_other
          | :queen_and_pawn
          | :queen_endgame
          | :rook_and_pawn
          | :rook_endgame
          | :minor_piece_and_pawn
          | :minor_piece_endgame
          | :pawn_endgame

  @doc "The material families, in a stable order."
  def families, do: @families

  @doc """
  Returns the material family for a Key.

  Returns `:kings_only` for `"K v K"` and `:unknown` when the Key is missing or
  not shaped like `"<side> v <side>"`.
  """
  @spec family(String.t() | nil) :: family() | :kings_only | :unknown
  def family(key) when is_binary(key) do
    case String.split(key, " v ") do
      [a, b] ->
        cond do
          bare?(a) and bare?(b) -> :kings_only
          bare?(a) -> bare_king_family(counts(b))
          bare?(b) -> bare_king_family(counts(a))
          true -> material_family(merge(counts(a), counts(b)))
        end

      _ ->
        :unknown
    end
  end

  def family(_key), do: :unknown

  @doc """
  Creates or corrects the material themes, keyed by family.

  An existing theme with the same name is reused and its kind and description
  are corrected, so a theme seeded as a technique becomes a material theme
  without losing its existing links.
  """
  @spec ensure_themes() :: %{family() => Chesstrainer.Themes.Theme.t()}
  def ensure_themes do
    Map.new(@families, fn {family, attrs} ->
      {:ok, theme} = Themes.get_or_create(attrs.name, "endgame", kind: :material)
      {family, ensure_material_theme(theme, attrs)}
    end)
  end

  @doc """
  Refreshes every endgame's derived material theme.

  Returns the number of endgames tagged, the number skipped (kings only or no
  Key) and the number of material themes. Re-running is idempotent.
  """
  @spec derive() :: %{
          tagged: non_neg_integer(),
          skipped: non_neg_integer(),
          themes: non_neg_integer()
        }
  def derive do
    themes = ensure_themes()
    material_ids = Enum.map(themes, fn {_family, theme} -> theme.id end)

    {links, skipped} =
      Endgame
      |> select([e], {e.id, e.key})
      |> Repo.all()
      |> Enum.reduce({[], 0}, fn {id, key}, {links, skipped} ->
        case family(key) do
          family when family in [:kings_only, :unknown] ->
            {links, skipped + 1}

          family ->
            {[{id, Map.fetch!(themes, family).id} | links], skipped}
        end
      end)

    :ok = Themes.replace_theme_links(material_ids, links)

    %{tagged: length(links), skipped: skipped, themes: map_size(themes)}
  end

  defp ensure_material_theme(theme, attrs) do
    if theme.kind == :material and (theme.description || "") == attrs.description do
      theme
    else
      {:ok, updated} =
        Themes.update_theme(theme, %{kind: :material, description: attrs.description})

      updated
    end
  end

  defp bare?(side), do: side == "K"

  defp bare_king_family(counts) do
    cond do
      count(counts, "P") == 0 and (count(counts, "Q") > 0 or count(counts, "R") > 0) ->
        :basic_mate

      count(counts, "P") > 0 and count(counts, "Q") == 0 and count(counts, "R") == 0 ->
        :king_and_pawn

      true ->
        :bare_king_other
    end
  end

  defp material_family(counts) do
    cond do
      count(counts, "Q") > 0 and count(counts, "P") > 0 ->
        :queen_and_pawn

      count(counts, "Q") > 0 ->
        :queen_endgame

      count(counts, "R") > 0 and count(counts, "P") > 0 ->
        :rook_and_pawn

      count(counts, "R") > 0 ->
        :rook_endgame

      count(counts, "B") + count(counts, "N") > 0 and count(counts, "P") > 0 ->
        :minor_piece_and_pawn

      count(counts, "B") + count(counts, "N") > 0 ->
        :minor_piece_endgame

      count(counts, "P") > 0 ->
        :pawn_endgame

      true ->
        :kings_only
    end
  end

  defp counts(side), do: Enum.frequencies(String.graphemes(side))

  defp merge(left, right), do: Map.merge(left, right, fn _piece, a, b -> a + b end)

  defp count(counts, piece), do: Map.get(counts, piece, 0)
end
