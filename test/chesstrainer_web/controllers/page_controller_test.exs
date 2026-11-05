defmodule ChesstrainerWeb.PageControllerTest do
  use ChesstrainerWeb.ConnCase

  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.DailyPuzzles
  alias Chesstrainer.Endgames
  alias Chesstrainer.Themes

  @fen_kr "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
  @fen_kr_other "8/8/4k3/8/8/3K1R2/8/8 w - - 0 1"
  @fen_kq "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1"

  setup do
    previous = Application.get_env(:chesstrainer, :curated_endgame_codes)
    on_exit(fn -> Application.put_env(:chesstrainer, :curated_endgame_codes, previous) end)
    :ok
  end

  defp create_endgame(fen, rating, theme_name) do
    {:ok, theme} = Themes.create_theme(%{name: theme_name, category: :endgame})

    {:ok, endgame} =
      Endgames.create_endgame(%{fen: fen, color: :white, result: :win, rating: rating}, [theme])

    endgame
  end

  defp curated! do
    beginner = create_endgame(@fen_kr, 1500, "Opposition")
    intermediate = create_endgame(@fen_kr_other, 1800, "Lucena")
    advanced = create_endgame(@fen_kq, 2100, "Philidor")

    Application.put_env(:chesstrainer, :curated_endgame_codes, [
      beginner.public_code,
      intermediate.public_code,
      advanced.public_code
    ])

    {beginner, intermediate, advanced}
  end

  @description "Short, focused endgame puzzles against tablebase-perfect defence. " <>
                 "Learn to see the winning move and make the endgame your strongest phase."

  test "GET / renders the landing page, navbar, and footer", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert html =~ "Learn to see the"
    assert html =~ "LUCID"
    assert html =~ "Privacy Policy"
    assert html =~ "/#terms-conditions"
    assert html =~ "Start training"
    assert html =~ ~s(id="nav-links")
    assert html =~ "menu-button"
    assert html =~ ~s(class="site-footer")
    assert html =~ "© #{DateTime.utc_now().year} Lucid Chess"
    assert html =~ ~p"/endgames"
    assert html =~ "/assets/js/marketing.js"
    refute html =~ "/assets/js/app.js"

    assert LazyHTML.text(LazyHTML.query(document, "title")) =~ "Lucid Chess — Endgame Trainer"
    refute html =~ "Phoenix Framework"

    eyebrow = LazyHTML.query(document, ".eyebrow")
    assert LazyHTML.text(eyebrow) =~ "Endgames, made clear"
    assert LazyHTML.attribute(LazyHTML.query(eyebrow, "svg"), "aria-hidden") == ["true"]

    assert LazyHTML.attribute(LazyHTML.query(document, ~s(meta[name="description"])), "content") ==
             [@description]

    assert [canonical] =
             LazyHTML.attribute(LazyHTML.query(document, ~s(link[rel="canonical"])), "href")

    assert URI.parse(canonical).path == "/"

    for {selector, content} <- [
          {~s(meta[property="og:type"]), "website"},
          {~s(meta[property="og:site_name"]), "Lucid Chess"},
          {~s(meta[property="og:title"]), "Lucid Chess — Endgame Trainer"},
          {~s(meta[property="og:description"]), @description},
          {~s(meta[property="og:url"]), canonical},
          {~s(meta[name="twitter:card"]), "summary"},
          {~s(meta[name="twitter:title"]), "Lucid Chess — Endgame Trainer"},
          {~s(meta[name="twitter:description"]), @description}
        ] do
      assert LazyHTML.attribute(LazyHTML.query(document, selector), "content") == [content]
    end
  end

  test "guest navbar links to log in and register", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~p"/users/log-in"
    assert html =~ ~p"/users/register"
    refute html =~ ~p"/users/settings"
  end

  test "signed-in navbar links to settings and log out", %{conn: conn} do
    html =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~p"/users/settings"
    assert html =~ ~p"/users/log-out"
    refute html =~ ~p"/users/register"
  end

  test "renders curated cards and the daily board", %{conn: conn} do
    {beginner, intermediate, advanced} = curated!()
    daily = DailyPuzzles.today()

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert LazyHTML.attribute(LazyHTML.query(document, ".puzzle-card"), "href") == [
             "/endgames/#{beginner.public_code}/play",
             "/endgames/#{intermediate.public_code}/play",
             "/endgames/#{advanced.public_code}/play"
           ]

    board = LazyHTML.text(LazyHTML.query(document, ".board-caption"))
    assert board =~ daily.key

    for theme <- daily.themes do
      assert board =~ theme.name
    end

    assert LazyHTML.text(LazyHTML.query(document, ".board-topline")) =~ "White"
    assert html =~ "Try today's puzzle"
    assert html =~ "Begin with the basics"
    assert html =~ "<span>puzzles</span>"
  end

  test "hero and progress CTAs link to the daily puzzle", %{conn: conn} do
    curated!()
    daily = DailyPuzzles.today()

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)
    play_path = "/endgames/#{daily.public_code}/play"

    assert LazyHTML.attribute(LazyHTML.query(document, ".hero-actions a"), "href") == [play_path]

    assert LazyHTML.attribute(LazyHTML.query(document, ".progress-banner a"), "href") == [
             play_path
           ]

    refute html =~ "/endgames//play"
  end

  test "shows the same daily puzzle across requests", %{conn: conn} do
    curated!()
    daily = DailyPuzzles.today()

    first = conn |> get(~p"/") |> html_response(200)
    second = conn |> get(~p"/") |> html_response(200)

    for html <- [first, second] do
      board = LazyHTML.text(LazyHTML.query(LazyHTML.from_document(html), ".board-caption"))
      assert board =~ daily.key
    end
  end

  test "renders without endgames", %{conn: conn} do
    Application.put_env(:chesstrainer, :curated_endgame_codes, [])

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert html =~ "Featured position"
    assert html =~ "<span>puzzles</span>"
    refute html =~ "puzzle-card"

    assert LazyHTML.attribute(LazyHTML.query(document, ".hero-actions a"), "href") == [
             "/endgames"
           ]

    assert LazyHTML.attribute(LazyHTML.query(document, ".progress-banner a"), "href") == [
             "/endgames"
           ]
  end
end
