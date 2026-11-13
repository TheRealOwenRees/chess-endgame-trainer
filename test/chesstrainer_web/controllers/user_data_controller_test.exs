defmodule ChesstrainerWeb.UserDataControllerTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts

  setup %{conn: conn} do
    user = user_fixture()
    endgame = endgame_fixture()
    {:ok, _attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

    %{conn: log_in_user(conn, user), user: user, endgame: endgame}
  end

  test "redirects anonymous visitors to log in" do
    conn = build_conn() |> get(~p"/users/profile/export/csv")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "returns the styled 404 page for an unknown format", %{conn: conn} do
    conn = get(conn, ~p"/users/profile/export/xml")

    html = html_response(conn, 404)
    assert html =~ "This page isn&#39;t on the board"
    assert html =~ "Back to home"
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
  end

  test "downloads the user details and attempts as CSV", %{
    conn: conn,
    user: user,
    endgame: endgame
  } do
    conn = get(conn, ~p"/users/profile/export/csv")

    assert response(conn, 200) =~
             "user_username,user_email,user_rating,user_rating_deviation,user_plan,user_joined_at," <>
               "played_at,puzzle,public_code,color,result,outcome,rated_at"

    assert response(conn, 200) =~ user.username
    assert response(conn, 200) =~ user.email
    assert response(conn, 200) =~ to_string(user.rating)
    assert response(conn, 200) =~ endgame.key
    assert response(conn, 200) =~ "solved"

    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    assert get_resp_header(conn, "content-disposition") == [
             ~s(attachment; filename="lucid-chess-data-#{Date.utc_today()}.csv")
           ]
  end

  test "downloads the user details and attempts as JSON", %{
    conn: conn,
    user: user,
    endgame: endgame
  } do
    conn = get(conn, ~p"/users/profile/export/json")

    body = Jason.decode!(response(conn, 200))

    assert %{
             "user" => %{
               "username" => username,
               "email" => email,
               "rating" => 1500.0,
               "rating_deviation" => 350.0,
               "plan" => "free",
               "joined_at" => joined_at
             },
             "attempts" => [
               %{
                 "puzzle" => puzzle,
                 "public_code" => public_code,
                 "color" => "white",
                 "result" => "win",
                 "outcome" => "solved",
                 "rated_at" => nil
               }
             ]
           } = body

    assert username == user.username
    assert email == user.email
    assert is_binary(joined_at)
    assert puzzle == endgame.key
    assert public_code == endgame.public_code

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
  end

  test "includes user details when there are no attempts", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user) |> get(~p"/users/profile/export/csv")

    [header, row] =
      conn
      |> response(200)
      |> String.trim_trailing("\n")
      |> String.split("\n")

    assert header =~ "user_username"
    assert row =~ user.username
    assert row =~ user.email
  end

  test "only exports the signed-in user's attempts", %{conn: conn} do
    other = user_fixture()
    other_endgame = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
    {:ok, _} = Attempts.record_attempt(Scope.for_user(other), other_endgame, :failed)

    body = conn |> get(~p"/users/profile/export/json") |> response(200)

    refute body =~ other_endgame.public_code
  end
end
