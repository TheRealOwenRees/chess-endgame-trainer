defmodule ChesstrainerWeb.Admin.ThemeLive.TagTest do
  use ChesstrainerWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  setup :register_and_log_in_admin

  @kp_v_kp_1 "4k3/8/8/8/8/4p3/4P3/4K3 w - - 0 1"
  @kp_v_kp_2 "3k4/8/8/8/8/4p3/4P3/4K3 w - - 0 1"
  @kr_v_kr "8/8/3k4/8/8/3K1R2/8/5r2 b - - 0 1"

  test "lists candidate groups with counts and previews boards", %{conn: conn} do
    theme = technique_theme()
    kp_1 = create_endgame!(@kp_v_kp_1)
    kp_2 = create_endgame!(@kp_v_kp_2)
    kr = create_endgame!(@kr_v_kr)

    {:ok, view, _html} = live(conn, ~p"/admin/themes/#{theme.id}/tag")

    assert has_element?(view, "#candidate-count", "3")
    assert has_element?(view, "#candidates-KP-v-KP", "2")

    view |> element("#toggle-candidates-KP-v-KP") |> render_click()

    assert has_element?(view, "#endgame-#{kp_1.id}")
    assert has_element?(view, "#endgame-#{kp_2.id}")
    refute has_element?(view, "#endgame-#{kr.id}")
    assert render(view) =~ "Chess position"
  end

  test "applies the theme in bulk and updates coverage", %{conn: conn} do
    theme = technique_theme()
    kp_1 = create_endgame!(@kp_v_kp_1)
    kp_2 = create_endgame!(@kp_v_kp_2)
    _kr = create_endgame!(@kr_v_kr)

    {:ok, view, _html} = live(conn, ~p"/admin/themes/#{theme.id}/tag")

    view |> element("#toggle-candidates-KP-v-KP") |> render_click()
    view |> element("#select-#{kp_1.id}") |> render_click()
    view |> element("#select-#{kp_2.id}") |> render_click()
    view |> element("#apply-theme") |> render_click()

    assert render(view) =~ "Tagged 2 endgame(s)"
    assert has_element?(view, "#tagged-count", "2")
    assert has_element?(view, "#candidate-count", "1")

    assert Enum.sort(curated_endgame_ids(theme)) == Enum.sort([kp_1.id, kp_2.id])

    {:ok, _index, html} = live(conn, ~p"/admin/themes")
    assert html =~ "2 of 3 endgames"
  end

  test "removes a curated link but leaves a community link alone", %{conn: conn} do
    theme = technique_theme()
    curated = create_endgame!(@kp_v_kp_1)
    community = create_endgame!(@kr_v_kr)

    {:ok, _} = Themes.tag_endgames(theme, [curated.id], :curated)
    {:ok, _} = Themes.tag_endgames(theme, [community.id], :community)

    {:ok, view, _html} = live(conn, ~p"/admin/themes/#{theme.id}/tag")

    view |> element("#toggle-tagged-KP-v-KP") |> render_click()
    view |> element("#remove-#{curated.id}") |> render_click()

    assert render(view) =~ "Removed"
    assert curated_endgame_ids(theme) == []

    assert {Ecto.UUID.dump!(community.id), "community"} in link_rows(theme.id)
  end

  test "refuses a material theme", %{conn: conn} do
    {:ok, theme} =
      Themes.create_theme(%{name: "Rook endgame", kind: :material, category: :endgame})

    assert {:error, {:live_redirect, %{to: "/admin/themes"}}} =
             live(conn, ~p"/admin/themes/#{theme.id}/tag")
  end

  test "switching the theme navigates to its workspace", %{conn: conn} do
    first = technique_theme(%{name: "Lucena"})
    second = technique_theme(%{name: "Philidor"})

    {:ok, view, _html} = live(conn, ~p"/admin/themes/#{first.id}/tag")

    assert {:error, {:live_redirect, %{to: path}}} =
             view
             |> form("#theme-workspace-form", %{theme_id: to_string(second.id)})
             |> render_change()

    assert path == "/admin/themes/#{second.id}/tag"
  end

  test "members cannot open the workspace", %{conn: conn} do
    theme = technique_theme()
    conn = log_in_user(conn, user_fixture())

    assert redirected_to(get(conn, ~p"/admin/themes/#{theme.id}/tag")) == ~p"/"
  end

  defp technique_theme(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{name: unique_theme_name(), kind: :technique, category: :endgame},
        attrs
      )

    {:ok, theme} = Themes.create_theme(attrs)
    theme
  end

  defp create_endgame!(fen) do
    {:ok, endgame} =
      Endgames.create_endgame(%{fen: fen, color: :white, result: :win, rating: 1500})

    endgame
  end

  defp curated_endgame_ids(theme) do
    Repo.all(
      from l in "endgames_themes",
        where: l.theme_id == ^theme.id and l.source == "curated",
        select: l.endgame_id
    )
    |> Enum.map(&Ecto.UUID.load!/1)
  end

  defp link_rows(theme_id) do
    Repo.all(
      from l in "endgames_themes",
        where: l.theme_id == ^theme_id,
        select: {l.endgame_id, l.source}
    )
  end
end
