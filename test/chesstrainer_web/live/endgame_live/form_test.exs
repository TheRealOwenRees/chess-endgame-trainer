defmodule ChesstrainerWeb.EndgameLive.FormTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.TagsFixtures

  alias Chesstrainer.Endgames
  alias Chesstrainer.Repo
  alias Chesstrainer.Tags

  @fen "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"

  test "creates an endgame with staged themes", %{conn: conn} do
    tag = tag_fixture(%{name: "Lucena"})

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

    view |> form("#theme-form", %{tag_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    view
    |> form("#endgame-form",
      endgame: %{fen: @fen, key: "KR v K", rating: 1500, result: "win"}
    )
    |> render_submit()

    assert_redirect(view, ~p"/admin/endgames")

    endgame =
      Endgames.list_endgames()
      |> Enum.find(&(&1.fen == @fen))
      |> Repo.preload(:tags)

    assert Enum.map(endgame.tags, & &1.id) == [tag.id]
  end

  test "attaches multiple themes", %{conn: conn} do
    tag_fixture(%{name: "Lucena"})
    tag_fixture(%{name: "Philidor"})

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

    view |> form("#theme-form", %{tag_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    view |> form("#theme-form", %{tag_search: "Phil"}) |> render_change()
    view |> element("button", "Philidor") |> render_click()

    html = render(view)
    assert html =~ "Lucena"
    assert html =~ "Philidor"
  end

  test "creates and attaches a new theme inline", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/endgames/new")

    view |> form("#theme-form", %{tag_search: "Lucerne"}) |> render_submit()

    assert render(view) =~ "Lucerne"
    assert [%{name: "Lucerne"}] = Tags.search("Lucerne", "endgame")
  end

  test "removes a theme from an existing endgame", %{conn: conn} do
    tag = tag_fixture(%{name: "Lucena"})
    attrs = %{fen: @fen, color: :white, key: "KR v K", result: :win, rating: 1500}
    {:ok, endgame} = Endgames.create_endgame(attrs, [tag])

    {:ok, view, _html} = live(conn, ~p"/admin/endgames/#{endgame}/edit")

    assert render(view) =~ "Lucena"

    view |> element("button[aria-label='Remove Lucena']") |> render_click()

    view
    |> form("#endgame-form", endgame: %{key: "KR v K", rating: 1500, result: "win"})
    |> render_submit()

    assert_redirect(view, ~p"/admin/endgames")

    updated = Endgames.get_endgame!(endgame.id) |> Repo.preload(:tags)
    assert updated.tags == []
  end
end
