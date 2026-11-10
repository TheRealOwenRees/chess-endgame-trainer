defmodule ChesstrainerWeb.PageControllerTest do
  use ChesstrainerWeb.ConnCase

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.Branding
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
    assert html =~ Branding.wordmark()
    assert html =~ "Privacy Policy"
    assert html =~ "/terms-conditions"
    assert html =~ "Start training"
    assert html =~ ~s(id="nav-links")
    assert html =~ "menu-button"
    assert html =~ ~s(class="site-footer")
    assert html =~ "© #{DateTime.utc_now().year} #{Branding.name()}"
    assert html =~ ~p"/endgames"
    assert html =~ "/assets/js/marketing.js"
    refute html =~ "/assets/js/app.js"

    assert LazyHTML.text(LazyHTML.query(document, "title")) =~ Branding.home_title()
    refute html =~ "Phoenix Framework"

    eyebrow = LazyHTML.query(document, ".eyebrow")
    assert LazyHTML.text(eyebrow) =~ "Endgames, simplified"
    assert LazyHTML.attribute(LazyHTML.query(eyebrow, "svg"), "aria-hidden") == ["true"]

    assert LazyHTML.attribute(LazyHTML.query(document, ~s(meta[name="description"])), "content") ==
             [@description]

    assert [canonical] =
             LazyHTML.attribute(LazyHTML.query(document, ~s(link[rel="canonical"])), "href")

    assert URI.parse(canonical).path == "/"

    for {selector, content} <- [
          {~s(meta[property="og:type"]), "website"},
          {~s(meta[property="og:site_name"]), Branding.name()},
          {~s(meta[property="og:title"]), Branding.home_title()},
          {~s(meta[property="og:description"]), @description},
          {~s(meta[property="og:url"]), canonical},
          {~s(meta[name="twitter:card"]), "summary"},
          {~s(meta[name="twitter:title"]), Branding.home_title()},
          {~s(meta[name="twitter:description"]), @description}
        ] do
      assert LazyHTML.attribute(LazyHTML.query(document, selector), "content") == [content]
    end
  end

  test "GET /privacy renders the privacy policy", %{conn: conn} do
    html = conn |> get(~p"/privacy") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert LazyHTML.text(LazyHTML.query(document, "h1")) == "Privacy Policy"
    assert html =~ "Last updated: 10 November 2026"
    assert html =~ "What we collect"
    assert html =~ "Cookies and local storage"
    assert html =~ "Analytics"
    assert html =~ "self-hosted Matomo"
    assert html =~ "without cookies"
    assert html =~ ~s(id="analytics-opt-out")
    assert html =~ "Guest puzzle limit"
    assert html =~ "HMAC-SHA256"
    assert html =~ "Article 6(1)(f) GDPR"
    assert html =~ "Hosting and infrastructure"
    assert html =~ "Cloudflare"
    assert html =~ "Data controller"
    assert html =~ "suppression list"
    refute html =~ "not directed at children"

    assert LazyHTML.text(LazyHTML.query(document, "title")) ==
             Branding.title("Privacy Policy")

    assert [canonical] =
             LazyHTML.attribute(LazyHTML.query(document, ~s(link[rel="canonical"])), "href")

    assert URI.parse(canonical).path == "/privacy"
  end

  test "GET /terms-conditions renders the terms", %{conn: conn} do
    html = conn |> get(~p"/terms-conditions") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert LazyHTML.text(LazyHTML.query(document, "h1")) == "Terms & Conditions"
    assert html =~ "Last updated: 10 November 2026"
    assert html =~ "Acceptable use"
    assert html =~ "Governing law"
    assert html =~ "fixed number of puzzles per UTC day"
    assert html =~ "consent of a parent or guardian"
    assert html =~ ~p"/privacy"

    assert LazyHTML.text(LazyHTML.query(document, "title")) ==
             Branding.title("Terms & Conditions")

    assert [canonical] =
             LazyHTML.attribute(LazyHTML.query(document, ~s(link[rel="canonical"])), "href")

    assert URI.parse(canonical).path == "/terms-conditions"
  end

  test "GET /mentions-legales renders the French legal notice", %{conn: conn} do
    html = conn |> get(~p"/mentions-legales") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert LazyHTML.text(LazyHTML.query(document, "h1")) == "Mentions légales"
    assert html =~ "Owen REES"
    assert html =~ "929"
    assert html =~ "293 B"
    assert html =~ "Hetzner Online GmbH"
    assert html =~ "Directeur de la publication"
    assert html =~ ~p"/privacy"

    assert LazyHTML.text(LazyHTML.query(document, "title")) ==
             Branding.title("Mentions légales")

    assert [canonical] =
             LazyHTML.attribute(LazyHTML.query(document, ~s(link[rel="canonical"])), "href")

    assert URI.parse(canonical).path == "/mentions-legales"
  end

  test "branding is read from application config", %{conn: conn} do
    previous = Application.get_env(:chesstrainer, :branding)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:chesstrainer, :branding, previous),
        else: Application.delete_env(:chesstrainer, :branding)
    end)

    Application.put_env(:chesstrainer, :branding,
      name: "Test Brand",
      wordmark: "TEST",
      tagline: "Trainer",
      support_email: "help@test.example"
    )

    html = conn |> get(~p"/privacy") |> html_response(200)

    assert html =~ "Privacy Policy — Test Brand"
    assert html =~ "Test Brand is an endgame training site"
    assert html =~ "help@test.example"
    assert html =~ ~s(content="Test Brand")
  end

  test "hero shows the number of users with a valid session", %{conn: conn} do
    user = user_fixture()
    _token = Accounts.generate_user_session_token(user)

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert LazyHTML.text(LazyHTML.query(document, ".rating-note strong")) == "1"
  end

  test "hero does not count users who have only trained", %{conn: conn} do
    user = user_fixture()
    endgame = endgame_fixture()
    {:ok, _} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert LazyHTML.text(LazyHTML.query(document, ".rating-note strong")) == "0"
  end

  test "renders the coming soon page while prelaunch is on", %{conn: conn} do
    previous = Application.get_env(:chesstrainer, :prelaunch)
    on_exit(fn -> restore_env(:prelaunch, previous) end)
    Application.put_env(:chesstrainer, :prelaunch, true)

    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "coming soon"
    assert html =~ "Master the"
    refute html =~ "Try today"
  end

  test "hides the mailing list when it is disabled", %{conn: conn} do
    previous = Application.get_env(:chesstrainer, :mailing_list_enabled)
    on_exit(fn -> restore_env(:mailing_list_enabled, previous) end)
    Application.put_env(:chesstrainer, :mailing_list_enabled, false)

    html = conn |> get(~p"/") |> html_response(200)

    refute html =~ ~s(id="mailing-list-form")
    refute html =~ "Join the list"
  end

  test "renders the mailing list signup form", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    form = LazyHTML.query(document, "#mailing-list-form")
    assert LazyHTML.attribute(form, "action") == ["/mailing-list"]
    assert LazyHTML.attribute(form, "method") == ["post"]

    input = LazyHTML.query(document, "#mailing-list-email")
    assert LazyHTML.attribute(input, "type") == ["email"]
    assert LazyHTML.attribute(input, "name") == ["subscriber[email]"]

    assert html =~ "Join the list"
    assert html =~ ~s(name="_csrf_token")
    assert html =~ ~s(name="subscriber[form_token]")
    assert html =~ ~s(id="mailing-list-company")
    assert html =~ ~s(class="mailing-list-honeypot")
  end

  test "guest navbar links to log in and register", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~p"/users/log-in"
    assert html =~ ~p"/users/register"
    refute html =~ ~p"/users/profile"
  end

  test "signed-in navbar links to the profile and log out", %{conn: conn} do
    html =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~p"/users/profile"
    assert html =~ ~p"/users/log-out"
    refute html =~ ~p"/users/register"
  end

  test "renders the daily board", %{conn: conn} do
    curated!()
    daily = DailyPuzzles.today()

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)

    board = LazyHTML.text(LazyHTML.query(document, ".board-caption"))
    assert board =~ daily.key

    for theme <- daily.themes do
      assert board =~ theme.name
    end

    assert LazyHTML.text(LazyHTML.query(document, ".board-topline")) =~ "White"
    assert html =~ "Try today's puzzle"
  end

  test "hero CTA links to the daily puzzle", %{conn: conn} do
    curated!()
    daily = DailyPuzzles.today()

    html = conn |> get(~p"/") |> html_response(200)
    document = LazyHTML.from_document(html)
    play_path = "/endgames/#{daily.public_code}/play"

    assert LazyHTML.attribute(LazyHTML.query(document, ".hero-actions a"), "href") == [play_path]

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
    refute html =~ "puzzle-card"

    assert LazyHTML.attribute(LazyHTML.query(document, ".hero-actions a"), "href") == [
             "/endgames"
           ]
  end

  test "unknown routes render the branded 404 page", %{conn: conn} do
    html = conn |> get("/this-page-does-not-exist") |> html_response(404)
    document = LazyHTML.from_document(html)

    assert LazyHTML.text(LazyHTML.query(document, "title")) == Branding.title("Page not found")
    assert LazyHTML.text(LazyHTML.query(document, ".error-code")) == "404"
    assert html =~ "The page you were looking for moved"
    refute html =~ "Browse puzzles"
    assert html =~ ~s(class="site-footer")
    assert html =~ "/assets/js/marketing.js"
    assert html =~ ~s(name="robots")
  end

  test "premium users see the puzzles link on the 404 page", %{conn: conn} do
    {:ok, user} =
      user_fixture()
      |> Ecto.Changeset.change(plan: :premium)
      |> Chesstrainer.Repo.update()

    html =
      conn
      |> log_in_user(user)
      |> get("/this-page-does-not-exist")
      |> html_response(404)

    assert html =~ "Browse puzzles"
    assert html =~ ~s(href="/endgames")
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
