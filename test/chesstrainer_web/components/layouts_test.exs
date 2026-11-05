defmodule ChesstrainerWeb.LayoutsTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ChesstrainerWeb.Layouts

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
