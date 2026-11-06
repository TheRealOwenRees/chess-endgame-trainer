defmodule ChesstrainerWeb.LayoutsTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias ChesstrainerWeb.Layouts

  describe "navbar/1" do
    test "signed-in users get a profile menu" do
      scope = Scope.for_user(%User{username: "alice"})

      html = render_component(&Layouts.navbar/1, %{current_scope: scope})

      assert html =~ "alice"
      assert html =~ ~s(class="nav-user-menu")
      assert html =~ ~p"/users/profile"
      assert html =~ ~p"/users/profile/settings"
      assert html =~ ~p"/users/profile/data"
      assert html =~ ~p"/users/log-out"
    end

    test "guests get log in and register links" do
      html = render_component(&Layouts.navbar/1, %{current_scope: nil})

      assert html =~ ~p"/users/log-in"
      assert html =~ ~p"/users/register"
      refute html =~ ~s(class="nav-user-menu")
    end
  end

  describe "colour_mode_toggle/1" do
    test "renders all three modes as a labelled radiogroup" do
      html = render_component(&Layouts.colour_mode_toggle/1, %{})

      assert html =~ ~s(role="radiogroup")
      assert html =~ ~s(aria-label="Colour mode")

      for {mode, label} <- [
            {"system", "System colour mode"},
            {"light", "Light colour mode"},
            {"dark", "Dark colour mode"}
          ] do
        assert html =~ ~s(data-phx-theme="#{mode}")
        assert html =~ ~s(aria-label="#{label}")
        assert html =~ ~s(role="radio")
      end

      assert html =~ ~s(aria-checked="true")
    end

    test "is rendered by the navbar" do
      html = render_component(&Layouts.navbar/1, %{current_scope: nil})

      assert html =~ ~s(aria-label="Colour mode")
      assert html =~ ~s(class="nav-right")
    end
  end
end
