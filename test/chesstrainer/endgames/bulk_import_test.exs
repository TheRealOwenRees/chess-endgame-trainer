defmodule Chesstrainer.Endgames.BulkImportTest do
  # Not async: the tablebase path is application config and Fathom keeps global
  # state, so other tests must not flip the local backend while this runs.
  use Chesstrainer.DataCase, async: false

  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.BulkImport
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Repo

  @krk "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"
  @mate "7k/6Q1/5K2/8/8/8/8/8 b - - 0 1"
  @six_pieces "4k2r/8/8/8/8/8/8/R2QK2R w - - 0 1"

  describe "preview/1" do
    test "classifies a position the local tablebase can answer" do
      assert %{entries: [entry], too_many?: false} = BulkImport.preview(@krk)

      assert entry.status == :ready
      assert entry.result == :win
      assert entry.color == :white
      assert entry.key == "KR v K"
      assert entry.fen == @krk
      assert entry.reason == nil
    end

    test "marks checkmate positions as terminal" do
      assert %{entries: [entry]} = BulkImport.preview(@mate)

      assert entry.status == :terminal
      assert entry.result == nil
    end

    test "rejects positions with more than five pieces" do
      assert %{entries: [entry]} = BulkImport.preview(@six_pieces)

      assert entry.status == :too_many_pieces
      assert entry.reason =~ "5 or fewer pieces"
    end

    test "rejects malformed FENs" do
      assert %{entries: [entry]} = BulkImport.preview("not a fen")

      assert entry.status == :invalid_fen
      assert entry.reason =~ "6 space-separated fields"
    end

    test "reports duplicates within the batch without probing twice" do
      assert %{entries: [first, second]} = BulkImport.preview("#{@krk}\n#{@krk}")

      assert first.status == :ready
      assert second.status == :duplicate
      assert second.reason == "Duplicate FEN in this batch"
    end

    test "reports FENs already stored as duplicates" do
      {:ok, _endgame} =
        Endgames.create_endgame(%{fen: @krk, color: :white, result: :win})

      assert %{entries: [entry]} = BulkImport.preview(@krk)

      assert entry.status == :duplicate
      assert entry.reason == "FEN already exists"
    end

    test "ignores blank lines and comments" do
      text = "\n# a comment\n#{@krk}\n\n"

      assert %{entries: [entry]} = BulkImport.preview(text)
      assert entry.status == :ready
    end

    test "caps the input at max_fens/0" do
      text = Enum.join(List.duplicate("not a fen", BulkImport.max_fens() + 1), "\n")

      assert %{entries: entries, too_many?: true} = BulkImport.preview(text)
      assert length(entries) == BulkImport.max_fens()
    end

    test "reports unsupported when the local tablebase is not configured" do
      previous = Application.get_env(:chesstrainer, :tablebase_path)

      on_exit(fn -> Application.put_env(:chesstrainer, :tablebase_path, previous) end)

      Application.put_env(:chesstrainer, :tablebase_path, nil)

      assert %{entries: [entry]} = BulkImport.preview(@krk)
      assert entry.status == :unsupported
      assert entry.reason =~ "not configured"
    end
  end

  describe "commit/3" do
    test "inserts ready entries with the batch rating and themes" do
      theme = theme_fixture(%{name: "Lucena"})

      assert %{entries: entries} = BulkImport.preview(@krk)
      assert %{imported: 1, skipped: 0} = BulkImport.commit(entries, [theme], 1700)

      endgame =
        Repo.get_by!(Endgame, fen: @krk)
        |> Repo.preload(:themes)

      assert endgame.color == :white
      assert endgame.result == :win
      assert endgame.key == "KR v K"
      assert endgame.rating == 1700.0
      assert [%{id: theme_id}] = endgame.themes
      assert theme_id == theme.id
    end

    test "ignores entries that are not ready" do
      assert %{entries: entries} = BulkImport.preview("not a fen")

      assert %{imported: 0, skipped: 1} = BulkImport.commit(entries)
      assert Repo.aggregate(Endgame, :count) == 0
    end

    test "skips rows that collide with an existing FEN" do
      {:ok, _existing} =
        Endgames.create_endgame(%{fen: @krk, color: :white, result: :win})

      entries = [
        %{
          line: 1,
          fen: @krk,
          key: "KR v K",
          color: :white,
          result: :win,
          status: :ready,
          reason: nil
        }
      ]

      assert %{imported: 0, skipped: 1} = BulkImport.commit(entries)
      assert Repo.aggregate(Endgame, :count) == 1
    end
  end
end
