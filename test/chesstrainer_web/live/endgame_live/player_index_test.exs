defmodule ChesstrainerWeb.EndgameLive.PlayerIndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Endgames

  setup :register_and_log_in_user

  test "groups endgames by Key and shows themes on expand", %{conn: conn} do
    theme = theme_fixture(%{name: "Lucena"})
    endgame = endgame_fixture()
    other = endgame_fixture()
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [theme])

    {:ok, view, html} = live(conn, ~p"/endgames")

    assert html =~ "Endgames"
    assert html =~ "max-w-7xl"
    assert html =~ "/assets/js/app.js"
    refute html =~ "/assets/js/marketing.js"
    assert has_element?(view, "#key-group-K-v-K")
    refute html =~ "Lucena"

    view |> element("#key-group-K-v-K button") |> render_click()

    html = render(view)
    assert html =~ ~p"/endgames/#{endgame.public_code}/play"
    assert html =~ ~p"/endgames/#{other.public_code}/play"
    assert html =~ "Lucena"
  end

  test "links to the public code, never the database id", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/endgames")
    view |> element("#key-group-K-v-K button") |> render_click()

    html = render(view)
    assert html =~ ~s{/endgames/#{endgame.public_code}/play}
    refute html =~ endgame.id
  end

  test "the play button carries the current filter", %{conn: conn} do
    lucena = theme_fixture(%{name: "Lucena"})
    endgame = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [lucena])

    {:ok, view, _html} = live(conn, ~p"/endgames?themes=lucena&key=KR+v+K")

    assert has_element?(view, "#play-collection[href*='themes=lucena']", "Play these 1")
  end

  test "filters by theme", %{conn: conn} do
    lucena = theme_fixture(%{name: "Lucena"})
    philidor = theme_fixture(%{name: "Philidor"})

    kr = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    kq = endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")
    {:ok, _} = Endgames.update_endgame(kr, %{}, [lucena])
    {:ok, _} = Endgames.update_endgame(kq, %{}, [philidor])

    {:ok, view, _html} = live(conn, ~p"/endgames")

    view |> form("#theme-filter-form", %{theme_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    assert has_element?(view, "#key-group-KR-v-K")
    refute has_element?(view, "#key-group-KQ-v-K")
    assert has_element?(view, "#play-collection[href='/train?themes=lucena']")
  end

  test "navigating to a play page renders the board", %{conn: conn} do
    endgame = endgame_fixture()

    {:ok, view, _html} = live(conn, ~p"/endgames/#{endgame.public_code}/play")

    assert has_element?(view, "#endgame-board")
    assert has_element?(view, ~s{a[href="/endgames"]})
  end

  test "puts the Key filter in the address bar", %{conn: conn} do
    endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")

    {:ok, view, _html} = live(conn, ~p"/endgames")

    view |> form("#key-filter-form", %{key: "KR v K"}) |> render_change()

    assert_patch(view, ~p"/endgames?key=KR+v+K")
  end

  test "the Key filter narrows the list and the play button", %{conn: conn} do
    endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")

    {:ok, view, _html} = live(conn, ~p"/endgames")

    assert has_element?(view, "#key-group-KQ-v-K")
    assert has_element?(view, "#key-group-KR-v-K")

    view |> form("#key-filter-form", %{key: "KR v K"}) |> render_change()

    assert has_element?(view, "#key-group-KR-v-K")
    refute has_element?(view, "#key-group-KQ-v-K")
    assert has_element?(view, "#play-collection[href*='key=KR']", "Play these 1")
  end

  test "keeps the Key when a theme is added and removed", %{conn: conn} do
    lucena = theme_fixture(%{name: "Lucena"})
    kr = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    {:ok, _} = Endgames.update_endgame(kr, %{}, [lucena])

    {:ok, view, _html} = live(conn, ~p"/endgames?key=KR+v+K")

    view |> form("#theme-filter-form", %{theme_search: "Luc"}) |> render_change()
    view |> element("button", "Lucena") |> render_click()

    assert_patch(view, ~p"/endgames?key=KR+v+K&themes=lucena")

    view |> element("button[aria-label='Remove Lucena']") |> render_click()

    assert_patch(view, ~p"/endgames?key=KR+v+K")
  end

  test "each Key section can be played whole", %{conn: conn} do
    lucena = theme_fixture(%{name: "Lucena"})
    endgame = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    {:ok, _} = Endgames.update_endgame(endgame, %{}, [lucena])

    {:ok, view, _html} = live(conn, ~p"/endgames?themes=lucena")

    assert has_element?(view, "#play-group-KR-v-K[href*='key=KR']", "Play all 1")
    assert has_element?(view, "#play-group-KR-v-K[href*='themes=lucena']")
  end

  test "an unexpanded section can be played without opening it", %{conn: conn} do
    endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")

    {:ok, view, _html} = live(conn, ~p"/endgames")

    assert has_element?(view, "#play-group-KR-v-K[href*='key=KR']")
    refute has_element?(view, "#key-group-KR-v-K table")
  end

  describe "collection URLs" do
    test "puts the theme filter in the address bar", %{conn: conn} do
      lucena = theme_fixture(%{name: "Lucena"})
      endgame = endgame_fixture()
      {:ok, _} = Endgames.update_endgame(endgame, %{}, [lucena])

      {:ok, view, _html} = live(conn, ~p"/endgames")

      view |> form("#theme-filter-form", %{theme_search: "Luc"}) |> render_change()
      view |> element("button", "Lucena") |> render_click()

      assert_patch(view, ~p"/endgames?themes=lucena")
    end

    test "restores the selection from the address bar", %{conn: conn} do
      lucena = theme_fixture(%{name: "Lucena"})
      kr = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      _kq = endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")
      {:ok, _} = Endgames.update_endgame(kr, %{}, [lucena])

      {:ok, view, _html} = live(conn, ~p"/endgames?themes=lucena")

      assert has_element?(view, "#key-group-KR-v-K")
      refute has_element?(view, "#key-group-KQ-v-K")
      assert has_element?(view, "#play-collection[href='/train?themes=lucena']")
    end

    test "combines themes and a Key", %{conn: conn} do
      lucena = theme_fixture(%{name: "Lucena"})
      endgame = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      {:ok, _} = Endgames.update_endgame(endgame, %{}, [lucena])

      {:ok, view, _html} = live(conn, ~p"/endgames?themes=lucena&key=KR+v+K")

      assert has_element?(view, "#key-group-KR-v-K")
      assert has_element?(view, "#play-collection[href*='key=KR']")
    end

    test "removing a theme patches the address bar back", %{conn: conn} do
      lucena = theme_fixture(%{name: "Lucena"})
      endgame = endgame_fixture()
      {:ok, _} = Endgames.update_endgame(endgame, %{}, [lucena])

      {:ok, view, _html} = live(conn, ~p"/endgames?themes=lucena")

      view |> element("button[aria-label='Remove Lucena']") |> render_click()

      assert_patch(view, ~p"/endgames")
    end

    test "ignores themes and keys that do not exist", %{conn: conn} do
      endgame_fixture()

      {:ok, view, _html} = live(conn, ~p"/endgames?themes=nope&key=Q+v+Q")

      assert has_element?(view, "#key-group-K-v-K")
      assert has_element?(view, "#play-collection[href='/train']")
    end
  end
end
