defmodule ChesstrainerWeb.Admin.UserLive.IndexTest do
  use ChesstrainerWeb.ConnCase

  import Phoenix.LiveViewTest
  import Chesstrainer.AccountsFixtures

  alias Chesstrainer.Accounts

  setup :register_and_log_in_admin

  test "lists the users an admin may manage", %{conn: conn} do
    member = user_fixture()
    moderator = user_with_role(:moderator)
    other_admin = user_with_role(:admin)
    super_admin = user_with_role(:super_admin)

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    assert has_element?(view, "#user-" <> member.id)
    assert has_element?(view, "#user-" <> moderator.id)
    refute has_element?(view, "#user-" <> other_admin.id)
    refute has_element?(view, "#user-" <> super_admin.id)
  end

  test "searches by email or username", %{conn: conn} do
    target = user_fixture(%{email: "FindMe@Example.com", username: "searchable_name"})
    user_fixture()

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    view |> form("#admin-user-search-form", %{search: "findme"}) |> render_change()

    assert has_element?(view, "#user-" <> target.id)
    assert has_element?(view, "td", target.email)

    view |> form("#admin-user-search-form", %{search: "searchable"}) |> render_change()
    assert has_element?(view, "#user-" <> target.id)

    view |> form("#admin-user-search-form", %{search: "nobody"}) |> render_change()
    assert render(view) =~ "No users match"
  end

  test "paginates 25 users per page", %{conn: conn} do
    for _ <- 1..26 do
      user_fixture()
    end

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    assert row_count(view) == 25
    assert render(view) =~ "Page 1 of 2"

    view |> element("#next-page") |> render_click()

    assert row_count(view) == 1
    assert render(view) =~ "Page 2 of 2"
  end

  test "shows the admin navigation and invite action", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/admin/users")

    assert html =~ ~p"/admin/endgames"
    assert html =~ ~p"/admin/themes"
    assert html =~ ~p"/admin/users/new"
    assert has_element?(view, "#admin-user-search-form")
  end

  defp row_count(view) do
    document = LazyHTML.from_fragment(render(view))
    document |> LazyHTML.query("#admin-users tr") |> LazyHTML.to_tree() |> length()
  end

  defp user_with_role(role) do
    {:ok, user} = Accounts.update_user_role(user_fixture(), role)
    user
  end
end
