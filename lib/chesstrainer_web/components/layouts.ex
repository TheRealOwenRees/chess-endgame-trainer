defmodule ChesstrainerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ChesstrainerWeb, :html

  alias Chesstrainer.Accounts.Role
  alias Chesstrainer.Accounts.Scope

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :wide, :boolean,
    default: false,
    doc: "use a wide container instead of the default narrow column"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main id="main-content" tabindex="-1" class="px-4 py-20 sm:px-6 lg:px-8">
      <div class={["mx-auto space-y-4", if(@wide, do: "max-w-7xl", else: "max-w-2xl")]}>
        {render_slot(@inner_block)}
      </div>
    </main>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the application navbar.

  The marketing and account links are defined once in `nav_links/1` and rendered
  in both the desktop bar and the mobile menu. Edit that list to change what
  appears in either place.
  """
  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  def navbar(assigns) do
    user = signed_in_user(assigns.current_scope)
    nav_links = nav_links(assigns.current_scope)
    prelaunch = ChesstrainerWeb.prelaunch?()

    assigns =
      assigns
      |> assign(:nav_links, nav_links)
      |> assign(:start_href, start_href(assigns.current_scope))
      |> assign(:user, user)
      |> assign(:prelaunch, prelaunch)
      |> assign(:show_nav, not prelaunch or not is_nil(user) or nav_links != [])

    ~H"""
    <header>
      <nav class="nav-wrap" aria-label="Main navigation">
        <a class="brand" href="/" aria-label={"#{Branding.name()} home"}>
          <span class="brand-mark">♞</span>
          <span>{Branding.wordmark()}</span>
        </a>

        <div class="nav-right">
          <.colour_mode_toggle />

          <%= if @show_nav do %>
            <button
              class="menu-button"
              type="button"
              aria-expanded="false"
              aria-controls="nav-links"
              aria-label="Toggle menu"
            >
              <span></span>
              <span></span>
            </button>

            <div class="nav-links" id="nav-links">
              <%= for link <- @nav_links do %>
                <.link href={link.href}>{link.label}</.link>
              <% end %>

              <%= if @user do %>
                <details class="nav-user-menu">
                  <summary>{@user.username}</summary>
                  <div class="nav-user-menu-panel">
                    <.link navigate={~p"/users/profile"}>Account</.link>
                    <.link navigate={~p"/users/profile/settings"}>Settings</.link>
                    <.link navigate={~p"/users/profile/data"}>Data</.link>
                    <.link href={~p"/users/log-out"} method="delete">Log out</.link>
                  </div>
                </details>
              <% else %>
                <%= if !@prelaunch do %>
                  <.link href={~p"/users/log-in"}>Log in</.link>
                  <.link href={~p"/users/register"}>Register</.link>
                <% end %>
              <% end %>

              <%= if !@prelaunch do %>
                <.pill_button variant={:nav} href={@start_href}>
                  Start training <.icon_arrow />
                </.pill_button>
              <% end %>
            </div>
          <% end %>
        </div>
      </nav>
    </header>
    """
  end

  defp nav_links(scope) do
    marketing =
      if Scope.premium?(scope) do
        [
          %{label: "Puzzle Search", href: "/endgames"}
        ]
      else
        []
      end

    admin =
      if admin?(scope) do
        [%{label: "Admin", href: ~p"/admin/endgames"}]
      else
        []
      end

    marketing ++ admin
  end

  defp signed_in_user(%{user: %{username: _} = user}), do: user
  defp signed_in_user(_scope), do: nil

  defp admin?(%{user: %{role: role}}), do: Role.admin?(role)
  defp admin?(_scope), do: false

  # Signed-in users start a puzzle session; visitors browse the public list.
  defp start_href(%{user: %{}}), do: ~p"/train"
  defp start_href(_scope), do: ~p"/guest-train"

  @doc """
  Renders the site-wide footer.

  Rendered once from the root layout so it appears on every page, matching the
  navbar. Links to the landing-page anchors keep working from other pages
  because they point at `/` first.
  """
  def footer(assigns) do
    assigns = assign(assigns, :year, DateTime.utc_now().year)

    ~H"""
    <footer class="site-footer">
      <div class="footer-brand">
        <a class="brand" href="/" aria-label={"#{Branding.name()} home"}>
          <span class="brand-mark">♞</span>
          <span>{Branding.wordmark()}</span>
        </a>
        <p>Short, focused endgame training.</p>
      </div>

      <nav class="footer-links" aria-label="Footer">
        <a href="/privacy">Privacy Policy</a>
        <a href="/terms-conditions">Terms & Conditions</a>
      </nav>

      <small>© {@year} {Branding.name()}</small>
    </footer>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed right-4 top-4 z-50 flex w-80 max-w-80 flex-col gap-2 sm:w-96 sm:max-w-96"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides the light / dark colour-mode switch.

  With no saved preference the page follows the OS setting; only the explicit
  light and dark modes are selectable here.

  The click handling and `aria-checked` syncing live in `theme_script.html.heex`,
  which runs before paint and also on pages without LiveView (the landing page
  uses the marketing bundle). Error pages include it explicitly because they do
  not render through the root layout.
  """
  def colour_mode_toggle(assigns) do
    ~H"""
    <div
      class="relative flex flex-row items-center rounded-full border-2 border-base-300 bg-base-300"
      role="radiogroup"
      aria-label="Colour mode"
    >
      <div
        class="absolute w-1/2 h-full rounded-full border border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=dark]_&]:left-1/2 transition-[left]"
        aria-hidden="true"
      >
      </div>

      <button
        type="button"
        class="flex p-2 cursor-pointer w-1/2 justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        data-phx-theme="light"
        role="radio"
        aria-checked="true"
        aria-label="Light colour mode"
        tabindex="0"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        class="flex p-2 cursor-pointer w-1/2 justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        data-phx-theme="dark"
        role="radio"
        aria-checked="false"
        aria-label="Dark colour mode"
        tabindex="-1"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
