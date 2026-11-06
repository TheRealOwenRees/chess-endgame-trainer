defmodule ChesstrainerWeb.ErrorHTMLTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Branding
  alias ChesstrainerWeb.ErrorHTML

  defp render(template, scope \\ nil) do
    Phoenix.Template.render_to_string(ErrorHTML, template, "html", %{current_scope: scope})
  end

  test "404 renders a complete document with the site chrome" do
    html = render("404")

    assert html =~ "<!DOCTYPE html>"
    assert html =~ "<title>#{Branding.title("Page not found")}</title>"
    assert html =~ ~s(class="error-code">404</span>)
    assert html =~ "The page you were looking for moved"
    assert html =~ ~s(class="site-footer")
    assert html =~ "/assets/js/marketing.js"
    refute html =~ ~s(name="csrf-token")
  end

  test "500 renders a complete document and the support address" do
    html = render("500")

    assert html =~ "<title>#{Branding.title("Something went wrong")}</title>"
    assert html =~ ~s(class="error-code">500</span>)
    assert html =~ "An unexpected error stopped this page"
    assert html =~ Branding.support_email()
    assert html =~ ~s(class="site-footer")
  end

  test "hides the puzzles link from guests and free users" do
    refute render("404") =~ "Browse puzzles"
    refute render("404", Scope.for_user(%User{plan: :free})) =~ "Browse puzzles"
  end

  test "shows the puzzles link to premium users" do
    html = render("404", Scope.for_user(%User{plan: :premium}))

    assert html =~ "Browse puzzles"
    assert html =~ ~s(href="/endgames")
  end

  test "unknown statuses fall back to the plain status message" do
    assert ErrorHTML.render("503.html", %{}) == "Service Unavailable"
  end
end
