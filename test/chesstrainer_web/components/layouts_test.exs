defmodule ChesstrainerWeb.LayoutsTest do
  use ChesstrainerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Branding
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
      refute html =~ ~s(href="/endgames")
    end

    test "any signed-in user gets the endgame library link" do
      for plan <- [:free, :premium] do
        scope = Scope.for_user(%User{username: "alice", plan: plan})

        html = render_component(&Layouts.navbar/1, %{current_scope: scope})

        assert html =~ ~s(href="/endgames")
      end
    end

    test "renders the utility controls in both the bar and the mobile menu" do
      html = render_component(&Layouts.navbar/1, %{current_scope: nil})

      assert html =~ ~s(class="nav-menu-tools")
      # One copy for the bar, one for the collapsible menu; CSS shows one.
      assert length(String.split(html, ~s(role="radiogroup"))) == 3
      assert length(String.split(html, ~s(class="discord-link"))) == 3
    end
  end

  describe "discord_link/1" do
    setup do
      previous = Application.get_env(:chesstrainer, :branding)
      on_exit(fn -> restore_env(:branding, previous) end)
      :ok
    end

    test "renders an icon-only link to the configured invite" do
      html = render_component(&Layouts.discord_link/1, %{})

      assert html =~ ~s(href="#{Branding.discord_invite_url()}")
      assert html =~ ~s(aria-label="Join the #{Branding.name()} Discord")
      assert html =~ ~s(target="_blank")
      assert html =~ "noopener noreferrer"
      assert html =~ ~r/<a[^>]*class="discord-link"[^>]*>\s*<svg/
    end

    test "is rendered by the navbar and the footer" do
      navbar = render_component(&Layouts.navbar/1, %{current_scope: nil})
      assert navbar =~ ~s(class="discord-link")

      footer = render_component(&Layouts.footer/1, %{})
      assert footer =~ ~s(class="discord-link")
    end

    test "renders nothing when no invite is configured" do
      Application.put_env(
        :chesstrainer,
        :branding,
        Keyword.put(Application.get_env(:chesstrainer, :branding, []), :discord_invite, "")
      )

      html = render_component(&Layouts.discord_link/1, %{})

      refute html =~ "discord-link"
    end
  end

  describe "colour_mode_toggle/1" do
    test "renders light and dark modes as a labelled radiogroup" do
      html = render_component(&Layouts.colour_mode_toggle/1, %{})

      assert html =~ ~s(role="radiogroup")
      assert html =~ ~s(aria-label="Colour mode")

      for {mode, label} <- [
            {"light", "Light colour mode"},
            {"dark", "Dark colour mode"}
          ] do
        assert html =~ ~s(data-phx-theme="#{mode}")
        assert html =~ ~s(aria-label="#{label}")
        assert html =~ ~s(role="radio")
      end

      refute html =~ ~s(data-phx-theme="system")
      assert html =~ ~s(aria-checked="true")
    end

    test "is rendered by the navbar" do
      html = render_component(&Layouts.navbar/1, %{current_scope: nil})

      assert html =~ ~s(aria-label="Colour mode")
      assert html =~ ~s(class="nav-right")
    end
  end

  describe "pill button" do
    test "renders the navigation call to action as a link" do
      html = render_component(&Layouts.navbar/1, %{current_scope: nil})

      assert html =~ ~r/<a[^>]*class="nav-cta"/
      refute html =~ ~r/<button[^>]*class="nav-cta"/
    end
  end

  describe "analytics/1" do
    setup do
      previous = Application.get_env(:chesstrainer, :matomo)
      on_exit(fn -> restore_env(:matomo, previous) end)
      :ok
    end

    test "renders the Matomo config for anonymous visitors" do
      Application.put_env(:chesstrainer, :matomo,
        url: "https://analytics.owenrees.eu/",
        site_id: "6"
      )

      html = render_component(&Layouts.analytics/1, %{current_scope: nil})

      assert html =~ ~s(id="matomo-config")
      assert html =~ ~s(data-url="https://analytics.owenrees.eu/")
      assert html =~ ~s(data-site-id="6")
    end

    test "does not render for signed-in users" do
      Application.put_env(:chesstrainer, :matomo,
        url: "https://analytics.owenrees.eu/",
        site_id: "6"
      )

      scope = Scope.for_user(%User{username: "alice"})
      html = render_component(&Layouts.analytics/1, %{current_scope: scope})

      refute html =~ ~s(id="matomo-config")
    end

    test "does not render when Matomo is unconfigured" do
      Application.delete_env(:chesstrainer, :matomo)

      html = render_component(&Layouts.analytics/1, %{current_scope: nil})

      refute html =~ ~s(id="matomo-config")
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chesstrainer, key)
  defp restore_env(key, value), do: Application.put_env(:chesstrainer, key, value)
end
