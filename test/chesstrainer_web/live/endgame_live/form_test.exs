defmodule ChesstrainerWeb.EndgameLive.FormTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes

  @fen "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"

  setup :register_and_log_in_admin

  describe "rating default" do
    test "new endgame form pre-fills rating with 1500", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

      html = view |> element("#endgame-form input[name='endgame[rating]']") |> render()

      assert html =~ ~s(value="1500")
    end

    test "creates an endgame rated 1500 when rating is left unchanged", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

      view
      |> form("#endgame-form", endgame: %{fen: @fen, result: "win"})
      |> render_submit()

      assert_redirect(view, ~p"/admin/endgames")

      endgame = Endgames.list_endgames() |> Enum.find(&(&1.fen == @fen))
      assert endgame.rating == 1500
    end

    test "editing an endgame keeps its stored rating", %{conn: conn} do
      attrs = %{fen: @fen, color: :white, result: :win, rating: 1625}
      {:ok, endgame} = Endgames.create_endgame(attrs)

      {:ok, view, _html} = live(conn, ~p"/admin/endgames/#{endgame}/edit")

      html = view |> element("#endgame-form input[name='endgame[rating]']") |> render()

      assert html =~ ~s(value="1625")
    end
  end

  test "creates an endgame with staged themes", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})

    {:ok, view, html} = live(conn, ~p"/admin/endgames/new")

    assert html =~ "max-w-2xl"

    view |> form("#theme-form", %{theme_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    view
    |> form("#endgame-form",
      endgame: %{fen: @fen, rating: 1500, result: "win"}
    )
    |> render_submit()

    assert_redirect(view, ~p"/admin/endgames")

    endgame =
      Endgames.list_endgames()
      |> Enum.find(&(&1.fen == @fen))
      |> Repo.preload(:themes)

    assert Enum.map(endgame.themes, & &1.id) == [theme.id]
  end

  test "attaches multiple themes", %{conn: conn} do
    theme_fixture(%{name: "Lucena"})
    theme_fixture(%{name: "Philidor"})

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

    view |> form("#theme-form", %{theme_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    view |> form("#theme-form", %{theme_search: "Phil"}) |> render_change()
    view |> element("button", "Philidor") |> render_click()

    html = render(view)
    assert html =~ "Lucena"
    assert html =~ "Philidor"
  end

  test "creates and attaches a new theme inline", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

    view |> form("#theme-form", %{theme_search: "Lucerne"}) |> render_submit()

    assert render(view) =~ "Lucerne"
    assert [%{name: "Lucerne"}] = Themes.search("Lucerne", "endgame")
  end

  test "removes a theme from an existing endgame", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})
    attrs = %{fen: @fen, color: :white, result: :win, rating: 1500}
    {:ok, endgame} = Endgames.create_endgame(attrs, [theme])

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/#{endgame}/edit")

    assert render(view) =~ "Lucena"

    view |> element("button[aria-label='Remove Lucena']") |> render_click()

    view
    |> form("#endgame-form", endgame: %{rating: 1500, result: "win"})
    |> render_submit()

    assert_redirect(view, ~p"/admin/endgames")

    updated = Endgames.get_endgame!(endgame.id) |> Repo.preload(:themes)
    assert updated.themes == []
  end
end
