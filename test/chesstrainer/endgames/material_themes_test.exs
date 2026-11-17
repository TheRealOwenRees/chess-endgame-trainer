defmodule Chesstrainer.Endgames.MaterialThemesTest do
  use Chesstrainer.DataCase

  import Ecto.Query

  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.MaterialThemes
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  @kr_v_k "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
  @kp_v_k "8/8/3k4/8/8/3KP3/8/8 w - - 0 1"
  @kbn_v_k "8/8/3k4/8/8/3KBN2/8/8 w - - 0 1"
  @krp_v_k "8/8/3k4/8/8/3KR2P/8/8 w - - 0 1"
  @kp_v_kp "4k3/8/8/8/8/4p3/4P3/4K3 w - - 0 1"
  @kq_v_kp "8/8/3k4/8/8/3K1Q1p/8/8 w - - 0 1"
  @kq_v_kq "3q4/8/3k4/8/8/3K1Q2/8/8 w - - 0 1"
  @kn_v_kp "8/8/3k4/8/8/3KN2p/8/8 w - - 0 1"
  @kb_v_kb "8/8/3k1b2/8/8/3K1B2/8/8 w - - 0 1"
  @krp_v_kr "8/8/3k4/8/8/3KR2P/8/5r2 w - - 0 1"
  @kr_v_kr "8/8/3k4/8/8/3K1R2/8/5r2 b - - 0 1"
  @k_v_k "8/8/3k4/8/8/3K4/8/8 w - - 0 1"

  describe "family/1" do
    test "classifies a lone king against heavy or pawn material" do
      assert MaterialThemes.family("KQ v K") == :basic_mate
      assert MaterialThemes.family("KR v K") == :basic_mate
      assert MaterialThemes.family("KP v K") == :king_and_pawn
      assert MaterialThemes.family("KPP v K") == :king_and_pawn
      assert MaterialThemes.family("KBN v K") == :bare_king_other
      assert MaterialThemes.family("KRP v K") == :bare_king_other
    end

    test "classifies material presence into one family" do
      assert MaterialThemes.family("KP v KP") == :pawn_endgame
      assert MaterialThemes.family("KQ v KP") == :queen_and_pawn
      assert MaterialThemes.family("KQ v KQ") == :queen_endgame
      assert MaterialThemes.family("KRP v KR") == :rook_and_pawn
      assert MaterialThemes.family("KR v KR") == :rook_endgame
      assert MaterialThemes.family("KN v KP") == :minor_piece_and_pawn
      assert MaterialThemes.family("KB v KB") == :minor_piece_endgame
    end

    test "flags content-free and malformed keys" do
      assert MaterialThemes.family("K v K") == :kings_only
      assert MaterialThemes.family(nil) == :unknown
      assert MaterialThemes.family("not a key") == :unknown
    end
  end

  describe "derive/0" do
    test "creates every material family as a material theme" do
      MaterialThemes.derive()

      themes = Themes.list_themes()

      assert length(themes) == length(MaterialThemes.families())
      assert Enum.all?(themes, &(&1.kind == :material))
      assert Enum.all?(themes, &(&1.description not in [nil, ""]))
    end

    test "tags every endgame with exactly one family" do
      pawn = create_endgame!(@kp_v_kp)
      rook = create_endgame!(@kr_v_kr)
      rook_and_pawn = create_endgame!(@krp_v_kr)
      queen_and_pawn = create_endgame!(@kq_v_kp)
      queen = create_endgame!(@kq_v_kq)
      minor_and_pawn = create_endgame!(@kn_v_kp)
      minor = create_endgame!(@kb_v_kb)
      mate = create_endgame!(@kr_v_k)
      promotion = create_endgame!(@kp_v_k)
      bare_minor = create_endgame!(@kbn_v_k)
      bare_other = create_endgame!(@krp_v_k)
      kings_only = create_endgame!(@k_v_k)

      assert %{tagged: 11, skipped: 1} = MaterialThemes.derive()

      assert ["pawn endgame"] = theme_names(pawn)
      assert ["rook endgame"] = theme_names(rook)
      assert ["rook and pawn"] = theme_names(rook_and_pawn)
      assert ["queen and pawn"] = theme_names(queen_and_pawn)
      assert ["queen endgame"] = theme_names(queen)
      assert ["minor piece and pawn"] = theme_names(minor_and_pawn)
      assert ["minor piece endgame"] = theme_names(minor)
      assert ["basic mate"] = theme_names(mate)
      assert ["king and pawn"] = theme_names(promotion)
      assert ["bare king other"] = theme_names(bare_minor)
      assert ["bare king other"] = theme_names(bare_other)
      assert [] = theme_names(kings_only)
    end

    test "corrects an existing technique theme and claims its links as derived" do
      {:ok, existing} = Themes.create_theme(%{name: "rook endgame", category: :endgame})
      endgame = create_endgame!(@kr_v_kr, [existing])

      MaterialThemes.derive()

      theme = Themes.get_theme!(existing.id)
      assert theme.kind == :material
      assert theme.description =~ "Rooks"

      assert [{theme_id, "derived"}] = link_rows(endgame.id)
      assert theme_id == existing.id
    end

    test "removes a curated link to a material theme that contradicts the family" do
      {:ok, rook} = Themes.create_theme(%{name: "rook endgame", category: :endgame})
      mate = create_endgame!(@kr_v_k, [rook])

      MaterialThemes.derive()

      assert ["basic mate"] = theme_names(mate)
    end

    test "is idempotent" do
      endgame = create_endgame!(@kq_v_kp)

      MaterialThemes.derive()
      first = link_rows(endgame.id)
      MaterialThemes.derive()

      assert link_rows(endgame.id) == first
      assert length(first) == 1
    end

    test "leaves curated and community links to other themes alone" do
      {:ok, lucena} = Themes.create_theme(%{name: "Lucena", category: :endgame})
      endgame = create_endgame!(@kr_v_kr)
      insert_link(endgame.id, lucena.id, "community")

      MaterialThemes.derive()

      rows = link_rows(endgame.id)
      assert {lucena.id, "community"} in rows
      assert length(rows) == 2
    end
  end

  defp create_endgame!(fen, themes \\ []) do
    {:ok, endgame} =
      Endgames.create_endgame(%{fen: fen, color: :white, result: :win, rating: 1500}, themes)

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

  defp insert_link(endgame_id, theme_id, source) do
    Repo.insert_all("endgames_themes", [
      %{
        endgame_id: Ecto.UUID.dump!(endgame_id),
        theme_id: theme_id,
        source: source,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    ])
  end
end
