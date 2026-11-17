defmodule Chesstrainer.Endgames.MotifThemes do
  @moduledoc """
  Derives objective motif themes by probing each endgame's position.

  Motifs describe the kind of problem, independent of the material family: an
  endgame can be a rook endgame and an only-move puzzle at the same time. Every
  motif is proved from the local Syzygy tables — one probe returns the root WDL,
  the DTZ and every legal move with its own WDL — so nothing here is a guess and
  nothing calls the remote backend.

  Motif links are recorded as `derived` and refreshed as a whole. Material
  families, curated links and community links are untouched because the refresh
  is scoped to the motif themes.

  Loss endgames are skipped: only-move is undefined when every move loses, and
  the library no longer contains them.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.Endgames.Tablebase.Backend.Fathom, as: FathomBackend
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  @motifs [
    only_move: %{
      name: "only move",
      description:
        "Exactly one legal move keeps the result, so the puzzle is about finding the single accurate move."
    },
    underpromotion: %{
      name: "underpromotion",
      description:
        "The result can only be preserved by promoting to a rook, bishop or knight; promoting to a queen does not work."
    },
    fifty_move_draw: %{
      name: "50-move draw",
      description:
        "The result turns on the fifty-move rule: the win needs more moves than the halfmove clock allows, so the defender can claim a draw."
    }
  ]

  @type motif :: :only_move | :underpromotion | :fifty_move_draw

  @doc "The motif themes, in a stable order."
  def motifs, do: @motifs

  @doc """
  Returns the motifs for one probed position.

  `moves` are Fathom move tuples `{wdl, from, to, promotes, ep, dtz}` and carry
  the mover's perspective, so they are compared with the root WDL directly.
  `halfmove_clock` comes from the FEN; the probe itself runs with `rule50 = 0`.
  """
  @spec motifs_for(atom(), integer() | nil, [tuple()], non_neg_integer()) :: [motif()]
  def motifs_for(wdl, dtz, moves, halfmove_clock) do
    outcome = Tablebase.normalize_wdl(wdl)

    preserving =
      Enum.filter(moves, fn {move_wdl, _from, _to, _promotes, _ep, _dtz} ->
        Tablebase.normalize_wdl(move_wdl) == outcome
      end)

    []
    |> maybe_only_move(outcome, moves, preserving)
    |> maybe_underpromotion(preserving)
    |> maybe_fifty_move(wdl, dtz, halfmove_clock)
  end

  @doc """
  Creates or corrects the motif themes, keyed by motif.

  An existing theme with the same name is reused and its kind and description
  are corrected, so a theme seeded as a technique becomes a motif without
  losing its existing links.
  """
  @spec ensure_themes() :: %{motif() => Chesstrainer.Themes.Theme.t()}
  def ensure_themes do
    Map.new(@motifs, fn {motif, attrs} ->
      {:ok, theme} = Themes.get_or_create(attrs.name, "endgame", kind: :motif)
      {motif, ensure_motif_theme(theme, attrs)}
    end)
  end

  @doc """
  Refreshes every endgame's derived motif links.

  Returns the number of links written, the number of endgames skipped because
  the local tables could not answer them, and a count per motif. Re-running is
  idempotent.
  """
  @spec derive() :: %{
          links: non_neg_integer(),
          skipped: non_neg_integer(),
          by_motif: %{motif() => non_neg_integer()},
          themes: non_neg_integer()
        }
  def derive do
    themes = ensure_themes()
    motif_ids = Enum.map(themes, fn {_motif, theme} -> theme.id end)

    initial_counts = Map.new(@motifs, fn {motif, _attrs} -> {motif, 0} end)

    {links, skipped, by_motif} =
      Endgame
      |> where([e], e.result in [:win, :draw])
      |> select([e], {e.id, e.fen})
      |> Repo.all()
      |> Enum.reduce({[], 0, initial_counts}, fn {id, fen}, {links, skipped, counts} ->
        case probe(fen) do
          {:ok, %{wdl: wdl, dtz: dtz, moves: moves}} ->
            motifs = motifs_for(wdl, dtz, moves, halfmove_clock(fen))

            links =
              Enum.reduce(motifs, links, fn motif, acc ->
                [{id, Map.fetch!(themes, motif).id} | acc]
              end)

            counts =
              Enum.reduce(motifs, counts, fn motif, acc ->
                Map.update!(acc, motif, &(&1 + 1))
              end)

            {links, skipped, counts}

          {:error, _reason} ->
            {links, skipped + 1, counts}
        end
      end)

    :ok = Themes.replace_theme_links(motif_ids, links)

    %{links: length(links), skipped: skipped, by_motif: by_motif, themes: map_size(themes)}
  end

  defp ensure_motif_theme(theme, attrs) do
    if theme.kind == :motif and (theme.description || "") == attrs.description do
      theme
    else
      {:ok, updated} =
        Themes.update_theme(theme, %{kind: :motif, description: attrs.description})

      updated
    end
  end

  defp probe(fen), do: probe_module().probe_local_detail(fen)

  defp probe_module do
    Application.get_env(:chesstrainer, :motif_probe, FathomBackend)
  end

  defp maybe_only_move(acc, outcome, moves, preserving) do
    if outcome in [:win, :draw] and length(moves) > 1 and length(preserving) == 1 do
      [:only_move | acc]
    else
      acc
    end
  end

  defp maybe_underpromotion(acc, preserving) do
    underpromotes? =
      Enum.any?(preserving, fn {_wdl, _from, _to, promotes, _ep, _dtz} ->
        promotes in [2, 3, 4]
      end)

    queen_promotes? =
      Enum.any?(preserving, fn {_wdl, _from, _to, promotes, _ep, _dtz} ->
        promotes == 1
      end)

    if underpromotes? and not queen_promotes?, do: [:underpromotion | acc], else: acc
  end

  defp maybe_fifty_move(acc, wdl, dtz, halfmove_clock) do
    table_draw? = wdl in [:cursed_win, :blessed_loss]

    clock_exhausted? =
      wdl == :win and is_integer(dtz) and dtz > 100 - halfmove_clock

    if table_draw? or clock_exhausted?, do: [:fifty_move_draw | acc], else: acc
  end

  defp halfmove_clock(fen) do
    case String.split(fen, " ") do
      [_board, _active, _castling, _ep, clock, _fullmove] ->
        case Integer.parse(clock) do
          {value, _rest} -> value
          :error -> 0
        end

      _ ->
        0
    end
  end
end
