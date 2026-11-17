defmodule Chesstrainer.Endgames.MotifThemesTest.Stub do
  @moduledoc false

  def probe_local_detail(fen), do: Map.fetch!(Process.get(:motif_stub), fen)
end

defmodule Chesstrainer.Endgames.MotifThemesTest do
  use Chesstrainer.DataCase

  import Ecto.Query

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.MotifThemes
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  setup do
    previous = Application.get_env(:chesstrainer, :motif_probe)
    Application.put_env(:chesstrainer, :motif_probe, __MODULE__.Stub)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:chesstrainer, :motif_probe, previous),
        else: Application.delete_env(:chesstrainer, :motif_probe)
    end)

    :ok
  end

  describe "motifs_for/4" do
    test "detects an only move for wins and draws" do
      assert [:only_move] = MotifThemes.motifs_for(:win, 5, [move(:win), move(:draw)], 0)

      assert [:only_move] =
               MotifThemes.motifs_for(:draw, 5, [move(:draw), move(:loss), move(:loss)], 0)
    end

    test "does not report an only move when several moves preserve the result" do
      assert [] = MotifThemes.motifs_for(:win, 5, [move(:win), move(:win)], 0)
    end

    test "does not report an only move for a forced single move or a lost position" do
      assert [] = MotifThemes.motifs_for(:win, 5, [move(:win)], 0)
      assert [] = MotifThemes.motifs_for(:loss, 5, [move(:loss), move(:loss)], 0)
    end

    test "requires an underpromotion while no queen promotion preserves the result" do
      assert [:underpromotion] =
               MotifThemes.motifs_for(:win, 5, [move(:win, 4), move(:win), move(:draw, 1)], 0)

      assert [] = MotifThemes.motifs_for(:win, 5, [move(:win, 4), move(:win, 1)], 0)
      assert [] = MotifThemes.motifs_for(:win, 5, [move(:draw, 4), move(:win), move(:win)], 0)
    end

    test "detects the 50-move rule from the raw WDL" do
      assert [:fifty_move_draw] =
               MotifThemes.motifs_for(:cursed_win, 120, [move(:cursed_win)], 0)

      assert [:fifty_move_draw] =
               MotifThemes.motifs_for(:blessed_loss, 120, [move(:blessed_loss)], 0)
    end

    test "detects the 50-move rule when the clock runs out before the next zeroing move" do
      assert [:fifty_move_draw] = MotifThemes.motifs_for(:win, 60, [move(:win)], 50)
      assert [] = MotifThemes.motifs_for(:win, 40, [move(:win)], 50)
      assert [] = MotifThemes.motifs_for(:win, 100, [move(:win)], 0)
    end

    test "a position can carry several motifs" do
      assert [:underpromotion, :only_move] =
               MotifThemes.motifs_for(:win, 5, [move(:win, 4), move(:draw)], 0)
    end
  end

  describe "derive/0" do
    @win_fen "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
    @draw_fen "4k3/8/8/8/8/4p3/4P3/4K3 w - - 0 1"
    @loss_fen "8/8/3k4/8/8/3K4/8/6q1 w - - 0 1"

    test "links the motifs reported for each endgame and skips losses" do
      win = create_endgame!(@win_fen, :win)
      draw = create_endgame!(@draw_fen, :draw)
      loss = create_endgame!(@loss_fen, :loss)

      stub(%{
        win.fen => {:ok, %{wdl: :win, dtz: 5, moves: [move(:win), move(:draw)]}},
        draw.fen => {:ok, %{wdl: :cursed_win, dtz: 120, moves: [move(:cursed_win)]}}
      })

      assert %{links: 2, skipped: 0, themes: 3} = MotifThemes.derive()

      assert theme_names(win) == ["only move"]
      assert theme_names(draw) == ["50-move draw"]
      assert theme_names(loss) == []

      assert Enum.all?(Themes.list_themes(), &(&1.kind == :motif))
      assert Enum.all?(Themes.list_themes(), &(&1.description not in [nil, ""]))
    end

    test "reports endgames the local tables cannot answer" do
      endgame = create_endgame!(@win_fen, :win)
      stub(%{endgame.fen => {:error, :unsupported}})

      assert %{links: 0, skipped: 1} = MotifThemes.derive()
      assert theme_names(endgame) == []
    end

    test "is idempotent and leaves material, curated and community links alone" do
      win = create_endgame!(@win_fen, :win)
      stub(%{win.fen => {:ok, %{wdl: :win, dtz: 5, moves: [move(:win), move(:draw)]}}})

      {:ok, lucena} = Themes.create_theme(%{name: "Lucena", category: :endgame})

      {:ok, rook_endgame} =
        Themes.create_theme(%{name: "rook endgame", kind: :material, category: :endgame})

      {:ok, _} = Themes.tag_endgames(lucena, [win.id], :curated)
      :ok = Themes.sync_derived_themes(win.id, [rook_endgame.id])

      MotifThemes.derive()
      first = link_rows(win.id)
      MotifThemes.derive()

      assert link_rows(win.id) == first
      assert {lucena.id, "curated"} in first
      assert {rook_endgame.id, "derived"} in first
      assert length(first) == 3
    end

    test "corrects an existing technique theme into a motif theme" do
      {:ok, existing} = Themes.create_theme(%{name: "only move", category: :endgame})
      endgame = create_endgame!(@win_fen, :win)
      stub(%{endgame.fen => {:ok, %{wdl: :win, dtz: 5, moves: [move(:win), move(:draw)]}}})

      MotifThemes.derive()

      theme = Themes.get_theme!(existing.id)
      assert theme.kind == :motif
      assert theme.description =~ "Exactly one legal move"
    end
  end

  defp stub(responses), do: Process.put(:motif_stub, responses)

  defp move(wdl, promotes \\ 0, dtz \\ 0), do: {wdl, 0, 0, promotes, 0, dtz}

  defp create_endgame!(fen, result) do
    {:ok, endgame} =
      Endgames.create_endgame(%{fen: fen, color: :white, result: result, rating: 1500})

    endgame
  end

  defp theme_names(endgame) do
    endgame
    |> Map.fetch!(:id)
    |> link_rows()
    |> Enum.map(fn {theme_id, _source} -> Themes.get_theme!(theme_id).name end)
    |> Enum.sort()
  end

  defp link_rows(endgame_id) do
    Repo.all(
      from l in "endgames_themes",
        where: l.endgame_id == type(^endgame_id, :binary_id),
        select: {l.theme_id, l.source},
        order_by: l.theme_id
    )
  end
end
