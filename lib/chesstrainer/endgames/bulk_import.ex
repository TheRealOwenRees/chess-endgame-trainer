defmodule Chesstrainer.Endgames.BulkImport do
  @moduledoc """
  Classifies pasted FENs for the admin bulk importer and inserts the positions
  the local Syzygy tablebase can answer.

  Results always come from `Chesstrainer.Endgames.Tablebase.probe_local_result/1`,
  so a bulk import never consults the remote (Lichess) backend.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Endgames.Tablebase
  alias Chesstrainer.{FEN, Key, Repo}

  @max_fens 1000
  @max_pieces 5
  @default_rating 1500.0

  @type status ::
          :ready
          | :duplicate
          | :invalid_fen
          | :too_many_pieces
          | :illegal
          | :terminal
          | :unsupported

  @type entry :: %{
          line: pos_integer(),
          fen: String.t(),
          key: String.t() | nil,
          color: :white | :black | nil,
          result: Tablebase.result() | nil,
          status: status(),
          reason: String.t() | nil
        }

  @doc """
  The most FENs a single import will consider.
  """
  @spec max_fens() :: pos_integer()
  def max_fens, do: @max_fens

  @doc """
  Parses one FEN per line, skipping blank lines and lines beginning with `#`.

  Returns entries with a status explaining whether the line can be imported,
  and `too_many?` when the input exceeded `max_fens/0` (only the first
  `max_fens/0` lines are considered).

  FENs already in the database and duplicates within the batch are reported as
  duplicates without probing the tablebase.
  """
  @spec preview(String.t()) :: %{entries: [entry()], too_many?: boolean()}
  def preview(text) when is_binary(text) do
    lines = parse_lines(text)
    {lines, rest} = Enum.split(lines, @max_fens)

    fens = Enum.map(lines, fn {_line, fen} -> FEN.normalize(fen) end)
    existing = existing_fens(fens)

    {entries, _seen} =
      Enum.map_reduce(lines, %{}, fn {line, raw_fen}, seen ->
        classify(line, FEN.normalize(raw_fen), seen, existing)
      end)

    %{entries: entries, too_many?: rest != []}
  end

  @doc """
  Inserts every `:ready` entry, attaching `themes` and `rating` to each.

  Rows that collide with an existing FEN are skipped. Returns the number
  imported and the number of entries that were not ready or were skipped.
  """
  @spec commit([entry()], [Chesstrainer.Themes.Theme.t()], number()) ::
          %{imported: non_neg_integer(), skipped: non_neg_integer()}
  def commit(entries, themes \\ [], rating \\ @default_rating) do
    ready = Enum.filter(entries, &(&1.status == :ready))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(ready, fn entry ->
        %{
          id: Ecto.UUID.generate(),
          public_code: Endgame.generate_public_code(),
          fen: entry.fen,
          color: entry.color,
          key: entry.key,
          result: entry.result,
          rating: (rating || @default_rating) * 1.0,
          rating_deviation: 350.0,
          times_attempted: 0,
          times_solved: 0,
          inserted_at: now,
          updated_at: now
        }
      end)

    {imported, inserted_rows} =
      Repo.insert_all(Endgame, rows, on_conflict: :nothing, returning: [:id])

    join_rows =
      for %Endgame{id: id} <- inserted_rows, theme <- themes do
        %{
          endgame_id: Ecto.UUID.dump!(id),
          theme_id: theme.id
        }
      end

    if join_rows != [] do
      Repo.insert_all("endgames_themes", join_rows, on_conflict: :nothing)
    end

    %{imported: imported, skipped: length(entries) - imported}
  end

  defp parse_lines(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {raw, index}, acc ->
      trimmed = String.trim(raw)

      if trimmed == "" or String.starts_with?(trimmed, "#") do
        acc
      else
        [{index, trimmed} | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp existing_fens(fens) do
    fens
    |> Enum.uniq()
    |> then(fn fens -> Repo.all(from e in Endgame, where: e.fen in ^fens, select: e.fen) end)
    |> Map.new(&{&1, true})
  end

  defp classify(line, fen, seen, existing) do
    cond do
      Map.has_key?(seen, fen) ->
        {entry(line, fen, :duplicate, "Duplicate FEN in this batch"), seen}

      Map.has_key?(existing, fen) ->
        {entry(line, fen, :duplicate, "FEN already exists"), seen}

      true ->
        {classify_new(line, fen), Map.put(seen, fen, true)}
    end
  end

  defp classify_new(line, fen) do
    issues = Endgame.fen_issues(fen)
    pieces = FEN.piece_count(fen)

    cond do
      issues != [] ->
        entry(line, fen, :invalid_fen, Enum.join(issues, "; "))

      is_integer(pieces) and pieces > @max_pieces ->
        entry(
          line,
          fen,
          :too_many_pieces,
          "Only positions with #{@max_pieces} or fewer pieces are supported"
        )

      true ->
        classify_probe(line, fen)
    end
  end

  defp classify_probe(line, fen) do
    case Tablebase.probe_local_result(fen) do
      {:ok, result} ->
        entry(line, fen, :ready, nil) |> Map.put(:result, result)

      {:error, :terminal} ->
        entry(line, fen, :terminal, "Checkmate, stalemate, or no legal moves")

      {:error, :illegal} ->
        entry(line, fen, :illegal, "The tablebase rejected this position")

      {:error, :not_configured} ->
        entry(
          line,
          fen,
          :unsupported,
          "Local tablebase is not configured (set TABLEBASE_PATH)"
        )

      {:error, :unsupported} ->
        entry(line, fen, :unsupported, "The local tablebase cannot answer this position")
    end
  end

  defp entry(line, fen, status, reason) do
    %{
      line: line,
      fen: fen,
      key: key_for(fen),
      color: FEN.color_from_fen(fen),
      result: nil,
      status: status,
      reason: reason
    }
  end

  defp key_for(fen) do
    case Key.from_fen(fen) do
      {:ok, key} -> key
      _ -> nil
    end
  end
end
